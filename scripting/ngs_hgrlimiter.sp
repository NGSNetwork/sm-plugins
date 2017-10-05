#include <sourcemod>
#include <hgr>
#include <tf2>
#include <tf2_stocks>
#include <multicolors>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "1.0.0"

// Handle hHookCooldown[MAXPLAYERS + 1];
bool inCiv[MAXPLAYERS + 1];

//--------------------//

public Plugin myinfo = {
	name = "[NGS] Hook Nerfer",
	author = "TheXeon",
	description = "Nerfs hooks for donors and above!",
	version = PLUGIN_VERSION,
	url = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	// HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("post_inventory_application", EventInventory);
	LoadTranslations("common.phrases");
}

public Action HGR_OnClientHook(int client)
{
	// if (hHookCooldown[client] != null) return Plugin_Handled;
	KillBuildingsAndCiv(client);
	return Plugin_Continue;
}

public Action HGR_OnClientRope(int client)
{
	// if (hHookCooldown[client] != null) return Plugin_Handled;
	KillBuildingsAndCiv(client);
	return Plugin_Continue;
}

public void EventInventory(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	inCiv[client] = false;
}

stock void KillBuildingsAndCiv(int client)
{
	if (inCiv[client]) return; // A bit of optimization
	if (TF2_GetPlayerClass(client) == TFClass_Engineer)
	{
		int iEnt = -1;
		while ((iEnt = FindEntityByClassname(iEnt, "obj_sentrygun")) != INVALID_ENT_REFERENCE)
		{
			if (GetEntPropEnt(iEnt, Prop_Send, "m_hBuilder") == client)
			{
				// AcceptEntityInput(iEnt, "Kill");
				SetVariantInt(1000);
				AcceptEntityInput(iEnt, "RemoveHealth");
			}
		}
	}
	TF2_RemoveAllWeapons(client);
	inCiv[client] = true;
	CPrintToChat(client, "{GREEN}[HGR]{DEFAULT} You have been put into civilian mode.");
}
/*
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) 
{
	if (buttons & IN_ATTACK && hHookCooldown[client] == null) 
	{
		hHookCooldown[client] = CreateTimer(7.0, OnHookCooldownTimer, client);
		if (HGR_IsHooking(client) || HGR_IsRoping(client) || HGR_IsPushing(client) || HGR_IsAscending(client) || HGR_IsDescending(client))
		{
			CPrintToChat(client, "{GREEN}[HGR]{DEFAULT} Your hook has been temporarily broken!");
			HGR_StopHook(client);
			HGR_StopRope(client);
		}
	}
	return Plugin_Continue; 
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
 	if (hHookCooldown[client] == null)
	{
		hHookCooldown[client] = CreateTimer(7.0, OnHookCooldownTimer, client);
		if (HGR_IsHooking(client) || HGR_IsRoping(client) || HGR_IsPushing(client) || HGR_IsAscending(client) || HGR_IsDescending(client))
		{
			CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Your hook has been temporarily broken!");
			HGR_StopHook(client);
			HGR_StopRope(client);
		}
	}
}

public Action OnHookCooldownTimer(Handle timer, any client)
{
	if (hHookCooldown[client] != null)
	{
		KillTimer(hHookCooldown[client]);
		hHookCooldown[client] = null;
	}
}

public void OnClientDisconnect(int client)
{
	if (hHookCooldown[client] != null)
	{
		KillTimer(hHookCooldown[client]);
		hHookCooldown[client] = null;
	}
}
*/
public bool IsValidClient (int client)
{
	if(client > 4096) client = EntRefToEntIndex(client);
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsFakeClient(client)) return false;
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}