#pragma newdecls required
#pragma semicolon 1

#include <sdktools>
#include <sourcemod>
#define PLUGIN_VERSION "1.0"

//-------------------------------------------------------------------------------------------------
public Plugin myinfo = {
	name = "[NGS] Spy Crab Event Creator",
	author = "caty",
	description = "Use this command to start a spycrab event.",
	version = PLUGIN_VERSION,
	url = "https://matespastdates.servegame.com"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_spycrab_red", cmd_spycrab_blu, "starts and ends a spycrab");
	RegConsoleCmd("sm_spycrab_blu", cmd_spycrab_red, "starts and ends a spycrab");
}

public Action cmd_spycrab_red(int client, int args)
{
	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) <= 1 || !IsPlayerAlive(client))
	{
		ReplyToCommand(client, "[SM] Event: You must be alive to start this event.");
		return Plugin_Handled;
	}
	
	if(GetClientTeam(client) <= 2)
	{
	
	
	float spy_redorigin[3];
	spy_redorigin[0] = 3096.031250;
	spy_redorigin[1] = 1970.062744;
	spy_redorigin[2] = 651.031311;
	
	TeleportEntity(client, spy_redorigin, NULL_VECTOR, NULL_VECTOR);
	
	return Plugin_Handled;
	}
	return Plugin_Handled;
}

public Action cmd_spycrab_blu(int client, int args)
{
	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) <= 1 || !IsPlayerAlive(client))
	{
		ReplyToCommand(client, "[SM] Event: You must be alive to start this event.");
		return Plugin_Handled;
	}
	if(GetClientTeam(client) <= 0)
	{
		float spyorigin[3];
		spyorigin[0] = 3099.921143;
		spyorigin[1] = 1179.364258;
		spyorigin[2] = 651.031311;
		
		TeleportEntity(client, spyorigin, NULL_VECTOR, NULL_VECTOR);
		
		return Plugin_Handled;
	}
	return Plugin_Handled;
}