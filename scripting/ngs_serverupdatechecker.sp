//  Automatic Steam Update (SteamWorks) (C) 2014-2014 , 2014-2018 TheXeon <thexeon@neogenesisnetwork.net>
//
//  Automatic Server Update Checker (SteamWorks) is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, per version 3 of the License.
//
//  Automatic Server Update Checker (SteamWorks) is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Automatic Server Update Checker (SteamWorks). If not, see <http://www.gnu.org/licenses/>.
//
//  This file is based off work(s) covered by the following copyright(s):
//
//   [TF2] Automatic Steam Update
//   Copyright (C) 2011-2012 Dr. McKay
//   Licensed under GNU GPL version 3
//   Page: <https://forums.alliedmods.net/showthread.php?t=170532>]
//
//   [ANY] Automatic Steam Update (SteamWorks)
//   Copyright (C) Sarabveer Singh <me@sarabveer.me>
//   Licensed under GNU GPL version 3
//   Page: <https://forums.alliedmods.net/showthread.php?p=2238058>]

/**
* TheXeon
* ngs_serverupdatechecker.sp
*
* Files:
* addons/sourcemod/plugins/ngs_serverupdatechecker.smx
* addons/sourcemod/data/tf2idbupdate.sh (if on TF2, Unix, and using tf2idb)
* cfg/sourcemod/serverupdatechecker.cfg
*
* Dependencies:
* sdktools.inc, system2.inc, afk_manager.inc, ngsutils.inc, ngsupdater.inc,
* SteamWorks.inc
*/

#pragma newdecls required
#pragma semicolon 1

#define ALL_PLUGINS_LOADED_FUNC AllPluginsLoaded
#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <sdktools>
#include <system2>
#include <afk_manager>
#include <ngsutils>
#include <ngsupdater>
#include <SteamWorks>

#define ALERT_SOUND "ui/system_message_alert.wav"

// #define DEBUG

ConVar delayCvar, timerCvar, messageTimeCvar, lockCvar, passwordCvar, kickMessageCvar, shutdownMessageCvar;
ConVar hudXCvar, hudYCvar, hudRCvar, hudGCvar, hudBCvar;

SMTimer restartTimer;

bool suspendPlugin = false;
int timeRemaining = 0;
bool disallowPlayers = false;
char originalPassword[255];

bool isTF = false;

Handle hudText;
ConVar sv_password;

public Plugin myinfo = {
	name        = "Automatic Server Update Checker (SteamWorks)",
	author      = "Dr. McKay, Sarabveer(VEER™), TheXeon",
	description = "Automagically restarts the server to update via Steam",
	version     = "1.0.4",
	url         = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	AutoExecConfig(true, "serverupdatechecker");
	isTF = (GetEngineVersion() == Engine_TF2);

	delayCvar = CreateConVar("auto_steam_update_delay", "5", "How long in minutes the server should wait before starting another countdown after being postponed.");
	timerCvar = CreateConVar("auto_steam_update_timer", "5", "How long in minutes the server should count down before restarting.");
	messageTimeCvar = CreateConVar("auto_steam_update_message_display_time", "5", "At how much time in minutes left on the timer should the timer be displayed?");
	lockCvar = CreateConVar("auto_steam_update_lock", "0", "0 - don't lock the server / 1 - set sv_password to auto_steam_update_password during timer / 2 - don't set a password, but kick everyone who tries to connect during the timer");
	passwordCvar = CreateConVar("auto_steam_update_password", "", "The password to set sv_password to if auto_steam_update_lock = 1", FCVAR_PROTECTED);
	kickMessageCvar = CreateConVar("auto_steam_update_kickmessage", "The server will shut down soon to acquire Steam updates, so no new connections are allowed", "The message to display to kicked clients if auto_steam_update_lock = 2");
	shutdownMessageCvar = CreateConVar("auto_steam_update_shutdown_message", "Server shutting down for Steam update", "The message displayed to clients when the server restarts");
	hudXCvar = CreateConVar("auto_steam_update_hud_text_x_pos", "0.01", "X-position for HUD timer (only on supported games) -1 = center", _, true, -1.0, true, 1.0);
	hudYCvar = CreateConVar("auto_steam_update_hud_text_y_pos", "0.01", "Y-position for HUD timer (only on supported games) -1 = center", _, true, -1.0, true, 1.0);
	hudRCvar = CreateConVar("auto_steam_update_hud_text_red", "0", "Amount of red for the HUD timer (only on supported games)", _, true, 0.0, true, 255.0);
	hudGCvar = CreateConVar("auto_steam_update_hud_text_green", "255", "Amount of red for the HUD timer (only on supported games)", _, true, 0.0, true, 255.0);
	hudBCvar = CreateConVar("auto_steam_update_hud_text_blue", "0", "Amount of red for the HUD timer (only on supported games)", _, true, 0.0, true, 255.0);

	sv_password = FindConVar("sv_password");

	RegAdminCmd("sm_postponeupdate", Command_PostponeUpdate, ADMFLAG_RCON, "Postpone a pending server restart for a Steam update");
	RegAdminCmd("sm_updatetimer", Command_ForceRestart, ADMFLAG_RCON, "Force the server update timer to start immediately");

	hudText = CreateHudSynchronizer();
	if(hudText == null)
	{
		LogMessage("HUD text is not supported on this mod. The persistant timer will not display.");
	}
	else
	{
		LogMessage("HUD text is supported on this mod. The persistant timer will display.");
	}
}

