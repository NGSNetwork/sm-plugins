#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <morecolors>

#define PLUGIN_VERSION "1.0"

int arr_RaffleNum[MAXPLAYERS + 1];
int rafflemax;

public Plugin myinfo = {
	name = "[NGS] Raffle",
	author = "NuclearWatermelon / TheXeon",
	description = "Raffle number generator",
	version = PLUGIN_VERSION,
	url = "https://matespastdates,servegame.com"
}

public void OnPluginStart() 
{
	CreateConVar("sm_raffle_version", PLUGIN_VERSION, "Generates a random number for a raffle.", FCVAR_NOTIFY | FCVAR_REPLICATED);
	RegAdminCmd("sm_raffle", CommandGenerateRaffle, ADMFLAG_CHAT, "Generates a random number for a raffle.");
	RegAdminCmd("sm_raffle_assign", CommandAssignRaffle, ADMFLAG_CHAT, "Assigns a raffle number to a player.");
	RegAdminCmd("sm_raffle_remove", CommandRemoveRaffle, ADMFLAG_CHAT, "Removes a raffle number from a player.");
	RegAdminCmd("sm_raffle_cancel", CommandCancelRaffle, ADMFLAG_CHAT, "Cancels a raffle.");
	RegConsoleCmd("sm_raffle_list", CommandListRaffle, "List those in a raffle.");
	LoadTranslations("common.phrases");
	rafflemax = 0;
}

public Action CommandListRaffle(int client, int args) 
{
	if (args > 1) {
		CReplyToCommand(client, "{GREEN}[RAFFLE]{DEFAULT} Usage: sm_raffle_list");
		return Plugin_Handled;
	}
	for (int i = 0; i <= MAXPLAYERS; i++) {
		if (arr_RaffleNum[i] != 0) {
			char rafflename[32];
			GetClientName(i, rafflename, sizeof(rafflename));			
			CPrintToChat(client, "{LIGHTGREEN}%s{DEFAULT} has raffle number {GREEN}%d{DEFAULT}.", rafflename, arr_RaffleNum[i]);
		}
	}
	return Plugin_Handled;
}

public Action CommandCancelRaffle(int client, int args) 
{
	if (args > 0) {
		CReplyToCommand(client, "{GREEN}[RAFFLE]{DEFAULT} Usage: sm_raffle_cancel");
		return Plugin_Handled;
	}
	for (int i = 0; i <= MAXPLAYERS; i++) {
		arr_RaffleNum[i] = 0;
	}
	CPrintToChatAll("{GREEN}[RAFFLE]{DEFAULT} The raffle has been canceled.");
	rafflemax = 0;
	
	char clientname[32];
	GetClientName(client, clientname, sizeof(clientname));
	LogAction(client, -1, "%s canceled the raffle.", clientname);
	
	return Plugin_Handled;
}

public Action CommandGenerateRaffle(int client, int args) 
{
	if (args > 1) {
		CReplyToCommand(client, "{GREEN}[RAFFLE]{DEFAULT} Usage: sm_raffle");
		return Plugin_Handled;
	}
	if (rafflemax == 0) {
		CReplyToCommand(client, "{GREEN}[RAFFLE]{DEFAULT} No persons in the raffle.");
		return Plugin_Handled;
	}
	if (rafflemax == 1) {
		CReplyToCommand(client, "{GREEN}[RAFFLE]{DEFAULT} Only one person in the raffle.");
		return Plugin_Handled;
	}
	int randnumber;
	randnumber = GetRandomInt(1, rafflemax);
	CPrintToChatAll("{GREEN}[RAFFLE]{DEFAULT} The winning raffle number is {GREEN}%d!", randnumber);
	for (int i = 0; i <= MAXPLAYERS; i++) {
		if (arr_RaffleNum[i] == randnumber) {
			char winname[32];
			GetClientName(i, winname, sizeof(winname));
			CPrintToChatAll("{GREEN}[RAFFLE]{DEFAULT} The winner of the raffle is {LIGHTGREEN}%s!", winname);
			LogAction(client, -1, "%s won the raffle with raffle number %d.", winname, randnumber);
			arr_RaffleNum[i] = 0;
		}
		else {
			arr_RaffleNum[i] = 0;
		}
	}
	rafflemax = 0;
	return Plugin_Handled;
}

