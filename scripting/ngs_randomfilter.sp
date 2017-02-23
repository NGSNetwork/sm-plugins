#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>

#define PLUGIN_VERSION "1.0.5"

//--------------------//

public Plugin myinfo = {
	name = "[NGS] Random Filter",
	author = "TheXeon",
	description = "Adds a filter to target random people.",
	version = PLUGIN_VERSION,
	url = "https://matespastdates.servegame.com"
}

public void OnPluginStart()
{
	AddMultiTargetFilter("@random", TargetRandom, "Random player", false);
	AddMultiTargetFilter("@r", TargetRandom, "Random player", false);
	AddMultiTargetFilter("@randomred", TargetRandomRed, "Random player on red", false);
	AddMultiTargetFilter("@rred", TargetRandomRed, "Random player on red", false);
	AddMultiTargetFilter("@randomblue", TargetRandomBlue, "Random player on blue", false);
	AddMultiTargetFilter("@rblue", TargetRandomBlue, "Random player on blue", false);
}

public void OnPluginEnd ()
{
	RemoveMultiTargetFilter("@random", TargetRandom);
	RemoveMultiTargetFilter("@r", TargetRandom);
	RemoveMultiTargetFilter("@randomred", TargetRandomRed);
	RemoveMultiTargetFilter("@rred", TargetRandomRed);
	RemoveMultiTargetFilter("@randomblue", TargetRandomBlue);
	RemoveMultiTargetFilter("@rblue", TargetRandomBlue);
	
}

public bool TargetRandom(const char[] pattern, Handle clients)
{
	if (GetClientCount() < 1) return false;
	int client;
	do
	{
		client = GetRandomInt(1, MaxClients);
	}
	while(!IsClientInGame(client));
	PushArrayCell(clients, client);
	return true;
}

public bool TargetRandomBlue(const char[] pattern, Handle clients)
{
	if (GetTeamClientCount(view_as<int>(TFTeam_Blue)) < 1) return false;
	int client;
	do
	{
		client = GetRandomInt(1, MaxClients);
	}
	while(!IsClientInGame(client) || TF2_GetClientTeam(client) != TFTeam_Blue);
	PushArrayCell(clients, client);
	return true;
}

public bool TargetRandomRed(const char[] pattern, Handle clients)
{
	if (GetTeamClientCount(view_as<int>(TFTeam_Red)) < 1) return false;
	int client;
	do
	{
		client = GetRandomInt(1, MaxClients);
	}
	while(!IsClientInGame(client) || TF2_GetClientTeam(client) != TFTeam_Red);
	PushArrayCell(clients, client);
	return true;
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

