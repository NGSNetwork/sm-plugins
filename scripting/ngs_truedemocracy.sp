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

int results[5] = {0, 0, 0, 0, 0};
int optionplaces[5] = {1, 2, 3, 4, 5};

int numOptions = 0;

char question[1024], options[5][48], baseoptions[5][48];
//new Handle:BleedTime;

public Plugin myinfo = {
	name             = "[NGS] Randomized Votes - True Democracy",
	author         = "TheXeon",
	description     = "Chance for bottles to break.",
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

	LoadTranslations("common.phrases");
}

public Action CommandRandomVote(int client, int args)
{
	if (args < 3)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Please provide a question and two options!");
		return Plugin_Handled;
	}
	voteEnabled = true;
	numOptions = args - 1;
	char voteTitle[64];
	
	clearVoteResults();
	
	GetCmdArg(1, question, sizeof(question));
	for (int i = 2; i <= 6; i++)
	{
		if (args < i) break;
		int place = i - 2;
		GetCmdArg(i, options[place], 48);
		strcopy(baseoptions[place], 48, options[place]);
	}
	
	Format(voteTitle, sizeof(voteTitle), "%s (random options)", question);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i)) continue;
		voteMenu[i] = new Menu(RandomizedVoteMenuHandler);
		voteMenu[i].SetTitle(voteTitle);
		for (int j = 0; j < numOptions; j++)
		{
			int randPos = GetRandomInt(0, numOptions - 1);
			char tmp[48];
			strcopy(tmp, 48, options[j]);
			int pos = optionplaces[j];
			strcopy(options[j], 48, options[randPos]);
			optionplaces[j] = optionplaces[randPos];
			strcopy(options[randPos], 48, tmp);
			optionplaces[randPos] = pos;
		}
		for (int k = 0; k < numOptions; k++)
		{
			char info[32];
			Format(info, sizeof(info), "option%d", optionplaces[k]);
			voteMenu[i].AddItem(info, options[k]);
		}
		voteMenu[i].Display(i, 20);
	}
	CreateTimer(25.0, OnVoteTimerEnd);
	return Plugin_Handled;
}

public Action OnVoteTimerEnd(Handle timer, any data)
{
	ServerCommand("sm_rvoteend");
	ServerCommand("sm_rvoteresults");
}

public Action CommandRandomVoteResults(int client, int args)
{
	CPrintToChatAll("{GREEN}[SM]{DEFAULT} === Vote results ===");
	for (int i = 0; i < numOptions; i++)
	{
		CPrintToChatAll("{CRIMSON}%d.{DEFAULT} {YELLOW}%s{DEFAULT}: %d.", i + 1, baseoptions[i], results[i]);
	}
	return Plugin_Handled;
}

public Action CommandRandomVoteEnd(int client, int args)
{
	voteEnabled = false;
	CPrintToChatAll("{GREEN}[SM]{DEFAULT} Vote has ended.");
	return Plugin_Handled;
}

public Action CommandRandomVoteClear(int client, int args)
{
	clearVoteResults();
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
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			int place = info[6] - 49;
//			CPrintToChatAdmins(ADMFLAG_ROOT, "info is %s", info);
//			CPrintToChatAdmins(ADMFLAG_ROOT, "info[6] - 49 is %d", place);
			results[place]++;
		}
 
		case MenuAction_Cancel:
		{
			PrintToServer("Client %d's menu was cancelled for reason %d", param1, param2);
		}
 
		case MenuAction_End:
		{
			delete menu;
		}
	}
 
	return 0;
}

void clearVoteResults()
{
	for (int i = 0; i < 5; i++)
	{
		results[i] = 0;
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