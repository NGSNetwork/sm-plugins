// Developed by <eVa>Dog
// June 2008
// http://www.theville.org
//

//
// DESCRIPTION:
// Allows players to vote mute a player

// Voting adapted from AlliedModders' basevotes system
// basevotes.sp, basekick.sp
//
#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <morecolors>

#define PLUGIN_VERSION "2.0" 

ConVar g_Cvar_Limits;
Menu g_hVoteMenu;


#define VOTE_CLIENTID	0
#define VOTE_USERID		1
#define VOTE_NAME		0
#define VOTE_NO 		"###no###"
#define VOTE_YES 		"###yes###"

int g_voteClient[2];
char g_voteInfo[3][MAXPLAYERS + 1];

int g_votetype = 0;

public Plugin myinfo = {
	name = "[NGS] Vote Mute/Vote Silence",
	author = "<eVa>Dog / AlliedModders LLC / TheXeon",
	description = "Vote Muting and Silencing",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.net"
}

public void OnPluginStart()
{
	CreateConVar("sm_votemute_version", PLUGIN_VERSION, "Version of votemute/votesilence", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
	g_Cvar_Limits = CreateConVar("sm_votemute_limit", "0.70", "percent required for successful mute vote or mute silence.");
		
	//Allowed for ALL players
	RegConsoleCmd("sm_votemute", Command_Votemute, "sm_votemute <player> ");
	RegConsoleCmd("sm_votesilence", Command_Votesilence, "sm_votesilence <player> ");
	RegConsoleCmd("sm_votegag", Command_Votegag, "sm_votegag <player> ");
	
	LoadTranslations("common.phrases");
}
	
public Action Command_Votemute(int client, int args)
{
	if (IsVoteInProgress())
	{
		ReplyToCommand(client, "[SM] Vote in Progress");
		return Plugin_Handled;
	}	
	
	if (!TestVoteDelay(client))
	{
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		g_votetype = 0;
		DisplayVoteTargetMenu(client);
	}
	else
	{
		char arg[64];
		GetCmdArg(1, arg, 64);
		
		int target = FindTarget(client, arg);

		if (target == -1 || CheckCommandAccess(target, "sm_admin", ADMFLAG_GENERIC))
		{
			return Plugin_Handled;
		}
		
		g_votetype = 0;
		DisplayVoteMuteMenu(client, target);
	}
	
	return Plugin_Handled;
}

public Action Command_Votesilence(int client, int args)
{
	if (IsVoteInProgress())
	{
		ReplyToCommand(client, "[SM] Vote in Progress");
		return Plugin_Handled;
	}	
	
	if (!TestVoteDelay(client))
	{
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		g_votetype = 1;
		DisplayVoteTargetMenu(client);
	}
	else
	{
		char arg[64];
		GetCmdArg(1, arg, 64);
		
		int target = FindTarget(client, arg);

		if (target == -1 || CheckCommandAccess(target, "sm_admin", ADMFLAG_GENERIC))
		{
			return Plugin_Handled;
		}
		
		g_votetype = 1;
		DisplayVoteMuteMenu(client, target);
	}
	return Plugin_Handled;
}

public Action Command_Votegag(int client, int args)
{
	if (IsVoteInProgress())
	{
		ReplyToCommand(client, "[SM] Vote in Progress");
		return Plugin_Handled;
	}	
	
	if (!TestVoteDelay(client))
	{
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		g_votetype = 2;
		DisplayVoteTargetMenu(client);
	}
	else
	{
		char arg[64];
		GetCmdArg(1, arg, 64);
		
		int target = FindTarget(client, arg);

		if (target == -1 || CheckCommandAccess(target, "sm_admin", ADMFLAG_GENERIC))
		{
			return Plugin_Handled;
		}
		
		g_votetype = 2;
		DisplayVoteMuteMenu(client, target);
	}
	return Plugin_Handled;
}

void DisplayVoteMuteMenu(int client, int target)
{
	g_voteClient[VOTE_CLIENTID] = target;
	g_voteClient[VOTE_USERID] = GetClientUserId(target);

	GetClientName(target, g_voteInfo[VOTE_NAME], sizeof(g_voteInfo[]));

	if (g_votetype == 0)
	{
		LogAction(client, target, "\"%L\" initiated a mute vote against \"%L\"", client, target);
		ShowActivity(client, "%s", "Initiated Vote Mute", g_voteInfo[VOTE_NAME]);
		
		g_hVoteMenu = new Menu(Handler_VoteCallback, MENU_ACTIONS_ALL);
		g_hVoteMenu.SetTitle("Mute Player:");
	}
	else if (g_votetype == 1)
	{
		LogAction(client, target, "\"%L\" initiated a silence vote against \"%L\"", client, target);
		ShowActivity(client, "%s", "Initiated Vote Silence", g_voteInfo[VOTE_NAME]);
		
		g_hVoteMenu = new Menu(Handler_VoteCallback, MENU_ACTIONS_ALL);
		g_hVoteMenu.SetTitle("Silence Player:");
	}
	else 
	{
		LogAction(client, target, "\"%L\" initiated a gag vote against \"%L\"", client, target);
		ShowActivity(client, "%s", "Initiated Vote Gag", g_voteInfo[VOTE_NAME]);
		
		g_hVoteMenu = new Menu(Handler_VoteCallback, MENU_ACTIONS_ALL);
		g_hVoteMenu.SetTitle("Gag Player:");
	}
	g_hVoteMenu.AddItem(VOTE_YES, "Yes");
	g_hVoteMenu.AddItem(VOTE_NO, "No");
	SetMenuExitButton(g_hVoteMenu, false);
	VoteMenuToAll(g_hVoteMenu, 20);
}

void DisplayVoteTargetMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Vote);
	
	char title[100];
	char playername[128];
	char identifier[64];
	Format(title, sizeof(title), "%s", "Choose player:");
	menu.SetTitle(title);
	SetMenuExitBackButton(menu, true);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !(CheckCommandAccess(i, "sm_admin", ADMFLAG_GENERIC)))
		{
			GetClientName(i, playername, sizeof(playername));
			Format(identifier, sizeof(identifier), "%i", i);
			menu.AddItem(identifier, playername);
		}
	}
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}


