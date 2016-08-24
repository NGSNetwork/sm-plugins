#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION  "1.0.1"

public Plugin myinfo = {
	name = "[NGS] Point_viewcontrol Fix",
	author = "MasterOfTheXP / TheXeon",
	description = "Fix for viewcontrols not being reset upon death.",
	version = PLUGIN_VERSION,
	url = "http://mstr.ca/"
}

public void OnPluginStart()
{
	HookEvent("player_death", Event_Death, EventHookMode_Pre);
	HookEvent("player_spawn", Event_Death, EventHookMode_Pre);
	CreateConVar("sm_pointviewcontrolfix_version", PLUGIN_VERSION, "Plugin version.", FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_SPONLY);
	HookEvent("teamplay_round_start", Event_RoundStart);
}

public Action Event_Death(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client)) return;
	if (GetEventInt(event, "death_flags") & 32) return; // Ignore fake deaths caused by the Dead Ringer in Team Fortress 2
	int ViewEnt = GetEntPropEnt(client, Prop_Data, "m_hViewEntity");
	
	if (ViewEnt > MaxClients)
	{
		char cls[25];
		GetEntityClassname(ViewEnt, cls, sizeof(cls));
		if (StrEqual(cls, "point_viewcontrol", false)) SetClientViewEntity(client, client);
	}
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	char Map[25];
	GetCurrentMap(Map, sizeof(Map));
	if (!StrEqual(Map, "trade_clocktown_b2a", false)) return;
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "func_button")) != -1)
	{
		char entName[25];
		GetEntPropString(entity, Prop_Data, "m_iName", entName, sizeof(entName));
		if (StrEqual(entName, "Telescope_button"))
			AcceptEntityInput(entity, "Unlock");
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