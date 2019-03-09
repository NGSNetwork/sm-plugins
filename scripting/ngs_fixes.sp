/**
* TheXeon
* ngs_fixes.sp
*
* Files:
* addons/sourcemod/plugins/ngs_fixes.smx
* cfg/sourcemod/ngs_fixes.cfg
*
* Dependencies:
* sdkhooks.inc, basecomm.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <sdkhooks>
#include <basecomm>
#include <ngsutils>
#include <ngsupdater>

ConVar cvarDisableDoveSpawn, cvarDisableNonAuthedSpam, cvarDisableVoiceMenuSpam,
	cvarDisableHolidayHealth;
bool allowVoiceMenuSpam;
SMTimer authClientTimer[MAXPLAYERS + 1];
SMTimer voiceMenuTimer[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[NGS] Game Fixes",
	author = "TheXeon",
	description = "Small plugin including changes for NGS server.",
	version = "1.0.4",
	url = "https://www.neogenesisnetwork.net/"
}

public void OnPluginStart()
{
	AutoExecConfig_SetCreateDirectory(true);
	AutoExecConfig_SetFile("ngs_fixes");
	AutoExecConfig_SetCreateFile(true);
	bool appended;
	cvarDisableNonAuthedSpam = AutoExecConfig_CreateConVarCheckAppend(appended, "ngsfixes_disable_authspam", "1", "Should players be kicked if they don\'t auth?");
	cvarDisableVoiceMenuSpam = AutoExecConfig_CreateConVarCheckAppend(appended, "ngsfixes_disable_voicespam", "1", "Should we limit the voicemenu spam on the server?");
	cvarDisableVoiceMenuSpam.AddChangeHook(OnVoiceMenuSpamChanged);
	if (GetEngineVersion() == Engine_TF2)
	{
		cvarDisableDoveSpawn = AutoExecConfig_CreateConVarCheckAppend(appended, "ngsfixes_disable_doves", "1", "Should the plugin disable dove spawning?");
		HookUserMessage(GetUserMessageId("SpawnFlyingBird"), UserMsg_SpawnBird, true);

		cvarDisableHolidayHealth = AutoExecConfig_CreateConVarCheckAppend(appended, "ngsfixes_disable_holiday_health", "1", "Should the healthpacks be set to default?");

		AddCommandListener(CmdVoiceMenu, "voicemenu");
	}
	AutoExecConfig_ExecAndClean(appended);
}

public void OnConfigsExecuted()
{
	char voicemenuspam[8];
	cvarDisableVoiceMenuSpam.GetString(voicemenuspam, sizeof(voicemenuspam));
	allowVoiceMenuSpam = !(view_as<bool>(StringToInt(voicemenuspam)));
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (IsValidEntity(entity))
	{
		// From Mr. Silence's TF2 Sanitizer
		if (cvarDisableHolidayHealth.BoolValue && strncmp(classname, "item_healthkit_", 15) == 0)
		{      
			SDKHook(entity, SDKHook_SpawnPost, OnHealthKitSpawned);
		}
	}
}

public void OnHealthKitSpawned(int entity)
{
	// From Mr. Silence's TF2 Sanitizer
	SetEntProp(entity, Prop_Send, "m_nModelIndexOverrides", 0, _, 2);
}

public void OnVoiceMenuSpamChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	allowVoiceMenuSpam = !convar.BoolValue;
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

public Action CmdVoiceMenu(int client, const char[] command, int argc)
{
	if (allowVoiceMenuSpam) return Plugin_Continue;
	if (voiceMenuTimer[client] != null)
	{
		return Plugin_Handled;
	}
	else
	{
		char CmdString[4];
		GetCmdArgString(CmdString, sizeof(CmdString));
		if (StrEqual(CmdString, "0 0"))
			voiceMenuTimer[client] = new SMTimer(0.5, OnVoiceMenuTimer, GetClientUserId(client));
		else
			voiceMenuTimer[client] = new SMTimer(0.1, OnVoiceMenuTimer, GetClientUserId(client));
		return Plugin_Continue;
	}
}

public Action OnVoiceMenuTimer(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (client == 0) return;
	voiceMenuTimer[client] = null;
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
			PrintToChat(client, "%t", "ClientNotAuthed");
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
	delete voiceMenuTimer[client];
}