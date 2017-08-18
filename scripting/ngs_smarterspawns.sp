#pragma newdecls required
#pragma semicolon 1

#include <sdkhooks>
#include <sdktools>

#define PLUGIN_VERSION "1.0.1"

bool IsRoundEnd = false;
bool IsInSpawn[MAXPLAYERS + 1] = false;

float g_fDamageInSpawn = 0.01;
float g_fDamageOutsideSpawn = 0.01;
ConVar v_DamageInSpawn;
ConVar v_DamageOutsideSpawn;

public Plugin myinfo = {
	name = "[NGS] Smarter Spawns",
	author = "DarthNinja / TheXeon",
	description = "Damage controls for players in spawn rooms",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.net/"
}

public void OnPluginStart()
{
	CreateConVar("smarter_spawns", PLUGIN_VERSION, "Plugin Version", FCVAR_REPLICATED|FCVAR_NOTIFY);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);	// Lateload support
	}
	
	//If we load after the map has started, the OnEntityCreated check wont be called
	int iSpawn = -1;
	while ((iSpawn = FindEntityByClassname(iSpawn, "func_respawnroom")) != -1)
	{
		// If plugin is loaded early, these won't be called because the func_respawnroom wont exist yet
		SDKHook(iSpawn, SDKHook_StartTouch, SpawnStartTouch);
		SDKHook(iSpawn, SDKHook_EndTouch, SpawnEndTouch);
	}
	
	//RegAdminCmd("smarter_spawns_debug", Test, 0);
	
	HookEvent("player_spawn", OnPlayerSpawned);
	HookEvent("teamplay_round_win", OnRoundEnd);
	HookEvent("teamplay_round_active", OnRoundStart);
	//HookEvent("arena_round_start", OnRoundStart);	This plugin really doesn't need to do anything in arena since arena maps have no spawn rooms so to speak

	v_DamageInSpawn = CreateConVar("smarter_spawns_damage_inspawn", "0.25", "Damage will be multiplied by this value for players inside spawn being attacked by players outside of spawn", 0, true, 0.0, true, 2.0);
	v_DamageOutsideSpawn = CreateConVar("smarter_spawns_damage_outsidespawn", "0.50", "Damage will be multiplied by this value for players outside of spawn being attacked by players inside spawn", 0, true, 0.0, true, 2.0);

	HookConVarChange(v_DamageInSpawn, OnConVarChanged);
	HookConVarChange(v_DamageOutsideSpawn, OnConVarChanged);
}

public void OnConVarChanged(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	if (cvar == v_DamageInSpawn)
		g_fDamageInSpawn = StringToFloat(newVal);
	else //if (cvar == v_DamageOutsideSpawn)
		g_fDamageOutsideSpawn = StringToFloat(newVal);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (IsRoundEnd)
		return Plugin_Continue;	// End up the round, so we dont care

	if (victim > MaxClients || victim < 1 || attacker > MaxClients || attacker < 1)
		return Plugin_Continue;	// That ain't valid for our array.

	if (IsInSpawn[victim] && !IsInSpawn[attacker])	// Someone is shooting into the spawn room.
	{
		if (g_fDamageInSpawn == 0.0)
			damage = 0.0;
		else
			damage = damage * g_fDamageInSpawn;	// Reduce the damage done to players in the spawn
		return Plugin_Changed;
	}

	if (!IsInSpawn[victim] && IsInSpawn[attacker])	// Someone is shooting *out of* the spawn room.
	{
		if (g_fDamageOutsideSpawn == 0.0)
			damage = 0.0;
		else
		damage = damage * g_fDamageOutsideSpawn;	// Reduce the damage done to players outside the spawn.... but maybe not as much.
		return Plugin_Changed;
	}

	// Any other combo we'll ignore for now (like outsider attacking outsider, player in spawn attacking a player in the spawn - not really possible)
	return Plugin_Continue;
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	IsRoundEnd = false;
}
public Action OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	IsRoundEnd = true;
}

public Action OnPlayerSpawned(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	IsInSpawn[client] = true;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "func_respawnroom", false))	// This is the earliest we can catch this
	{
		SDKHook(entity, SDKHook_StartTouch, SpawnStartTouch);
		SDKHook(entity, SDKHook_EndTouch, SpawnEndTouch);
	}
}

public void SpawnStartTouch(int spawn, int client)
{
	// Make sure it is a client and not something random
	if (client > MaxClients || client < 1)
		return;	// Not a client

	if (IsClientConnected(client) && IsClientInGame(client))
		IsInSpawn[client] = true;
}

public void SpawnEndTouch(int spawn, int client)
{
	if (client > MaxClients || client < 1)
		return;

	if (IsClientConnected(client) && IsClientInGame(client))
		IsInSpawn[client] = false;
}

public void OnClientDisconnect(int client)
{
	IsInSpawn[client] = false;
}
