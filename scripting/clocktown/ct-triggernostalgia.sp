#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>

#define PLUGIN_VERSION  "1.0.1"

public Plugin myinfo = {
	name = "[NGS] Trigger Nostalgia",
	author = "MasterOfTheXP / TheXeon",
	description = "Applies grayscale vision on clients who step into a defined trigger",
	version = PLUGIN_VERSION,
	url = "http://mstr.ca/"
}

bool Enabled;
bool inBrush[MAXPLAYERS + 1];
ConVar cvarGarden;
ConVar cvarRewind;
ConVar cvarRewindGarden;

public void OnPluginStart()
{
	HookEntityOutput("trigger_multiple", "OnStartTouch", OnStartTouch);
	HookEntityOutput("trigger_multiple", "OnEndTouch", OnEndTouch);
	HookEvent("player_death", Event_Death);
	HookEvent("player_spawn", Event_Death);
	
	cvarGarden = CreateConVar("nostalgia_garden", "0");
	cvarRewind = CreateConVar("nostalgia_rewind", "1");
	cvarRewindGarden = CreateConVar("nostalgia_rewindgarden", "1");
}

public void OnMapStart()
{
	char Map[PLATFORM_MAX_PATH];
	GetCurrentMap(Map, sizeof(Map));
	Enabled = StrEqual(Map, "trade_clocktown_b2a", false);
}

public void OnPluginEnd() 
{
	TurnOffOnAll();
}

public void OnStartTouch(const char[] output, int caller, int activator, float delay)
{
	if (!Enabled) return;
	if (activator < 0 || activator > MaxClients) return;
	if (!IsPlayerAlive(activator)) return;
	char name[128];
	GetEntPropString(caller, Prop_Data, "m_iName", name, sizeof(name));
	if ((StrEqual("nostalgia_garden", name, false) && GetConVarBool(cvarGarden)) ||
	(StrEqual("nostalgia_on", name, false) && GetConVarBool(cvarRewind)) ||
	(StrEqual("nostalgia_rewindgarden", name, false) && GetConVarBool(cvarRewindGarden)))
	{
		inBrush[activator] = true;
		DoOverlay(activator, "debug/yuv");
	}
	if (StrEqual("nostalgia_off", name, false) && GetConVarBool(cvarRewindGarden))
	{
		inBrush[activator] = false;
		DoOverlay(activator, "");
	}
}

public void OnClientPutInServer(int client) 
{
	inBrush[client] = false;
}

public void OnEndTouch(const char[] output, int caller, int activator, float delay)
{
	if (!Enabled) return;
	if (activator < 0 || activator > MaxClients) return;
	if (!IsClientInGame(activator)) return;
	if (!IsPlayerAlive(activator)) return;
	char name[MAX_NAME_LENGTH];
	GetEntPropString(caller, Prop_Data, "m_iName", name, sizeof(name));
	if (StrEqual("nostalgia_garden", name, false) || StrEqual("nostalgia_rewindgarden", name, false))
	{
		inBrush[activator] = false;
		DoOverlay(activator);
	}
}

public void Event_Death(Handle event, char[] name, bool dontBroadcast)
{
	if (!Enabled) return;
	if (GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER) return;
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!inBrush[client]) return;
	inBrush[client] = false;
	DoOverlay(client, "");
}

void TurnOffOnAll()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!inBrush[i]) continue;
		if (!IsClientInGame(i)) continue;
		DoOverlay(i);
	}
}

stock void DoOverlay(int client, char[] material = "") // Ghostnode
{
	if (IsValidClient(client))
	{
		int iFlags = GetCommandFlags("r_screenoverlay");
		SetCommandFlags("r_screenoverlay", iFlags & ~FCVAR_CHEAT);
		if (!StrEqual(material, "")) ClientCommand(client, "r_screenoverlay \"%s\"", material);
		else ClientCommand(client, "r_screenoverlay \"\"");
		SetCommandFlags("r_screenoverlay", iFlags);
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