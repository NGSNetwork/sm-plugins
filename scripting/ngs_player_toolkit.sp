#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <tf2_stocks>
#include <tf2>
#include <advanced_motd>
#include <multicolors>

#define PLUGIN_VERSION "1.0.0"
#define STEAMCOMMUNITY_PROFILESURL "https://steamcommunity.com/profiles/"

int BAMCooldown[MAXPLAYERS + 1];
bool BAMOptOut[MAXPLAYERS + 1];
bool isPlayerAutoTagEnabled[MAXPLAYERS + 1];
bool isDamageNotificationEnabled[MAXPLAYERS + 1];

ConVar cvarAutoTag;

Handle autoTagEnabledCookie;
Handle getDamageNotificationCookie;

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
	RegConsoleCmd("sm_rr", CommandRussianRoulette, "Usage: sm_rr <numofbullets>");
	RegConsoleCmd("sm_russianroulette", CommandRussianRoulette, "Usage: sm_russianroulette <numofbullets>");
	RegConsoleCmd("sm_autotag", CommandAutoTag, "Usage: sm_autotag to toggle");
	RegConsoleCmd("sm_wondertained", CommandWondertained, "Usage: sm_wondertained");
	RegConsoleCmd("sm_toggledamagenotif", CommandToggleDamageNotif, "Usage: sm_toggledamagenotif");
	RegConsoleCmd("sm_toggledamagenotifs", CommandToggleDamageNotif, "Usage: sm_toggledamagenotifs");
	LoadTranslations("common.phrases");
	
	cvarAutoTag = CreateConVar("sm_ngsplayertoolkit_autotag", "NGS", "Tag to give players, leave blank to disable.");
	autoTagEnabledCookie = RegClientCookie("AutoTagEnabled", "Is autotag enabled?", CookieAccess_Public);
	getDamageNotificationCookie = RegClientCookie("DamageNotifsEnabled", "Is damage notifications enabled.", CookieAccess_Public);
	
	HookEvent("player_death", OnPlayerDeath);
	
	for (int i = MaxClients; i > 0; --i)
	{
		if (!AreClientCookiesCached(i))
		{
			continue;
		}
		OnClientCookiesCached(i);
	}
}

public void OnMapStart()
{
	PrecacheSound("ambient/bumper_car_quack11.wav", false);
	PrecacheSound("vo/demoman_specialcompleted11.mp3", false);
	PrecacheSound("coach/coach_attack_here.wav", false);
	PrecacheSound("misc/happy_birthday_tf_08.wav", false);
	PrecacheSound("weapons/ambassador_shoot.wav", false);
	PrecacheSound("weapons/sentry_empty.wav", false);
	PrecacheSound("weapons/diamond_back_01.wav", false);
	
	// Laughing taunt
	PrecacheSound("vo/scout_laughlong02.mp3");
	PrecacheSound("vo/soldier_laughlong03.mp3");
	PrecacheSound("vo/pyro_laugh_addl04.mp3");
	PrecacheSound("vo/demoman_laughlong02.mp3");
	PrecacheSound("vo/heavy_laugherbigsnort01.mp3");
	PrecacheSound("vo/engineer_laughlong02.mp3");
	PrecacheSound("vo/medic_laughlong01.mp3");
	PrecacheSound("vo/sniper_laughlong02.mp3");
	PrecacheSound("vo/spy_laughlong01.mp3");
}

public void OnClientCookiesCached(int client)
{
	char sValue[8];
	char notifValue[8];
	GetClientCookie(client, autoTagEnabledCookie, sValue, sizeof(sValue));
	GetClientCookie(client, getDamageNotificationCookie, notifValue, sizeof(notifValue));
	
	isPlayerAutoTagEnabled[client] = (sValue[0] != '\0' && StringToInt(sValue));
	isDamageNotificationEnabled[client] = (notifValue[0] != '\0' && StringToInt(notifValue));
}

