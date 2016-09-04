/**
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 */
 
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <basecomm>
#include <morecolors>
#undef REQUIRE_PLUGIN
#include <adminmenu>

//Version include from build script
#define VERSION "2.4"

//Game detection constants
#define GAME_OTHER   		0
#define GAME_TF2			1
#define GAME_CSS			2
#define GAME_DODSRC			3

// -------------------------------------------------------------------------------
// Set any of these to 0 and recompile to completely disable those commands
// -------------------------------------------------------------------------------
#define RGBA			1
#define TELEPORT		1
#define FF				1
#define HAPPY			1
#define EXPLODE			1
#define SAYACTIONS		1
#define FAKESAY			1
#define OVERLAY			1

// -------------------------------------------------------------------------------

/*****************************************************************


			P L U G I N   I N F O


*****************************************************************/
public Plugin:myinfo = 
{
	name = "Fun Commands X",
	author = "Spazman0 and Arg!",
	description = "Expansion of core fun commands",
	version = VERSION,
	url = "http://forums.alliedmods.net/showthread.php?p=665771"
};

/*****************************************************************


			G L O B A L   V A R S


*****************************************************************/
new Handle:hTopMenu = INVALID_HANDLE;

new String:g_PlayerProperty[12];			//offset to use for player type, depending on game type

new g_GameType;								//for use in game specific settigns, GameDetect will set this.

/*****************************************************************


			L I B R A R Y   I N C L U D E S


*****************************************************************/
// Include various commands and supporting functions
#if RGBA
#include "funcommandsX/rgba.sp"
#endif
#if TELEPORT
#include "funcommandsX/teleport.sp"
#endif
#if FF
#include "funcommandsX/ff.sp"
#endif
#if HAPPY
#include "funcommandsX/happy.sp"
#endif
#if EXPLODE
#include "funcommandsX/explode.sp"
#endif
#if SAYACTIONS
#include "funcommandsX/sayactions.sp"
#endif
#if FAKESAY
#include "funcommandsX/fakesay.sp"
#endif
#if OVERLAY
#include "funcommandsX/overlay.sp"
#endif

/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/
public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("funcommandsX.phrases");
	
	CreateConVar("sm_funcommandsx_version", VERSION, "Expansion of core fun commands", FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	//detect game type
	GameDetect();
	
	//set game mode for base player class
	SetPlayerProperty();

	//setup each plugin include
	#if RGBA
	SetupRGBA();
	#endif
	#if TELEPORT
	SetupTeleport();
	#endif
	#if FF
	SetupFF();
	#endif
	#if HAPPY
	SetupHappy();
	#endif
	#if EXPLODE
	SetupExplode();
	#endif
	#if SAYACTIONS
	SetupSayActions();
	#endif
	#if FAKESAY
	SetupFakeSay();
	#endif
	#if OVERLAY
	SetupOverlay();
	#endif
	
	//setup config file
	AutoExecConfig(true, "funcommandsX");
	
	
	//Account for late loading
	new Handle:topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}
}

public OnPluginEnd()
{
	#if RGBA
	OnPluginEnd_RGBA();
	#endif
}

public OnLibraryRemoved(const String:name[])
{
	//remove this menu handle if adminmenu plugin unloaded
	if (strcmp(name, "adminmenu") == 0)
	{
		hTopMenu = INVALID_HANDLE;
	}
}

public OnMapStart()
{
	#if RGBA
	OnMapStart_RGBA();
	#endif
}

public OnMapEnd()
{
	#if RGBA
	OnMapEnd_RGBA();
	#endif
}

public bool:OnClientConnect(client, String:rejectmsg[], maxlen)
{
	#if RGBA
	OnClientConnect_RGBA(client, rejectmsg, maxlen);
	#endif
	#if HAPPY
	OnClientConnect_Happy(client, rejectmsg, maxlen);
	#endif
	
	return true;
}

/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) { 
    MarkNativeAsOptional("GetUserMessageType"); 
    return APLRes_Success; 
}  


/*****************************************************************


			P L U G I N   F U N C T I O N S


*****************************************************************/
GameDetect()
{
	new String:gamename[10];
	GetGameFolderName(gamename,sizeof(gamename));
	
	if(StrEqual(gamename,"dods"))
	{
		g_GameType = GAME_DODS;
		LogMessage("Game detected as Day of Defeat: Source (GAME_DODS)");
	}
	else if(StrEqual(gamename,"tf"))
	{
		g_GameType = GAME_TF2;
		LogMessage("Game detected as Team Fortress 2: Source (GAME_TF2)");
	}
	else if(StrEqual(gamename,"cstrike"))
	{
		g_GameType = GAME_CSS;
		LogMessage("Game detected as Counter-Strike: Source (GAME_CSS)");
	}
	else
	{
		g_GameType = GAME_OTHER;
		LogMessage("Game detected as Other (unknown) (GAME_OTHER)");
	}
}

SetPlayerProperty()
{
	if(g_GameType == GAME_DODS)
	{
		Format(g_PlayerProperty,sizeof(g_PlayerProperty),"CDODPlayer");
	}
	else
	{
		Format(g_PlayerProperty,sizeof(g_PlayerProperty),"CBasePlayer");
	}
}

//SayText2: Ripped directly from the DJ Tsunami Plugin 'Advertisements' - http://forums.alliedmods.net/showthread.php?t=67885
SayText2(to, const String:message[])
{
	new Handle:hBf = StartMessageOne("SayText2", to);
	if(!hBf)
		return;
	
#if SOURCEMOD_V_MAJOR >= 1 && SOURCEMOD_V_MINOR >= 5
	if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf)
	{
		PbSetBool(hBf,   "chat",     true);
		PbSetInt(hBf,    "ent_idx",  to);
		PbSetString(hBf, "msg_name", message);
		PbAddString(hBf, "params",   "");
		PbAddString(hBf, "params",   "");
		PbAddString(hBf, "params",   "");
		PbAddString(hBf, "params",   "");
	}
	else
	{
#endif
		BfWriteByte(hBf,   to);
		BfWriteByte(hBf,   true);
		BfWriteString(hBf, message);
#if SOURCEMOD_V_MAJOR >= 1 && SOURCEMOD_V_MINOR >= 5
	}
#endif
	EndMessage();
}

/*****************************************************************


			A D M I N   M E N U   F U N C T I O N S


*****************************************************************/
public OnAdminMenuReady(Handle:topmenu)
{
	//Block us from being called twice
	if (topmenu == hTopMenu)
	{
		return;
	}
	
	//Save the Handle
	hTopMenu = topmenu;
	
	//Build the "Player Commands" category
	new TopMenuObject:player_commands = FindTopMenuCategory(hTopMenu, ADMINMENU_PLAYERCOMMANDS);
	
	if (player_commands != INVALID_TOPMENUOBJECT)
	{
		#if RGBA
		Setup_AdminMenu_RGBA_Player(player_commands);
		#endif		
		#if TELEPORT
		Setup_AdminMenu_Teleport_Player(player_commands);
		#endif
		#if HAPPY
		Setup_AdminMenu_Happy_Player(player_commands);
		#endif
		#if EXPLODE
		Setup_AdminMenu_Explode_Player(player_commands);
		#endif
	}

	new TopMenuObject:server_commands = FindTopMenuCategory(hTopMenu, ADMINMENU_SERVERCOMMANDS);

	if (server_commands != INVALID_TOPMENUOBJECT)
	{
		#if FF
		Setup_AdminMenu_FF_Server(server_commands);
		#endif	
		#if RGBA
		Setup_AdminMenu_RGBA_Server(server_commands);
		#endif

	}
}



