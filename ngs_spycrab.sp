#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2>
#include <morecolors>
#define PLUGIN_VERSION "1.0"

//-------------------------------------------------------------------------------------------------
public Plugin myinfo = {
	name = "[NGS] Spy Crab Event Creator",
	author = "caty / TheXeon",
	description = "Start spycrab events!",
	version = PLUGIN_VERSION,
	url = "https://matespastdates.servegame.com"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_spycrab", CommandSpycrab, "starts and ends a spycrab");
}

public Action CommandSpycrab(int client, int args)
{
	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) == 1 || !IsPlayerAlive(client))
	{
		CReplyToCommand(client, "{GREEN}[SM]{NORMAL} Event: You must be alive to start this event.");
		return Plugin_Handled;
	}
	
	int clientTeam = GetClientTeam(client);
	if(clientTeam < 1 && clientTeam > 4)
	{
		float spy_redorigin[3];
		float spy_blueorigin[3];
		spy_redorigin[0] = 3096.031250;
		spy_redorigin[1] = 1970.062744;
		spy_redorigin[2] = 651.031311;
		spy_blueorigin[0] = 3099.921143;
		spy_blueorigin[1] = 1179.364258;
		spy_blueorigin[2] = 651.031311;
		
		if (clientTeam == 2) TeleportEntity(client, spy_redorigin, NULL_VECTOR, NULL_VECTOR);
		if (clientTeam == 3) TeleportEntity(client, spy_blueorigin, NULL_VECTOR, NULL_VECTOR);
		
		return Plugin_Handled;
	}
	return Plugin_Handled;
}