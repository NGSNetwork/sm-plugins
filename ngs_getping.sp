#pragma newdecls required
#pragma semicolon 1

#include <sdktools>
#include <sourcemod>
#define VERSION "1.0"

//-------------------------------------------------------------------------------------------------
public Plugin myinfo = {
	name = "[NGS] Get Ping",
	author = "caty / TheXeon",
	description = "Displays your ping.",
	version = VERSION,
	url = "matespastdates.servegame.com"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_ping", CommandGetPing, "Displays your ping.");
}

public Action CommandGetPing(int client, int args)
{
	if(IsClientInGame(client))
	{
		float ping = GetClientLatency(client, NetFlow_Outgoing) * 1024;
		ReplyToCommand(client, "Your ping is %f!", ping);
		return Plugin_Handled;
	}
	return Plugin_Handled;
}