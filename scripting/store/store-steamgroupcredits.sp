#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <SteamWorks>
#include <store>

ConVar iGroupID;
ConVar CreditsAdder;
ConVar group_adverts;
ConVar CreditsTime;
Handle TimeAuto = null;
bool b_IsMember[MAXPLAYERS+1];
int i_advert[MAXPLAYERS+1];

public Plugin myinfo = {
	name = "[NGS] Steam Group Credits",
	author = "Xines / TheXeon",
	description = "Deals x amount of credits per x amount of secounds",
	version = "1.1",
	url = "https://neogenesisnetwork.servegame.com"
}

public void OnPluginStart()
{
	//Chat print on/off for all players
	group_adverts = CreateConVar("sm_group_enable_adverts", "1", "Enables/Disables notifications for all in chat (1=On/0=Off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	//Chat print on/off Client
	RegConsoleCmd("sm_sgc", SgcCmd, "(On/Off) Steam Group Credits, Client Announcements");
	
	//Configs
	iGroupID = CreateConVar("sm_groupid_add", "0000000", "Steam Group ID (Replace with yours)", FCVAR_NOTIFY);
	CreditsAdder = CreateConVar("sm_group_credits", "5", "Credits to give per X time, if player is in group.", FCVAR_NOTIFY);
	CreditsTime = CreateConVar("sm_group_credits_time", "60", "Time in seconds to deal credits.", FCVAR_NOTIFY);
	
	//Don't Touch
	HookConVarChange(CreditsTime, Change_CreditsTime);
}

public void OnMapStart()
{
	TimeAuto = CreateTimer(GetConVarFloat(CreditsTime), CheckPlayers, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action CheckPlayers(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			addcredits(i);
		}
	}
	
	return Plugin_Continue;
}

public void addcredits(int client)
{
	if(b_IsMember[client])
	{
		Store_GiveCredits(Store_GetClientAccountID(client), GetConVarInt(CreditsAdder));
		if(GetConVarBool(group_adverts))
		{
			if(!i_advert[client]) CPrintToChat(client, "{GREEN}[SM]{DEFAULT} You received {TEAMCOLOR}%i{DEFAULT} credits for being a member of our {GREEN}steam group{DEFAULT}!", GetConVarInt(CreditsAdder));
		}
	}
}

public void OnClientPostAdminCheck(int client)
{
	if (IsFakeClient(client))
		return;

	b_IsMember[client] = false;
	SteamWorks_GetUserGroupStatus(client, GetConVarInt(iGroupID));
}

public int SteamWorks_OnClientGroupStatus(int authid, int groupAccountID, bool isMember, bool isOfficer)
{
	int client = UserAuthGrab(authid);
	
	if (client == -1)
	{
		return;
	}
	
	if(isMember)
	{
		b_IsMember[client] = true;
	}
}

public int UserAuthGrab(int authid)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		char charauth[64];
		GetClientAuthId(i, AuthId_Engine, charauth, sizeof(charauth));	
		char authchar[64];
		IntToString(authid, authchar, sizeof(authchar));
		if(StrContains(charauth, authchar) != -1)
		{
			return i;
		}
	}
	
	return -1;
}

public void Change_CreditsTime(Handle cvar, const char[] oldVal, const char[] newVal)
{
	if (TimeAuto != null)
	{
		KillTimer(TimeAuto);
		TimeAuto = null;
	}

	TimeAuto = CreateTimer(GetConVarFloat(CreditsTime), CheckPlayers, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action SgcCmd(int client, int args)
{
	if (!GetConVarBool(group_adverts))
	{
		return Plugin_Continue;
	}
	
	switch (i_advert[client])
	{
		case 0:
		{
			i_advert[client] = 1;
			CPrintToChat(client, "{GREEN}[Store]{DEFAULT} Group Announcements {GREEN}[OFF]");
		}
		default:
		{
			i_advert[client] = 0;
			CPrintToChat(client, "{GREEN}[Store]{DEFAULT} Group Announcements {GREEN}[ON]");
		}
	}
	
	return Plugin_Handled;
}