#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>
#include <colorvariables>

#define PLUGIN_VERSION "1.0.0"

// ConVar BleedChance;
Menu voteMenu[MAXPLAYERS + 1];

bool voteEnabled;

int results[MAXPLAYERS + 1];
int resultCount[5] = {0, 0, 0, 0, 0};

int numOptions = 0;

char question[1024], options[5][2][48], baseoptions[5][48];

public Plugin myinfo = {
	name            = "[NGS] True Democracy",
	author          = "TheXeon",
	description     = "True democracy through smart votes.",
	version         = PLUGIN_VERSION,
	url             = "https://www.neogenesisnetwork.net/"
};

public void OnPluginStart( )
{
	CreateConVar("sm_truedemocracy_version", PLUGIN_VERSION, "True democracy randomized vote version");

	RegAdminCmd("sm_rvote", CommandRandomVote, ADMFLAG_VOTE, "Creates a randomized vote.");
	RegAdminCmd("sm_rvoteresults", CommandRandomVoteResults, ADMFLAG_VOTE, "Prints vote results.");
	RegAdminCmd("sm_rvoteend", CommandRandomVoteEnd, ADMFLAG_VOTE, "Ends a vote.");
	RegAdminCmd("sm_rvoteclear", CommandRandomVoteClear, ADMFLAG_VOTE, "Clears results of last vote.");

	RegConsoleCmd("sm_rrevote", CommandRandomVoteRevote, "Revote on a randomized vote!");
	
	LoadTranslations("common.phrases");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
   CreateNative("TrueDemocracy_StartVote", Native_StartRandomizedVote);
   return APLRes_Success;
}

public Action CommandRandomVote(int client, int args)
{
	if (voteEnabled)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} There is already a vote going on!");
		return Plugin_Handled;
	}
	if (args < 3)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Please provide a question and two options!");
		return Plugin_Handled;
	}
	voteEnabled = true;
	numOptions = args - 1;
	
	ClearVoteResults();
	
	GetCmdArg(1, question, sizeof(question));
	for (int i = 2; i <= numOptions + 1; i++)
	{
		int place = i - 2;
		GetCmdArg(i, options[place][0], 48);
		strcopy(baseoptions[place], 48, options[place][0]);
		Format(options[place][1], 48, "option%d", (place + 1));
	}
	DisplayRandomVoteToAll(30.0);
	return Plugin_Handled;
}

void DisplayRandomVoteToAll(float time)
{
	char voteTitle[64];	
	Format(voteTitle, sizeof(voteTitle), "%s (random options)", question);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i)) continue;
		PrepareVoteMenu(i, voteTitle);
		voteMenu[i].Display(i, 30);
	}
	CreateTimer(time, OnVoteTimerEnd);
}

public void RandomizeOptions()
{
	for (int j = 0; j < numOptions; j++)
	{
		int randPos = GetRandomInt(0, numOptions - 1);
		char tmpQuestion[48], tmpOption[48];
		strcopy(tmpQuestion, 48, options[j][0]);
		strcopy(tmpOption, 48, options[j][1]);
		strcopy(options[j][0], 48, options[randPos][0]);
		strcopy(options[j][1], 48, options[randPos][1]);
		strcopy(options[randPos][0], 48, tmpQuestion);
		strcopy(options[randPos][1], 48, tmpOption);
	}
}

public int Native_StartRandomizedVote(Handle plugin, int numParams)
{
	if (voteEnabled)
		return ThrowNativeError(1, "There is currently a vote already happening!");
	if (numParams < 4) // at least question, two options, and a time
		return ThrowNativeError(2, "There are not enough options in this vote!");
	voteEnabled = true;
	GetNativeString(1, question, sizeof(question));
	numOptions = numParams - 2;
	for (int i = 2; i <= numParams - 1; i++)
	{
		int place = i - 2;
		GetNativeString(i, options[place][0], 48);
		strcopy(baseoptions[place], 48, options[place][0]);
		Format(options[place][1], 48, "option%d", (place + 1));
	}
	DisplayRandomVoteToAll(GetNativeCell(numParams));
}

public Action OnVoteTimerEnd(Handle timer, any data)
{
	ServerCommand("sm_rvoteend");
	ServerCommand("sm_rvoteresults");
}

public Action CommandRandomVoteResults(int client, int args)
{
	CountVoteResults();
	CPrintToChatAll("{GREEN}[SM]{DEFAULT} === Vote results ===");
	for (int i = 0; i < numOptions; i++)
	{
		CPrintToChatAll("{CRIMSON}%d.{DEFAULT} {YELLOW}%s{DEFAULT}: %d.", i + 1, baseoptions[i], resultCount[i]);
	}
	return Plugin_Handled;
}

public Action CommandRandomVoteEnd(int client, int args)
{
	voteEnabled = false;
	CPrintToChatAll("{GREEN}[SM]{DEFAULT} Vote has ended.");
	return Plugin_Handled;
}

public Action CommandRandomVoteRevote(int client, int args)
{
	if (!IsValidClient(client) || !voteEnabled) return Plugin_Handled;
	char voteTitle[64];
	Format(voteTitle, sizeof(voteTitle), "%s (random options)", question);
	PrepareVoteMenu(client, voteTitle);
	voteMenu[client].Display(client, 30);
	return Plugin_Handled;
}

public Action CommandRandomVoteClear(int client, int args)
{
	ClearVoteResults();
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Vote results cleared.");
	return Plugin_Handled;
}

public int RandomizedVoteMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if (!voteEnabled) return 0;
			char info[32], displayBuffer[48];
			menu.GetItem(param2, info, sizeof(info), _, displayBuffer, sizeof(displayBuffer));
			int place = info[6] - 48;
			CPrintToChat(param1, "{GREEN}[SM]{DEFAULT} Vote for {OLIVE}%s{DEFAULT} counted! Use {YELLOW}!rrevote{DEFAULT} to revote!", displayBuffer);
//			CPrintToChatAdmins(ADMFLAG_ROOT, "%N chose %s", param1, info);
//			CPrintToChatAdmins(ADMFLAG_ROOT, "%N set to place info[6] - 48 is %d", param1, place);
			results[param1] = place;
		}
		case MenuAction_Cancel:
			PrintToServer("Client %d's menu was cancelled for reason %d", param1, param2);
		case MenuAction_End:
			delete menu;
	}
 
	return 0;
}

void PrepareVoteMenu(int client, char[] title)
{
//	if (voteMenu[client] != null) return; commenting this out but I'm not sure it'll leak
	voteMenu[client] = new Menu(RandomizedVoteMenuHandler);
	voteMenu[client].SetTitle(title);
	RandomizeOptions();
	for (int k = 0; k < numOptions; k++)
	{
		voteMenu[client].AddItem(options[k][1], options[k][0]);
	}
	voteMenu[client].ExitButton = false;
}

void CountVoteResults()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		int result = results[i];
		if (result == 0) continue;
		resultCount[result - 1]++;
	}
}

void ClearVoteResults()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		results[i] = 0;
	}
	for (int i = 0; i < 5; i++)
	{
		resultCount[i] = 0;
	}
}

stock bool IsValidClient(int client, bool aliveTest=false, bool botTest=true, bool rangeTest=true, 
	bool ingameTest=true)
{
	if (client > 4096) client = EntRefToEntIndex(client);
	if (rangeTest && (client < 1 || client > MaxClients)) return false;
	if (ingameTest && !IsClientInGame(client)) return false;
	if (botTest && IsFakeClient(client)) return false;
	if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	if (aliveTest && !IsPlayerAlive(client)) return false;
	return true;
}