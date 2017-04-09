#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.5"


char Chat1[MAXPLAYERS+1][1024], Chat2[MAXPLAYERS+1][1024], Chat3[MAXPLAYERS+1][1024], Chat4[MAXPLAYERS+1][1024];

bool IsBlocked[MAXPLAYERS + 1] = {false, ...};
int LineCount[MAXPLAYERS + 1] = 1;

Handle DelayTimer[MAXPLAYERS+1] = {null, ...};

ConVar sm_advertflood_time;
ConVar sm_advertflood_minlen;

public Plugin myinfo = {
	name = "[NGS] Advert Antiflood",
	author = "EHG / TheXeon",
	description = "Advert Antiflood",
	version = PLUGIN_VERSION,
	url = ""
}

public void OnPluginStart()
{
	CreateConVar("sm_advertflood_version", PLUGIN_VERSION, "Advert Antiflood Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	sm_advertflood_time = CreateConVar("sm_advertflood_time", "5.00", "Amount of time allowed between advert chat messages");
	sm_advertflood_minlen = CreateConVar("sm_advertflood_minlen", "2", "Minimum length of text to be detected");
	
	
	AddCommandListener(Command_SayChat, "say");
	AddCommandListener(Command_SayChat, "say_team");
}

public void OnClientPostAdminCheck(int client)
{
	IsBlocked[client] = false;
	LineCount[client] = 1;
	strcopy(Chat1[client], sizeof(Chat1[]), "NULL_INVALID_CHAT1");
	strcopy(Chat2[client], sizeof(Chat2[]), "NULL_INVALID_CHAT2");
	strcopy(Chat3[client], sizeof(Chat3[]), "NULL_INVALID_CHAT3");
	strcopy(Chat4[client], sizeof(Chat4[]), "NULL_INVALID_CHAT4");
	DelayTimer[client] = INVALID_HANDLE;
}


public void OnClientDisconnect(int client)
{
	if (DelayTimer[client] != INVALID_HANDLE)
	{
		CloseHandle(DelayTimer[client]);
		DelayTimer[client] = INVALID_HANDLE;
	}
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
	if (DelayTimer[client] != null)
	{
		CloseHandle(DelayTimer[client]);
		DelayTimer[client] = null;
	}
	DataPack pack;
	DelayTimer[client] = CreateDataTimer(sm_advertflood_time.FloatValue, Timer_Reset, pack);
	pack.WriteCell(client);
	pack.WriteCell(GetClientUserId(client));
}

public Action Timer_Reset(Handle timer, DataPack pack)
{
	int client;
	int userid;
	pack.Reset();
	client = pack.ReadCell();
	userid = pack.ReadCell();
	if (userid != GetClientUserId(client))
		return Plugin_Handled;
	
	DelayTimer[client] = INVALID_HANDLE;
	strcopy(Chat1[client], sizeof(Chat1[]), "NULL_INVALID_CHAT1");
	strcopy(Chat2[client], sizeof(Chat2[]), "NULL_INVALID_CHAT2");
	strcopy(Chat3[client], sizeof(Chat3[]), "NULL_INVALID_CHAT3");
	strcopy(Chat4[client], sizeof(Chat4[]), "NULL_INVALID_CHAT4");
	IsBlocked[client] = false;
	return Plugin_Handled;
}


