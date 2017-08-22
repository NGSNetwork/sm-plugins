#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <devzones>
#include <multicolors>

bool spawnprotect[MAXPLAYERS+1];
Handle spawnProtectionTimer[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[NGS] SM DEV Zones - SpawnProtection",
	author = "Franc1sco franug / TheXeon",
	description = "For use for extended spawns ONLY",
	version = "2.0",
	url = "https://www.neogenesisnetwork.net/"
}

public void OnPluginStart()
{
	HookEvent("player_spawn", OnPlayerSpawn);
	RegConsoleCmd("sm_ismyspawnprotecton", CommandSpawnProtectStatus, "Checks whether your spawn protection is on.");
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
}

public Action CommandSpawnProtectStatus(int client, int args)
{
	if (!IsValidClient(client) || !IsPlayerAlive(client)) return Plugin_Handled;
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} BETA: Your spawn protection is %s!", spawnprotect[client] ? "on" : "off");
	return Plugin_Handled;
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	spawnprotect[client] = true;
	/*if (CheckCommandAccess(client, "ADMFLAG_ROOT", ADMFLAG_ROOT))
	{*/
	CPrintToChat(client, "{GREEN}[SM]{DEFAULT} BETA: Spawn protection is enabled.");
	//}
}

public void Zone_OnClientEntry(int client, char[] zone)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client)) 
		return;
		
	if (StrContains(zone, "spawnprotect", false) != 0) return;
	
	if (!spawnprotect[client] && spawnProtectionTimer[client] == null)
		spawnProtectionTimer[client] = CreateTimer(5.0, OnSpawnProtectTimer, client);
	
	if (CheckCommandAccess(client, "ADMFLAG_ROOT", ADMFLAG_ROOT))
	{
		PrintToChat(client, "[SM] You entered a spawnprotect zone!");
		if (spawnprotect[client])
		{
			PrintToChat(client, "spawn protect is still on.");
		}
	}
}

public Action OnSpawnProtectTimer(Handle timer, any client)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client)) 
		return;
	
	if (Zone_IsClientInZone(client, "spawnprotect", false))
	{
		if (!spawnprotect[client])
			CPrintToChat(client, "{GREEN}[SM]{DEFAULT} BETA: Spawn protection is enabled.");
		spawnprotect[client] = true;
	}

	if (CheckCommandAccess(client, "ADMFLAG_ROOT", ADMFLAG_ROOT))
	{
		PrintToChat(client, "spawnprotect is %s.", spawnprotect[client] ? "on" : "off");
	}
}

public void Zone_OnClientLeave(int client, char[] zone)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client)) 
		return;
		
	if (StrContains(zone, "spawnprotect", false) != 0) return;
	/*
	if (spawnprotect[client] && spawnProtectionTimer[client] != null && Zone_IsClientInZone(client, "spawnprotect", false))
	{
		KillTimer(spawnProtectionTimer[client]);
		spawnProtectionTimer[client] = null;
	}
	*/
	if (spawnprotect[client])
		CPrintToChat(client, "{GREEN}[SM]{DEFAULT} BETA: Spawn protection is disabled.");
	spawnprotect[client] = false;

	if (CheckCommandAccess(client, "ADMFLAG_ROOT", ADMFLAG_ROOT))
	{
		PrintToChat(client, "[SM] You exited a spawnprotect zone!");
		PrintToChat(client, "spawnprotect is %s.", spawnprotect[client] ? "on" : "off");
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	if (spawnProtectionTimer[client] != null)
	{
		KillTimer(spawnProtectionTimer[client]);
		spawnProtectionTimer[client] = null;
	}
}

public Action OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!IsValidClient(attacker) || !IsValidClient(client)) return Plugin_Continue;
	
	if((spawnprotect[attacker] || spawnprotect[client]) && client != attacker)
	{
		PrintHintText(attacker, "You can't hurt players in this zone!");
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