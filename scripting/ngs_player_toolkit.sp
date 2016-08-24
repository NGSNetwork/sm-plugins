#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2>
#include <advanced_motd>
#include <morecolors>

#define PLUGIN_VERSION "1.0.0"
#define STEAMCOMMUNITY_PROFILESURL "https://steamcommunity.com/profiles/"

//--------------------//

public Plugin myinfo = {
	name = "[NGS] Player Tools",
	author = "TheXeon",
	description = "Player commands for NGS people.",
	version = PLUGIN_VERSION,
	url = "https://matespastdates.servegame.com"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_profile", CommandGetProfile, "Usage: sm_profile <#userid|name>");
	RegConsoleCmd("sm_friend", CommandGetProfile, "Usage: sm_friend <#userid|name>");
	RegConsoleCmd("sm_yum", CommandYum, "Usage: sm_yum");
	RegConsoleCmd("sm_doquack", CommandDoQuack, "Usage: sm_doquack");
	
	PrecacheSound("ambient/bumper_car_quack11.wav", false);
	
	LoadTranslations("common.phrases");
}

public Action CommandGetProfile(int client, int args)
{
	char arg1[MAX_TARGET_LENGTH];

	if (args < 1)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_profile <#userid|name>");
		return Plugin_Handled;
	}
	
	GetCmdArg(1, arg1, sizeof(arg1));
	int target = FindTarget(client, arg1);

	if (target == -1) return Plugin_Handled;
	
	
	char targetAuthID[MAX_BUFFER_LENGTH];
	char profileLink [MAX_BUFFER_LENGTH];
	GetClientAuthId(target, AuthId_SteamID64, targetAuthID, sizeof(targetAuthID), true);
	
	Format(profileLink, sizeof(profileLink), "%s%s", STEAMCOMMUNITY_PROFILESURL, targetAuthID);
	
	AdvMOTD_ShowMOTDPanel(client, "Steam Community", profileLink, MOTDPANEL_TYPE_URL, true, true, true);
	
	return Plugin_Handled;
}

public Action CommandYum(int client, int args)
{
	if (!IsValidClient) return Plugin_Handled;
	
	FakeClientCommand(client, "explode");
	CPrintToChat(client, "{GREEN}[SM]{DEFAULT} That's {LIGHTGREEN}Andy's{DEFAULT} thing, stahp.");
	return Plugin_Handled;
}

public Action CommandDoQuack(int client, int args)
{
	if (!IsValidClient) return Plugin_Handled;
	
	EmitSoundToClient(client, "ambient/bumper_car_quack11.wav");
	Handle hHudText = CreateHudSynchronizer();
	SetHudTextParams(-1.0, 0.1, 3.0, 255, 0, 0, 255, 1, 1.0, 1.0, 1.0);
	ShowSyncHudText(client, hHudText, "._o< *quack* >o_.");
	CloseHandle(hHudText);
	return Plugin_Handled;
}

public bool IsValidClient(int client)
{
	if(client > 4096) client = EntRefToEntIndex(client);
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsFakeClient(client)) return false;
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}