public void AllPluginsLoaded()
{
	if (isTF)
	{
		#if defined DEBUG
		PrintToServer("Game is TF2, utilizing tf2idb capabilities if existing!");
		#endif
		CheckForTF2IDBUpdate();
	}
}

public void OnMapStart()
{
	if(isTF)
	{
		PrecacheSound(ALERT_SOUND); // this sound is in TF2 only
	}
}

public void OnClientPostAdminCheck(int client)
{
	if(CheckCommandAccess(client, "BypassAutoSteamUpdateDisallow", ADMFLAG_GENERIC, true))
	{
		return;
	}
	if(disallowPlayers)
	{
		char kickMessage[255];
		kickMessageCvar.GetString(kickMessage, sizeof(kickMessage));
		KickClient(client, kickMessage);
	}
}

public Action SteamWorks_RestartRequested()
{
	startTimer();
	return Plugin_Continue;
}

public Action Command_ForceRestart(int client, int args)
{
	suspendPlugin = false;
	LogAction(client, -1, "%L manually triggered an update timer", client);
	startTimer(true);
	return Plugin_Handled;
}

void startTimer(bool forced = false) {
	if(suspendPlugin)
	{
		return;
	}
	if (isTF && System2_GetOS() == OS_UNIX)
	{
		char path[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, path, sizeof(path), "data/tf2idbrequested");
		if (!FileExists(path))
		{
			System2_ExecuteFormattedThreaded(TF2IDBUpdateCallback, 0, "touch tf/%s", path);
		}
	}
	if(!IsServerPopulated(true))
	{ // If there's no active clients in the server, go ahead and restart it
		LogMessage("Received a master server restart request, and there are no players in the server. Restarting to update.");
		ServerCommand("_restart");
		return;
	}
	switch (lockCvar.IntValue)
	{
		case 1:
		{
			char password[255];
			passwordCvar.GetString(password, sizeof(password));
			sv_password.GetString(originalPassword, sizeof(originalPassword));
			sv_password.SetString(password);
		}
		case 2:
		{
			disallowPlayers = true;
		}
	}
	if(!forced)
	{
		LogMessage("Received a master server restart request, beginning restart timer.");
	}
	timeRemaining = timerCvar.IntValue * 60;
	timeRemaining++;
	restartTimer = new SMTimer(1.0, DoTimer, _, TIMER_REPEAT);
	suspendPlugin = true;
	return;
}