public void OnClientPostAdminCheck(int client)
{
	char tagvalue[24], namevalue[MAX_NAME_LENGTH];
	cvarAutoTag.GetString(tagvalue, sizeof(tagvalue));
	if (strlen(tagvalue) < 1) return;
	GetClientName(client, namevalue, sizeof(namevalue));
	if (AreClientCookiesCached(client) && isPlayerAutoTagEnabled[client] && CommandExists("sm_rename") && StrContains(namevalue, tagvalue, false) == -1)
	{
		int userid = GetClientUserId(client);
		ServerCommand("sm_rename #%d \"%s | %N\"", userid, tagvalue, client);
  	}
}

public void OnClientPutInServer(int client)
{ 
	BAMOptOut[client] = false;
	BAMCooldown[client] = 0; 
}

public Action CommandGetProfile(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;

	if (args < 1)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_profile <#userid|name>");
		return Plugin_Handled;
	}
	
	char arg1[MAX_TARGET_LENGTH];
	
	GetCmdArg(1, arg1, sizeof(arg1));
	int target = FindTarget(client, arg1, true, false);

	if (!IsValidClient(target)) return Plugin_Handled;
	
	
	char targetAuthID[MAX_BUFFER_LENGTH];
	char profileLink [MAX_BUFFER_LENGTH];
	if (GetClientAuthId(target, AuthId_SteamID64, targetAuthID, sizeof(targetAuthID)))
	{
		Format(profileLink, sizeof(profileLink), "%s%s", STEAMCOMMUNITY_PROFILESURL, targetAuthID);
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} %N\'s profile link: %s", target, profileLink);
		AdvMOTD_ShowMOTDPanel(client, "Steam Community", profileLink, MOTDPANEL_TYPE_URL, true, true, true);
	}
	else
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Sorry! %N doesn\'t seem to be connected to Steam!", target);
	}
	return Plugin_Handled;
}

public Action CommandYum(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	
	FakeClientCommand(client, "explode");
	CPrintToChat(client, "{GREEN}[SM]{DEFAULT} That's {LIGHTGREEN}Andy{DEFAULT}'s thing, stahp.");
	return Plugin_Handled;
}

public Action CommandDoQuack(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	
	EmitSoundToClient(client, "ambient/bumper_car_quack11.wav");
	EmitSoundToClient(client, "ambient/bumper_car_quack11.wav");
	EmitSoundToClient(client, "ambient/bumper_car_quack11.wav");
	Handle hHudText = CreateHudSynchronizer();
	SetHudTextParams(-1.0, 0.1, 3.0, 255, 0, 0, 255, 1, 1.0, 1.0, 1.0);
	ShowSyncHudText(client, hHudText, "._o< *quack* >o_.");
	CloseHandle(hHudText);
	return Plugin_Handled;
}

public Action CommandWondertained(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	EmitSoundToClient(client, "vo/scout_laughlong02.mp3");
	EmitSoundToClient(client, "vo/soldier_laughlong03.mp3");
	EmitSoundToClient(client, "vo/pyro_laugh_addl04.mp3");
	EmitSoundToClient(client, "vo/demoman_laughlong02.mp3");
	EmitSoundToClient(client, "vo/heavy_laugherbigsnort01.mp3");
	EmitSoundToClient(client, "vo/engineer_laughlong02.mp3");
	EmitSoundToClient(client, "vo/medic_laughlong01.mp3");
	EmitSoundToClient(client, "vo/sniper_laughlong02.mp3");
	EmitSoundToClient(client, "vo/spy_laughlong01.mp3");
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} This {RED}Command{DEFAULT} Is Brought To You By {LIGHTGREEN}Dr. Wondertainment{DEFAULT} And The People Of NGS.");
	return Plugin_Handled;
}

public Action CommandRussianRoulette(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	if (!IsPlayerAlive(client))
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You must be alive to use this!");
		return Plugin_Handled;
	}
	
	int numOfBullets = 1;
	if (args > 0)
	{
		char arg1[MAX_BUFFER_LENGTH];
		GetCmdArg(1, arg1, sizeof(arg1));
		numOfBullets = StringToInt(arg1);
		if (numOfBullets < 1 || numOfBullets > 6)
		{
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You can only load in up to 6 bullets!");
			return Plugin_Handled;
		}
	}
	
	int randomInt = GetRandomInt(1, 6);
	if (numOfBullets < randomInt)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You are safe!");
		EmitSoundToClient(client, "weapons/sentry_empty.wav");
		return Plugin_Handled;
	}
	else
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You lost!");
		FakeClientCommand(client, "kill");
		if (view_as<bool>(GetRandomInt(0, 1)))
			EmitSoundToClient(client, "weapons/ambassador_shoot.wav");
		else
			EmitSoundToClient(client, "weapons/diamond_back_01.wav");
		return Plugin_Handled;
	}
}

