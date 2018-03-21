/**
* TheXeon
* ngs_fixes.sp
*
* Files:
* addons/sourcemod/plugins/ngs_fixes.smx
* cfg/sourcemod/autorestart.cfg
*
* Dependencies:
* sourcemod.inc, basecomm.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <sourcemod>
#include <basecomm>
#include <ngsutils>
#include <ngsupdater>

ConVar cvarDisableDoveSpawn, cvarDisableNonAuthedSpam;
SMTimer authClientTimer[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "[NGS] Game Fixes",
	author = "TheXeon",
	description = "Small plugin including changes for NGS server.",
	version = "1.0.2",
	url = "https://www.neogenesisnetwork.net/"
}

public void OnPluginStart()
{
	cvarDisableNonAuthedSpam = CreateConVar("sm_ngsfixes_disable_authspam", "1", "Should players be kicked if they don\'t auth?");
	if (GetEngineVersion() == Engine_TF2)
	{
		cvarDisableDoveSpawn = CreateConVar("sm_ngsfixes_disable_doves", "1", "Should the plugin disable dove spawning.");
		HookUserMessage(GetUserMessageId("SpawnFlyingBird"), UserMsg_SpawnBird, true);
	}
	AutoExecConfig(true, "ngs_fixes");
}

public Action UserMsg_SpawnBird(UserMsg msg_id, BfRead bf, const int[] players, int playersNum, bool reliable, bool init)
{
	if (!cvarDisableDoveSpawn.BoolValue) return Plugin_Continue;
	return Plugin_Stop;
}

public void OnClientConnected(int client)
{
	if (cvarDisableNonAuthedSpam.BoolValue && !IsFakeClient(client))
		authClientTimer[client] = new SMTimer(2.0, AuthCheckTimer, GetClientUserId(client), TIMER_REPEAT);
}

public Action AuthCheckTimer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client == 0)
	{
		authClientTimer[client] = null;
		return Plugin_Stop;
	}
	if (!IsClientInGame(client)) return Plugin_Continue;
	char auth[24];
	if (!GetClientAuthId(client, AuthId_Engine, auth, sizeof(auth)))
	{
		if (IsPlayerAlive(client))
		{
			ChangeClientTeam(client, 1);
			PrintToChat(client, "Your client has not been authed, please reconnect.");
		}
		BaseComm_SetClientGag(client, true);
		BaseComm_SetClientMute(client, true);
		ServerCommand("namelockid %d 1", userid);
	}
	else
	{
		authClientTimer[client] = null;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
	delete authClientTimer[client];
}