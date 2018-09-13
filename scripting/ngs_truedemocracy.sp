/**
* TheXeon
* ngs_truedemocracy.sp
*
* Files:
* addons/sourcemod/plugins/ngs_truedemocracy.smx
*
* Dependencies:
* json.inc, truedemocracy.inc, sdkhooks.inc, multicolors.inc, ngsutils.inc,
* ngsupdater.inc
*/
#pragma dynamic 16384
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

// id is internal to the database and will be used when mapping vote counts and results to votes
#define TD_CREATEVOTESTABLE "CREATE TABLE IF NOT EXISTS `td_votes`\
							(`id` INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,\
							 `devid` VARCHAR(64) NOT NULL,\
							 `question` VARCHAR(64) NOT NULL,\
							 `options` VARCHAR(4096) NOT NULL,\
							 `types` VARCHAR(1024) NOT NULL,\
							 `show` VARCHAR(1024),\
							 `hold` INT UNSIGNED NOT NULL,\
							 `anonymous` BOOLEAN NOT NULL,\
							 `rewards` VARCHAR(2048) NOT NULL);"
#define TD_CREATERESULTSTABLE "CREATE TABLE IF NOT EXISTS `td_results`\
							(`id` INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,\
							 `playerid` VARCHAR(64) NOT NULL,\
							 `voteid` VARCHAR(64) NOT NULL,\
							 `result` VARCHAR(64) NOT NULL);"
// TODO: Results table should have unique ID, STEAMID (hashed if anonymous), 
// and JSON results with array of chosen option(s).

#include <json>
#include <sdkhooks>
#include <truedemocracy>
#include <multicolors>
#include <ngsutils>
#include <ngsupdater>

enum VoteSetupPhase
{
	Not,
	Question,
	Options,
	Types,
	Show,
	Hold,
	Anonymous,
	Rewards
}

Database tdDB;
ArrayList votesCache;
JSON_Object voteSetupCache[MAXPLAYERS + 1];
VoteSetupPhase voteSetupPhase[MAXPLAYERS + 1];
Menu voteMenu[MAXPLAYERS + 1];

bool voteEnabled;

int voteResults[MAXPLAYERS + 1];
int resultCount[20];

int numOptions = 0;

char question[1024], options[5][2][48], baseoptions[5][48];

public Plugin myinfo = {
	name            = "[NGS] True Democracy",
	author          = "TheXeon",
	description     = "True democracy through smart votes.",
	version         = "1.0.1",
	url             = "https://www.neogenesisnetwork.net/"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_rvote", CommandRandomVote, ADMFLAG_VOTE, "Creates a randomized vote.");
	RegAdminCmd("sm_rvoteresults", CommandRandomVoteResults, ADMFLAG_VOTE, "Prints vote results.");
	RegAdminCmd("sm_rvoteend", CommandRandomVoteEnd, ADMFLAG_VOTE, "Ends a vote.");
	RegAdminCmd("sm_rvoteclear", CommandRandomVoteClear, ADMFLAG_VOTE, "Clears results of last vote.");
	RegAdminCmd("sm_rvotesetup", CommandRandomVoteSetup, ADMFLAG_VOTE, "Setup a persistent vote.");
	
	AddCommandListener(CommandPlayerSay, "say_team");
	AddCommandListener(CommandPlayerSay, "say");
	AddCommandListener(CommandRandomVoteRevote, "sm_revote");
	
	votesCache = new ArrayList();
	
	LoadTranslations("common.phrases");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("TrueDemocracy_StartVote", Native_StartTDVote);
	return APLRes_Success;
}

public void OnConfigsExecuted()
{
	if (SQL_CheckConfig("truedemocracy"))
	{
		Database.Connect(OnDatabaseConnect, "truedemocracy");
	}
	else
	{
		Database.Connect(OnDatabaseConnect);
	}
}

public void OnDatabaseConnect(Database db, const char[] error, any data)
{
	if (db == null)
	{
		SetFailState("Database error: %s", error);
		return;
	}
	
	tdDB = db;
	
	tdDB.Query(OnTablesCreated, TD_CREATEVOTESTABLE);
	tdDB.Query(OnTablesCreated, TD_CREATERESULTSTABLE);
}

public void OnTablesCreated(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		SetFailState("Could not create one or more databases, encountered error:\n%s", error);
		return;
	}
	
	delete results;
}

