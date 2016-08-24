#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>

#define PLUGIN_VERSION  "1.0.1"

public Plugin myinfo = {
	name = "[NGS] Clocktown Watch",
	author = "MasterOfTheXP / TheXeon",
	description = "And now you're older still.",
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

Handle HudSync;
char HudText[192];

public void OnPluginStart()
{
	HookEvent("player_spawn", Event_Spawn);
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEntityOutput("logic_relay", "OnTrigger", OnTrigger);
	HudSync = CreateHudSynchronizer();
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
	CreateTimer(0.0, Timer_TenSeconds, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(10.0, Timer_TenSeconds, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
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
	CreateTimer(0.05, Timer_TenSeconds, _, TIMER_FLAG_NO_MAPCHANGE);
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
	CreateTimer(0.0, Timer_TenSeconds, _, TIMER_FLAG_NO_MAPCHANGE);
}

stock void ShowWatch(int client)
{
	if (!WatchActive) return;
	if (!IsValidClient(client)) return;
	SetHudTextParams(-1.0, 1.0, 11.0, 255, 255, 255, 255);
	SetGlobalTransTarget(client);
	ShowSyncHudText(client, HudSync, HudText);
	CloseHandle(HudSync);
}

public Action Timer_Second(Handle timer)
{
	SecondsCount++;
	if (++HourSeconds >= 45)
	{
		if (++HourCount == 13) HourCount -= 12;
		HourSeconds = 0;
		for (int i = 1; i <= MaxClients; i++)
			ShowWatch(i);
	}
}

public Action Timer_TenSeconds(Handle timer)
{
	if (DayCount == 1) Format(HudText, sizeof(HudText), "1st\n");
	else if (DayCount == 2) Format(HudText, sizeof(HudText), "2nd\n");
	else if (DayCount == 3) Format(HudText, sizeof(HudText), "Final\n");
	int cur = RoundFloat(float(SecondsCount) / 20.0);
	int max = RoundFloat(541.0 / 20.0);
	for (int i = 0; i <= max; i++)
	{
		if (!Nighttime)
		{
			if (cur == i) Format(HudText, sizeof(HudText), "%s%i%s", HudText, HourCount, (HourCount < 6 || HourCount == 12) ? "pm" : "am");
			else Format(HudText, sizeof(HudText), "%s.", HudText);
		}
		else
		{
			if (cur == i) Format(HudText, sizeof(HudText), "%s%i%s", HudText, HourCount, (HourCount < 6 || HourCount == 12) ? "am" : "pm");
			else if (i == 0) Format(HudText, sizeof(HudText), "%s[", HudText);
			else if (i == max) Format(HudText, sizeof(HudText), "%s]", HudText);
			else Format(HudText, sizeof(HudText), "%s ", HudText);
		}
	}
	for (int i = 1; i <= MaxClients; i++)
		ShowWatch(i);
}

public void OnClientPutInServer(int client) 
{
	ShowWatch(client);
}

public Action Event_Spawn(Handle event, const char[] name, bool dontBroadcast)
{
	if (!Enabled) return;
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	ShowWatch(client);
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

public bool IsValidClient(int client)
{
	if(client > 4096) client = EntRefToEntIndex(client);
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsFakeClient(client)) return false;
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}