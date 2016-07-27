#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2>
#include <morecolors>
#define VERSION "1.0"

//--------------------//

public Plugin myinfo = {
	name = "[NGS] Admin Tools",
	author = "TheXeon",
	description = "Respawns The Player, changes the player's team.",
	version = VERSION,
	url = "https://matespastdates.servegame.com"
}

public void OnPluginStart()
{
	RegAdminCmd("sm_respawn", CommandForceRespawn, ADMFLAG_ROOT, "Usage: sm_respawn [target]");
	RegAdminCmd("sm_move", CommandChangeTeam, ADMFLAG_ROOT, "Usage: sm_move [target] <team> (1 = Spec / 2 = Red / 3 = Blue)");
}

public Action CommandForceRespawn(int client, int args)
{
	if (args == 1)
	{
		char arg[MAX_NAME_LENGTH];
		GetCmdArg(1, arg, sizeof(arg));
		int target = FindTarget(client, arg);
		if (IsClientConnected(target))
		{
			TF2_RespawnPlayer(target);
			CReplyToCommand(client,"{GREEN}[SM]{NORMAL} %N has been respawned!", target);
		}
		else
		{
			CReplyToCommand(client,"{GREEN}[SM]{NORMAL} No player by that name is connected!");
		}
	}
	return Plugin_Handled;
}


public Action CommandChangeTeam(int client, int args)
{
	if (args != 1)
	{
		char arg[MAX_NAME_LENGTH], arg2[32];
		GetCmdArg(1, arg, sizeof(arg));
		int target2 = FindTarget(client, arg);
		int Team;
		if (args >= 2 && GetCmdArg(2, arg2, sizeof(arg2)) && !IsClientReplay(target2))
		{
			if (StringToInt(arg2) < 4 && StringToInt(arg2) > 0)
			{
				Team = StringToInt(arg2);
			} 
			else
			{
				CPrintToChat(client, "{GREEN}[SM]{NORMAL} Please choose a team!");
			}
			ChangeClientTeam(target2, Team);
		}
	}
	else
	{
		CPrintToChat(client, "{GREEN}[SM]{NORMAL} Usage: sm_move [name] <team: 1/2/3>");
	}
	return Plugin_Handled;
}