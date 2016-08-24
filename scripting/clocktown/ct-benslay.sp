#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>

#define PLUGIN_VERSION  "1.0.1"

public Plugin myinfo = {
	name = "[NGS] Ben Slay",
	author = "MasterOfTheXP",
	description = "You shouldn't have done that",
	version = PLUGIN_VERSION,
	url = "http://mstr.ca/"
}

ConVar cvarEnabled;

public void OnPluginStart()
{
	cvarEnabled = CreateConVar("sm_benslay_enabled", "1");
	for (int i = MaxClients + 1; i <= 2048; i++)
	{
		if (!IsValidEntity(i)) continue;
		if (1089996 != GetEntProp(i, Prop_Data, "m_iHammerID")) continue;
		SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public void OnEntityCreated(int entity, const char[] cls)
{
	if (entity < 0 || entity > 2048) return;
	if (StrContains(cls, "prop_", false) != 0) return;
	SDKHook(entity, SDKHook_Spawn, OnEntitySpawned);
}

public Action OnEntitySpawned(int entity)
{
	if (1089996 != GetEntProp(entity, Prop_Data, "m_iHammerID")) return;
	SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (!GetConVarBool(cvarEnabled)) return Plugin_Continue;
	if (!IsValidClient(attacker)) return Plugin_Continue;
	SDKHooks_TakeDamage(attacker, victim, victim, GetClientHealth(attacker)*10.0);
	PrintToChat(attacker, "You shouldn't have done that.");
	return Plugin_Continue;
}

public bool IsValidClient (int client)
{
	if(client > 4096) client = EntRefToEntIndex(client);
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsFakeClient(client)) return false;
	if(IsClientSourceTV(client) || IsClientReplay(client)) return false;
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}