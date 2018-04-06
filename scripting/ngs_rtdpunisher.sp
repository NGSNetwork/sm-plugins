/**
* TheXeon
* ngs_rtdpunisher.sp
*
* Files:
* addons/sourcemod/plugins/ngs_rtdpunisher.smx
*
* Dependencies:
* tf2_stocks.inc, multicolors.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define LIBRARY_ADDED_FUNC LibraryAdded
#define LIBRARY_REMOVED_FUNC LibraryRemoved
#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <tf2_stocks>
#include <multicolors>
#include <ngsutils>
#include <ngsupdater>

#undef REQUIRE_PLUGIN
#include <basecomm>
#include <sourcecomms>
#define REQUIRE_PLUGIN

int RTDCooldown[MAXPLAYERS + 1];
bool basecommExists, sourcecommsExists;

public Plugin myinfo = {
	name = "[NGS] RTD Punisher",
	author = "TheXeon",
	description = "Negatively affects those who try rtd.",
	version = "1.5.6",
	url = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_rtd", CommandRTDEffect, "Anti-RTD in chat.");
	RegConsoleCmd("sm_rollthedice", CommandRTDEffect, "Anti-RTD in chat.");

	AddCommandListener(Listener_Say, "say");
	AddCommandListener(Listener_Say, "say_team");
}

public void OnClientPutInServer(int client)
{
	RTDCooldown[client] = 0;
}

public void LibraryAdded(const char[] name)
{
	if (StrEqual(name, "basecomm", false))
	{
		basecommExists = true;
	}
	else if (StrEqual(name, "sourcecomms", false))
	{
		sourcecommsExists = true;
	}
}

public void LibraryRemoved(const char[] name)
{
	if (StrEqual(name, "basecomm", false))
	{
		basecommExists = false;
	}
	else if (StrEqual(name, "sourcecomms", false))
	{
		sourcecommsExists = false;
	}
}

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
		CPrintToChat(client, "{YELLOW}[LOLRTD]{DEFAULT} You must be alive to use RTD!");
		return;
	}

	int currentTime = GetTime();
	if (currentTime - RTDCooldown[client] < 7)
	{
		CPrintToChat(client, "{YELLOW}[LOLRTD]{DEFAULT} You must wait {PURPLE}%d{DEFAULT} seconds to roll again.", 7 - (currentTime - RTDCooldown[client]));
		return;
	}

	RTDCooldown[client] = currentTime;

	int randomEffectID = GetRandomInt(1, 3);

	switch (randomEffectID)
	{
		case 1:
		{
			SlapPlayer(client, 1000);
			CPrintToChat(client, "{YELLOW}[LOLRTD]{DEFAULT} You rolled {PURPLE}Instant Death{DEFAULT}! {LIGHTGREEN}Roll again!");
			SayToAllElse(client);
			return;
		}

		case 2:
		{
			TF2_IgnitePlayer(client, client);
			CPrintToChat(client, "{YELLOW}[LOLRTD]{DEFAULT} You rolled {PURPLE}Ignition{DEFAULT}! {LIGHTGREEN}We will unfortunately never have this plugin on the server.");
			SayToAllElse(client);
			return;
		}

		case 3:
		{
			TF2_RespawnPlayer(client);
			CPrintToChat(client, "{YELLOW}[LOLRTD]{DEFAULT} You rolled {PURPLE}Instant Respawn{DEFAULT}! {LIGHTGREEN}Roll again, randomness is based on your lag!");
			SayToAllElse(client);
			return;
		}
	}
	return;
}

public Action Listener_Say(int client, const char[] command, int argc)
{
	if (!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	char text[512];
	GetCmdArgString(text, sizeof(text));
	StripQuotes(text);

	if (!(FindCharInString(text, '/') == 1 || FindCharInString(text, '!') == 1 || FindCharInString(text, '@') == 1) &&
		(StrEqual(text, "rtd", false) || StrEqual(text, "rollthedice", false)))
	{
		if ((basecommExists && BaseComm_IsClientGagged(client)) || (sourcecommsExists && SourceComms_GetClientGagType(client) != bNot))
		{
			CPrintToChat(client, "{YELLOW}[RTD]{DEFAULT} Sorry, you may not use RTD!");
		}
		else
		{
			DoRTD(client);
		}
	}

	return Plugin_Continue;
}

public void SayToAllElse(int client)
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
					CPrintToChat(i, "{YELLOW}[LOLRTD]{DEFAULT} {LIGHTGREEN}%N{DEFAULT} rolled {GREEN}toxic{DEFAULT}!", client);
				}

				case 2:
				{
					CPrintToChat(i, "{YELLOW}[LOLRTD]{DEFAULT} {LIGHTGREEN}%N{DEFAULT} rolled {GREEN}instant kills{DEFAULT}!", client);
				}

				case 3:
				{
					CPrintToChat(i, "{YELLOW}[LOLRTD]{DEFAULT} {LIGHTGREEN}%N{DEFAULT} rolled {GREEN}godmode{DEFAULT}!", client);
				}

				case 4:
				{
					CPrintToChat(i, "{YELLOW}[LOLRTD]{DEFAULT} {LIGHTGREEN}%N{DEFAULT} rolled {GREEN}homing projectiles{DEFAULT}!", client);
				}

				case 5:
				{
					CPrintToChat(i, "{YELLOW}[LOLRTD]{DEFAULT} {LIGHTGREEN}%N{DEFAULT} rolled {GREEN}noclip{DEFAULT}!", client);
				}

				case 6:
				{
					CPrintToChat(i, "{YELLOW}[LOLRTD]{DEFAULT} {LIGHTGREEN}%N{DEFAULT} rolled {GREEN}sp00ky bullets{DEFAULT}!", client);
				}
			}
		}
	}
}
