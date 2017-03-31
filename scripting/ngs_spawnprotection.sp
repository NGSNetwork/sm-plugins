#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <morecolors>

ConVar cvarSpawnProtect;
ConVar cvarAnnounce;
ConVar cvarProtectTime;

Handle hSpawnTimer[MAXPLAYERS + 1];

bool clientProtected[MAXPLAYERS + 1];

#define PLUGIN_VERSION "1.0.0"

public Plugin myinfo = {
	name = "[NGS] TF2 Spawn Protection",
	author = "Crimson / TheXeon",
	description = "Protects Player's on Spawn",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.net"
}

public void OnPluginStart()
{
	CreateConVar("sm_spawnprotect_version", PLUGIN_VERSION, "Spawn Protection Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	cvarSpawnProtect = CreateConVar("sm_spawnprotect_enable", "1", "Enable/Disable Spawn Protection", 0, true, 0.0, true, 1.0);
	cvarAnnounce = CreateConVar("sm_spawnprotect_announce", "1", "Enable/Disable Announcements", 0, true, 0.0, true, 1.0);
	cvarProtectTime = CreateConVar("sm_spawnprotect_timer", "10.0", "Length of Time to Protect Spawned Players", 0, true, 0.0, true, 30.0);

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
	
	AutoExecConfig(true, "plugins.spawnprotection");
} 

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (cvarSpawnProtect.BoolValue)
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		if (hSpawnTimer[client] != null)
		{
			KillTimer(hSpawnTimer[client]);
			hSpawnTimer[client] = null;
		}
		//Enable Protection on the Client
		clientProtected[client] = true;

		hSpawnTimer[client] = CreateTimer(cvarProtectTime.FloatValue, timer_PlayerProtect, client);
	}
}

//Player Protection Expires
public Action timer_PlayerProtect(Handle timer, any client)
{
	//Disable Protection on the Client
	clientProtected[client] = false;
	hSpawnTimer[client] = null;

	if (cvarAnnounce.BoolValue)
		CPrintToChat(client, "{LIGHTGREEN}[SpawnProtect] {DEFAULT}Your Spawn Protection is now Disabled!");
}

//If they take Damage during Protection Round, Restore their Health
public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int damageAmount = event.GetInt("damageamount");
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (clientProtected[client] && IsValidClient(attacker))
	{
		SetEntityHealth(client, GetClientHealth(client) + damageAmount);
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