#pragma newdecls required
#pragma semicolon 1

#include <sdktools>
#include <sourcemod>
#include <morecolors>

#define PLUGIN_VERSION "1.1"

//-------------------------------------------------------------------------------------------------
public Plugin myinfo = {
	name = "[NGS] Get Ping",
	author = "caty / TheXeon",
	description = "Displays your ping.",
	version = PLUGIN_VERSION,
	url = "matespastdates.servegame.com"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_ping", CommandGetPing, "Displays your ping.");
	LoadTranslations("common.phrases");
}

public Action CommandGetPing(int client, int args)
{
	if (args < 1)
	{
		char playerName[MAX_NAME_LENGTH];
		if(IsClientInGame(client))
		{
			GetClientName(client, playerName, sizeof(playerName));
			int ping = RoundToFloor(GetClientLatency(client, NetFlow_Outgoing) * 1024);
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Your ping is {LIGHTGREEN}%d{DEFAULT}!", ping);
			for(int i = 1 ; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && client != i)
				{
					AdminId adminid = GetUserAdmin(i);
					if(GetAdminFlag(adminid, Admin_Generic))
					{
						CPrintToChat(i, "{GREEN}[SM]{DEFAULT} {LIGHTGREEN}%s{DEFAULT} checked their ping, and it is {LIGHTGREEN}%d{DEFAULT}!", playerName, ping);
					}
				} 
			}
			LogMessage("%s checked their ping, and it is %d!", playerName, ping);
			return Plugin_Handled;
		}
	}
	
	char arg1[MAX_NAME_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));
	int target = FindTarget(client, arg1);
    
	if (target == -1)
	{
		PrintToConsole(client, "Could not find any player with the name: \"%s\"", arg1);
		return Plugin_Handled;
	}

	char targetName[MAX_NAME_LENGTH];
	GetClientName(target, targetName, sizeof(targetName));
	int targetPing = RoundToFloor(GetClientLatency(target, NetFlow_Outgoing) * 1024);
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} {LIGHTGREEN}%s{DEFAULT}'s ping is {GREEN}%d{DEFAULT}!", targetName, targetPing);
 
 
	return Plugin_Handled;
}