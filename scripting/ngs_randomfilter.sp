/**
* TheXeon
* ngs_randomfilter.sp
*
* Files:
* addons/sourcemod/plugins/ngs_randomfilter.smx
*
* Dependencies:
* tf2_stocks.inc, afk_manager.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <tf2_stocks>
#include <afk_manager>
#include <ngsutils>
#include <ngsupdater>

//--------------------//

public Plugin myinfo = {
	name = "[NGS] Random Filter",
	author = "TheXeon",
	description = "Adds a filter to target random people.",
	version = "1.1.2",
	url = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	AddMultiTargetFilter("@random", TargetRandom, "Random player", false);
	AddMultiTargetFilter("@r", TargetRandom, "Random player", false);
	AddMultiTargetFilter("@randomafk", TargetRandomAFK, "Random afk player", false);
	AddMultiTargetFilter("@randomnonafk", TargetRandomNonAFK, "Random nonafk player", false);
	AddMultiTargetFilter("@rafk", TargetRandomAFK, "Random afk player", false);
	AddMultiTargetFilter("@rnonafk", TargetRandomNonAFK, "Random nonafk player", false);
	AddMultiTargetFilter("@randomred", TargetRandomRed, "Random player on red", false);
	AddMultiTargetFilter("@rred", TargetRandomRed, "Random player on red", false);
	AddMultiTargetFilter("@randomblue", TargetRandomBlue, "Random player on blue", false);
	AddMultiTargetFilter("@rblue", TargetRandomBlue, "Random player on blue", false);
}

public void OnPluginEnd()
{
	RemoveMultiTargetFilter("@random", TargetRandom);
	RemoveMultiTargetFilter("@r", TargetRandom);
	RemoveMultiTargetFilter("@randomafk", TargetRandomAFK);
	RemoveMultiTargetFilter("@randomnonafk", TargetRandomNonAFK);
	RemoveMultiTargetFilter("@rafk", TargetRandomAFK);
	RemoveMultiTargetFilter("@rnonafk", TargetRandomNonAFK);
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

public bool TargetRandomAFK(const char[] pattern, Handle clients)
{
	if (GetClientCount() < 1) return false;
	int client;
	do
	{
		client = GetRandomInt(1, MaxClients);
	}
	while(!IsClientInGame(client) && !AFKM_IsClientAFK(client));
	PushArrayCell(clients, client);
	return true;
}

public bool TargetRandomNonAFK(const char[] pattern, Handle clients)
{
	if (GetClientCount() < 1) return false;
	int client;
	do
	{
		client = GetRandomInt(1, MaxClients);
	}
	while(!IsValidClient(client, _, _, _, _, true));
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