public int MenuHandler_Vote(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Select)
	{
		char info[32], name[32];
		int target;
		
		GetMenuItem(menu, param2, info, sizeof(info), _, name, sizeof(name));
		target = StringToInt(info);

		if (target == 0)
		{
			PrintToChat(param1, "[SM] %s", "Player no longer available");
		}
		else
		{
			DisplayVoteMuteMenu(param1, target);
		}
	}
}

public int Handler_VoteCallback(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		VoteMenuClose();
	}
	else if (action == MenuAction_Display)
	{
		char title[64];
		menu.GetTitle(title, sizeof(title));
		
		char buffer[255];
		Format(buffer, sizeof(buffer), "%s %s", title, g_voteInfo[VOTE_NAME]);

		Panel panel = view_as<Panel>(param2);
		panel.SetTitle(buffer);
	}
	else if (action == MenuAction_DisplayItem)
	{
		char display[64];
		GetMenuItem(menu, param2, "", 0, _, display, sizeof(display));
	 
	 	if (strcmp(display, "No") == 0 || strcmp(display, "Yes") == 0)
	 	{
			char buffer[255];
			Format(buffer, sizeof(buffer), "%s", display);

			return RedrawMenuItem(buffer);
		}
	}
	else if (action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes)
	{
		PrintToChatAll("[SM] %s", "No Votes Cast");
	}	
	else if (action == MenuAction_VoteEnd)
	{
		char item[64], display[64];
		float percent, limit;
		int votes, totalVotes;

		GetMenuVoteInfo(param2, votes, totalVotes);
		menu.GetItem(param1, item, sizeof(item), _, display, sizeof(display));
		
		if (strcmp(item, VOTE_NO) == 0 && param1 == 1)
		{
			votes = totalVotes - votes; // Reverse the votes to be in relation to the Yes option.
		}
		
		percent = GetVotePercent(votes, totalVotes);
		
		limit = GetConVarFloat(g_Cvar_Limits);
		
		if ((strcmp(item, VOTE_YES) == 0 && FloatCompare(percent,limit) < 0 && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1))
		{
			LogAction(-1, -1, "Vote failed.");
			PrintToChatAll("[SM] %s", "Vote Failed", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
		}
		else
		{
			PrintToChatAll("[SM] %s", "Vote Successful", RoundToNearest(100.0*percent), totalVotes);			
			if (g_votetype == 0)
			{
				LogAction(-1, g_voteClient[VOTE_CLIENTID], "Vote mute successful, muted \"%L\" ", g_voteClient[VOTE_CLIENTID]);
				ServerCommand("sm_mute #%d 20 Vote-Muted", GetClientUserId(g_voteClient[VOTE_CLIENTID]));			
			}
			else if (g_votetype == 1)
			{
				LogAction(-1, g_voteClient[VOTE_CLIENTID], "Vote silence successful, silenced \"%L\" ", g_voteClient[VOTE_CLIENTID]);
				ServerCommand("sm_silence #%d 20 Vote-Silenced", GetClientUserId(g_voteClient[VOTE_CLIENTID]));
			}		
			else 
			{
				LogAction(-1, g_voteClient[VOTE_CLIENTID], "Vote gag successful, gagged \"%L\" ", g_voteClient[VOTE_CLIENTID]);
				ServerCommand("sm_gag #%d 20 Vote-Gagged", GetClientUserId(g_voteClient[VOTE_CLIENTID]));
			}
		}
	}
	return 0;
}

void VoteMenuClose()
{
	delete g_hVoteMenu;
	g_hVoteMenu = null;
}

float GetVotePercent(int votes, int totalVotes)
{
	return FloatDiv(float(votes), float(totalVotes));
}

bool TestVoteDelay(int client)
{
	int delay = CheckVoteDelay();
	
	if (delay > 0)
	{
		if (delay > 60)
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Vote delay: %i mins", delay % 60);
 		else
 			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Vote delay: %i secs", delay);
 		return false;
 	}
	return true;
}