#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>

#define PLUGIN_VERSION  "indev"
public Plugin myinfo = {
	name = "[NGS] Clocktown Mono Spawner",
	author = "MasterOfTheXP / TheXeon",
	description = "Spawns Monoculus on top of the tower during the Final Hours.",
	version = PLUGIN_VERSION,
	url = "http://mstr.ca/"
}

int Relays[6];
int DayCount, SecondsCount;
bool Nighttime;
int HourCount, HourSeconds;
bool WatchActive; // Only true if the time is validated.
char Map[PLATFORM_MAX_PATH];
bool Enabled;

Handle cvarHealth;
Handle cvarHealthPerPlayer;
Handle cvarHealthPerLevel;

public void OnPluginStart()
{
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEntityOutput("logic_relay", "OnTrigger", OnTrigger);
	Enabled = (StrContains(Map, "trade_clocktown_", false) == 0 && !StrEqual(Map, "trade_clocktown_b1", false));
	if (!Enabled) return;
	// Late loading
	FindTimers();
}

public void OnMapStart()
{
	GetCurrentMap(Map, sizeof(Map));
	Enabled = (StrContains(Map, "trade_clocktown_", false) == 0 && !StrEqual(Map, "trade_clocktown_b1", false));
	if (!Enabled) return;
	CreateTimer(1.0, Timer_Second, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnConfigsExecuted()
{
	cvarHealth = FindConVar("tf_eyeball_boss_health_base");
	cvarHealthPerPlayer = FindConVar("tf_eyeball_boss_health_per_player");
	cvarHealthPerLevel = FindConVar("tf_eyeball_boss_health_per_level");
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if (!Enabled) return;
	FindTimers();
	DayCount = 1;
	SecondsCount = 0;
	HourCount = 6;
	HourSeconds = 0;
	Nighttime = false;
	WatchActive = true;
}

public void OnTrigger(const char[] output, int caller, int activator, float delay)
{
	if (!Enabled) return;
	if (caller == Relays[0]) DayCount = 1;
	else if (caller == Relays[2]) DayCount = 2;
	else if (caller == Relays[4]) DayCount = 3;
	else if (caller == Relays[1]) DayCount = 11;
	else if (caller == Relays[3]) DayCount = 12;
	else if (caller == Relays[5]) DayCount = 13;
	else return;
	SecondsCount = 0;
	HourCount = 6;
	HourSeconds = 0;
	if (DayCount > 3)
	{
		DayCount -= 10;
		Nighttime = true;
	}
	else Nighttime = false;
	WatchActive = true;
}

public Action Timer_Second(Handle timer)
{
	if (!WatchActive) return;
	SecondsCount++;
	if (++HourSeconds >= 45)
	{
		if (++HourCount == 13) HourCount -= 12;
		HourSeconds = 0;
	}
	if (DayCount == 3 && HourCount == 12 && !HourSeconds && Nighttime)
	{
		int BaseHealth = GetConVarInt(cvarHealth), HealthPerPlayer = GetConVarInt(cvarHealthPerPlayer), HealthPerLevel = GetConVarInt(cvarHealthPerLevel);
		SetConVarInt(cvarHealth, 4200), SetConVarInt(cvarHealthPerPlayer, 300), SetConVarInt(cvarHealthPerLevel, 2000);
		int Ent = CreateEntityByName("eyeball_boss");
		SetEntProp(Ent, Prop_Data, "m_iTeamNum", 5);
		float monoculusLocation[3] = {-290.0, -327.0, -92.0};
		TeleportEntity(Ent, monoculusLocation, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(Ent);
		SetConVarInt(cvarHealth, BaseHealth), SetConVarInt(cvarHealthPerPlayer, HealthPerPlayer), SetConVarInt(cvarHealthPerLevel, HealthPerLevel);
	}
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

public bool IsValidClient (int client)
{
	if(client > 4096) client = EntRefToEntIndex(client);
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsFakeClient(client)) return false;
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}