public Action CommandAssignRaffle(int client, int args) 
{
	if (args < 1) {
		CReplyToCommand(client, "{GREEN}[RAFFLE]{DEFAULT} Usage: sm_raffle_assign <name> <name2> ...");
		return Plugin_Handled;
	}
	int argnum = 1;
	while (argnum <= args) {
		char argstr[32];
		GetCmdArg(argnum, argstr, sizeof(argstr));
		
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count; 
		bool tn_is_ml;

		if ((target_count = ProcessTargetString(argstr, 
			client, 
			target_list, 
			MAXPLAYERS, 
			COMMAND_FILTER_NO_IMMUNITY|COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED, 
			target_name, 
			sizeof(target_name), 
			tn_is_ml)) <= 0) {
			ReplyToTargetError(client, target_count);
			argnum++;
			return Plugin_Handled;
		}
		for (int i = 0; i < target_count; i++) {
			char rafflename[32];
			GetClientName(target_list[i], rafflename, sizeof(rafflename));
			if (arr_RaffleNum[target_list[i]] > 0) {
				CReplyToCommand(client, "{GREEN}[RAFFLE]{DEFAULT} {LIGHTGREEN}%s {DEFAULT}is already in the raffle.", rafflename);
				continue;
			}
			rafflemax++;	
			arr_RaffleNum[target_list[i]] = rafflemax;
			CShowActivity2(client, "{GREEN}[RAFFLE]{DEFAULT} ", "{LIGHTGREEN}%s{DEFAULT} has raffle number %d!", rafflename, rafflemax);
			LogAction(client, target_list[i], "%s was given raffle number %d.", rafflename, rafflemax);
			argnum++;
		}
	}
	return Plugin_Handled;
}


public Action CommandRemoveRaffle(int client, int args) 
{
	if (args < 1) {
		CReplyToCommand(client, "{GREEN}[RAFFLE]{DEFAULT} Usage: sm_raffle_remove <name> <name2> ...");
		return Plugin_Handled;
	}
	int argnum = 1;
	while (argnum <= args) {
		char argstr[32];
		GetCmdArg(argnum, argstr, sizeof(argstr));
		int target = FindTarget(client, argstr, true, false);
		if  (target == -1) 
		{
			argnum++;
		}
		else 
		{
			char rafflename[32];
			GetClientName(target, rafflename, sizeof(rafflename));
			if (arr_RaffleNum[target] == 0) {
				CReplyToCommand(client, "{GREEN}[RAFFLE]{DEFAULT} {LIGHTGREEN}%s{DEFAULT} was not in the raffle to begin with!", rafflename);
				return Plugin_Handled;
			}
			int removenum = arr_RaffleNum[target];
			arr_RaffleNum[target] = 0;
			CPrintToChatAll("{GREEN}[RAFFLE]{DEFAULT} {LIGHTGREEN}%s{DEFAULT} was removed from the raffle!", rafflename);
			LogAction(client, target, "%s was removed from the raffle", rafflename);
			
			if (removenum != 0)
			{
				for (int i = 1; i <= rafflemax; i++) 
				{
					if (!IsClientInGame(i)) 
					{
						for (int nextPerson = i + 1; nextPerson <= rafflemax; nextPerson++)
						{
							arr_RaffleNum[nextPerson] = arr_RaffleNum[nextPerson] - 1;
							LogMessage("[RAFFLE] %d changed to %d.", arr_RaffleNum[nextPerson] + 1, arr_RaffleNum[nextPerson]);
						}
						rafflemax--;
						continue;
					}
					if (arr_RaffleNum[i] > removenum) 
					{
						char iname[32];
						GetClientName(i, iname, sizeof(iname));
						arr_RaffleNum[i] = arr_RaffleNum[i] - 1;
						CPrintToChat(i, "{GREEN}[RAFFLE]{DEFAULT} Your raffle number has changed from {GREEN}%d{DEFAULT} to {GREEN}%d{DEFAULT}.", arr_RaffleNum[i] + 1, arr_RaffleNum[i]);
						LogAction(client, target, "%s had raffle number changed from %d to %d.", iname, arr_RaffleNum[i] + 1, arr_RaffleNum[i]);
						rafflemax--;
					}
				}
			}
		}
		argnum++;
	}
	return Plugin_Handled;
}