public Action CommandBamboozle(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	
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
	delete hHudText;
	
	char targetName[MAX_BUFFER_LENGTH], clientName[MAX_BUFFER_LENGTH];
	GetClientName(target, targetName, sizeof(targetName));
	GetClientName(client, clientName, sizeof(clientName));
	
	CPrintToChatAll("{GREEN}[SM]{DEFAULT} {LIGHTGREEN}%s{DEFAULT} just {RED}B{ORANGE}A{YELLOW}M{GREEN}B{BLUE}O{PURPLE}O{MAGENTA}Z{BLACK}L{WHITE}E{GREEN}D{DEFAULT} {LIGHTGREEN}%s{DEFAULT}!", clientName, targetName);
	return Plugin_Handled;
}

public Action CommandDontBamboozle(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	
	BAMOptOut[client] = !BAMOptOut[client];
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You have opted %s bamboozlement.", BAMOptOut[client] ? "out of" : "into");
	return Plugin_Handled;
}

public Action CommandChowMane(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} APPLY CHOW MANE LIBERALLY TO EAR CANALS!!ONE!11!ONE");
	EmitSoundToClient(client, "coach/coach_attack_here.wav");
	return Plugin_Handled;
}

public Action CommandAdministration(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
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

public Action CommandAutoTag(int client, int args)
{
	if (!IsValidClient(client) || !AreClientCookiesCached(client)) return Plugin_Handled;
  	
	char tagvalue[24], namevalue[MAX_NAME_LENGTH];
	cvarAutoTag.GetString(tagvalue, sizeof(tagvalue));
	if (strlen(tagvalue) < 1) return Plugin_Handled;
	GetClientName(client, namevalue, sizeof(namevalue));
	isPlayerAutoTagEnabled[client] = !isPlayerAutoTagEnabled[client];
	if (isPlayerAutoTagEnabled[client])
	{
		int userid = GetClientUserId(client);
		if (CommandExists("sm_rename") && StrContains(namevalue, tagvalue, false) == -1)
			ServerCommand("sm_rename #%d \"%s | %N\"", userid, tagvalue, client);
		SetClientCookie(client, autoTagEnabledCookie, "1");
		CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Your autotag has been enabled. Use !autotag to disable it.");
  	}
  	else
  	{
  		SetClientCookie(client, autoTagEnabledCookie, "0");
  		CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Your tag has been disabled. Reconnect to reset your name.");
  	}
 		
  	return Plugin_Handled;
}

public Action CommandToggleDamageNotif(int client, int args)
{
	if (!IsValidClient(client) || !AreClientCookiesCached(client)) return Plugin_Handled;
	
	char numToSet[4];
	Format(numToSet, sizeof(numToSet), "%s", isDamageNotificationEnabled[client] ? "0" : "1");
	SetClientCookie(client, getDamageNotificationCookie, numToSet);
	isDamageNotificationEnabled[client] = !isDamageNotificationEnabled[client];
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You %s receive damage notifications now. Use !toggledamagenotifs to %s it.", isDamageNotificationEnabled[client] ? "will" : "will not", isDamageNotificationEnabled[client] ? "disable" : "enable");
	return Plugin_Handled;
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int deathFlags = event.GetInt("death_flags");
	if (!IsValidClient(victim) || !IsValidClient(attacker)) return;
	if (!isDamageNotificationEnabled[victim] || victim == attacker || deathFlags & 32) return;
	int attackerHealth = 0;
	if (IsPlayerAlive(attacker))
		attackerHealth = GetClientHealth(attacker);
	CPrintToChat(victim, "{GREEN}[SM]{DEFAULT} {LIGHTGREEN}%N{DEFAULT} had {LIGHTGREEN}%d{DEFAULT} health remaining.", attacker, attackerHealth);
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
