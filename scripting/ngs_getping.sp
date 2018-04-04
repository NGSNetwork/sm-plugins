/**
* TheXeon
* ngs_getping.sp
*
* Files:
* addons/sourcemod/plugins/ngs_getping.smx
*
* Dependencies:
* multicolors.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <multicolors>
#include <ngsutils>
#include <ngsupdater>

//-------------------------------------------------------------------------------------------------
public Plugin myinfo = {
	name = "[NGS] Get Ping",
	author = "caty / TheXeon",
	description = "Displays your ping.",
	version = "1.1.1",
	url = "https://www.neogenesisnetwork.net"
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
		if(IsValidClient(client))
		{
			int ping = RoundToNearest(GetClientLatency(client, NetFlow_Outgoing) * 1024);
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Your ping is {LIGHTGREEN}%d{DEFAULT}!", ping);
			for(int i = 1 ; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && client != i)
				{
					AdminId adminid = GetUserAdmin(i);
					if(GetAdminFlag(adminid, Admin_Generic))
					{
						CPrintToChat(i, "{GREEN}[SM]{DEFAULT} {LIGHTGREEN}%N{DEFAULT} checked their ping, and it is {LIGHTGREEN}%d{DEFAULT}!", client, ping);
					}
				} 
			}
			LogMessage("%N checked their ping, and it is %d!", client, ping);
		}
		return Plugin_Handled;
	}

	char arg1[MAX_NAME_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));
	int target = FindTarget(client, arg1);
    
	if (!IsValidClient(target))
	{
		CReplyToCommand(client, "Invalid client \"%s\"", arg1);
		return Plugin_Handled;
	}

	int targetPing = RoundToNearest(GetClientLatency(target, NetFlow_Outgoing) * 1024);
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} {LIGHTGREEN}%N{DEFAULT}'s ping is {GREEN}%d{DEFAULT}!", target, targetPing);
 
 
	return Plugin_Handled;
}