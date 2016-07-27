#pragma newdecls required
#pragma semicolon 1

#include <sdktools>
#include <sourcemod>
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
	RegConsoleCmd("sm_rtd", CommandRTDSlap, "Anti-RTD in chat.");
}

public Action CommandRTDSlap(int client, int args)
{
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		SlapPlayer(client, 1000);
		CReplyToCommand(client, "{YELLOW}[RTD]{NORMAL} You rolled {GREEN}Instant Death{NORMAL}! {LIGHTGREEN}We will unfortunately never have this plugin on the server.");
		return Plugin_Handled;
	}
	return Plugin_Handled;
}