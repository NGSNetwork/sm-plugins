//  Automatic Steam Update (SteamWorks) (C) 2014-2014 Sarabveer Singh <me@sarabveer.me>
//  
//  Automatic Steam Update (SteamWorks) is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, per version 3 of the License.
//  
//  Automatic Steam Update (SteamWorks) is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//  
//  You should have received a copy of the GNU General Public License
//  along with Automatic Steam Update (SteamWorks). If not, see <http://www.gnu.org/licenses/>.
//
//  This file is based off work(s) covered by the following copyright(s):   
//
//   [TF2] Automatic Steam Update
//   Copyright (C) 2011-2012 Dr. McKay
//   Licensed under GNU GPL version 3
//   Page: <https://forums.alliedmods.net/showthread.php?t=170532>]
//

#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <SteamWorks>

#undef REQUIRE_PLUGIN
#tryinclude <updater>

#define UPDATE_URL    "https://raw.githubusercontent.com/Sarabveer/SM-Plugins/master/sw_auto_steam_update/updater.txt"
#define PLUGIN_VERSION "1.1"

#define ALERT_SOUND "ui/system_message_alert.wav"

ConVar delayCvar, timerCvar, messageTimeCvar, lockCvar, passwordCvar, kickMessageCvar, shutdownMessageCvar;
ConVar hudXCvar, hudYCvar, hudRCvar, hudGCvar, hudBCvar, updaterCvar;

Handle restartTimer;

bool suspendPlugin = false;
int timeRemaining = 0;
bool disallowPlayers = false;
char originalPassword[255];

bool isTF = false;

Handle hudText;
ConVar sv_password;

public Plugin myinfo = {
	name        = "Automatic Steam Update (SteamWorks)",
	author      = "Dr. McKay, Sarabveer(VEER™), TheXeon",
	description = "Automatically restarts the server to update via Steam",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	MarkNativeAsOptional("Updater_AddPlugin"); 
	return APLRes_Success;
} 

public void OnPluginStart() {
	AutoExecConfig(true, "plugin.autosteamupdate");
	
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
	updaterCvar = CreateConVar("auto_steam_update_auto_update", "1", "Enables automatic plugin updating (has no effect if Updater is not installed)");
	
	sv_password = FindConVar("sv_password");
	
	RegAdminCmd("sm_postponeupdate", Command_PostponeUpdate, ADMFLAG_RCON, "Postpone a pending server restart for a Steam update");
	RegAdminCmd("sm_updatetimer", Command_ForceRestart, ADMFLAG_RCON, "Force the server update timer to start immediately");
	
	hudText = CreateHudSynchronizer();
	if(hudText == INVALID_HANDLE) {
		LogMessage("HUD text is not supported on this mod. The persistant timer will not display.");
	} else {
		LogMessage("HUD text is supported on this mod. The persistant timer will display.");
	}
	
	char folder[16];
	GetGameFolderName(folder, sizeof(folder));
	if(StrEqual(folder, "tf", false)) {
		isTF = true;
	}
}

public void OnMapStart() {
	if(isTF) {
		PrecacheSound(ALERT_SOUND); // this sound is in TF2 only
	}
}

public void OnClientPostAdminCheck(int client) {
	if(CheckCommandAccess(client, "BypassAutoSteamUpdateDisallow", ADMFLAG_GENERIC, true)) {
		return;
	}
	if(disallowPlayers) {
		char kickMessage[255];
		kickMessageCvar.GetString(kickMessage, sizeof(kickMessage));
		KickClient(client, kickMessage);
	}
}

public Action SteamWorks_RestartRequested() {
	startTimer();
	return Plugin_Continue;
}

public Action Command_ForceRestart(int client, int args) {
	suspendPlugin = false;
	LogAction(client, -1, "%L manually triggered an update timer", client);
	startTimer(true);
	return Plugin_Handled;
}

