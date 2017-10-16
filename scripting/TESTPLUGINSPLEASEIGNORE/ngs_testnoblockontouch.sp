#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <friendly>
#include <colorvariables>

ConVar friendlyNoblockValue;

Handle antiStuckEndTimer[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[NGS] Test Antistuck with Friendlies",
	author = "TheXeon",
	description = "Testeroni antistuckeroni",
	version = "1.0",
	url = "https://www.neogenesisnetwork.net/"
}

public void OnPluginStart()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i))
        {
			SDKHook(i, SDKHook_StartTouch, StartTouchHook);
			SDKHook(i, SDKHook_EndTouch, EndTouchHook);
        }
    }
    
    friendlyNoblockValue = FindConVar("sm_friendly_noblock");
}

public void OnClientPutInServer(int client)
{
	KillAntiStuckTimer(client);
	SDKHook(client, SDKHook_StartTouch, StartTouchHook);
	SDKHook(client, SDKHook_EndTouch, EndTouchHook);
}

public void OnClientDisconnect(int client)
{
	KillAntiStuckTimer(client);
}

public void StartTouchHook(int client, int entity)
{
    if (IsValidClient(client) && IsValidClient(entity) && (TF2Friendly_IsFriendly(client) || TF2Friendly_IsFriendly(entity)))
    {
    	if (!TF2Friendly_IsFriendly(client) && TF2Friendly_IsFriendly(entity))
    	{
    		// CPrintToChatAll("A friendly touched a nonfriendly!");
    		SetEntProp(client, Prop_Send, "m_CollisionGroup", friendlyNoblockValue.IntValue);
		}
		else if (!TF2Friendly_IsFriendly(entity) && TF2Friendly_IsFriendly(client))
		{
			// CPrintToChatAll("A friendly touched a nonfriendly!");
			SetEntProp(entity, Prop_Send, "m_CollisionGroup", friendlyNoblockValue.IntValue);
		}
    }
} 


public void EndTouchHook(int client, int entity)
{
    if (IsValidClient(client) && IsValidClient(entity) && (TF2Friendly_IsFriendly(client) || TF2Friendly_IsFriendly(entity)))
    {
    	if (!TF2Friendly_IsFriendly(client) && TF2Friendly_IsFriendly(entity))
    	{
    		CreateTimer(0.5, OnEndTouchHookTimer, GetClientUserId(client));
		}
		else if (!TF2Friendly_IsFriendly(entity) && TF2Friendly_IsFriendly(client))
		{
			CreateTimer(0.5, OnEndTouchHookTimer, GetClientUserId(entity));
		}
    }
}

public Action OnEndTouchHookTimer(Handle timer, any client)
{
	if (IsValidClient(client) && !TF2Friendly_IsFriendly(client))
	{
		SetEntProp(client, Prop_Send, "m_CollisionGroup", 5);
	}
}

stock void KillAntiStuckTimer(int client)
{
	if (antiStuckEndTimer[client] != null)
	{
		KillTimer(antiStuckEndTimer[client]);
		antiStuckEndTimer[client] = null;
	}
}

public bool IsValidClient(int client)
{
	if(client > 4096) client = EntRefToEntIndex(client);
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsFakeClient(client)) return false;
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}