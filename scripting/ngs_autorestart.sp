/**
* TheXeon
* ngs_autorestart.sp
*
* Files:
* addons/sourcemod/plugins/ngs_autorestart.smx
* cfg/sourcemod/autorestart.cfg
*
* Dependencies:
* sourcemod.inc, ngsutils.inc, ngsupdater.inc, afk_manager.inc, multicolors.inc
*/
#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <ngsutils>
#include <ngsupdater>
#include <afk_manager>
#include <multicolors>

#define PLUGIN_VERSION  "1.0.1"

public Plugin myinfo = {
	name = "[NGS] Timed Restart",
	author = "TheXeon",
	description = "Restart the server automagically :D",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.net/"
}

ConVar cvarEnabled;
ConVar cvarUptimeRequirement;
SMTimer autoRestartTimer;

public void OnPluginStart()
{
	RegAdminCmd("sm_ngsforcerestart", CommandForceRestart, ADMFLAG_ROOT, "Force a server restart timer.");
	RegAdminCmd("sm_ngscheckrestarttimer", CommandCheckRestartTimer, ADMFLAG_ROOT, "Check a server restart timer.");
	cvarEnabled = CreateConVar("sm_ngsar_enabled", "1", "Enable autorestart on no players.", 0, true, 0.0, true, 1.0);
	cvarUptimeRequirement = CreateConVar("sm_ngsar_uptime_requirement", "16", "How many hours the server should have since first connection to allow a restart.");
	AutoExecConfig(true, "autorestart");
}

public Action CommandForceRestart(int client, int args)
{
	if (autoRestartTimer == null)
	{
		autoRestartTimer = new SMTimer(30.0, AutoRestartTimer);
		CPrintToChatAll("{GREEN}[SM]{DEFAULT} A forced restart timer has been started, server will be restarting in 30 seconds!");
	}
	else
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} There is already a timer going on!");
	}
	return Plugin_Handled;
}

public Action CommandCheckRestartTimer(int client, int args)
{
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} There is %s restart timer going on!",
		(autoRestartTimer == null) ? "not a" : "a");
	return Plugin_Handled;
}

public void OnClientPostAdminCheck(int client)
{
	if (autoRestartTimer != null && !IsFakeClient(client))
	{
		autoRestartTimer.Close();
		autoRestartTimer = null;
		CPrintToChatAll("{GREEN}[SM]{DEFAULT} Server restart aborted (someone joined)!");
	}
}

public void OnClientDisconnect_Post(int client)
{
	if (cvarEnabled.BoolValue && autoRestartTimer == null && (GetClientCount(false) == 0 ||
		!NonAFKPlayersExist()) && RoundToZero(GetGameTime() / 3600) > cvarUptimeRequirement.IntValue)
	{
		autoRestartTimer = new SMTimer(30.0, AutoRestartTimer);
		CPrintToChatAll("{GREEN}[SM]{DEFAULT} The server will be restarting in 30 seconds!");
	}
}

public Action AutoRestartTimer(Handle timer, any dummy)
{
	if (GetClientCount(false) == 0 || !NonAFKPlayersExist())
	{
		LogMessage("Server is restarting at Unix Timestamp %d!", GetTime());
		ServerCommand("_restart");
	}
	else
	{
		CPrintToChatAll("{GREEN}[SM]{DEFAULT} Restart aborted!");
	}
	delete timer;
}

stock bool NonAFKPlayersExist()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && !AFKM_IsClientAFK(i))
		{
			return true;
		}
	}
	return false;
}
