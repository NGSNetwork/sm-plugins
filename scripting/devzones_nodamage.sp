#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <devzones>

bool nodamage[MAXPLAYERS+1];

public Plugin myinfo = {
	name = "[NGS] SM DEV Zones - NoDamage",
	author = "Franc1sco franug / TheXeon",
	description = "",
	version = "2.0",
	url = "https://neogenesisnetwork.net"
}

public OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawn);
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
}

public void PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (Zone_IsClientInZone(client, "nodamage", false, false))
	{
		nodamage[client] = true;
		if (CheckCommandAccess(client, "ADMFLAG_ROOT", ADMFLAG_ROOT))
		{
			PrintToChat(client, "[SM] You entered a nodamage zone!");
			PrintToChat(client, "Nodamage is %s.", nodamage[client] ? "on" : "off");
		}
	}
	else
	{
		nodamage[client] = false;
		if (CheckCommandAccess(client, "ADMFLAG_ROOT", ADMFLAG_ROOT))
		{
			PrintToChat(client, "[SM] You exited a nodamage zone!");
			PrintToChat(client, "Nodamage is %s.", nodamage[client] ? "on" : "off");
		}
	}
		
	CreateTimer(2.0, SpawnTimer, GetClientUserId(client));
}

public Action SpawnTimer(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsClientInGame(client))
		return;
		
	if (Zone_IsClientInZone(client, "nodamage", false, false))
	{
		nodamage[client] = true;
		if (CheckCommandAccess(client, "ADMFLAG_ROOT", ADMFLAG_ROOT))
		{
			PrintToChat(client, "[SM] You entered a nodamage zone!");
			PrintToChat(client, "Nodamage is %s.", nodamage[client] ? "on" : "off");
		}
	}
	else
	{
		nodamage[client] = false;
		if (CheckCommandAccess(client, "ADMFLAG_ROOT", ADMFLAG_ROOT))
		{
			PrintToChat(client, "[SM] You exited a nodamage zone!");
			PrintToChat(client, "Nodamage is %s.", nodamage[client] ? "on" : "off");
		}
	}
	
}

public int Zone_OnClientEntry(int client, char[] zone)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client)) 
		return;
		
	if(StrContains(zone, "nodamage", false) != 0) return;
	
	nodamage[client] = true;
	
	if (CheckCommandAccess(client, "ADMFLAG_ROOT", ADMFLAG_ROOT))
	{
		PrintToChat(client, "[SM] You entered a nodamage zone!");
		PrintToChat(client, "Nodamage is %s.", nodamage[client] ? "on" : "off");
	}
}

public int Zone_OnClientLeave(int client, char[] zone)
{
	if(client < 1 || client > MaxClients || !IsClientInGame(client) ||!IsPlayerAlive(client)) 
		return;
		
	if (StrContains(zone, "nodamage", false) != 0) return;
	
	nodamage[client] = false;
	
	if (CheckCommandAccess(client, "ADMFLAG_ROOT", ADMFLAG_ROOT))
	{
		PrintToChat(client, "[SM] You exited a nodamage zone!");
		PrintToChat(client, "Nodamage is %s.", nodamage[client] ? "on" : "off");
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(!IsValidClient(attacker) || !IsValidClient(client)) return Plugin_Continue;
	
	if((nodamage[attacker] || nodamage[client]) && client != attacker)
	{
		PrintHintText(attacker, "You cant hurt players in this zone!");
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
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