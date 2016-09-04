#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2>
#include <morecolors>
#define PLUGIN_VERSION "1.2.1"

ConVar cvarPluginVersion;

//--------------------//

public Plugin myinfo = {
	name = "[NGS] Admin Tools",
	author = "TheXeon",
	description = "Admin commands for NGS people.",
	version = PLUGIN_VERSION,
	url = "https://matespastdates.servegame.com"
}

public void OnPluginStart()
{
	RegAdminCmd("sm_forcerespawn", CommandForceRespawn, ADMFLAG_GENERIC, "Usage: sm_forcerespawn <#userid|name>");
	RegAdminCmd("sm_changeteam", CommandChangeTeam, ADMFLAG_GENERIC, "Usage: sm_changeteam <#userid|name> <team> (1 = Spec / 2 = Red / 3 = Blue)");
	RegAdminCmd("sm_sethealth", CommandSetHealth, ADMFLAG_GENERIC, " Usage: sm_sethealth <#userid|name> <amount>");
	RegAdminCmd("sm_bamall", CommandBamboozleAll, ADMFLAG_GENERIC, " Usage: sm_bamall <#userid|name>");
	
	cvarPluginVersion = CreateConVar("tf_ngsadmintoolkit_version", PLUGIN_VERSION, "Version of [NGS] Admin Toolkit");
	
	LoadTranslations("common.phrases");
}

public Action CommandForceRespawn(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_forcerespawn [target]");
		return Plugin_Handled;
	}
	char arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
 
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
 
	for (int i = 0; i < target_count; i++)
	{
		TF2_RespawnPlayer(target_list[i]);
		LogAction(client, target_list[i], "\"%L\" respawned \"%L\"!", client, target_list[i]);
	}
	
	if (tn_is_ml)
	{
		CShowActivity2(client, "{GREEN}[SM]{DEFAULT} ", "Respawned %t!", target_name);
	}
	else
	{
		CShowActivity2(client, "{GREEN}[SM]{DEFAULT} ", "Respawned %s!", target_name);
	}
	return Plugin_Handled;
}

public Action CommandChangeTeam(int client, int args)
{
	if (args < 2)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_changeteam [name] <team: 1/2/3>");
	}
	
	char arg1[MAX_NAME_LENGTH], arg2[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	int Team;
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
 
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	if (StringToInt(arg2) < 4 && StringToInt(arg2) > 0)
	{
		Team = StringToInt(arg2);
	} 
	else
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Please choose a team!");
		return Plugin_Handled;
	}
 
	for (int i = 0; i < target_count; i++)
	{
		ChangeClientTeam(target_list[i], Team);
		LogAction(client, target_list[i], "\"%L\" moved \"%L\" to team %d.", client, target_list[i], Team);
	}
 
	if (tn_is_ml)
		CShowActivity2(client, "{GREEN}[SM]{DEFAULT} ", "Moved %t to team %d!", target_name, Team);
	else
		CShowActivity2(client, "{GREEN}[SM]{DEFAULT} ", "Moved %s to team %d!", target_name, Team);
	return Plugin_Handled;
}

public Action CommandSetHealth(int client, int args)
{
	char arg1[MAX_TARGET_LENGTH], arg2[10], mod[32];
	int iHealth;

	GetGameFolderName(mod, sizeof(mod));

	if (args < 2)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_sethealth <#userid|name> <amount>");
		return Plugin_Handled;
	}
	else {
		GetCmdArg(1, arg1, sizeof(arg1));
		GetCmdArg(2, arg2, sizeof(arg2));
		iHealth = StringToInt(arg2);
	}

	if (iHealth < 0) {
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Health must be greater then zero.");
		return Plugin_Handled;
	}

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;

	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		if (StrEqual(mod, "tf", false)) 
		{		
			if (iHealth == 0)
				FakeClientCommand(target_list[i], "explode");
			else
			{
				SetEntProp(target_list[i], Prop_Data, "m_iMaxHealth", iHealth);
				SetEntityHealth(target_list[i], iHealth);
			}
		}

		else 
		{
			if (iHealth == 0)
				SetEntityHealth(target_list[i], 1);
			else
				SetEntityHealth(target_list[i], iHealth);
		}

		LogAction(client, target_list[i], "\"%L\" set \"%L\"'s health to  %i", client, target_list[i], iHealth);
	}

	if (tn_is_ml)
		CShowActivity2(client, "{GREEN}[SM]{DEFAULT} ", "Set {LIGHTGREEN}%t{DEFAULT}'s health to {LIGHTGREEN}%d{DEFAULT}.", target_name, iHealth);
	else
		CShowActivity2(client, "{GREEN}[SM]{DEFAULT} ", "Set {LIGHTGREEN}%s{DEFAULT}'s health to {LIGHTGREEN}%d{DEFAULT}.", target_name, iHealth);
	
	return Plugin_Handled;

}

public Action CommandBamboozleAll(int client, int args)
{
	if (args < 1) return Plugin_Handled;
	char arg1[MAX_BUFFER_LENGTH], playerName[MAX_NAME_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	int target = FindTarget(client, arg1, false, false);
	if (target == -1) return Plugin_Handled;
	GetClientName(target, playerName, sizeof(playerName));
		
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			EmitSoundToClient(i, "vo/demoman_specialcompleted11.mp3");
			EmitSoundToClient(i, "vo/demoman_specialcompleted11.mp3");
			Handle hHudText = CreateHudSynchronizer();
			SetHudTextParams(-1.0, 0.1, 3.0, 255, 0, 0, 255, 1, 1.0, 1.0, 1.0);
			ShowSyncHudText(i, hHudText, "BAMBOOZLED");
			CloseHandle(hHudText);
			LogAction(target, i, "\"%s\" bamboozled \"%L\"!", playerName, i);
		}
	}
	
	CPrintToChatAll("{GREEN}[SM]{DEFAULT} {LIGHTGREEN}%s{DEFAULT} just {RED}B{ORANGE}A{YELLOW}M{GREEN}B{BLUE}O{PURPLE}O{MAGENTA}Z{BLACK}L{WHITE}E{GREEN}D{DEFAULT} {LIGHTGREEN}EVERYONE{DEFAULT}!", playerName);
	CPrintToChatAll("{GREEN}[SM]{DEFAULT} FEEL THE {BLACK}B{BLUE}A{YELLOW}M{GREEN}B{ORANGE}O{PURPLE}O{MAGENTA}Z{RED}L{WHITE}E{DEFAULT}!");
	return Plugin_Handled;
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