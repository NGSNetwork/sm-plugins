#pragma newdecls required
#pragma semicolon 1

#include <friendly>
#include <tf2_stocks>
#include <morecolors>

#define PLUGIN_VERSION "1.4"

Handle cvar_version = INVALID_HANDLE;
Handle cvar_enabled = INVALID_HANDLE;

bool InCivilianMode[MAXPLAYERS + 1];
int CivilianCooldown[MAXPLAYERS + 1];

public Plugin myinfo = {
    name = "[NGS] Civilian Command",
    author = "Derek D. Howard / TheXeon",
    description = "No weapons on command.",
    version = PLUGIN_VERSION,
    url = "https://forums.alliedmods.net/showthread.php?t=232318"
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] strError, int iErr_Max) {
    char strGame[32];
    GetGameFolderName(strGame, sizeof(strGame));
    if(!StrEqual(strGame, "tf")) {
        Format(strError, iErr_Max, "This plugin only works for Team Fortress 2.");
        return APLRes_Failure;
    }
    return APLRes_Success;
}

public void OnPluginStart()
{
    cvar_version = CreateConVar("sm_civilianmode_version", PLUGIN_VERSION, "Plugin Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
    SetConVarString(cvar_version, PLUGIN_VERSION);
    HookConVarChange(cvar_version, cvarChange);
    RegConsoleCmd("sm_civilian", CommandCivilian, "Usage: sm_civilian");
    RegConsoleCmd("sm_civ", CommandCivilian, "Usage: sm_civilian");
    RegAdminCmd("sm_forcecivilian", CommandForceCivilian, ADMFLAG_GENERIC, "Usage: sm_forcecivilian <#userid|name>");
    cvar_enabled = CreateConVar("sm_alwayscivilian_enabled", "1", "0 to disable the plugin, 1 to enable", 0);
    
    HookEvent("post_inventory_application", Inventory_App, EventHookMode_Post);
}

public void cvarChange(Handle hHandle, const char[] oldValue, const char[] newValue)
{
    if (hHandle == cvar_version) {
        SetConVarString(hHandle, PLUGIN_VERSION);
    }
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
		TF2_RemoveAllWeapons(client);
	else
		FakeClientCommand(client, "explode");
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You have %s civilian mode!", InCivilianMode[client] ? "enabled" : "disabled");
	return Plugin_Handled;
}

public Action CommandForceCivilian(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_forcecivilian <#userid|name>");
		return Plugin_Handled;
	}
	char arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	
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
		InCivilianMode[target_list[i]] = !InCivilianMode[target_list[i]];
		if(InCivilianMode[target_list[i]]) TF2_RemoveAllWeapons(target_list[i]);
		else TF2_RespawnPlayer(target_list[i]);
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
    if (GetConVarBool(cvar_enabled))
    {
        int clientUserID = GetEventInt(event, "userid");
        int client = GetClientOfUserId(clientUserID);
        if(IsValidClient(client) && InCivilianMode[client]) CreateTimer(0.1, RemoveAllWeapons, clientUserID);
    }
}

public void OnClientPutInServer(int client)
{ 
	CivilianCooldown[client] = 0;
	InCivilianMode[client] = false;
}

public Action RemoveAllWeapons(Handle timer, any clientUserID)
{
    int client = GetClientOfUserId(clientUserID);
    if (!IsValidClient(client))
        return;
    TF2_RemoveAllWeapons(client);
}

public bool IsValidClient (int client)
{
	if(client > 4096) client = EntRefToEntIndex(client);
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsFakeClient(client)) return false;
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}