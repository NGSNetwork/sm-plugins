/**
* TheXeon
* ngs_civilianmode.sp
*
* Files:
* addons/sourcemod/plugins/ngs_civilianmode.smx
*
* Dependencies:
* sourcemod.inc, tf2_stocks.inc, multicolors.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <sourcemod>
#include <tf2_stocks>
#include <multicolors>
#include <ngsutils>
#include <ngsupdater>

ConVar cvar_enabled;

bool InCivilianMode[MAXPLAYERS + 1];
int CivilianCooldown[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[NGS] Civilian Command",
	author = "Derek D. Howard / TheXeon",
	description = "No weapons on command.",
	version = "1.4.1",
	url = "https://forums.alliedmods.net/showthread.php?t=232318"
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] strError, int iErr_Max) {
	if(GetEngineVersion() != Engine_TF2) {
		Format(strError, iErr_Max, "This plugin only works for Team Fortress 2.");
		return APLRes_Failure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_civilian", CommandCivilian, "Usage: sm_civilian");
	RegConsoleCmd("sm_civ", CommandCivilian, "Usage: sm_civilian");
	RegAdminCmd("sm_forcecivilian", CommandForceCivilian, ADMFLAG_GENERIC, "Usage: sm_forcecivilian <#userid|name>");
	cvar_enabled = CreateConVar("sm_civilianmode_enabled", "1", "0 to disable the plugin, 1 to enable", 0);

	HookEvent("post_inventory_application", Inventory_App, EventHookMode_Post);
}

public Action CommandCivilian(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	int currentTime = GetTime();
	if (currentTime - CivilianCooldown[client] < 7)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You must wait {PURPLE}%d{DEFAULT} seconds to use this again.", 7 - (currentTime - CivilianCooldown[client]));
		return Plugin_Handled;
	}
	CivilianCooldown[client] = currentTime;

	InCivilianMode[client] = !InCivilianMode[client];
	if (InCivilianMode[client])
		CreateTimer(0.1, RemoveAllWeapons, GetClientUserId(client));
	else
		FakeClientCommand(client, "explode");
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You have %s civilian mode!", InCivilianMode[client] ? "enabled" : "disabled");
	return Plugin_Handled;
}

public Action CommandForceCivilian(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_forcecivilian <#userid|name> <0/1>");
		return Plugin_Handled;
	}
	char arg1[32], arg2[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));

	bool enable = view_as<bool>(StringToInt(arg2));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;

	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		if (args > 1)
		{
			if (enable)
			{
				InCivilianMode[target_list[i]] = true;
				CreateTimer(0.1, RemoveAllWeapons, GetClientUserId(target_list[i]));
			}
			else
			{
				InCivilianMode[target_list[i]] = false;
				TF2_RespawnPlayer(target_list[i]);
			}
		}
		else
		{
			InCivilianMode[target_list[i]] = !InCivilianMode[target_list[i]];
			if(InCivilianMode[target_list[i]])
				CreateTimer(0.1, RemoveAllWeapons, GetClientUserId(target_list[i]));
			else
				TF2_RespawnPlayer(target_list[i]);
		}
	}

	if (tn_is_ml)
	{
		CShowActivity2(client, "{GREEN}[SM]{DEFAULT} ", "Toggled civilian on %t!", target_name);
	}
	else
	{
		CShowActivity2(client, "{GREEN}[SM]{DEFAULT} ", "Toggled civilian on %s!", target_name);
	}
	return Plugin_Handled;
}

public Action Inventory_App(Handle event, const char[] name, bool dontBroadcast)
{
	if (cvar_enabled.BoolValue)
	{
		int clientUserID = GetEventInt(event, "userid");
		int client = GetClientOfUserId(clientUserID);
		if(IsValidClient(client) && InCivilianMode[client])
			CreateTimer(0.1, RemoveAllWeapons, clientUserID);
	}
}

public void OnClientPutInServer(int client)
{
	CivilianCooldown[client] = 0;
	InCivilianMode[client] = false;
}

public Action RemoveAllWeapons(Handle timer, int clientUserID)
{
	int client = GetClientOfUserId(clientUserID);
	if (!IsValidClient(client))
		return;
	TF2_RemoveAllWeapons(client);
}