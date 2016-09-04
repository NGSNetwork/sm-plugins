//------------------------------------------------------------------------------
/*
    AutoReady.sp

    Copyright 2013 Andrew V. Dromaretsky  <dromaretsky@gmail.com>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this library; if not, write to the Free Software Foundation,
    Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/
//------------------------------------------------------------------------------
#pragma newdecls required
#pragma semicolon 1

// Tab = 4
//------------------------------------------------------------------------------
#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <morecolors>
//------------------------------------------------------------------------------
#define		PLUGIN_VER		"0.3"
#define		PLUGIN_NAME		"[TF2] Auto-ready"
#define		PLUGIN_AUTHOR	"Andrew Dromaretsky aka avi9526"
#define		PLUGIN_DESC		"If there is enough players that ready - lets go play, no more wait"
#define		PLUGIN_URL		"https://bitbucket.org/avi9526/autoready/src/"
//------------------------------------------------------------------------------
// String constants
#define		STR_AUTO_CHAT	"{GREEN}[SM]{DEFAULT}"
#define		STR_AUTO_LOG	"[Auto-ready]"
//------------------------------------------------------------------------------
// Global variables
//------------------------------------------------------------------------------
// Global Handle Console Variable MinPlayers
Handle g_hcvMinPlayers	= null;
// Global Handle Console Variable MinPercent
Handle g_hcvMinPercent	= null;
// Global Integer MinPlayers
int g_iMinPlayers = 3;
// Global Float MinPercent
float g_fMinPercent = 0.6;
// Lock - used to prevent infinite recursive call
bool Lock = false;
//------------------------------------------------------------------------------
// Service variables
//------------------------------------------------------------------------------
public Plugin myinfo = {
	name		= PLUGIN_NAME,
	author		= PLUGIN_AUTHOR,
	description	= PLUGIN_DESC,
	version		= PLUGIN_VER,
	url			= PLUGIN_URL
}
//------------------------------------------------------------------------------
// Hook functions
//------------------------------------------------------------------------------
// Initialize required console variables, commands, etc.
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	CreateConVar("mvm_autoready_version", PLUGIN_VER, "Plugin Version", FCVAR_NOTIFY);
	
	// Add console variable 'mvm_autoready_threshold' which is hooked to 'g_iMinPlayers'
	g_hcvMinPlayers = CreateConVar("mvm_autoready_threshold", "2", "Amount of players that must be ready to allow forced wave start", _, true, 1.0, false, 10.0);
	g_iMinPlayers = GetConVarInt(g_hcvMinPlayers);
	HookConVarChange(g_hcvMinPlayers, OnConVarChanged);
	
	// Add console variable 'mvm_autoready_percent' which is hooked to 'g_fMinPercent'
	g_hcvMinPercent = CreateConVar("mvm_autoready_percent", "0.6", "Relative amount of players that must be ready to allow forced wave start", _, true, 0.0, true, 1.0);
	g_fMinPercent = GetConVarFloat(g_hcvMinPercent);
	HookConVarChange(g_hcvMinPercent, OnConVarChanged);
	
	// Add hook to command from client to detect if he change his 'Ready' state
	// Command 'tournament_player_readystate' is autodisabled by TF2 when wave started
	// But this hook is still possible
	AddCommandListener(AutoReady, "tournament_player_readystate");
}
//------------------------------------------------------------------------------
// If console variable changed - need change corresponding internal variables
public void OnConVarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	if(convar == g_hcvMinPlayers)
	{
		g_iMinPlayers = StringToInt(newValue);
	}
	if(convar == g_hcvMinPercent)
	{
		g_fMinPercent = StringToFloat(newValue);
	}
}
//------------------------------------------------------------------------------
// Action functions
//------------------------------------------------------------------------------
// This function decide if need to force all players (humans) to be ready
// It's called when 'tournament_player_readystate' console command executed
// and uses same command to make players ready - be sure to prevent infinite loop
// Use 'return Plugin_Continue' in this function, not 'return Plugin_Handled'
// because need forward player ready state, not block it
public Action AutoReady(int client, const char[] Command, int Argc)
{
	// Prevent recursive call
	// This function use console command which is hooked on
	if (Lock)
	{
		LogAction(-1, -1, "%s Locked", STR_AUTO_LOG);
		return Plugin_Continue;
	}
	// Logging reqired for testing
	LogAction(-1, -1, "%s Triggered 'Ready' state by '%L'", STR_AUTO_LOG, client);
	// Con. command 'tournament_player_readystate' require one argument or will do nothing
	if(Argc != 1)
	{
		ReplyToCommand(client, "[SM] Function '%s' require one argument", Command);
		return Plugin_Continue;
	}
	// Let's avoid processing command from unknown/bots/etc clients
	if (!IsValidClient(client))
	{
 		LogAction(-1, -1, "%s Wrong client '%L' triggered this function, do nothing", STR_AUTO_LOG, client);
		return Plugin_Continue;
	}
	// Locking
	// Do 'Lock = false' before exit
	Lock = true;
	// Check if we play Mann vs. Machine game mode
	if (IsMvM())
	{
		// TF2 automatically disable 'tournament_player_readystate' command when wave has started
		// But let's do one more check to be sure
		// TODO: Need also to avoid after victory calls
		if (!IsWaveStarted())
		{
			// Count all humans
			int CountAll = GetRedHumanCount(false);
			// Count all humans that ready
			int CountRdy = GetRedHumanCount(true);
			
			// This required because function called before player's 'Ready' state changed ...
			int RdyNew = 0;
			char sRdy [4];
			GetCmdArg(1, sRdy,  sizeof(sRdy));
			RdyNew = StringToInt(sRdy);
			
			int RdyOld = IsReady(client);
			
			// Argument from console command can be any integer number
			// we need to make it -1 for 'not ready' and 1 for 'ready'
			if (RdyNew > 0) RdyNew = 1;
			if (RdyNew < 1) RdyNew = -1;
						
			if (RdyNew != RdyOld)	// does player change his 'ready' state ?
			{
				CountRdy = CountRdy + RdyNew;	// then lets count him
			}
			// ... done
			
			// We will also check relative amount of players that is ready
			float PercentRdy = 0.0;
			// Prevent division by zero
			if (CountAll > 0)
			{
				PercentRdy = FloatDiv(float(CountRdy), float(CountAll));
			}
			
			CPrintToChatAll("%s - We have %d players", STR_AUTO_LOG, CountAll);
			LogAction(-1, -1, "%s - %d players is ready (minimum required is %d)", STR_AUTO_LOG, CountRdy, g_iMinPlayers);
			LogAction(-1, -1, "%s - its a %.2f%% (minimum required is %.2f%%)", STR_AUTO_LOG, PercentRdy*100.0, g_fMinPercent*100.0);
			
			// If we have enough players ready (absolute and relative)
			if ((CountRdy >= g_iMinPlayers) && (PercentRdy >= g_fMinPercent))
			{
				// No need to spam and do useless code
				if (CountRdy < CountAll)
				{
					CPrintToChatAll("Enough players are ready - let's go");
					LogAction(-1, -1, "%s Forcing wave start", STR_AUTO_LOG, CountRdy, CountAll);
					SetAllReady();	// make all players to be ready, let's go play
					LogAction(-1, -1, "%s All players were set to be ready", STR_AUTO_LOG, CountRdy, CountAll);
				}
			}
		}
		else
		{
			LogAction(-1, -1, "%s Wave started - 'Ready' is now useless", STR_AUTO_LOG);
		}
	}
	else
	{
		LogAction(-1, -1, "%s Not MvM game mode", STR_AUTO_LOG);
	}
	Lock = false;
	return Plugin_Continue;
}
//------------------------------------------------------------------------------
// Stock functions
//------------------------------------------------------------------------------
// Returns amount of humans in red team at all or only which is ready
stock int GetRedHumanCount(bool OnlyReady = false)
{
	// Number of clients
	int Count = 0;
	// Go through all clients on server
	for (int Client = 1; Client <= MaxClients; Client++)
	{
		// Determine who is real player (human)
		if (IsValidClient(Client))
		{
			// Accept only red team players (blu team can't be ready)
			TFTeam clientTeam = TF2_GetClientTeam(Client);
			if (clientTeam == TFTeam_Red)
			{
				// Need count only who is ready or not
				if (OnlyReady)
				{
					Count = Count + IsReady(Client);
				}
				else
				{
					Count = Count + 1;
				}
			}
		}
	}
	return Count;
}
//------------------------------------------------------------------------------
// Make all humans in red team ready
stock void SetAllReady()
{
	// Go through all clients on server
	for (int Client = 1; Client <= MaxClients; Client++)
	{
		// Determine who is real player (human)
		if (IsValidClient(Client))
		{
			// Accept only red team players (blu team can't be ready)
			if (TF2_GetClientTeam(Client) == TFTeam_Red)
			{
				DoReady(Client);
			}
		}
	}
	return;
}
//------------------------------------------------------------------------------
// Ckeck if client is normal player (human) that already in game, not bot or etc
public bool IsValidClient (int client)
{
	if(client > 4096) client = EntRefToEntIndex(client);
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsFakeClient(client)) return false;
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}
//------------------------------------------------------------------------------
// Return 1 is player is ready, 0 - if not
// This func. don't do any check for client to be valid
// You need to do it yourself
stock int IsReady(int client)
{
	int Ready = GameRules_GetProp("m_bPlayerReady", 1, client);
	return Ready;
}
//------------------------------------------------------------------------------
// Make client to be ready
// Return nothing
// This func. don't do any check for client to be valid
// You need to do it yourself
stock void DoReady(int client)
{
	// Execute client console command on server side
	FakeClientCommand(client, "tournament_player_readystate %d", 1);
	return;
}
//------------------------------------------------------------------------------
// Check if current game mode is 'Mann vs. Machine'
stock bool IsMvM()
{
	bool ismvm = view_as<bool>(GameRules_GetProp("m_bPlayingMannVsMachine"));
	return ismvm;
}
//------------------------------------------------------------------------------
// Check if wave/round started
stock bool IsWaveStarted()
{
	RoundState nRoundState = GameRules_GetRoundState();
	return (!GameRules_GetProp("m_bInWaitingForPlayers", 1) && (nRoundState == RoundState_RoundRunning));
}
//------------------------------------------------------------------------------