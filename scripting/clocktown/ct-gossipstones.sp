#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION  "1.0.1"

public Plugin myinfo = {
	name = "[NGS] Clocktown Gossip Stones",
	author = "MasterOfTheXP / TheXeon",
	description = "Needs moar gossip.",
	version = PLUGIN_VERSION,
	url = "http://mstr.ca/"
}

#define MINUTE_TIME 0.75138888888888888888888888888889

int Relays[6];
int MinutesCount;
bool WatchActive; // Only true if the time is validated.
char Map[PLATFORM_MAX_PATH];
bool Enabled;
int StoneMdl;
bool CanTriggerStone[MAXPLAYERS + 1] = {true, ...};

public void OnPluginStart()
{
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEntityOutput("logic_relay", "OnTrigger", OnTrigger);
	Enabled = (StrContains(Map, "trade_clocktown_", false) == 0);
	if (!Enabled) return;
	// Late loading
	StoneMdl = PrecacheModel("models/majoras_mask/common/gossipstone/mm_gossipstone.mdl", true);
	FindTimers();
	FindStones();
}

public void OnMapStart()
{
	GetCurrentMap(Map, sizeof(Map));
	Enabled = (StrContains(Map, "trade_clocktown_", false) == 0 && !StrEqual(Map, "trade_clocktown_b1", false));
	if (!Enabled) return;
	CreateTimer(MINUTE_TIME, Timer_Second, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	StoneMdl = PrecacheModel("models/majoras_mask/common/gossipstone/mm_gossipstone.mdl", true);
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if (!Enabled) return;
	FindTimers();
	FindStones();
	MinutesCount = 0;
	WatchActive = true;
}

public void OnTrigger(const char[] output, int caller, int activator, float delay)
{
	if (!Enabled) return;
	if (caller == Relays[0]) MinutesCount = 0;
	else if (caller == Relays[1]) MinutesCount = 720;
	else if (caller == Relays[2]) MinutesCount = 1440;
	else if (caller == Relays[3]) MinutesCount = 2160;
	else if (caller == Relays[4]) MinutesCount = 2880;
	else if (caller == Relays[5]) MinutesCount = 3600;
	else return;
	WatchActive = true;
}

public Action Timer_Second(Handle timer)
{
	MinutesCount++;
}

stock void FindTimers()
{
	int Ent = -1;
	while ((Ent = FindEntityByClassname(Ent, "logic_relay")) != -1)
	{
		char entName[35];
		GetEntPropString(Ent, Prop_Data, "m_iName", entName, sizeof(entName));
		if (StrEqual(entName, "day1relay")) Relays[0] = Ent;
		else if (StrEqual(entName, "night1relay")) Relays[1] = Ent;
		else if (StrEqual(entName, "day2relay")) Relays[2] = Ent;
		else if (StrEqual(entName, "night2relay")) Relays[3] = Ent;
		else if (StrEqual(entName, "day3relay")) Relays[4] = Ent;
		else if (StrEqual(entName, "night3relay")) Relays[5] = Ent;
	}
}

stock void FindStones()
{
	int Ent = -1;
	while ((Ent = FindEntityByClassname(Ent, "prop_dynamic")) != -1)
	{
		if (StoneMdl == GetEntProp(Ent, Prop_Data, "m_nModelIndex"))
			SDKHook(Ent, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (!WatchActive) return Plugin_Continue; // We dunno what time it is
	if (!IsValidClient(attacker)) return Plugin_Continue;
	if (!CanTriggerStone[attacker]) return Plugin_Continue;
	int hours, mins = MinutesCount;
	while (mins > 59)
	{
		mins -= 60;
		hours++;
	}
	int remhours = 71 - hours, remmins = 59 - mins;
	if (remhours < 0) remhours = 0;
	if (remmins < 0) remmins = 0;
	PrintToChat(attacker, "Only %s%i:%s%i remaining!", remhours <= 9 ? "0" : "", remhours, remmins <= 9 ? "0" : "", remmins);
	CanTriggerStone[attacker] = false;
	CreateTimer(1.0, LetTriggerStone, attacker);
	return Plugin_Continue;
}
public Action LetTriggerStone(Handle timer, any client)
{
	CanTriggerStone[client] = true; // Really simple timer to reset the bool, user ids don't really matter
}

public bool IsValidClient(int client)
{
	if(client > 4096) client = EntRefToEntIndex(client);
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsFakeClient(client)) return false;
	if(IsClientSourceTV(client) || IsClientReplay(client)) return false;
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}