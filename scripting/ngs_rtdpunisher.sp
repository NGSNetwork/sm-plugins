#pragma newdecls required
#pragma semicolon 1

#include <sdktools>
#include <sourcemod>
#include <tf2>
#include <morecolors>
#include <clientprefs>

#undef REQUIRE_PLUGIN
#include <basecomm>


#define PLUGIN_VERSION "1.5"

//-------------------------------------------------------------------------------------------------

int RTDCooldown[MAXPLAYERS + 1];
bool basecommExists = false;

//-------------------------------------------------------------------------------------------------

public Plugin myinfo = {
	name = "[NGS] RTD Punisher",
	author = "TheXeon",
	description = "Negatively affects those who try rtd",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.net"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_rtd", CommandRTDEffect, "Anti-RTD in chat.");
	RegConsoleCmd("sm_rollthedice", CommandRTDEffect, "Anti-RTD in chat.");
	RegConsoleCmd("say", Listener_Say);
	RegConsoleCmd("say_team", Listener_Say);
}

public void OnClientPutInServer(int client)
{ 
	RTDCooldown[client] = 0; 
}

public void OnLibraryAdded(const char[] name) { if (StrEqual(name, "basecomm")) basecommExists = true; }

public void OnLibraryRemoved(const char[] name) { if (StrEqual(name, "basecomm")) basecommExists = false; }

public Action CommandRTDEffect(int client, int args)
{
	DoRTD(client);
	return Plugin_Handled;
}

public void DoRTD(int client)
{
	if (!IsValidClient(client)) return;
	
	if(!IsPlayerAlive(client))
	{
		CReplyToCommand(client, "{YELLOW}[LOLRTD]{DEFAULT} You must be alive to use RTD!");
		return;
	}
	
	int currentTime = GetTime(); 
	if (currentTime - RTDCooldown[client] < 7)
    {
   		CReplyToCommand(client, "{YELLOW}[LOLRTD]{DEFAULT} You must wait {PURPLE}%d{DEFAULT} seconds to roll again.", 7 - (currentTime - RTDCooldown[client]));
   		return;
  	}

	RTDCooldown[client] = currentTime;
	
	char playerName[MAX_NAME_LENGTH];
	GetClientName(client, playerName, sizeof(playerName));
	
	int randomEffectID = GetRandomInt(1, 3);
	
	switch (randomEffectID)
	{
		case 1:
		{
			SlapPlayer(client, 1000);
			CReplyToCommand(client, "{YELLOW}[LOLRTD]{DEFAULT} You rolled {PURPLE}Instant Death{DEFAULT}! {LIGHTGREEN}Roll again!");
			SayToAllElse(client, playerName);
			return;
		}
		
		case 2:
		{
			TF2_IgnitePlayer(client, client);
			CReplyToCommand(client, "{YELLOW}[LOLRTD]{DEFAULT} You rolled {PURPLE}Ignition{DEFAULT}! {LIGHTGREEN}We will unfortunately never have this plugin on the server.");
			SayToAllElse(client, playerName);
			return;
		}
		
		case 3:
		{
			TF2_RespawnPlayer(client);
			CReplyToCommand(client, "{YELLOW}[LOLRTD]{DEFAULT} You rolled {PURPLE}Instant Respawn{DEFAULT}! {LIGHTGREEN}Roll again, randomness is based on your lag!");
			SayToAllElse(client, playerName);
			return;
		}
	}
	return;
}

public Action Listener_Say(int client, int args)
{
	char text[512];
	GetCmdArgString(text, sizeof(text));
	StripQuotes(text);
	// LogMessage("Text is %s!", text);
	if (!(FindCharInString(text, '/') == 1 || FindCharInString(text, '!') == 1) && 
		(StrEqual(text, "rtd", false) || StrEqual(text, "rollthedice", false)))
	{
		if (basecommExists && BaseComm_IsClientGagged(client))
		{
			CPrintToChat(client, "{YELLOW}[RTD]{DEFAULT} Sorry, you may not use RTD!");
			return Plugin_Continue;
		}
		else
		{
			DoRTD(client);
			return Plugin_Continue;
		}
	}
	
	return Plugin_Continue;
}

public void SayToAllElse(int client, char[] cPlayerName)
{
	int randomSayID = GetRandomInt(1, 6);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && i != client)
		{
			switch (randomSayID)
			{
				case 1:
				{
					CPrintToChat(i, "{YELLOW}[LOLRTD]{DEFAULT} {LIGHTGREEN}%s{DEFAULT} rolled {GREEN}toxic{DEFAULT}!", cPlayerName);
				}
				
				case 2:
				{
					CPrintToChat(i, "{YELLOW}[LOLRTD]{DEFAULT} {LIGHTGREEN}%s{DEFAULT} rolled {GREEN}instant kills{DEFAULT}!", cPlayerName);
				}
				
				case 3:
				{
					CPrintToChat(i, "{YELLOW}[LOLRTD]{DEFAULT} {LIGHTGREEN}%s{DEFAULT} rolled {GREEN}godmode{DEFAULT}!", cPlayerName);
				}
				
				case 4:
				{
					CPrintToChat(i, "{YELLOW}[LOLRTD]{DEFAULT} {LIGHTGREEN}%s{DEFAULT} rolled {GREEN}homing projectiles{DEFAULT}!", cPlayerName);
				}
				
				case 5:
				{
					CPrintToChat(i, "{YELLOW}[LOLRTD]{DEFAULT} {LIGHTGREEN}%s{DEFAULT} rolled {GREEN}noclip{DEFAULT}!", cPlayerName);
				}
				
				case 6:
				{
					CPrintToChat(i, "{YELLOW}[LOLRTD]{DEFAULT} {LIGHTGREEN}%s{DEFAULT} rolled {GREEN}sp00ky bullets{DEFAULT}!", cPlayerName);
				}
			}
		}
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