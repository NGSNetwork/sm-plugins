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

int BAMCooldown[MAXPLAYERS + 1];
bool BAMOptOut[MAXPLAYERS + 1];

//--------------------//

public Plugin myinfo = {
	name = "[NGS] Player Tools",
	author = "TheXeon",
	description = "Player commands for NGS people.",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.net"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_profile", CommandGetProfile, "Usage: sm_profile <#userid|name>");
	RegConsoleCmd("sm_friend", CommandGetProfile, "Usage: sm_friend <#userid|name>");
	RegConsoleCmd("sm_yum", CommandYum, "Usage: sm_yum");
	RegConsoleCmd("sm_doquack", CommandDoQuack, "Usage: sm_doquack");
	RegConsoleCmd("sm_bamboozle", CommandBamboozle, "Usage: sm_bamboozle <#userid|name>");
	RegConsoleCmd("sm_dontbamboozleme", CommandDontBamboozle, "Usage: sm_dontbamboozleme");
	RegConsoleCmd("sm_administration", CommandAdministration, "Usage: sm_administration");
	RegConsoleCmd("sm_chowmane", CommandChowMane, "Usage: sm_chowmane");
	RegConsoleCmd("sm_dazhlove", CommandDazhLove, "Usage: sm_dazhlove <#userid|name>");
	LoadTranslations("common.phrases");
}

public void OnMapStart()
{
	PrecacheSound("ambient/bumper_car_quack11.wav", false);
	PrecacheSound("vo/demoman_specialcompleted11.mp3", false);
	PrecacheSound("coach/coach_attack_here.wav", false);
	PrecacheSound("misc/happy_birthday_tf_08.wav", false);
}

public void OnClientPutInServer(int client)
{ 
	BAMCooldown[client] = 0; 
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
	int target = FindTarget(client, arg1, true, false);

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
	EmitSoundToClient(client, "ambient/bumper_car_quack11.wav");
	EmitSoundToClient(client, "ambient/bumper_car_quack11.wav");
	Handle hHudText = CreateHudSynchronizer();
	SetHudTextParams(-1.0, 0.1, 3.0, 255, 0, 0, 255, 1, 1.0, 1.0, 1.0);
	ShowSyncHudText(client, hHudText, "._o< *quack* >o_.");
	CloseHandle(hHudText);
	return Plugin_Handled;
}

public Action CommandBamboozle(int client, int args)
{
	if (!IsValidClient) return Plugin_Handled;
	
	if (BAMOptOut[client])
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You may not bamboozle when opted out. Use !dontbamboozleme to opt back in.");
		return Plugin_Handled;
	}
	
	int currentTime = GetTime(); 
	if (currentTime - BAMCooldown[client] < 7)
    {
   		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You must wait {PURPLE}%d{DEFAULT} seconds to bam again.", 7 - (currentTime - BAMCooldown[client]));
   		BAMCooldown[client] = currentTime;
   		return Plugin_Handled;
  	}

	BAMCooldown[client] = currentTime;
	
	if (args < 1)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_bamboozle <#userid|name>");
		return Plugin_Handled;
	}
	
	char arg1[MAX_BUFFER_LENGTH];
	
	GetCmdArg(1, arg1, sizeof(arg1));
	int target = FindTarget(client, arg1, true, false);

	if (target == -1) return Plugin_Handled;
	
	if (BAMOptOut[target])
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} The target has opted out of bamboozlement.");
		return Plugin_Handled;
	}
	
	EmitSoundToClient(target, "vo/demoman_specialcompleted11.mp3");
	EmitSoundToClient(target, "vo/demoman_specialcompleted11.mp3");
	EmitSoundToClient(target, "vo/demoman_specialcompleted11.mp3");
	Handle hHudText = CreateHudSynchronizer();
	SetHudTextParams(-1.0, 0.1, 3.0, 255, 0, 0, 255, 1, 1.0, 1.0, 1.0);
	ShowSyncHudText(target, hHudText, "BAMBOOZLED");
	ShowSyncHudText(client, hHudText, "BAMBOOZLED");
	CloseHandle(hHudText);
	
	char targetName[MAX_BUFFER_LENGTH], clientName[MAX_BUFFER_LENGTH];
	GetClientName(target, targetName, sizeof(targetName));
	GetClientName(client, clientName, sizeof(clientName));
	
	CPrintToChatAll("{GREEN}[SM]{DEFAULT} {LIGHTGREEN}%s{DEFAULT} just {RED}B{ORANGE}A{YELLOW}M{GREEN}B{BLUE}O{PURPLE}O{MAGENTA}Z{BLACK}L{WHITE}E{GREEN}D{DEFAULT} {LIGHTGREEN}%s{DEFAULT}!", clientName, targetName);
	return Plugin_Handled;
}

public Action CommandDontBamboozle(int client, int args)
{
	if (!IsValidClient) return Plugin_Handled;
	
	BAMOptOut[client] = !BAMOptOut[client];
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You have opted %s bamboozlement.", BAMOptOut[client] ? "out of" : "into");
	return Plugin_Handled;
}

public Action CommandChowMane(int client, int args)
{
	if (!IsValidClient) return Plugin_Handled;
	
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} APPLY CHOW MANE LIBERALLY TO EAR CANALS!!ONE!11!ONE");
	EmitSoundToClient(client, "coach/coach_attack_here.wav");
	return Plugin_Handled;
}

public Action CommandAdministration(int client, int args)
{
	if (!IsValidClient) return Plugin_Handled;
	/*
	char playerName[MAX_NAME_LENGTH];
	GetClientName(client, playerName, sizeof(playerName));
	*/
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Happy birthday, {LIGHTGREEN}%N{DEFAULT}!", client);
	EmitSoundToClient(client, "misc/happy_birthday_tf_08.wav");
	return Plugin_Handled;
}

public Action CommandDazhLove(int client, int args)
{
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Do {LIGHTGREEN}Dazh{DEFAULT}\'s parents love him?");
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} While the answer to this question might be unsure to him, we are definitely certain that we love {LIGHTGREEN}Dazh{DEFAULT}! We hope the best for you buddy, good luck in everything you ever do!");
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
