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
	AddMultiTargetFilter("@!randomred", TargetRandomNotRed, "Random player not on red", false);
	AddMultiTargetFilter("@!rred", TargetRandomNotRed, "Random player not on red", false);
	AddMultiTargetFilter("@randomblue", TargetRandomBlue, "Random player on blue", false);
	AddMultiTargetFilter("@rblue", TargetRandomBlue, "Random player on blue", false);
	AddMultiTargetFilter("@!randomblue", TargetRandomNotBlue, "Random player not on blue", false);
	AddMultiTargetFilter("@!rblue", TargetRandomNotBlue, "Random player not on blue", false);
}

public void OnPluginEnd ()
{
	RemoveMultiTargetFilter("@random", TargetRandom);
	RemoveMultiTargetFilter("@r", TargetRandom);
	RemoveMultiTargetFilter("@randomred", TargetRandomRed);
	RemoveMultiTargetFilter("@rred", TargetRandomRed);
	RemoveMultiTargetFilter("@!randomred", TargetRandomNotRed);
	RemoveMultiTargetFilter("@!rred", TargetRandomNotRed);
	RemoveMultiTargetFilter("@randomblue", TargetRandomBlue);
	RemoveMultiTargetFilter("@rblue", TargetRandomBlue);
	RemoveMultiTargetFilter("@!randomblue", TargetRandomNotBlue);
	RemoveMultiTargetFilter("@!rblue", TargetRandomNotBlue);
	
}

public bool TargetRandom(const char[] pattern, Handle clients)
{
	for (int iter = 0; iter < 5; iter++)
	{
		SetRandomSeed(GetTime() + iter);
		int client = GetRandomInt(1, MaxClients);
		if (IsValidClient(client))
		{
			PushArrayCell(clients, client);
			return true;
		}
	}
	return false;
}

public bool TargetRandomBlue(const char[] pattern, Handle clients)
{
	for (int iter = 0; iter < 5; iter++)
	{
		SetRandomSeed(GetTime() + iter);
		int client = GetRandomInt(1, MaxClients);
		if (IsValidClient(client))
		{
			if (TF2_GetClientTeam(client) == TFTeam_Blue)
			{
				PushArrayCell(clients, client);
				return true;
			}
		}
	}
	
	return false;
}

public bool TargetRandomRed(const char[] pattern, Handle clients)
{
	for (int iter = 0; iter < 5; iter++)
	{
		SetRandomSeed(GetTime() + iter);
		int client = GetRandomInt(1, MaxClients);
		if (IsValidClient(client))
		{
			if (TF2_GetClientTeam(client) == TFTeam_Red)
			{
				PushArrayCell(clients, client);
				return true;
			}
		}
	}
	
	return false;
}

public bool TargetRandomNotBlue(const char[] pattern, Handle clients)
{
	for (int iter = 0; iter < 5; iter++)
	{
		SetRandomSeed(GetTime() + iter);
		int client = GetRandomInt(1, MaxClients);
		if (IsValidClient(client))
		{
			if (TF2_GetClientTeam(client) != TFTeam_Blue && TF2_GetClientTeam(client) != TFTeam_Unassigned)
			{
				PushArrayCell(clients, client);
				return true;
			}
		}
	}
	
	return false;
}

public bool TargetRandomNotRed(const char[] pattern, Handle clients)
{
	for (int iter = 0; iter < 5; iter++)
	{
		SetRandomSeed(GetTime() + iter);
		int client = GetRandomInt(1, MaxClients);
		if (IsValidClient(client))
		{
			if (TF2_GetClientTeam(client) != TFTeam_Red && TF2_GetClientTeam(client) != TFTeam_Unassigned)
			{
				PushArrayCell(clients, client);
				return true;
			}
		}
	}
	
	return false;
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

