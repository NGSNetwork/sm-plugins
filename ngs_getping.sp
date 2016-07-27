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
}

public Action CommandGetPing(int client, int args)
{
	char playerName[MAX_NAME_LENGTH];
	GetClientName(client, playerName, sizeof(playerName));
	if(IsClientInGame(client))
	{
		float ping = GetClientLatency(client, NetFlow_Outgoing) * 1024;
		CReplyToCommand(client, "{GREEN}[SM]{NORMAL} Your ping is {LIGHTGREEN}%f{NORMAL}!", ping);
		LogMessage("%s checked their ping, and it is %f!", playerName, ping);
		return Plugin_Handled;
	}
	return Plugin_Handled;
}