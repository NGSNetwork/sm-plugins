/**
* TheXeon
* ngs_advert_antiflood.sp
*
* Files:
* addons/sourcemod/plugins/ngs_advert_antiflood.smx
* cfg/sourcemod/plugin.ngs_advert_antiflood.cfg
*
* Dependencies:
* sourcemod.inc, ngsutils.inc, ngsupdater.inc, sdktools.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <sourcemod>
#include <ngsutils>
#include <ngsupdater>
#include <sdktools>

char Chat1[MAXPLAYERS+1][1024], Chat2[MAXPLAYERS+1][1024], Chat3[MAXPLAYERS+1][1024], Chat4[MAXPLAYERS+1][1024];

bool IsBlocked[MAXPLAYERS + 1] = {false, ...};
int LineCount[MAXPLAYERS + 1] = 1;

SMDataTimer DelayTimer[MAXPLAYERS+1] = {null, ...};

ConVar sm_advertflood_time;
ConVar sm_advertflood_minlen;

public Plugin myinfo = {
	name = "[NGS] Advert Antiflood",
	author = "EHG / TheXeon",
	description = "Advert Antiflood",
	version = "1.0.5",
	url = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	sm_advertflood_time = CreateConVar("sm_advertflood_time", "5.00", "Amount of time allowed between advert chat messages");
	sm_advertflood_minlen = CreateConVar("sm_advertflood_minlen", "2", "Minimum length of text to be detected");

	AddCommandListener(Command_SayChat, "say");
	AddCommandListener(Command_SayChat, "say_team");
	AutoExecConfig();
}

public void OnClientPostAdminCheck(int client)
{
	IsBlocked[client] = false;
	LineCount[client] = 1;
	strcopy(Chat1[client], sizeof(Chat1[]), "NULL_INVALID_CHAT1");
	strcopy(Chat2[client], sizeof(Chat2[]), "NULL_INVALID_CHAT2");
	strcopy(Chat3[client], sizeof(Chat3[]), "NULL_INVALID_CHAT3");
	strcopy(Chat4[client], sizeof(Chat4[]), "NULL_INVALID_CHAT4");
	delete DelayTimer[client];
}


public void OnClientDisconnect(int client)
{
	delete DelayTimer[client];
}

public Action Command_SayChat(int client, const char[] command, int args)
{
	char CurrentChat[1024];
	if (GetCmdArgString(CurrentChat, sizeof(CurrentChat)) < 1 || client == 0)
	{
		return Plugin_Continue;
	}

	if (strlen(CurrentChat) >= sm_advertflood_minlen.IntValue)
	{
		int line = LineCount[client];
		switch(line)
		{
			case 1:
			{
				strcopy(Chat1[client], sizeof(Chat1[]), CurrentChat);
				LineCount[client] = 2;
				if (IsBlocked[client])
				{
					if (strcmp(CurrentChat, Chat2[client], false) == 0
					|| strcmp(CurrentChat, Chat3[client], false) == 0
					|| strcmp(CurrentChat, Chat4[client], false) == 0)
					{
						PrintToChat(client, "[SM] You are flooding the chat");
						return Plugin_Handled;
					}
				}
				else
				{
					StartTimer(client);
				}
			}
			case 2:
			{
				strcopy(Chat2[client], sizeof(Chat2[]), CurrentChat);
				LineCount[client] = 3;
				if (IsBlocked[client])
				{
					if (strcmp(CurrentChat, Chat1[client], false) == 0
					|| strcmp(CurrentChat, Chat3[client], false) == 0
					|| strcmp(CurrentChat, Chat4[client], false) == 0)
					{
						PrintToChat(client, "[SM] You are flooding the chat");
						return Plugin_Handled;
					}
				}
				else
				{
					StartTimer(client);
				}
			}
			case 3:
			{
				strcopy(Chat3[client], sizeof(Chat3[]), CurrentChat);
				LineCount[client] = 4;
				if (IsBlocked[client])
				{
					if (strcmp(CurrentChat, Chat1[client], false) == 0
					|| strcmp(CurrentChat, Chat2[client], false) == 0
					|| strcmp(CurrentChat, Chat4[client], false) == 0)
					{
						PrintToChat(client, "[SM] You are flooding the chat");
						return Plugin_Handled;
					}
				}
				else
				{
					StartTimer(client);
				}
			}
			case 4:
			{
				strcopy(Chat4[client], sizeof(Chat4[]), CurrentChat);
				LineCount[client] = 1;
				if (IsBlocked[client])
				{
					if (strcmp(CurrentChat, Chat1[client], false) == 0
					|| strcmp(CurrentChat, Chat2[client], false) == 0
					|| strcmp(CurrentChat, Chat3[client], false) == 0)
					{
						PrintToChat(client, "[SM] You are flooding the chat");
						return Plugin_Handled;
					}
				}
				else
				{
					StartTimer(client);
				}
			}
		}
	}

	return Plugin_Continue;
}


public void StartTimer(int client)
{
	IsBlocked[client] = true;
	delete DelayTimer[client];
	DataPack pack;
	DelayTimer[client] = new SMDataTimer(sm_advertflood_time.FloatValue, Timer_Reset, pack);
	pack.WriteCell(client);
	pack.WriteCell(GetClientUserId(client));
}

public Action Timer_Reset(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	int userid = pack.ReadCell();
	DelayTimer[client] = null;
	if (userid != GetClientUserId(client))
		return Plugin_Continue;

	strcopy(Chat1[client], sizeof(Chat1[]), "NULL_INVALID_CHAT1");
	strcopy(Chat2[client], sizeof(Chat2[]), "NULL_INVALID_CHAT2");
	strcopy(Chat3[client], sizeof(Chat3[]), "NULL_INVALID_CHAT3");
	strcopy(Chat4[client], sizeof(Chat4[]), "NULL_INVALID_CHAT4");
	IsBlocked[client] = false;
	return Plugin_Continue;
}