public Action CommandPlayerSay(int client, const char[] command, int argc)
{
	if (voteSetupCache[client] == null || !IsValidClient(client))
	{
		return Plugin_Continue;
	}
	
	switch (voteSetupPhase[client])
	{
		case Question:
		{
			char voteQuestion[MAX_BUFFER_LENGTH], voteQuestionEscaped[MAX_BUFFER_LENGTH * 2 + 1];
			GetCmdArgString(voteQuestion, sizeof(voteQuestion));
			TrimString(voteQuestion);
			if (CheckCancelAndResetSetup(client, voteQuestion))
			{
				return Plugin_Handled;
			}
			tdDB.Escape(voteQuestion, voteQuestionEscaped, sizeof(voteQuestionEscaped));
			voteSetupCache[client].SetString("question", voteQuestionEscaped);
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Please give Option #1 or 'cancel' to abort.");
			voteSetupPhase[client] = Options;
			return Plugin_Handled;
		}
		case Options:
		{
			char voteOption[MAX_BUFFER_LENGTH], voteOptionEscaped[MAX_BUFFER_LENGTH * 2 + 1];
			GetCmdArgString(voteOption, sizeof(voteOption));
			TrimString(voteOption);
			if (CheckCancelAndResetSetup(client, voteOption))
			{
				return Plugin_Handled;
			}
			else if (StrEqual(voteOption, "done", false))
			{
				voteSetupPhase[client] = Types;
				CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Please choose the type of vote to do!");
				Menu menu = new Menu(MenuVoteTypeChooserHandler);
				menu.SetTitle("What kind of vote should be done?");
				menu.AddItem("random", "Random");
				menu.AddItem("cyclic", "Cyclic");
				menu.Display(client, 20);
				return Plugin_Handled;
			}
			tdDB.Escape(voteOption, voteOptionEscaped, sizeof(voteOptionEscaped));
			if (voteSetupCache[client].GetObject("options") == null)
			{
				voteSetupCache[client].SetObject("options", new JSON_Object(true));
			}
			voteSetupCache[client].GetObject("options").PushString(voteOptionEscaped);
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Please give Option #%d, \'done\' to continue, or \'cancel\' to abort.", voteSetupCache[client].GetObject("options").Length + 1);
			voteSetupPhase[client] = Options;
			return Plugin_Handled;
		}
		default:
		{
			return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}

public int MenuVoteTypeChooserHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:
		{
			ResetClientSetup(param1);
		}
		case MenuAction_Select:
		{
			char item[MAX_BUFFER_LENGTH];
			menu.GetItem(param2, item, sizeof(item));
			voteSetupCache[param1].SetString("types", item);
			voteSetupPhase[param1] = Show;
			CReplyToCommand(param1, "{GREEN}[SM]{DEFAULT} When should we show the vote?");
			// TODO: Make an array(list) of options to show, allow user to select and deselect as many as they want.
		}
	}
}

public bool CheckCancelAndResetSetup(int client, char[] buffer)
{
	if (StrEqual(buffer, "cancel", false))
	{
		ResetClientSetup(client);
		return true;
	}
	return false;
}

public void ResetClientSetup(int client)
{
	if (voteSetupCache[client] != null)
	{
		voteSetupCache[client].Cleanup();
		delete voteSetupCache[client];
		voteSetupPhase[client] = Not;
	}
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

public int Native_StartTDVote(Handle plugin, int numParams)
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
	return 0;
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

public Action CommandRandomVoteRevote(int client, const char[] command, int argc)
{
	if (!IsValidClient(client) || !voteEnabled) return Plugin_Continue;
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

public Action CommandRandomVoteSetup(int client, int args)
{
	if (!IsValidClient(client))
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} This command must be run in-game.");
		return Plugin_Handled;
	}
	
	ResetClientSetup(client);
	
	voteSetupCache[client] = new JSON_Object();
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Please type the question you want to use including punctuation!");
	
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
			CPrintToChat(param1, "{GREEN}[SM]{DEFAULT} Vote for {OLIVE}%s{DEFAULT} counted! Use {YELLOW}!revote{DEFAULT} to revote!", displayBuffer);
			#if defined DEBUG
			CPrintToChatAdmins(ADMFLAG_ROOT, "%N chose %s", param1, info);
			CPrintToChatAdmins(ADMFLAG_ROOT, "%N set to place info[6] - 48 is %d", param1, place);
			#endif
			voteResults[param1] = place;
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
		int result = voteResults[i];
		if (result == 0) continue;
		resultCount[result - 1]++;
	}
}

void ClearVoteResults()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		voteResults[i] = 0;
	}
	for (int i = 0; i < 5; i++)
	{
		resultCount[i] = 0;
	}
}