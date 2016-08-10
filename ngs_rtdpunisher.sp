#pragma newdecls required
#pragma semicolon 1

#include <sdktools>
#include <sourcemod>
#include <tf2>
#include <morecolors>
#define PLUGIN_VERSION "1.1"

//-------------------------------------------------------------------------------------------------
public Plugin myinfo = {
	name = "[NGS] RTD Punisher",
	author = "TheXeon",
	description = "Slaps those who try rtd",
	version = PLUGIN_VERSION,
	url = "matespastdates.servegame.com"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_rtd", CommandRTDEffect, "Anti-RTD in chat.");
	RegConsoleCmd("sm_rollthedice", CommandRTDEffect, "Anti-RTD in chat.");
}

public Action CommandRTDEffect(int client, int args)
{
	if(!IsPlayerAlive(client) || !IsClientInGame(client))
	{
		CReplyToCommand(client, "{YELLOW}[RTD]{DEFAULT} You must be alive to use RTD!");
		return Plugin_Handled;
	}
	
	char playerName[MAX_NAME_LENGTH];
	GetClientName(client, playerName, sizeof(playerName));
	
	int randomEffectID = GetRandomInt(1, 3);
	
	switch (randomEffectID)
	{
		case 1:
		{
			SlapPlayer(client, 1000);
			CReplyToCommand(client, "{YELLOW}[RTD]{DEFAULT} You rolled {PURPLE}Instant Death{DEFAULT}!");
			SayToAllElse(client, playerName);
			return Plugin_Handled;
		}
		
		case 2:
		{
			TF2_IgnitePlayer(client, client);
			CReplyToCommand(client, "{YELLOW}[RTD]{DEFAULT} You rolled {PURPLE}Ignition{DEFAULT}! {LIGHTGREEN}We will unfortunately never have this plugin on the server.");
			SayToAllElse(client, playerName);
			return Plugin_Handled;
		}
		
		case 3:
		{
			TF2_RespawnPlayer(client);
			CReplyToCommand(client, "{YELLOW}[RTD]{DEFAULT} You rolled {PURPLE}Instant Respawn{DEFAULT}!");
			SayToAllElse(client, playerName);
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}

public void SayToAllElse(int iClient, char[] cPlayerName)
{
	int randomSayID = GetRandomInt(1, 6);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && i != iClient && IsClientInGame(i))
		{
			switch (randomSayID)
			{
				case 1:
				{
					CPrintToChat(i, "{YELLOW}[RTD]{DEFAULT} {LIGHTGREEN}%s{DEFAULT} rolled {GREEN}toxic{DEFAULT}!", cPlayerName);
				}
				
				case 2:
				{
					CPrintToChat(i, "{YELLOW}[RTD]{DEFAULT} {LIGHTGREEN}%s{DEFAULT} rolled {GREEN}instant kills{DEFAULT}!", cPlayerName);
				}
				
				case 3:
				{
					CPrintToChat(i, "{YELLOW}[RTD]{DEFAULT} {LIGHTGREEN}%s{DEFAULT} rolled {GREEN}godmode{DEFAULT}!", cPlayerName);
				}
				
				case 4:
				{
					CPrintToChat(i, "{YELLOW}[RTD]{DEFAULT} {LIGHTGREEN}%s{DEFAULT} rolled {GREEN}homing projectiles{DEFAULT}!", cPlayerName);
				}
				
				case 5:
				{
					CPrintToChat(i, "{YELLOW}[RTD]{DEFAULT} {LIGHTGREEN}%s{DEFAULT} rolled {GREEN}noclip{DEFAULT}!", cPlayerName);
				}
				
				case 6:
				{
					CPrintToChat(i, "{YELLOW}[RTD]{DEFAULT} {LIGHTGREEN}%s{DEFAULT} rolled {GREEN}sp00ky bullets{DEFAULT}!", cPlayerName);
				}
			}
		}
	}
}