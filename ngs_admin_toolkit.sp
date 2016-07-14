#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2>
#define VERSION "1.0"

//--------------------//

public Plugin myinfo = 
{
	name = "[NGS] Admin Tools",
	author = "TheXeon",
	description = "Respawns The Player, changes the players team",
	version = VERSION,
	url = "https://matespastdates.servegame.com"
};

public OnPluginStart()
{
	RegAdminCmd("respawn", Spawn, ADMFLAG_ROOT, "Usage: respawn [target]");
	RegAdminCmd("move", CT, ADMFLAG_ROOT, "Usage: move [target] <team> (1 = Spec / 2 = Red / 3 = Blue)");
}

public Action Spawn(client, args)
{
	if (args == 1)
	{
		char arg[MAX_NAME_LENGTH];
		GetCmdArg(1, arg, sizeof(arg));
		new target = FindTarget(client, arg);
		if (IsClientConnected(target))
		{
			TF2_RespawnPlayer(target);
			ReplyToCommand(client,"[SM]: %N has been respawned", target);
		}
		else
		{
			ReplyToCommand(client,"[SM]: No player by that name is connected");
		}
	}
	return Plugin_Handled;
}


public Action CT(client, args)
{
	if (args != 1)
	{
		char arg[MAX_NAME_LENGTH], arg2[32];
		GetCmdArg(1, arg, sizeof(arg));
		new target2 = FindTarget(client, arg);
		new Team;
		if (args >= 2 && GetCmdArg(2, arg2, sizeof(arg2)) && !IsClientReplay(target2))
		{
			if (StringToInt(arg2) == 1)
			{
				Team = 1;
			} 
			else if (StringToInt(arg2) == 2)
			{
				Team = 2;
			}
			else if (StringToInt(arg2) == 3)
			{
				Team = 3;
			}
			else
			{
				PrintToChat(client, "[SM]: Please choose a team");
			}
			ChangeClientTeam(target2, Team);
		}
	}
	else
	{
		PrintToChat(client, "[SM]Usage: move [name] <team#1/2/3>");
	}
	return Plugin_Handled;
}