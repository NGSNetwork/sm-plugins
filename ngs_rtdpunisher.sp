#pragma newdecls required
#pragma semicolon 1

#include <sdktools>
#include <sourcemod>
#define VERSION "1.1"

//-------------------------------------------------------------------------------------------------
public Plugin myinfo = {
	name = "[NGS] RTD Punisher",
	author = "TheXeon",
	description = "Slaps those who try rtd",
	version = VERSION,
	url = "matespastdates.servegame.com"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_rtd", CommandRTDSlap, "Anti-RTD in chat.");
}

public Action CommandRTDSlap(client, args)
{
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		SlapPlayer(client, 1000);
		ReplyToCommand(client, "[RTD] You rolled Instant Death! We will unfortunately never have this plugin on the server.");
		return Plugin_Handled;
	}
	return Plugin_Handled;
}