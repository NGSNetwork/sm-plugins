/**
* TheXeon
* ngs_autorestart.sp
*
* Files:
* addons/sourcemod/plugins/ngs_autorestart.smx
* cfg/sourcemod/autorestart.cfg
*
* Dependencies:
* ngsutils.inc, ngsupdater.inc, multicolors.inc, afk_manager.inc,
* autoexecconfig.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <autoexecconfig>
#include <afk_manager>
#include <multicolors>
#include <ngsutils>
#include <ngsupdater>

//#define DEBUG

public Plugin myinfo = {
	name = "[NGS] Timed Restart",
	author = "TheXeon",
	description = "Restart the server automagically :D",
	version = "1.0.7",
	url = "https://www.neogenesisnetwork.net/"
}

ConVar cvarEnabled;
ConVar cvarUptimeRequirement;
ConVar cvarForcedRestartTime;
SMTimer autoRestartTimer;

public void OnPluginStart()
{
	AutoExecConfig_SetCreateDirectory(true);
	AutoExecConfig_SetFile("autorestart");
	AutoExecConfig_SetCreateFile(true);
	bool appended;
	cvarEnabled = AutoExecConfig_CreateConVarCheckAppend(appended, "ngsar_enabled", "1", "Enable autorestart on no players.", 0, true, 0.0, true, 1.0);
	cvarUptimeRequirement = AutoExecConfig_CreateConVarCheckAppend(appended, "ngsar_uptime_requirement", "960.0", "Minutes the server should have since first connection to allow a restart.");
	cvarForcedRestartTime = AutoExecConfig_CreateConVarCheckAppend(appended, "ngsar_forced_requirement", "1920.0", "Minutes the server should have since first connection to go to forced restart. Set to 0.0 to disable.");
	AutoExecConfig_ExecAndClean(appended);

	RegAdminCmd("sm_startrestarttimer", CommandStartRestartTimer, ADMFLAG_ROOT, "Force a server restart timer. Usage: sm_startrestarttimer <0 for regular, 1 for forced>");
	RegAdminCmd("sm_checkrestarttimer", CommandCheckRestartTimer, ADMFLAG_ROOT, "Check a server restart timer.");
}

public void OnConfigsExecuted()
{
	if (GetEngineVersion() == Engine_TF2 && (FindConVar("tf_allow_server_hibernation").BoolValue))
	{
		LogMessage("Warning! Timers will be messed up as tf_allow_server_hibernation is enabled!");
	}
}

public Action CommandStartRestartTimer(int client, int args)
{
	if (autoRestartTimer == null)
	{
		int status;
		if (args > 0)
		{
			char arg1[MAX_BUFFER_LENGTH];
			GetCmdArg(1, arg1, sizeof(arg1));
			status = StringToInt(arg1);
		}
		autoRestartTimer = new SMTimer(30.0, AutoRestartTimer, status);
		CPrintToChatAll("{GREEN}[SM]{DEFAULT} A %srestart timer has been started, server %s be restarting in 30 seconds!", 
			(status == 1) ? "forced " : "", (status == 1) ? "will" : "may");
	}
	else
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} There is already a timer going on!");
	}
	return Plugin_Handled;
}

public Action CommandCheckRestartTimer(int client, int args)
{
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} There is %sa restart timer going on!",
		(autoRestartTimer == null) ? "not " : "");
	return Plugin_Handled;
}

public void OnClientPostAdminCheck(int client)
{
	if (autoRestartTimer != null && !IsFakeClient(client) && !IsValidForcedTime())
	{
		delete autoRestartTimer;
		CPrintToChatAll("{GREEN}[SM]{DEFAULT} Server restart aborted (someone joined)!");
	}
}

public void OnClientDisconnect_Post(int client)
{
	if (cvarEnabled.BoolValue && autoRestartTimer == null)
	{
		float time = GetGameTime();
		if (IsValidForcedTime())
		{
			autoRestartTimer = new SMTimer(30.0, AutoRestartTimer, 1);
			CPrintToChatAll("{GREEN}[SM]{DEFAULT} The server has been up for %f hours, forcing a restart in 30 seconds!", time / 3600.0);
		}
		else if ((GetClientCount(false) == 0 ||
		!NonAFKPlayersExist()) && (time / 60.0) > cvarUptimeRequirement.FloatValue)
		{
			autoRestartTimer = new SMTimer(30.0, AutoRestartTimer, 0);
			CPrintToChatAll("{GREEN}[SM]{DEFAULT} The server will attempt a restart in 30 seconds!");
		}
	}
}

public Action AutoRestartTimer(Handle timer, any status)
{
	autoRestartTimer = null;
	#if defined DEBUG
	PrintToServer("Status is %d, GetClientCount(false) = %d, !NonAFKPlayersExist() = %u in AutoRestartTimer callback", status, GetClientCount(false), !NonAFKPlayersExist());
	#endif
	// status: 0 for regular, 1 for forced all the way
	if (status == 1 || GetClientCount(false) == 0 || !NonAFKPlayersExist())
	{
		#if defined DEBUG
		PrintToServer("Fake doing a restart!");
		#else
		LogMessage("Server is restarting at Unix Timestamp %d!", GetTime());
		ServerCommand("_restart");
		#endif
	}
	else
	{
		CPrintToChatAll("{GREEN}[SM]{DEFAULT} Restart aborted!");
	}
}

stock bool NonAFKPlayersExist()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i, _, _, _, _, true))
		{
			return true;
		}
	}
	return false;
}

stock bool IsValidForcedTime()
{
	float forcedTime = cvarForcedRestartTime.FloatValue;
	return forcedTime != 0.0 && (GetGameTime() / 60.0) > forcedTime;
}
