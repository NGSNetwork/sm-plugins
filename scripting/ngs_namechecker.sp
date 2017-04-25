#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <morecolors>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = {
	name = "[NGS] NameChecker",
	author = "TheXeon",
	description = "Checks if names are only special characters.",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.net"
}

public void OnClientPostAdminCheck(int client)
{
	char playerName[MAX_NAME_LENGTH];
	GetClientName(client, playerName, sizeof(playerName));
	bool nameIsSpecialCharacters = true;
	for (int i = 0; i <= strlen(playerName); i++)
	{
		if (IsCharAlpha(playerName[i]) || IsCharNumeric(playerName[i]))
		{
			nameIsSpecialCharacters = false;
			break;
		}
	}
	if (nameIsSpecialCharacters)
	{
		int userid = GetClientUserId(client);
		if (CommandExists("sm_rename"))
		{
			ServerCommand("sm_rename #%d \"INowHaveAName#%d\"", userid, userid);
			if (CommandExists("sm_namelock")) ServerCommand("sm_namelock #%d 1", userid);
			LogMessage("Renamed %s to %N!", playerName, client);
		}
		else
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC))
				{
					CPrintToChat(client, "{GREEN}[SM]{DEFAULT} %N(#%d) has all special characters as their name! Use their UserID for targetting.", client, userid);
				}
			}
		}
	}
}