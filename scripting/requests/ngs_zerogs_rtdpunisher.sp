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
	name = "[NGS] 0GS RTD Punisher",
	author = "TheXeon",
	description = "Negatively affects those who try rtd.",
	version = PLUGIN_VERSION,
	url = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_rtd", CommandRTDEffect, "Anti-RTD in chat.");
	RegConsoleCmd("sm_rollthedice", CommandRTDEffect, "Anti-RTD in chat.");
	RegConsoleCmd("say", CommandSay);
	RegConsoleCmd("say_team", CommandSay);
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
		CReplyToCommand(client, "{YELLOW}[RTD]{DEFAULT} You must be alive to use RTD!");
		return;
	}
	
	int currentTime = GetTime(); 
	if (currentTime - RTDCooldown[client] < 7)
    {
   		CReplyToCommand(client, "{YELLOW}[RTD]{DEFAULT} You must wait {PURPLE}%d{DEFAULT} seconds to roll again.", 7 - (currentTime - RTDCooldown[client]));
   		return;
  	}

	RTDCooldown[client] = currentTime;
	
	ServerCommand("sm_burn #%d", GetClientUserId(client));
	return;
}

public Action CommandSay(int client, int args)
{
	char text[512];
	GetCmdArgString(text, sizeof(text));
	
	if (!(FindCharInString(text, '/') == 1 || FindCharInString(text, '!') == 1) && 
		(StrEqual(text, "rtd", false) || StrEqual(text, "rollthedice", false)))
	{
		if (basecommExists && BaseComm_IsClientGagged(client))
		{
			CPrintToChat(client, "{YELLOW}[RTD]{DEFAULT} Sorry, you may not use RTD!");
			return Plugin_Handled;
		}
		else
		{
			DoRTD(client);
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
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