void CheckForTF2IDBUpdate()
{
	if (System2_GetOS() == OS_UNIX && LibraryExists("tf2idb"))
	{
		char path[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, path, sizeof(path), "data/tf2idbrequested");
		if (FileExists(path))
		{
			System2_ExecuteFormattedThreaded(TF2IDBUpdateCallback, 0, "rm tf/%s", path);
			BuildPath(Path_SM, path, sizeof(path), "data/tf2idbupdate.sh");
			if (!FileExists(path))
			{
				LogError("You are missing file %s, please get it from the repo! Aborting TF2IDB update, run it manually!", path);
				return;
			}
			System2_ExecuteFormattedThreaded(TF2IDBUpdateCallback, 0, "./tf/%s", path);
		}
	}
	#if defined DEBUG
	else
	{
		PrintToServer("Stuff still failed.\nSystem is%s Unix!", (System2_GetOS() == OS_UNIX) ? "" : " not");
		PrintToServer("TF2IDB is%s available.", (LibraryExists("tf2idb")) ? "" : " not");
	}
	#endif
}

public void TF2IDBUpdateCallback(bool success, const char[] command, System2ExecuteOutput output, any data) {
	if (!success || output.ExitStatus != 0)
	{
		LogError("Couldn't execute command %s successfully!", command);
  }
	if (StrContains(command, "tf2idbupdate.sh") != -1)
	{
		ServerCommand("sm plugins reload tf2idb");
		LogMessage("Successfully ran tf2idbupdate.sh, reloaded tf2idb.smx with new db!");
	}
}

public Action DoTimer(Handle timer)
{
	timeRemaining--;
	if(timeRemaining <= -1)
	{
		LogMessage("Restarting server for Steam update.");
		char kickMessage[255];
		shutdownMessageCvar.GetString(kickMessage, sizeof(kickMessage));
		for(int i = 1; i <= MaxClients; i++) {
			if (!IsValidClient(i))
			{
				continue;
			}
			KickClient(i, kickMessage);
		}
		ServerCommand("_restart");
		restartTimer = null;
		return Plugin_Stop;
	}
	if(timeRemaining / 60 <= GetConVarInt(messageTimeCvar)) {
		if(hudText != null) {
			SetHudTextParams(hudXCvar.FloatValue, hudYCvar.FloatValue, 1.0, GetConVarInt(hudRCvar), GetConVarInt(hudGCvar), GetConVarInt(hudBCvar), 255);
			ShowSyncHudTextAll(hudText, "Update: %i:%02i", timeRemaining / 60, timeRemaining % 60);
		}
		if(timeRemaining > 60 && timeRemaining % 60 == 0) {
			PrintHintTextToAll("A game update has been released.\nThis server will shut down to update in %i minutes.", timeRemaining / 60);
			PrintToServer("[SM] A game update has been released. This server will shut down to update in %i minutes.", timeRemaining / 60);
			if(isTF) {
				EmitSoundToAll(ALERT_SOUND);
			}
		}
		if(timeRemaining == 60) {
			PrintHintTextToAll("A game update has been released.\nThis server will shut down to update in 1 minute.");
			PrintToServer("[SM] A game update has been released. This server will shut down to update in 1 minute.");
			if(isTF) {
				EmitSoundToAll(ALERT_SOUND);
			}
		}
	}
	if(timeRemaining <= 60 && hudText == null) {
		PrintCenterTextAll("Update: %i:%02i", timeRemaining / 60, timeRemaining % 60);
	}
	return Plugin_Continue;
}

public Action Command_PostponeUpdate(int client, int args)
{
	if(restartTimer == null)
	{
		ReplyToCommand(client, "[SM] There is no update timer currently running.");
		return Plugin_Handled;
	}
	delete restartTimer;
	LogAction(client, -1, "%L aborted the update timer.", client);
	float delay = delayCvar.IntValue * 60.0;
	SMTimer.Make(delay, ReenablePlugin);
	int minutesCancelled = delayCvar.IntValue;
	ReplyToCommand(client, "[SM] The update timer has been cancelled for %i minutes.", minutesCancelled);
	PrintHintTextToAll("The update timer has been cancelled for %i minutes.", minutesCancelled);
	disallowPlayers = false;
	if(lockCvar.IntValue)
	{
		sv_password.SetString(originalPassword);
	}
	return Plugin_Handled;
}

public Action ReenablePlugin(Handle timer)
{
	suspendPlugin = false;
}
