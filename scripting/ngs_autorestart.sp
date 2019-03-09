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

#undef REQUIRE_PLUGIN
#include <afk_manager>
#define REQUIRE_PLUGIN

#include <autoexecconfig>
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
	Timber.plantToFile(appended);
	cvarEnabled = AutoExecConfig_CreateConVarCheckAppend(appended, "ngsar_enabled", "1", "Enable autorestart on no players.", 0, true, 0.0, true, 1.0);
	cvarUptimeRequirement = AutoExecConfig_CreateConVarCheckAppend(appended, "ngsar_uptime_requirement", "960.0", "Minutes the server should have since first connection to allow a restart.");
	cvarForcedRestartTime = AutoExecConfig_CreateConVarCheckAppend(appended, "ngsar_forced_requirement", "1920.0", "Minutes the server should have since first connection to go to forced restart. Set to 0.0 to disable.");
	AutoExecConfig_ExecAndClean(appended);

	RegAdminCmd("sm_startrestarttimer", CommandStartRestartTimer, ADMFLAG_ROOT, "Force a server restart timer. Usage: sm_startrestarttimer <0 for regular, 1 for forced>");
	RegAdminCmd("sm_checkrestarttimer", CommandCheckRestartTimer, ADMFLAG_ROOT, "Check a server restart timer.");
}

public void OnConfigsExecuted()
{
	if (GetEngineVersion() == Engine_TF2 && FindConVar("tf_allow_server_hibernation").BoolValue)
	{
		Timber.w("Timers will be messed up as tf_allow_server_hibernation is enabled!");
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
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} There is %sa restart timer going on at uptime %f!",
		(autoRestartTimer == null) ? "not " : "", GetGameTime());
	return Plugin_Handled;
}

stock void ProcessClientsAwake(int client, bool sendMsg)
{
	if (autoRestartTimer != null && !IsFakeClient(client) && !IsValidForcedTime())
	{
		delete autoRestartTimer;
		if (sendMsg)
		{
			CPrintToChatAll("{GREEN}[SM]{DEFAULT} Server restart aborted (we're awake)!");
		}
	}
}

stock void ProcessClientsAsleep(int client)
{
	if (cvarEnabled.BoolValue && autoRestartTimer == null)
	{
		float time = GetGameTime();
		if (IsValidForcedTime())
		{
			autoRestartTimer = new SMTimer(30.0, AutoRestartTimer, 1);
			CPrintToChatAll("{GREEN}[SM]{DEFAULT} The server has been up for %d hours, forcing a restart in 30 seconds!", RoundToNearest(time / 3600.0));
		}
		else if ((time / 60.0) > cvarUptimeRequirement.FloatValue)
		{
			if (GetClientCount(false) == 0)
			{
				autoRestartTimer = new SMTimer(30.0, AutoRestartTimer, 0);
				CPrintToChatAll("{GREEN}[SM]{DEFAULT} The server will attempt a restart in 30 seconds!");
			}
			else if (!NonAFKPlayersExist())
			{
				// Don't spam message
				autoRestartTimer = new SMTimer(30.0, AutoRestartTimer, 0);
			}
		}
	}
}
	
public void OnClientPostAdminCheck(int client)
{
	ProcessClientsAwake(client, true);
}

// public void AFKM_OnClientAFK(int client)
// {
// 	ProcessClientsAsleep(client);
// }

// public void AFKM_OnClientBack(int client)
// {
// 	ProcessClientsAwake(client, false);
// }

public void OnClientDisconnect_Post(int client)
{
	ProcessClientsAsleep(client);
}

public Action AutoRestartTimer(Handle timer, any status)
{
	autoRestartTimer = null;
	Timber.d("Status is %d, GetClientCount(false) = %d, !NonAFKPlayersExist() = %u in AutoRestartTimer callback", status, GetClientCount(false), !NonAFKPlayersExist());
	// status: 0 for regular, 1 for forced all the way
	if (status == 1 || GetClientCount(false) == 0 || !NonAFKPlayersExist())
	{
		#if defined DEBUG
		Timber.d("Fake doing a restart!");
		#else
		Timber.i("Server is restarting at Unix Timestamp %d!", GetTime());
		ServerCommand("_restart");
		#endif
	}
	else
	{
		CPrintToChatAll("{GREEN}[SM]{DEFAULT} Server restart aborted!");
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
	return forcedTime != 0.0 && (GetGameTime() / 60.0) >= forcedTime;
}
