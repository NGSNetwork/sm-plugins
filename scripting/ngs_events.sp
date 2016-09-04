#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2>
#include <morecolors>
#define PLUGIN_VERSION "1.2.1"

bool bBossBattleStarted;

//--------------------//

public Plugin myinfo = {
	name = "[NGS] Events",
	author = "TheXeon",
	description = "Events for NGS people.",
	version = PLUGIN_VERSION,
	url = "https://matespastdates.servegame.com"
}

public void OnPluginStart()
{
	RegAdminCmd("sm_startbossbattle", CommandStartBossBattle, ADMFLAG_GENERIC, "Starts a boss battle");
	LoadTranslations("common.phrases");
}

public Action CommandStartBossBattle(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_startbossbattle [target]");
		return Plugin_Handled;
	}
	char arg1[32];	GetCmdArg(1, arg1, sizeof(arg1));
	char arg2[32];	GetCmdArg(2, arg2, sizeof(arg2));
	char arg3[32];	GetCmdArg(3, arg3, sizeof(arg3));
	char arg4[32];	GetCmdArg(4, arg4, sizeof(arg4));
	char arg5[32];	GetCmdArg(5, arg5, sizeof(arg5));

	SpawnBoss
	
	return Plugin_Handled;
}

public void SpawnBoss(char[] cBossName, int iBossAmount = 1, int iBossHealth = 5000, int iBossSize bool bCrits = false)
{
	
}

public bool IsValidClient (int client)
{
	if(client > 4096) client = EntRefToEntIndex(client);
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsFakeClient(client)) return false;
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}