void startTimer(bool forced = false) {
	if(suspendPlugin) {
		return;
	}
	if(!IsServerPopulated()) { // If there's no clients in the server, go ahead and restart it
		LogMessage("Received a master server restart request, and there are no players in the server. Restarting to update.");
		ServerCommand("_restart");
		return;
	}
	int lock = lockCvar.IntValue;
	if(lock == 1) {
		char password[255];
		passwordCvar.GetString(password, sizeof(password));
		sv_password.GetString(originalPassword, sizeof(originalPassword));
		sv_password.SetString(password);
	}
	if(lock == 2) {
		disallowPlayers = true;
	}
	if(!forced) {
		LogMessage("Received a master server restart request, beginning restart timer.");
	}
	timeRemaining = GetConVarInt(timerCvar) * 60;
	timeRemaining++;
	restartTimer = CreateTimer(1.0, DoTimer, INVALID_HANDLE, TIMER_REPEAT);
	suspendPlugin = true;
	return;
}

public Action DoTimer(Handle timer) {
	timeRemaining--;
	if(timeRemaining <= -1) {
		LogMessage("Restarting server for Steam update.");
		for(int i = 1; i <= MaxClients; i++) {
			if (!IsClientAuthorized(i) || !IsClientInGame(i) || IsFakeClient(i)) {
				continue;
			}
			char kickMessage[255];
			shutdownMessageCvar.GetString(kickMessage, sizeof(kickMessage));
			KickClient(i, kickMessage);
		}
		ServerCommand("_restart");
		return Plugin_Stop;
	}
	if(timeRemaining / 60 <= GetConVarInt(messageTimeCvar)) {
		if(hudText != INVALID_HANDLE) {
			for(int i = 1; i <= MaxClients; i++) {
				if(!IsClientConnected(i) || !IsClientInGame(i) || IsFakeClient(i)) {
					continue;
				}
				SetHudTextParams(GetConVarFloat(hudXCvar), GetConVarFloat(hudYCvar), 1.0, GetConVarInt(hudRCvar), GetConVarInt(hudGCvar), GetConVarInt(hudBCvar), 255);
				ShowSyncHudText(i, hudText, "Update: %i:%02i", timeRemaining / 60, timeRemaining % 60);
			}
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
	if(timeRemaining <= 60 && hudText == INVALID_HANDLE) {
		PrintCenterTextAll("Update: %i:%02i", timeRemaining / 60, timeRemaining % 60);
	}
	return Plugin_Continue;
}

public Action Command_PostponeUpdate(int client, int args) {
	if(restartTimer == INVALID_HANDLE) {
		ReplyToCommand(client, "[SM] There is no update timer currently running.");
		return Plugin_Handled;
	}
	CloseHandle(restartTimer);
	restartTimer = INVALID_HANDLE;
	LogAction(client, -1, "%L aborted the update timer.", client);
	float delay = delayCvar.IntValue * 60.0;
	CreateTimer(delay, ReenablePlugin);
	int minutesCancelled = delayCvar.IntValue;
	ReplyToCommand(client, "[SM] The update timer has been cancelled for %i minutes.", minutesCancelled);
	PrintHintTextToAll("The update timer has been cancelled for %i minutes.", minutesCancelled);
	disallowPlayers = false;
	if(lockCvar.IntValue) {
		sv_password.SetString(originalPassword);
	}
	return Plugin_Handled;
}

public Action ReenablePlugin(Handle timer) {
	suspendPlugin = false;
	return Plugin_Stop;
}

bool IsServerPopulated() {
	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientConnected(i) && !IsFakeClient(i)) {
			return true;
		}
	}
	return false;
}

/////////////////////////////////

public void OnAllPluginsLoaded() {
	ConVar convar;
	if(LibraryExists("updater")) {
		Updater_AddPlugin(UPDATE_URL);
		char newVersion[10];
		Format(newVersion, sizeof(newVersion), "%sA", PLUGIN_VERSION);
		convar = CreateConVar("sw_auto_steam_update_version", newVersion, "Automatic Steam Update Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	} else {
		convar = CreateConVar("sw_auto_steam_update_version", PLUGIN_VERSION, "Automatic Steam Update Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);	
	}
	convar.AddChangeHook(Callback_VersionConVarChanged);
}

public void Callback_VersionConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	ResetConVar(convar);
}

public Action Updater_OnPluginDownloading() {
	if(!updaterCvar.BoolValue) {
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public void OnLibraryAdded(const char[] name) {
	if(StrEqual(name, "updater")) {
		Updater_AddPlugin(UPDATE_URL);
	}
}

public void Updater_OnPluginUpdated() {
	ReloadPlugin();
}