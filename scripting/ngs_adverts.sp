/*
*****************************************************************************************************
 * [ANY] VPP Adverts
 * Displays In-Game VPP Adverts.
 *
 * Copyright (C)2014-2018 Very Poor People LLC. All rights reserved.
 
*****************************************************************************************************
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <https://www.gnu.org/licenses/#GPL>.
 
*****************************************************************************************************
	CHANGELOG: 
			1.1.0 - Rewriten plugin.
			1.1.1 - 
					- Override motd instead of popping out window.
					- Remove advert on death and instead play advert periodically
						- Cvar: sm_vpp_ad_period - How often the periodic adverts should be played (In Minutes)
						- Cvar: sm_vpp_ad_total - How many periodic adverts should be played in total? 0 = Unlimited. -1 = Disabled.
			1.1.2 - 
					- Remove default root immunity.
			1.1.3 - 
					- Revert override motd due to some issues.
			1.1.4 - 
					- Added playing adverts on game phases.
						- Cvar: sm_vpp_onphase - Show adverts during game phases (HalfTime, OverTime, MapEnd etc)
			1.1.5 - 
					- Added advert grace period cvar, This prevents adverts playing too soon after last advert, min value is 180, don't abuse it or you risk account termination.
						- Cvar: sm_vpp_ad_grace - Don't show adverts to client if one has already played in the last x seconds, Min value = 180, Abusing this value may result in termination.
					- Added cvar to kick player if they have motd disabled (Disabled by default)
						- Cvar: sm_vpp_kickmotd - Kick players with motd disabled? (Immunity flag is ignored)
					- Updated advert serve url to VPP host.
			1.1.6 - 
					- Wait until player is dead before showing advert unless its in phasetime.
			1.1.7 - 
					- Added initial TF2 support, Please report any bugs which you may find.
					- Adverts on Join will now play instantly (after team / class join) without waiting for client death.
					- General code / logic improvement.
			1.1.8 - 
					- Fixed issues with adverts not playing to spectators on join.
					- Fixed a rare but potential error that could of occured if the KV handle was invalid somehow.
					- Slight code refactor / cleanup.
			1.1.9 - 
					- Override initial motd instead of waiting for team join.
					- Improve completion rates by blocking info UserMessages while an advert is in progress.
					- Added extra events for TF2, This can be controlled with the sm_vpp_onphase cvar.
					- Miscellaneous tweaks / code & timer logic improvements.
					- Set sm_vpp_kickmotd to 1 by default.
			1.2.0 - 
					- Added initial support for CSS, NMRIH, Please report any bugs which you may find. 
					- Added support for Radio resumation.
						- This feature will automatically resume the radio for players after ad finishes or if they try to use the radio while the advert is playing it will wait for ad to finish.
						- The radio stations are stored in a KeyValue formatted config file, You can add your own if you wish, But please let me know about them so I can add them to an update, Thanks!
					- Added Multi-Lang support - Contributions are welcome!
					- Improved checks when trying to play advert, ads should play in more cases that don't disturb players.
					- Set sm_vpp_kickmotd 0 by default again.
					- Some Syntax modernization.
			1.2.1 - 
					- Added command sm_vppreload with Admin Cvar flag to reload radios from config file.
					- Added some polish radio stations (Thanks xWangan - Also helped me with translations)
			1.2.2 - 
					- Added support for Day of defeat: Source, Fist full of Frags, Please report any bugs which you may find. 
					- Added support for loading third party radio stations (https://forums.alliedmods.net/showthread.php?p=512035)
					- Added vpp_adverts_radios_custom.txt from now on, please avoid editing vpp_adverts_radios.txt as this file may get overwritten when plugin updates happen.
						- If you have any custom radio stations in vpp_adverts_radios.txt then please move them to vpp_adverts_radios_custom.txt, 
						Also let us know and we can add them to vpp_adverts_radios.txt for next update.
					- Added duplicate radio detection to prevent the same radio station getting added multiple times.
					- Improved reload command, it will now say how many radio stations were actually loaded.
					- Fixed an issue which would cause radio resume to wait until player died or fail in some special cases.
			
			1.2.3 - 
					- Added initial support for Codename: CURE, BrainBread 2 & Nuclear Dawn, Please report any bugs which you may find.
					- Improved game detection to use path instead of engine version now, We still use engine version to determine a couple of things though.
						- You are welcome to try the plugin on games which we don't yet officially support, but please note that things might not work correctly.
						- If you want game support then please let us know!
					- Added Cvar sm_vpp_spec_ad_period to play adverts to spectators on a set period (In minutes), Default = 3, Min = 3, 0 = Disabled.
					- Fixed a couple of issues where Radio would not resume correctly & Fixed a rare case where adverts could resume for players who were not listening it.
					- Remove adverts at round end / freezetime being a "Good" period, it apppers to have caused a couple of complaints that it was disturbing players.
					- Removed advert grace period cvar and set it to 3 mins, Adverts should not be playing more often than every 3 mins anyway as it will risk getting you banned for spamming ads.
			1.2.4 - 
					- Fixed timer error from caused by it being closed twice due to disconnect and team event happening at same time.
					- Fixed Immunity not working, (Thanks sneaK for reporting the bug)
						- Immunity now uses overrides, You can set this up by adding advertisement_immunity to admin_overrides.cfg.
					- Added old Cvar catcher (Thanks Pinion for the idea)
					- Replaced Cvar sm_vpp_immunity with sm_vpp_immunity_enabled
						- Set to 1 to prevent displaying ads to users with access to 'advertisement_immunity', Root flag is always immune.
			1.2.5 - 
					- Added Cvar sm_vpp_radio_resumation
						- When this Cvar is enabled, The radio will be resumed for players who recieve an ad while listening or attempting to start the radio. (Once the ad finishes).
						- This Cvar is enabled by default.
					- Added Cvar sm_vpp_messages
						- When this Cvar is enabled, Messages will be printed to clients.
							- This Cvar is enabled by default.
					- Overrides now makes reserve flag immune by default, You can change this by using advertisement_immunity inside admin_overrides.cfg.
					- General code cleanup.
			1.2.6 - 
					- Attempted to fix error, although if its not fixed, then this error is nothing serious.
					- Made setting sm_vpp_ad_total -1 exlude join adverts, (It will only affect periodic, spec & phase ads now) If you want to disable join adverts you can use sm_vpp_onjoin 0.
						- This is a lump total of all ads other than the join ad, once it has been reached then no more ads will play the client until he rejoins or map changes.
					- Made setting sm_vpp_ad_period 0 disable periodic adverts.
			1.2.7 - 
					- Fixed a regression with overriding Motd on ProtoBuf games.
					- Added Cvar sm_vpp_onjoin_type, 1 = Override Motd, 2 = Wait for team join.
						- If you have issues with method 1 then set this to method 2, It defaults at 1, in most cases you should leave this at 1.
			1.2.8 - 
					- Fixed team join getting stuck on CSCO and potentially on CSGO aswell.
					- Fixed Convar change hook for sm_vpp_onjoin_type.
					- Fixed SteamWorks support in Updater.
			1.2.9 - 
					- Added Cvar sm_vpp_wait_until_dead
						- When enabled the plugin will wait until the player is dead before playing an advert (Except first join).
						- This Cvar is disabled by default, If you run a gamemode where players don't die then you will want to leave this disabled.
			1.3.0 - 
					- Fixed radio resumation in cases where the radio was started before the advert started.
					- Fixed an issue where the periodic ad timer would repeat itself even when Periodic ads were disabled.
					- Added Cvar sm_vpp_every_x_deaths (Default 0) If you have a DM / Retakes / Arena or mod where the client dies a lot then you will want to leave this at 0.
						- This Cvar allows you to play adverts every time the client dies this many times, Please note that if the last ad was less than 3 mins it will it will wait until 3 mins have passed.
					- Added some developer stuff for people who want to play ads in various other scenarios.
						- Forward VPP_OnAdvertStarted(int iClient, const char[] szRadioResumeUrl);
						- Forward VPP_OnAdvertFinished(int iClient, const char[] szRadioResumeUrl);
						- Native BOOL VPP_PlayAdvert(int iClient) - Note to prevent spam it will delay the ad until 3 mins have passed since previous ad (If applicable)
						- Native BOOL VPP_IsAdvertPlaying(int iClient);
						
			1.3.1 - 
					- Rewrote Timer and advert logic to fix error and prevent useless handles being opened.
			1.3.2 - 
					- Fixed a missing ! which caused ads not to be played and nested the if statement.
					- Removed useless check which might of caused spectator ads not to play.
					- Fixed a bug where a new UserMessage was being created inside the hook instead of overriding the existing one.
			1.3.3 - 
					- Fixed invalid handle error spam.
					- Improved check before serving ad to make sure client is properly authorized and immunity checks are accurate.
					- Added notify option to as an alternative to kicking player for having html motd disabled, sm_vpp_kickmotd 1 = Kick, 2 = Notify, 0 = Do nothing.
					- Added min and max values to cvars and decreased default advert interval from 15 to 5 mins.
					- Increased advert play time to 60 seconds to improve completion rates.
					- Removed redirect to about:blank after advert as its now broken due to a CSGO update (and was not too important anyway).
			1.3.4 -
					- Fixed missing advert play times to improve completion rates.
			1.3.5 -
					- (IMPORTANT UPDATE) Fixed adverts not playing after first ad had started.
			1.3.6 -
					- (IMPORTANT UPDATE 2) Fixed intial advert not playing on games other than CSGO. 
					- This update is optional only if you run CSGO, if you run a game other than CSGO then its important!
			1.3.7 -
					- Fix the remaining issues where ads would refuse to play regardless of the game.
					- Fixed the a few cvar min values (Thanks Rushy for reporting the issue.)
					- Changed how adverts play on phases -- 
						- If an advert was qued (Regardless of the trigger) it would either wait for the client to die or for a phase to start, It will now respect the value of sm_vpp_onphase.
						- For example if you have sm_vpp_onphase 0, It will continue waiting until the client dies before the qued advert starts, if however you set this to 1, it will supersede 
						sm_vpp_wait_until_dead and play regardless of if the client is alive or not. (Thanks to Rushy for bringing this to my attention.)
			1.3.8 - 
				 	- (IMPORTANT UPDATE 3) Fix advert interval cvar.
			1.3.9 - 
					- Force sv_disable_motd to 0 to allow ads to play correctly.
					- Change updater url for easier future updates.
			1.4.0 - 
					- Account for people using cl_disablehtmlmotd -1.
					- Fix a potential bug which could cause radio resumation to continue after a player stopped listening to radio.
					- Added sending of parameters for future backend improvements.
					- Added built in updater which should be more reliable.
					- Added custom log file (VPP_Adverts.log)
			1.4.1 - 
					- Fixed built in Updater.
					- Fixed parameter formatting.
			1.4.2 - 
					- Completion rate improvements.
					- Fix regression in Day of defeat source.
			1.4.3 -
					- Fix regression in No more room in hell, Nuclear Dawn (We were unable to test Brainbread 2 and Codename Cure, if somebody finds any issues with these game please let us know!)
			1.4.4 -
					- Fix wait until death in No more room in hell.
			1.4.5 -
					- Removed support for Codename: CURE as motd no longer functions in this game.
					- Rewrote VGUI hook logic.
					- Improved initial motd overriding in games which use bitbuffer messages.
					- Increased default min advert period from 3 mins to 5 mins.
					- Added cache buster which fixes motd caching issues, our solution is universal and cross game compatible, please remove any existing plugins which do such thing as they will cause severe conflicts, we have implemented such solution so you can continue to use VPP Adverts without losing this important fix.
					- Added check for conflicting cache buster plugin.
					- Added forward VPP_OnURL_Pre which gets called right before a url is sent to client (After cache busted).
					- Added safety features to prevent initial motd / team menu getting scuffed by other plugins which show VGUI panels.
					- Added request count tracking.
					- Removed sm_vpp_every_x_deaths as this did not make sense when an ad could not always be guaranteed every x deaths, please use the interval ConVar instead.
					- Removed sm_vpp_onjoin_type as all issues with initial motd should now be resolved, if you want to remove motd ads on join please use sm_vpp_onjoin 0.
					- Renamed radio reload command to sm_vpp_reloadradios.
					- Changed immunity to default with admins that have root now, it is still changable with the override 'advertisement_immunity' though.
					- General code cleanup and logic improvements.
			1.4.5.1 -
					- Revert default immunity to reservation flag due to complaints.
			1.4.5.2 -
					- Fixed team join issues in TF2 for immune players.
			1.4.5.3 -
					- Quick patch for TF2 big motd.
			1.4.5.4 -
					- Really fix TF2 issues for immune players this time (Thanks bottiger)
			1.4.5.5 -
					- Temporarily removed tracking for backend test reasons.
					- Temporary fix for EasyHTTP include not compiling, we are going to be replacing this later anyway.
			1.4.5.6 -
					- Fixed missing CellRef in forward. (Thanks zo6zo6)
			1.4.5.7 -
					- Resolved issues with sm_vpp_onphase Cvar in TF2
					- Fixed issue with VGUIs not showing up during Steam API downtime
					
****************************************************************************************************
	ETIQUETTE.
*****************************************************************************************************/
#pragma newdecls required;
#pragma semicolon 1;
#pragma dynamic 131072

/*****************************************************************************************************
	INCLUDES
*****************************************************************************************************/
#include <sdktools>
#include <autoexecconfig>
#include <multicolors>
#include <ngs_adverts>
#include <EasyHTTP>

#define UPDATE_URL    "https://raw.githubusercontent.com/VPPGamingNetwork/vppgn-sourcemod/master/addons/sourcemod/updatev2.txt"

/****************************************************************************************************
	DEFINES
*****************************************************************************************************/
#define LoopValidClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsValidClient(%1))
#define PREFIX "[{lightgreen}Advert{default}] "

/****************************************************************************************************
	PLUGIN INFO.
*****************************************************************************************************/
public Plugin myinfo = 
{
	name = "VPP Advertisement Plugin", 
	author = "VPP Gaming Network & SM9();", 
	description = "Plugin for displaying VPP Network's advertisement on server aswell as allowing extra ones.", 
	version = PL_VERSION, 
	url = "http://vppgamingnetwork.com/"
}

/****************************************************************************************************
	HANDLES.
*****************************************************************************************************/
ConVar g_hVPPUrl = null;
ConVar g_hCvarJoinGame = null;
ConVar g_hCvarAdvertPeriod = null;
ConVar g_hCvarImmunityEnabled = null;
ConVar g_hCvarAdvertTotal = null;
ConVar g_hCvarPhaseAds = null;
ConVar g_hCvarMotdCheck = null;
ConVar g_hCvarSpecAdvertPeriod = null;
ConVar g_hCvarRadioResumation = null;
ConVar g_hCvarMessages = null;
ConVar g_hCvarWaitUntilDead = null;
ConVar g_hCvarDisableMotd = null;
ConVar g_hCvarUnloadOnDismissal = null;

Handle g_hQueueTimer[MAXPLAYERS + 1];
Handle g_hFinishedTimer[MAXPLAYERS + 1];
Handle g_hSpecTimer[MAXPLAYERS + 1];
Handle g_hPeriodicTimer[MAXPLAYERS + 1];
Handle g_hOnAdvertStarted = null;
Handle g_hOnAdvertFinished = null;
Handle g_hOnUrlPre = null;

Menu g_mMenuWarning = null;

ArrayList g_alRadioStations = null;
EngineVersion g_eVersion = Engine_Unknown;

DataPack g_dCache[MAXPLAYERS + 1];

/****************************************************************************************************
	STRINGS.
*****************************************************************************************************/
char g_szVPPUrl[256];
char g_szGameName[256];

enum EGame
{
	eGameUntested = -1, 
	eGameCSGO, 
	eGameCSCO, 
	eGameTF2, 
	eGameCSS, 
	eGameBB2, 
	eGameDODS, 
	eGameFOF, 
	eGameND, 
	eGameNMRIH
};

char g_szTestedGames[][] = 
{
	"csgo", 
	"csco", 
	"tf", 
	"cstrike", 
	"brainbread2", 
	"dod", 
	"fof", 
	"nucleardawn", 
	"nmrih"
};

char g_szJoinGames[][] = 
{
	"dod", 
	"nucleardawn", 
	"brainbread2", 
	"cstrike"
};

char g_szResumeUrl[MAXPLAYERS + 1][256];
char g_szServerIP[64];
char g_szLogFile[PLATFORM_MAX_PATH];

/****************************************************************************************************
	BOOLS.
*****************************************************************************************************/
bool g_bJoinAdverts = false;
bool g_bProtoBuf = false;
bool g_bPhaseAds = false;
bool g_bPhase = false;
bool g_bForceJoinGame = false;
bool g_bImmunityEnabled = false;
bool g_bRadioResumation = false;
bool g_bMessages = false;
bool g_bWaitUntilDead = false;
bool g_bUpdating = false;
bool g_bHasClasses = false;
bool g_bLateLoad = false;
bool g_bFirstMotd[MAXPLAYERS + 1] =  { true, ... };
bool g_bAdvertPlaying[MAXPLAYERS + 1];
bool g_bMotdDisabled[MAXPLAYERS + 1];
bool g_bCacheBusted[MAXPLAYERS + 1];
bool g_bBustingCache[MAXPLAYERS + 1];
bool g_bAdRequeue[MAXPLAYERS + 1];
bool g_bGameJoined[MAXPLAYERS + 1];
bool g_bAdvertCleared[MAXPLAYERS + 1] =  { true, ... };

/****************************************************************************************************
	INTS.
*****************************************************************************************************/
int g_iAdvertTotal = -1;
int g_iAdvertRequests[MAXPLAYERS + 1];
int g_iLastAdvertTime[MAXPLAYERS + 1];
int g_iMotdOccurence[MAXPLAYERS + 1];
int g_iMotdAction = 0;
int g_iPort = -1;
int g_iExpectedMotdOccurence = 2;

/****************************************************************************************************
	FLOATS.
*****************************************************************************************************/
float g_fAdvertPeriod;
float g_fSpecAdvertPeriod;

/****************************************************************************************************
	MISC.
*****************************************************************************************************/
EGame g_eGame = eGameUntested;

public void OnPluginStart()
{
	BuildPath(Path_SM, g_szLogFile, sizeof(g_szLogFile), "logs/VPP_Adverts.log");
	
	if (!FileExists(g_szLogFile)) {
		File fFile = OpenFile(g_szLogFile, "a+");
		
		if (fFile == null) {
			SetFailState("Unable to open %s, please contact us for support!", g_szLogFile);
			return;
		}
		
		fFile.Close();
	}
	
	CheckExtensions();
	
	UserMsg umVGUIMenu = GetUserMessageId("VGUIMenu");
	
	if (umVGUIMenu == INVALID_MESSAGE_ID) {
		VPP_FailState("This game does not support VGUI menu's, please contact us and let us know what game it is!");
	}
	
	HookUserMessage(umVGUIMenu, OnVGUIMenu, true);
	
	g_bProtoBuf = (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf);
	
	if (GetGameFolderName(g_szGameName, sizeof(g_szGameName)) <= 0) {
		VPP_FailState("Unable to retrieve game directory name, please contact us for support!");
	}
	
	for (int i = 0; i < sizeof(g_szTestedGames); i++) {
		if (StrEqual(g_szGameName, g_szTestedGames[i], false)) {
			g_eGame = view_as<EGame>(i);
			break;
		}
	}
	
	for (int i = 0; i < sizeof(g_szJoinGames); i++) {
		if (StrEqual(g_szGameName, g_szJoinGames[i], false)) {
			g_bForceJoinGame = true;
			break;
		}
	}
	
	if (g_eGame == eGameUntested) {
		VPP_Log(false, "The plugin has not been tested on this game (game: %s, engine: %d), things may not work correctly.", g_szGameName, g_eVersion);
	}
	
	AutoExecConfig_SetFile("plugin.vpp_adverts");
	
	CreateConVar("sm_vppadverts_version", PL_VERSION, "[SM] VPP Adverts Plugin Version", FCVAR_DONTRECORD);
	
	g_hVPPUrl = AutoExecConfig_CreateConVar("sm_vpp_url", "", "Put your VPP Advert Link here", FCVAR_PROTECTED);
	g_hVPPUrl.AddChangeHook(OnCvarChanged);
	
	g_hCvarJoinGame = AutoExecConfig_CreateConVar("sm_vpp_onjoin", "1", "Should advertisement be displayed to players on first team join?, 0 = Disabled.", _, true, 0.0, true, 1.0);
	g_hCvarJoinGame.AddChangeHook(OnCvarChanged);
	
	g_hCvarAdvertPeriod = AutoExecConfig_CreateConVar("sm_vpp_ad_period", "5", "How often the periodic adverts should be played (In Minutes), 0 = Disabled.", _, true, 0.0);
	g_hCvarAdvertPeriod.AddChangeHook(OnCvarChanged);
	
	g_hCvarSpecAdvertPeriod = AutoExecConfig_CreateConVar("sm_vpp_spec_ad_period", "5", "How often should ads be played to spectators (In Minutes), 0 = Disabled.", _, true, 0.0);
	g_hCvarSpecAdvertPeriod.AddChangeHook(OnCvarChanged);
	
	g_hCvarPhaseAds = AutoExecConfig_CreateConVar("sm_vpp_onphase", "1", "Should advertisement attempt to be displayed on game phases? (HalfTime, OverTime, MapEnd, WinPanels etc) (This will supersede sm_vpp_wait_until_dead) 0 = Disabled.", _, true, 0.0, true, 1.0);
	g_hCvarPhaseAds.AddChangeHook(OnCvarChanged);
	
	g_hCvarAdvertTotal = AutoExecConfig_CreateConVar("sm_vpp_ad_total", "0", "How many adverts should be played in total (excluding join adverts)? 0 = Unlimited, -1 = Disabled.", _, true, -1.0);
	g_hCvarAdvertTotal.AddChangeHook(OnCvarChanged);
	
	g_hCvarImmunityEnabled = AutoExecConfig_CreateConVar("sm_vpp_immunity_enabled", "0", "Prevent displaying ads to users with access to 'advertisement_immunity', 0 = Disabled. (Default: Reservartion flag)", _, true, 0.0, true, 1.0);
	g_hCvarImmunityEnabled.AddChangeHook(OnCvarChanged);
	
	g_hCvarMotdCheck = AutoExecConfig_CreateConVar("sm_vpp_kickmotd", "0", "Action for player with html motd disabled, 0 = Disabled, 1 = Kick Player, 2 = Display notifications.", _, true, 0.0, true, 2.0);
	g_hCvarMotdCheck.AddChangeHook(OnCvarChanged);
	
	g_hCvarRadioResumation = AutoExecConfig_CreateConVar("sm_vpp_radio_resumation", "1", "Resume Radio after advertisement finishes, 0 = Disabled.", _, true, 0.0, true, 1.0);
	g_hCvarRadioResumation.AddChangeHook(OnCvarChanged);
	
	g_hCvarMessages = AutoExecConfig_CreateConVar("sm_vpp_messages", "1", "Show messages to clients, 0 = Disabled.", _, true, 0.0, true, 1.0);
	g_hCvarMessages.AddChangeHook(OnCvarChanged);
	
	g_hCvarWaitUntilDead = AutoExecConfig_CreateConVar("sm_vpp_wait_until_dead", "0", "Wait until player is dead (Except first join) 0 = Disabled.", _, true, 0.0, true, 1.0);
	g_hCvarWaitUntilDead.AddChangeHook(OnCvarChanged);
	
	RegAdminCmd("sm_vpp_reloadradios", Command_Reload, ADMFLAG_CONVARS, "Reloads radio stations");
	
	HookEventEx("game_win", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("game_end", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("round_win", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("tf_game_over", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("teamplay_win_panel", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("teamplay_round_win", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("arena_win_panel", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("announce_phase_end", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("cs_win_panel_match", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("wave_complete", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("dod_game_over", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("dod_win_panel", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("round_start", Event_RoundStart, EventHookMode_Post);
	HookEventEx("teamplay_round_start", Event_RoundStart, EventHookMode_Post);
	HookEventEx("player_team", Event_PlayerTeam, EventHookMode_Post);
	HookEventEx("player_class", Event_Requeue, EventHookMode_Post);
	HookEventEx("player_spawn", Event_Requeue, EventHookMode_Post);
	HookEventEx("player_death", Event_Requeue, EventHookMode_Post);
	
	LoadTranslations("vppadverts.phrases.txt");
	
	AutoExecConfig_ExecuteFile();
	LoadRadioStations();
	
	RegServerCmd("sm_vpp_immunity", OldCvarFound, "Outdated cvar, please update your config.");
	RegServerCmd("sm_vpp_ad_grace", OldCvarFound, "Outdated cvar, please update your config.");
	RegServerCmd("sm_vpp_every_x_deaths", OldCvarFound, "Outdated cvar, please update your config.");
	RegServerCmd("sm_vpp_onjoin_type", OldCvarFound, "Outdated cvar, please update your config.");
	
	g_hOnAdvertStarted = CreateGlobalForward("VPP_OnAdvertStarted", ET_Ignore, Param_Cell, Param_String);
	g_hOnAdvertFinished = CreateGlobalForward("VPP_OnAdvertFinished", ET_Ignore, Param_Cell, Param_String);
	g_hOnUrlPre = CreateGlobalForward("VPP_OnURL_Pre", ET_Ignore, Param_Cell, Param_String, Param_String, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef);
	
	CreateMotdMenu();
	
	if (g_eGame == eGameDODS || g_eGame == eGameNMRIH || g_eGame == eGameND || g_eGame == eGameBB2) {
		g_iExpectedMotdOccurence = 1;
	} else {
		g_iExpectedMotdOccurence = 2;
	}
	
	AddCommandListener(JoinGame_Listener, "joingame");
	
	if (g_bLateLoad) {
		LoopValidClients(iClient) {
			OnClientPutInServer(iClient);
		}
		
		OnMapStart();
		OnConfigsExecuted();
	}
}

public void OnAllPluginsLoaded() {
	CheckForConflictingPlugins();
}

public void OnLibraryAdded(const char[] szName) 
{
	CheckExtensions();
	CheckForConflictingPlugins();
}

public void OnLibraryRemoved(const char[] szName) {
	CheckExtensions();
}

public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] szError, int iErrMax)
{
	CreateNative("VPP_PlayAdvert", Native_PlayAdvert);
	CreateNative("VPP_IsAdvertPlaying", Native_IsAdvertPlaying);
	
	RegPluginLibrary("VPPAdverts");
	EasyHTTP_MarkNatives();
	
	g_bLateLoad = bLate;
	return APLRes_Success;
}

public void OnClientPutInServer(int iClient)
{
	if (!IsValidClient(iClient)) {
		return;
	}
	
	DataPack dPack = new DataPack();
	dPack.WriteCell(GetClientUserId(iClient));
	dPack.WriteCell(false);
	
	QueryClientConVar(iClient, "cl_disablehtmlmotd", Query_MotdPlayAd, dPack);
	
	ClearTimers(iClient, null, true, true);
	
	if (g_fAdvertPeriod > 0.0 && g_fAdvertPeriod < 3.0) {
		g_fAdvertPeriod = 3.0;
		g_hCvarAdvertPeriod.IntValue = 3;
	}
	
	if (g_fAdvertPeriod > 0.0) {
		g_hPeriodicTimer[iClient] = CreateTimer(g_fAdvertPeriod * 60.0, Timer_IntervalAd, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	}
	
	if (!g_bHasClasses) {
		g_bHasClasses = HasEntProp(iClient, Prop_Send, "m_iClass");
	}
	
	strcopy(g_szResumeUrl[iClient], 128, "about:blank");
	
	g_bFirstMotd[iClient] = true;
	g_bAdvertCleared[iClient] = true;
	g_iMotdOccurence[iClient] = 0;
}

public void OnClientDisconnect(int iClient)
{
	g_iAdvertRequests[iClient] = 0;
	g_iLastAdvertTime[iClient] = 0;
	g_iMotdOccurence[iClient] = 0;
	g_bFirstMotd[iClient] = true;
	g_bAdvertPlaying[iClient] = false;
	g_bMotdDisabled[iClient] = false;
	g_bCacheBusted[iClient] = false;
	g_bBustingCache[iClient] = false;
	g_bAdRequeue[iClient] = false;
	g_bGameJoined[iClient] = false;
	g_bAdvertCleared[iClient] = true;
	
	delete g_dCache[iClient];
	
	ClearTimers(iClient, null, true, true);
	
	strcopy(g_szResumeUrl[iClient], 128, "about:blank");
}

public void OnMapStart() {
	g_bPhase = false;
}

public void OnConfigsExecuted()
{
	CheckExtensions();
	CheckForConflictingPlugins();
	CheckForUpdates();
	UpdateConVars();
	GetServerIP();
}

public void OnMapEnd()
{
	g_bPhase = false;
	g_bUpdating = false;
}

public void Event_RoundStart(Event eEvent, char[] szEvent, bool bDontBroadcast) {
	g_bPhase = false;
}

public void Phase_Hooks(Event eEvent, char[] szEvent, bool bDontBroadcast)
{
	if (!g_bPhaseAds) {
		return;
	}
	
	g_bPhase = true;
	
	LoopValidClients(iClient) {
		SendAdvert(iClient);
	}
}

public Action Event_PlayerEvents(Event eEvent, char[] szEvent, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	
	if (!IsValidClient(iClient)) {
		return Plugin_Continue;
	}
	
	SendAdvert(iClient);
	return Plugin_Continue;
}

public Action Event_Requeue(Event eEvent, char[] szEvent, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	
	if (!g_bAdRequeue[iClient]) {
		return;
	}
	
	SendAdvert(iClient);
}

public Action Event_PlayerTeam(Event eEvent, char[] szEvent, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	int iTeam = eEvent.GetInt("team");
	bool bDisconnect = eEvent.GetBool("disconnect");
	
	if (!IsValidClient(iClient) || bDisconnect) {
		return Plugin_Continue;
	}
	
	if (iTeam != 1 || g_fSpecAdvertPeriod <= 0.0) {
		NullifyTimer(iClient, g_hSpecTimer[iClient], true);
	}
	
	if (!g_bAdRequeue[iClient] && iTeam != 1) {
		return Plugin_Continue;
	}
	
	SendAdvert(iClient);
	return Plugin_Continue;
}

public Action OnVGUIMenu(UserMsg umId, Handle hMsg, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit)
{
	int iClient = iPlayers[0];
	
	if (g_bSteamWorks)
	{
		if (!SteamWorks_IsConnected()) {
			return Plugin_Continue;
		}
	}
	else if (g_bSteamTools)
	{
		if (!Steam_IsConnected()) {
			return Plugin_Continue;
		}
	}

	if (!IsValidClient(iClient)) {
		return Plugin_Continue;
	}

	char szUrl[256]; char szTitle[256]; char szKey[256];
	bool bShow; bool bCustomSvr; bool bCacheBuster_Pre; int iWidth; int iHeight;
	bool bGotURL = GetVGUIInfo(iClient, hMsg, szKey, szUrl, szTitle, iWidth, iHeight, bCacheBuster_Pre, bShow, bCustomSvr);
	bool bMotd; bool bVPP; bool bCacheBuster; bool bAboutBlank; bool bRadio; bool bMotdClear;
	
	if (StrEqual(szTitle, "Clear Motd", false)) {
		bMotdClear = true;
	} else if (StrEqual(szUrl, "motd", false) || StrEqual(szUrl, "motd_text", false)) {
		bMotd = true;
	} else if (StrContains(szUrl, g_szVPPUrl, false) != -1) {
		bVPP = true;
	} else if (StrContains(szUrl, "http://vppgaming.network/cachebuster/", false) != -1) {
		bCacheBuster = true;
	} else if (StrEqual(szUrl, "about:blank", false)) {
		bAboutBlank = true;
	} else if (IsRadio(szUrl)) {
		bRadio = true;
		bShow = false;
	}
	
	if (GetClientTeam(iClient) < 1 && g_bProtoBuf && !bMotd && !StrEqual(szKey, "team") && !bMotdClear && !bCacheBuster && !bCacheBuster_Pre) {
		return Plugin_Handled;
	}
	
	if (!bGotURL) {
		return Plugin_Continue;
	}
	
	if (g_bBustingCache[iClient]) {
		return Plugin_Handled;
	}
	
	if (StrEqual(szUrl, "http://clanofdoom.co.uk/servers/motd/?id=radio")) {
		return Plugin_Handled;
	}
	
	if (g_bJoinAdverts && g_bFirstMotd[iClient] && !bMotd && !bVPP && !bMotdClear && !bCacheBuster && !bCacheBuster_Pre) {
		return Plugin_Handled;
	}
	
	if (bRadio) {
		strcopy(g_szResumeUrl[iClient], sizeof(szUrl), szUrl);
	} else if (!bMotd && !bVPP && !bMotdClear && !bCacheBuster && !bCacheBuster_Pre) {
		strcopy(g_szResumeUrl[iClient], sizeof(szUrl), "about:blank");
	}
	
	if (bVPP && AdShouldWait(iClient)) {
		return Plugin_Handled;
	}
	
	int iUserId = GetClientUserId(iClient);
	
	if (g_bAdvertPlaying[iClient]) {
		if (bCacheBuster || bAboutBlank || bMotd || bVPP || bMotdClear || bCacheBuster_Pre) {
			return Plugin_Handled;
		}
		
		if (bRadio || (!StrEqual(g_szResumeUrl[iClient], "", false) && !StrEqual(g_szResumeUrl[iClient], "about:blank", false) && g_bRadioResumation)) {
			RequestFrame(PrintRadioMessage, iUserId);
		} else {
			RequestFrame(PrintMiscMessage, iUserId);
		}
		
		return Plugin_Handled;
	}
	
	if (bMotdClear) {
		if (bCacheBuster_Pre) {
			CreateTimer(0.1, Timer_SendCacheBuster, iUserId, TIMER_FLAG_NO_MAPCHANGE);
		}
		
		g_bAdvertCleared[iClient] = true;
		
		return Plugin_Continue;
	}
	
	if (bCacheBuster) {
		g_bBustingCache[iClient] = true;
		g_bAdvertCleared[iClient] = true;
		CreateTimer(0.5, Timer_CacheBusted, iUserId, TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Continue;
	}
	
	if (!g_bBustingCache[iClient] && !g_bCacheBusted[iClient] && !bAboutBlank && !bMotd && !bMotdClear && !bCacheBuster_Pre && !bCacheBuster && (!g_bFirstMotd[iClient] || !g_bJoinAdverts)) {
		if (g_dCache[iClient] == null) {
			g_dCache[iClient] = new DataPack();
		}
		
		g_dCache[iClient].Reset();
		g_dCache[iClient].WriteString(szTitle);
		g_dCache[iClient].WriteString(szUrl);
		g_dCache[iClient].WriteCell(iWidth);
		g_dCache[iClient].WriteCell(iHeight);
		g_dCache[iClient].WriteCell(bShow);
		g_dCache[iClient].WriteCell((bReliable ? USERMSG_RELIABLE : 0) | (bInit ? USERMSG_INITMSG : 0));
		g_dCache[iClient].WriteCell(bVPP);
		g_dCache[iClient].WriteCell(bCustomSvr);
		
		DataPack dPack = new DataPack();
		dPack.WriteCell(iUserId);
		dPack.WriteCell(true);
		dPack.Reset();
		
		RequestFrame(ClearMotd, dPack);
		
		return Plugin_Handled;
	}
	
	if (bVPP) {
		RequestFrame(Frame_AdvertStartedForward, iUserId);
		
		g_bAdvertPlaying[iClient] = true;
		g_hFinishedTimer[iClient] = CreateTimer(60.0, Timer_AdvertFinished, iUserId, TIMER_FLAG_NO_MAPCHANGE);
		
		g_bCacheBusted[iClient] = false;
		g_bAdRequeue[iClient] = false;
		g_bAdvertCleared[iClient] = false;
		
		g_iLastAdvertTime[iClient] = GetTime();
		g_iAdvertRequests[iClient]++;
		
		return Plugin_Continue;
	}
	
	if (bMotd) {
		if (IsClientImmune(iClient)) {
			g_bFirstMotd[iClient] = false;
			return Plugin_Continue;
		}
		
		if (++g_iMotdOccurence[iClient] != g_iExpectedMotdOccurence) {
			g_bAdvertCleared[iClient] = false;
			
			DataPack dPack = new DataPack();
			dPack.WriteCell(iUserId);
			dPack.WriteCell(false);
			dPack.Reset();
			
			RequestFrame(ClearMotd, dPack);
			return Plugin_Handled;
		}
		
		if (!g_bJoinAdverts || g_bMotdDisabled[iClient]) {
			g_bFirstMotd[iClient] = false;
			g_bAdRequeue[iClient] = true;
			return Plugin_Continue;
		}
		
		if (!g_bProtoBuf) {
			RequestFrame(Frame_BfMotdOverride, iUserId);
			return Plugin_Handled;
		}
		
		if (!FormatAdvertUrl(iClient, g_szVPPUrl, szUrl) || !ShowVGUIPanelEx(iClient, "VPP Network Advertisement MOTD", szUrl, _, _, _, hMsg)) {
			g_bAdRequeue[iClient] = true;
			g_bCacheBusted[iClient] = false;
			g_bAdvertCleared[iClient] = false;
			
			DataPack dPack = new DataPack();
			dPack.WriteCell(iUserId);
			dPack.WriteCell(false);
			dPack.Reset();
			
			RequestFrame(ClearMotd, dPack);
			g_bFirstMotd[iClient] = false;
			return Plugin_Changed;
		}
		
		RequestFrame(Frame_AdvertStartedForward, iUserId);
		
		g_bAdvertPlaying[iClient] = true;
		g_iAdvertRequests[iClient]++;
		g_hFinishedTimer[iClient] = CreateTimer(60.0, Timer_AdvertFinished, iUserId, TIMER_FLAG_NO_MAPCHANGE);
		
		g_bCacheBusted[iClient] = false;
		g_bAdvertCleared[iClient] = false;
		g_bFirstMotd[iClient] = false;
		
		return Plugin_Changed;
	}
	
	if (bAboutBlank) {
		g_bAdvertCleared[iClient] = false;
		
		DataPack dPack = new DataPack();
		dPack.WriteCell(iUserId);
		dPack.WriteCell(false);
		dPack.Reset();
		
		RequestFrame(ClearMotd, dPack);
	}
	
	if (!g_bJoinAdverts) {
		g_bAdRequeue[iClient] = true;
	}
	
	if (!bVPP) {
		g_bAdvertCleared[iClient] = true;
	}
	
	g_bCacheBusted[iClient] = false;
	return Plugin_Continue;
}

public Action Timer_SendCacheBuster(Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	
	if (!IsValidClient(iClient)) {
		return Plugin_Stop;
	}
	
	char szAuthId[64];
	
	if (!GetClientAuthId(iClient, AuthId_Steam2, szAuthId, sizeof(szAuthId))) {
		strcopy(szAuthId, sizeof(szAuthId), "null");
	}
	
	char szUrl[256]; Format(szUrl, sizeof(szUrl), "http://vppgaming.network/cachebuster/?ip=%s&po=%d&st=%s&pv=%s&gm=%s", g_szServerIP, g_iPort, szAuthId, PL_VERSION, g_szGameName);
	ShowVGUIPanelEx(iClient, "Cache Buster", szUrl, _, _, false, _, false);
	
	return Plugin_Stop;
}

public void Frame_BfMotdOverride(int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	
	if (!IsValidClient(iClient)) {
		return;
	}
	
	char szUrl[256];
	bool bFailed = false;
	bFailed = !FormatAdvertUrl(iClient, g_szVPPUrl, szUrl);
	
	if (!bFailed) {
		bFailed = !ShowVGUIPanelEx(iClient, "VPP Network Advertisement MOTD", szUrl);
	}
	
	if (bFailed) {
		ShowMOTDPanel(iClient, "Motd", "motd", MOTDPANEL_TYPE_URL);
	}
	
	g_bFirstMotd[iClient] = false;
}

public void Query_MotdPlayAd(QueryCookie qCookie, int iClient, ConVarQueryResult cqResult, const char[] szCvarName, const char[] szCvarValue, DataPack dPack)
{
	if (!IsValidClient(iClient)) {
		delete dPack;
		return;
	}
	
	if (IsClientImmune(iClient)) {
		delete dPack;
		return;
	}
	
	dPack.Reset();
	
	int iUserId = dPack.ReadCell();
	bool bPlayAd = view_as<bool>(dPack.ReadCell());
	delete dPack;
	
	if (iClient != GetClientOfUserId(iUserId)) {
		return;
	}
	
	if (StringToInt(szCvarValue) != 0) {
		g_bMotdDisabled[iClient] = true;
		
		if (g_iMotdAction == 1) {
			KickClient(iClient, "%t", "Kick Message");
		} else if (g_iMotdAction == 2) {
			PrintHintText(iClient, "%t", "Menu_Title");
			g_mMenuWarning.Display(iClient, 10);
			g_bAdRequeue[iClient] = true;
		}
		
		return;
	}
	
	if (bPlayAd && g_hQueueTimer[iClient] == null) {
		g_bCacheBusted[iClient] = false;
		g_bAdvertCleared[iClient] = false;
		g_hQueueTimer[iClient] = CreateTimer(1.0, Timer_PlayAdvert, iUserId, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	}
	
	g_bMotdDisabled[iClient] = false;
}

public void Frame_AdvertStartedForward(int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	
	if (!IsValidClient(iClient)) {
		return;
	}
	
	Call_StartForward(g_hOnAdvertStarted);
	Call_PushCell(iClient);
	Call_PushString(g_szResumeUrl[iClient]);
	Call_Finish();
}

public void Frame_AdvertFinishedForward(int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	
	if (!IsValidClient(iClient)) {
		return;
	}
	
	Call_StartForward(g_hOnAdvertFinished);
	Call_PushCell(iClient);
	Call_PushString(g_szResumeUrl[iClient]);
	Call_Finish();
}

public void PrintRadioMessage(int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	
	if (!IsValidClient(iClient)) {
		return;
	}
	
	if (!g_bMessages) {
		return;
	}
	
	CPrintToChat(iClient, "%s%t", PREFIX, "Radio Message");
}

public void PrintMiscMessage(int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	
	if (!IsValidClient(iClient)) {
		return;
	}
	
	if (!g_bMessages) {
		return;
	}
	
	CPrintToChat(iClient, "%s%t", PREFIX, "Misc Message");
}

public Action Timer_CacheBusted(Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	
	if (!IsValidClient(iClient)) {
		return Plugin_Stop;
	}
	
	g_bCacheBusted[iClient] = true;
	g_bBustingCache[iClient] = false;
	
	if (g_dCache[iClient] == null) {
		return Plugin_Stop;
	}
	
	g_dCache[iClient].Reset();
	
	char szTitle[256]; g_dCache[iClient].ReadString(szTitle, sizeof(szTitle));
	char szUrl[256]; g_dCache[iClient].ReadString(szUrl, sizeof(szUrl));
	int iWidth = g_dCache[iClient].ReadCell();
	int iHeight = g_dCache[iClient].ReadCell();
	bool bShow = view_as<bool>(g_dCache[iClient].ReadCell());
	
	int iFlags = g_dCache[iClient].ReadCell();
	bool bAdvert = view_as<bool>(g_dCache[iClient].ReadCell());
	bool bCustomSvr = view_as<bool>(g_dCache[iClient].ReadCell());
	delete g_dCache[iClient];
	
	if (!bAdvert) {
		Action aResult;
		
		Call_StartForward(g_hOnUrlPre);
		Call_PushCell(iClient);
		Call_PushStringEx(szUrl, sizeof(szUrl), SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
		Call_PushStringEx(szTitle, sizeof(szTitle), SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
		Call_PushCellRef(bShow);
		Call_PushCellRef(iWidth);
		Call_PushCellRef(iHeight);
		Call_PushCellRef(bCustomSvr);
		Call_Finish(aResult);
		
		if (aResult == Plugin_Stop || aResult == Plugin_Handled) {
			return Plugin_Stop;
		}
	}
	
	ShowVGUIPanelEx(iClient, szTitle, szUrl, _, iFlags, bShow, _, bAdvert, iWidth, iHeight, bCustomSvr);
	return Plugin_Stop;
}

public Action Timer_IntervalAd(Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	
	if (!IsValidClient(iClient)) {
		return Plugin_Stop;
	}
	
	SendAdvert(iClient);
	return Plugin_Continue;
}

public Action Timer_PlayAdvert(Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	
	if (!IsValidClient(iClient)) {
		return Plugin_Stop;
	}
	
	if (HasClientFinishedAds(iClient)) {
		ClearTimers(iClient, hTimer, true, false);
		NullifyTimer(iClient, hTimer, false);
		return Plugin_Stop;
	}
	
	if (g_bAdvertPlaying[iClient] || g_hFinishedTimer[iClient] != null) {
		if (hTimer == g_hSpecTimer[iClient] || hTimer == g_hPeriodicTimer[iClient] || hTimer == g_hQueueTimer[iClient]) {
			return Plugin_Continue;
		}
		
		return Plugin_Stop;
	}
	
	if (AdShouldWait(iClient) || g_bBustingCache[iClient]) {
		return Plugin_Continue;
	}
	
	if (IsClientImmune(iClient)) {
		ClearTimers(iClient, hTimer, true, true);
		NullifyTimer(iClient, hTimer, false);
		return Plugin_Stop;
	}
	
	char szUrl[256];
	
	if (!FormatAdvertUrl(iClient, g_szVPPUrl, szUrl)) {
		return Plugin_Continue;
	}
	
	ShowVGUIPanelEx(iClient, "VPP Network Advertisement MOTD", szUrl);
	
	NullifyTimer(iClient, hTimer, false);
	
	int iTeam = GetClientTeam(iClient);
	
	if (hTimer == g_hPeriodicTimer[iClient]) {
		return Plugin_Continue;
	} else if (iTeam == 1 && g_fSpecAdvertPeriod > 0.0 && g_eGame != eGameNMRIH) {
		if (g_hSpecTimer[iClient] == null) {
			g_hSpecTimer[iClient] = CreateTimer(g_fSpecAdvertPeriod * 60.0, Timer_PlayAdvert, iUserId, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
		}
		
		return Plugin_Continue;
		
	} else if ((iTeam != 1 || g_eGame == eGameNMRIH) && hTimer != g_hSpecTimer[iClient]) {
		NullifyTimer(iClient, g_hSpecTimer[iClient], true);
	}
	
	if (hTimer == g_hSpecTimer[iClient] || hTimer == g_hPeriodicTimer[iClient]) {
		return Plugin_Continue;
	}
	
	NullifyTimer(iClient, hTimer, false);
	return Plugin_Stop;
}

public Action Timer_AdvertFinished(Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	
	if (!IsValidClient(iClient)) {
		return Plugin_Stop;
	}
	
	if (!g_bAdvertPlaying[iClient]) {
		ShowVGUIPanelEx(iClient, "Adverts Finished", "about:blank", _, _, false, _, false);
		NullifyTimer(iClient, g_hFinishedTimer[iClient], g_hFinishedTimer[iClient] != hTimer);
		return Plugin_Stop;
	}
	
	g_bCacheBusted[iClient] = false;
	g_bAdvertPlaying[iClient] = false;
	
	if (g_bMessages) {
		CPrintToChat(iClient, "%s%t", PREFIX, "Advert Finished");
	}
	
	if (g_bRadioResumation && !StrEqual(g_szResumeUrl[iClient], "about:blank", false) && !StrEqual(g_szResumeUrl[iClient], "", false)) {
		ShowVGUIPanelEx(iClient, "Radio Resumation", g_szResumeUrl[iClient], _, _, false, _, false);
	} else {
		strcopy(g_szResumeUrl[iClient], 128, "about:blank");
	}
	
	RequestFrame(Frame_AdvertFinishedForward, iUserId);
	NullifyTimer(iClient, g_hFinishedTimer[iClient], false);
	
	return Plugin_Stop;
}

public Action OldCvarFound(int iArgs)
{
	if (iArgs != 1) {
		return Plugin_Handled;
	}
	
	char szCvarName[64]; GetCmdArg(0, szCvarName, sizeof(szCvarName));
	
	VPP_Log(true, "\n\nHey, it looks like your config is outdated, Please consider having a look at the information below and update your config.\n");
	
	if (StrEqual(szCvarName, "sm_vpp_immunity", false)) {
		VPP_Log(true, "======================[sm_vpp_immunity]======================");
		VPP_Log(true, "sm_vpp_immunity has changed to sm_vpp_immunity_enabled, and the overrides system is now being used.");
		VPP_Log(true, "Users with access to 'advertisement_immunity' are now immune to ads when sm_vpp_immunity_enabled is set to 1.\n");
	} else if (StrEqual(szCvarName, "sm_vpp_ad_grace", false)) {
		VPP_Log(true, "======================[sm_vpp_ad_grace]======================");
		VPP_Log(true, "sm_vpp_ad_grace no longer exists and the cvar is now unused.");
		VPP_Log(true, "You can simply use the other cvars to control when how often ads are played, But a 3 min cooldown between each ad is always enforced.\n");
	} else if (StrEqual(szCvarName, "sm_vpp_every_x_deaths", false)) {
		VPP_Log(true, "======================[sm_vpp_every_x_deaths]======================");
		VPP_Log(true, "sm_vpp_every_x_deaths no longer exists and the cvar is now unused.");
		VPP_Log(true, "Please use sm_vpp_ad_period to control how often adverts play, and set sm_vpp_wait_until_dead 1 if you want to prevent ads being displayed to alive players.\n");
	} else if (StrEqual(szCvarName, "sm_vpp_onjoin_type", false)) {
		VPP_Log(true, "======================[sm_vpp_onjoin_type]======================");
		VPP_Log(true, "sm_vpp_onjoin_type no longer exists and the cvar is now unused.");
		VPP_Log(true, "All issues with initial motd should now be resolved.\n");
	}
	
	VPP_Log(true, "After you have acknowledged the above message(s) and updated your config, you may completely remove the ConVars from your config file to prevent this error appearing.");
	return Plugin_Handled;
}

public void OnCvarChanged(ConVar hConVar, const char[] szOldValue, const char[] szNewValue)
{
	if (hConVar == g_hVPPUrl) {
		strcopy(g_szVPPUrl, sizeof(g_szVPPUrl), szNewValue);
		TrimString(g_szVPPUrl); StripQuotes(g_szVPPUrl);
	} else if (hConVar == g_hCvarJoinGame) {
		g_bJoinAdverts = view_as<bool>(StringToInt(szNewValue));
	} else if (hConVar == g_hCvarPhaseAds) {
		g_bPhaseAds = view_as<bool>(StringToInt(szNewValue));
	} else if (hConVar == g_hCvarAdvertPeriod) {
		g_fAdvertPeriod = StringToFloat(szNewValue);
		
		if (g_fAdvertPeriod > 0.0 && g_fAdvertPeriod < 3.0) {
			g_fAdvertPeriod = 3.0;
			g_hCvarAdvertPeriod.IntValue = 3;
		}
	}
	else if (hConVar == g_hCvarAdvertTotal) {
		g_iAdvertTotal = StringToInt(szNewValue);
	} else if (hConVar == g_hCvarImmunityEnabled) {
		g_bImmunityEnabled = view_as<bool>(StringToInt(szNewValue));
	} else if (hConVar == g_hCvarSpecAdvertPeriod) {
		g_fSpecAdvertPeriod = StringToFloat(szNewValue);
		
		if (g_fSpecAdvertPeriod < 3.0 && g_fSpecAdvertPeriod > 0.0) {
			g_fSpecAdvertPeriod = 3.0;
			g_hCvarSpecAdvertPeriod.IntValue = 3;
		}
	} else if (hConVar == g_hCvarRadioResumation) {
		g_bRadioResumation = view_as<bool>(StringToInt(szNewValue));
	} else if (hConVar == g_hCvarWaitUntilDead) {
		g_bWaitUntilDead = view_as<bool>(StringToInt(szNewValue));
	} else if (hConVar == g_hCvarMessages) {
		g_bMessages = view_as<bool>(StringToInt(szNewValue));
	} else if (hConVar == g_hCvarMotdCheck) {
		g_iMotdAction = StringToInt(szNewValue);
	} else if (hConVar == g_hCvarDisableMotd) {
		if (StringToInt(szNewValue) != 0) {
			g_hCvarDisableMotd.IntValue = 0;
		}
	} else if (hConVar == g_hCvarUnloadOnDismissal) {
		if (StringToInt(szNewValue) != 0) {
			g_hCvarUnloadOnDismissal.IntValue = 0;
		}
	}
}

public void UpdateConVars()
{
	g_bJoinAdverts = g_hCvarJoinGame.BoolValue;
	g_bPhaseAds = g_hCvarPhaseAds.BoolValue;
	g_bImmunityEnabled = g_hCvarImmunityEnabled.BoolValue;
	g_bRadioResumation = g_hCvarRadioResumation.BoolValue;
	g_bWaitUntilDead = g_hCvarWaitUntilDead.BoolValue;
	g_bMessages = g_hCvarMessages.BoolValue;
	g_iMotdAction = g_hCvarMotdCheck.IntValue;
	
	g_fAdvertPeriod = g_hCvarAdvertPeriod.FloatValue;
	g_fSpecAdvertPeriod = g_hCvarSpecAdvertPeriod.FloatValue;
	
	if (g_fAdvertPeriod > 0.0 && g_fAdvertPeriod < 3.0) {
		g_fAdvertPeriod = 3.0;
		g_hCvarAdvertPeriod.IntValue = 3;
	}
	
	if (g_fSpecAdvertPeriod < 3.0 && g_fSpecAdvertPeriod > 0.0) {
		g_fSpecAdvertPeriod = 3.0;
		g_hCvarSpecAdvertPeriod.IntValue = 3;
	}
	
	g_iAdvertTotal = g_hCvarAdvertTotal.IntValue;
	
	g_hVPPUrl.GetString(g_szVPPUrl, sizeof(g_szVPPUrl));
	TrimString(g_szVPPUrl); StripQuotes(g_szVPPUrl);
	
	if (g_hCvarDisableMotd == null) {
		g_hCvarDisableMotd = FindConVar("sv_disable_motd");
	}
	
	if (g_hCvarDisableMotd != null) {
		g_hCvarDisableMotd.AddChangeHook(OnCvarChanged);
		g_hCvarDisableMotd.IntValue = 0;
	}
	
	if (g_hCvarUnloadOnDismissal == null) {
		g_hCvarUnloadOnDismissal = FindConVar("sv_motd_unload_on_dismissal");
	}
	
	if (g_hCvarUnloadOnDismissal != null) {
		g_hCvarUnloadOnDismissal.AddChangeHook(OnCvarChanged);
		g_hCvarUnloadOnDismissal.IntValue = 0;
	}
}

public int VersionRecieved(any aData, const char[] szBuffer, bool bSuccess)
{
	if (!bSuccess) {
		g_bUpdating = false;
		return;
	}
	
	KeyValues kKV = new KeyValues("Updater");
	
	if (!kKV.ImportFromString(szBuffer, "VersionTracker")) {
		g_bUpdating = false;
		delete kKV;
		return;
	}
	
	if (!kKV.JumpToKey("Information")) {
		g_bUpdating = false;
		delete kKV;
		return;
	}
	
	if (!kKV.JumpToKey("Version")) {
		g_bUpdating = false;
		delete kKV;
		return;
	}
	
	char szLatest[10]; kKV.GetString("Latest", szLatest, 10, "null");
	char szCurrent[10]; Format(szCurrent, 10, "%s", PL_VERSION);
	
	if (StrEqual(szLatest, "null", false)) {
		g_bUpdating = false;
		delete kKV;
		return;
	}
	
	char szBuffer2[256];
	strcopy(szBuffer2, sizeof(szBuffer2), szLatest); ReplaceString(szBuffer2, sizeof(szBuffer2), ".", "", false); int iLatest = StringToInt(szBuffer2);
	strcopy(szBuffer2, sizeof(szBuffer2), szCurrent); ReplaceString(szBuffer2, sizeof(szBuffer2), ".", "", false); int iCurrent = StringToInt(szBuffer2);
	
	if (iLatest > iCurrent) {
		char szPath[64]; GetPluginFilename(INVALID_HANDLE, szPath, sizeof(szPath));
		
		if (BuildPath(Path_SM, szPath, sizeof(szPath), "plugins/%s", szPath)) {
			VPP_Log(false, "Update available Current: %s - Latest: %s", szCurrent, szLatest, szPath);
			kKV.GoBack(); int iPatch = 0;
			DataPack dPack = new DataPack(); dPack.WriteString(szLatest); dPack.Reset();
			
			do {
				Format(szBuffer2, sizeof(szBuffer2), "%d", iPatch);
				
				kKV.GetString(szBuffer2, szBuffer2, sizeof(szBuffer2), "null");
				
				if (StrEqual(szBuffer2, "null", false)) {
					break;
				}
				
				VPP_Log(false, "[%d]  %s", iPatch++, szBuffer2);
			} while (!StrEqual(szBuffer2, "null", false));
			
			if (!EasyHTTP("https://raw.githubusercontent.com/VPPGamingNetwork/vppgn-sourcemod/master/addons/sourcemod/plugins/vpp_adverts.smx", GET, null, UpdateRecieved, dPack, szPath)) {
				g_bUpdating = false;
				VPP_Log(false, "Error downloading update, Please update manually.");
				delete dPack;
				delete kKV;
			}
		}
	} else {
		g_bUpdating = false;
	}
	
	delete kKV;
}

public int UpdateRecieved(DataPack dPack, const char[] szBuffer, bool bSuccess)
{
	if (!bSuccess) {
		g_bUpdating = false;
		VPP_Log(false, "Error downloading update, Please update manually.");
		return;
	}
	
	char szFileName[64]; GetPluginFilename(INVALID_HANDLE, szFileName, sizeof(szFileName));
	char szVersion[10]; dPack.Reset(); dPack.ReadString(szVersion, sizeof(szVersion));
	delete dPack;
	
	VPP_Log(false, "Successfully updated and installed version %s.", szVersion);
	g_bUpdating = false;
	
	ServerCommand("sm plugins reload %s", szFileName);
}

public Action JoinGame_Listener(int iClient, const char[] szCommand, int iArgs)
{
	g_bGameJoined[iClient] = true;
	
	if (!g_bAdRequeue[iClient]) {
		return;
	}
	
	SendAdvert(iClient);
}

public Action Command_Reload(int iClient, int iArgs)
{
	CReplyToCommand(iClient, "%s%t", PREFIX, "Radios Loaded", LoadRadioStations());
	return Plugin_Handled;
}

public void CreateMotdMenu()
{
	if (g_mMenuWarning != null) {
		return;
	}
	
	char szBuffer[128];
	
	g_mMenuWarning = new Menu(MenuHandler);
	
	Format(szBuffer, sizeof(szBuffer), "%t", "Menu_Title");
	
	g_mMenuWarning.SetTitle(szBuffer);
	g_mMenuWarning.Pagination = MENU_NO_PAGINATION;
	g_mMenuWarning.ExitBackButton = false;
	g_mMenuWarning.ExitButton = false;
	
	Format(szBuffer, sizeof(szBuffer), "%t", "Menu_Phrase_0");
	g_mMenuWarning.AddItem("", szBuffer, ITEMDRAW_DISABLED);
	
	Format(szBuffer, sizeof(szBuffer), "%t", "Menu_Phrase_1");
	g_mMenuWarning.AddItem("", szBuffer, ITEMDRAW_DISABLED);
	
	Format(szBuffer, sizeof(szBuffer), "%t", "Menu_Phrase_2");
	g_mMenuWarning.AddItem("", szBuffer, ITEMDRAW_DISABLED);
	
	Format(szBuffer, sizeof(szBuffer), "%t", "Menu_Phrase_Exit");
	g_mMenuWarning.AddItem("0", szBuffer);
}

public int Native_IsAdvertPlaying(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	
	return g_bAdvertPlaying[iClient];
}

public int Native_PlayAdvert(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	
	return SendAdvert(iClient);
}

stock bool GetVGUIInfo(int iClient, Handle hMsg, char szKey[256], char szUrl[256], char szTitle[256], int & iWidth, int & iHeight, bool & bCacheBuster_Pre, bool & bShow, bool & bCustomSvr)
{
	if (g_bProtoBuf) {
		PbReadString(hMsg, "name", szKey, sizeof(szKey));
	} else {
		BfReadString(hMsg, szKey, sizeof(szKey));
	}
	
	if (g_iMotdOccurence[iClient] == 2 && g_bProtoBuf && StrEqual(szKey, "team") && g_bAdvertPlaying[iClient] && g_bJoinAdverts) {
		g_bAdvertPlaying[iClient] = false;
		
		NullifyTimer(iClient, g_hFinishedTimer[iClient], true);
		return false;
	}
	
	if (!StrEqual(szKey, "info")) {
		return false;
	}
	
	bool bUrlFound = false;
	
	bShow = g_bProtoBuf ? PbReadBool(hMsg, "show") : view_as<bool>(BfReadByte(hMsg));
	
	Handle hSubKey = null;
	
	int iKeyCount = g_bProtoBuf ? PbGetRepeatedFieldCount(hMsg, "subkeys") : BfGetNumBytesLeft(hMsg);
	
	for (int i = 0; i < iKeyCount; i++) {
		if (g_bProtoBuf) {
			hSubKey = PbReadRepeatedMessage(hMsg, "subkeys", i);
			PbReadString(hSubKey, "name", szKey, sizeof(szKey));
		} else {
			BfReadString(hMsg, szKey, sizeof(szKey));
		}
		
		if (StrContains(szKey, "msg", false) != -1) {
			if (g_bProtoBuf) {
				PbReadString(hSubKey, "str", szUrl, sizeof(szUrl));
			} else {
				BfReadString(hMsg, szUrl, sizeof(szUrl));
			}
			
			bUrlFound = true;
		} else if (StrContains(szKey, "title", false) != -1) {
			if (g_bProtoBuf) {
				PbReadString(hSubKey, "str", szTitle, sizeof(szTitle));
			} else {
				BfReadString(hMsg, szTitle, sizeof(szTitle));
			}
		} else if (StrContains(szKey, "cachebuster", false) != -1) {
			char szResult[10];
			
			if (g_bProtoBuf) {
				PbReadString(hSubKey, "str", szResult, sizeof(szResult));
			} else {
				BfReadString(hMsg, szResult, sizeof(szResult));
			}
			
			bCacheBuster_Pre = StrContains(szResult, "true", false) != -1;
		} else if (StrContains(szKey, "x-vgui-width", false) != -1) {
			char szResult[10];
			
			if (g_bProtoBuf) {
				PbReadString(hSubKey, "str", szResult, sizeof(szResult));
			} else {
				BfReadString(hMsg, szResult, sizeof(szResult));
			}
			
			iWidth = StringToInt(szResult);
		} else if (StrContains(szKey, "x-vgui-height", false) != -1) {
			char szResult[10];
			
			if (g_bProtoBuf) {
				PbReadString(hSubKey, "str", szResult, sizeof(szResult));
			} else {
				BfReadString(hMsg, szResult, sizeof(szResult));
			}
			
			iHeight = StringToInt(szResult);
		} else if (StrContains(szKey, "customsvr", false) != -1) {
			char szResult[10];
			
			if (g_bProtoBuf) {
				PbReadString(hSubKey, "str", szResult, sizeof(szResult));
			} else {
				BfReadString(hMsg, szResult, sizeof(szResult));
			}
			
			bCustomSvr = view_as<bool>(StringToInt(szResult));
		}
	}
	
	return bUrlFound;
}

stock void ClearTimers(int iClient, Handle hCurrentTimer, bool bDelete = true, bool bFinishedTimer = false)
{
	if (hCurrentTimer != g_hSpecTimer[iClient]) {
		NullifyTimer(iClient, g_hSpecTimer[iClient], bDelete);
	}
	
	if (hCurrentTimer != g_hPeriodicTimer[iClient]) {
		NullifyTimer(iClient, g_hPeriodicTimer[iClient], bDelete);
	}
	
	if (hCurrentTimer != g_hQueueTimer[iClient]) {
		NullifyTimer(iClient, g_hQueueTimer[iClient], bDelete);
	}
	
	if (hCurrentTimer != g_hFinishedTimer[iClient] && bFinishedTimer) {
		NullifyTimer(iClient, g_hFinishedTimer[iClient], bDelete);
	}
}

stock void NullifyTimer(int iClient, Handle hTimer, bool bDelete)
{
	if (bDelete && !IsValidHandle(hTimer)) {
		bDelete = false;
	}
	
	if (hTimer == g_hSpecTimer[iClient]) {
		if (bDelete) {
			delete g_hSpecTimer[iClient];
		}
		
		g_hSpecTimer[iClient] = null;
	} else if (hTimer == g_hPeriodicTimer[iClient]) {
		if (bDelete) {
			delete g_hPeriodicTimer[iClient];
		}
		
		g_hPeriodicTimer[iClient] = null;
	} else if (hTimer == g_hQueueTimer[iClient]) {
		if (bDelete) {
			delete g_hQueueTimer[iClient];
		}
		
		g_hQueueTimer[iClient] = null;
	} else if (hTimer == g_hFinishedTimer[iClient]) {
		if (bDelete) {
			delete g_hFinishedTimer[iClient];
		}
		
		g_hFinishedTimer[iClient] = null;
	}
}

stock bool ShowVGUIPanelEx(int iClient, const char[] szTitle, char szUrl[256], int iType = MOTDPANEL_TYPE_URL, int iFlags = 0, bool bShow = true, Handle hMsg = null, bool bAdvert = true, int iWidth = 0, int iHeight = 0, bool bCustomSvr = false)
{
	if (g_bMotdDisabled[iClient]) {
		return false;
	}
	
	bool bOverride = hMsg != null && g_bProtoBuf;
	int iTeam = GetClientTeam(iClient);
	int iClass = 0;
	
	bool bMotd; bool bCacheBuster; bool bAboutBlank; bool bRadio;
	
	if (StrEqual(szUrl, "motd") || StrEqual(szUrl, "motd_text")) {
		bMotd = true;
	} else if (StrContains(szUrl, g_szVPPUrl, false) != -1) {
		bAdvert = true;
	} else if (StrContains(szUrl, "http://vppgaming.network/cachebuster/", false) != -1) {
		bCacheBuster = true;
	} else if (StrEqual(szUrl, "about:blank", false)) {
		bAboutBlank = true;
	} else if (IsRadio(szUrl)) {
		bRadio = true;
	}
	
	if (bCacheBuster || bMotd || bAboutBlank || bRadio) {
		bAdvert = false;
	}
	
	if (g_bHasClasses) {
		iClass = GetEntProp(iClient, Prop_Send, "m_iClass");
	}
	
	if ((iTeam < 1 || (g_bHasClasses && iClass <= 0 && iTeam > 1)) && g_eGame != eGameNMRIH) {
		if (!g_bFirstMotd[iClient] || (g_bFirstMotd[iClient] && !g_bJoinAdverts)) {
			return false;
		}
		
		if (g_bProtoBuf && !bOverride) {
			return false;
		}
	}
	
	if (bAdvert) {
		if (AdShouldWait(iClient) || HasClientFinishedAds(iClient) || IsClientImmune(iClient)) {
			return false;
		}
		
		if (g_bAdRequeue[iClient] && IsPlayerAlive(iClient)) {
			bShow = false;
		}
	}
	
	if (g_bFirstMotd[iClient] && g_bForceJoinGame && !g_bGameJoined[iClient]) {
		FakeClientCommandEx(iClient, "joingame");
	}
	
	if (bCacheBuster || bOverride || bRadio || bAboutBlank) {
		bShow = false;
	}
	
	KeyValues hKv = new KeyValues("data");
	
	hKv.SetString("title", szTitle);
	hKv.SetNum("type", iType);
	hKv.SetString("msg", szUrl);
	
	if (g_eGame == eGameCSGO || g_eGame == eGameCSCO) {
		hKv.SetString("cmd", "1");
	} else {
		hKv.SetNum("cmd", 5);
	}
	
	hKv.SetNum("x-vgui-width", iWidth);
	hKv.SetNum("x-vgui-height", iHeight);
	hKv.SetNum("customsvr", bCustomSvr);
	
	hKv.GotoFirstSubKey(false);
	iFlags &= ~USERMSG_BLOCKHOOKS;
	
	if (!bOverride) {
		hMsg = StartMessageOne("VGUIMenu", iClient, iFlags);
	}
	
	char szKey[256]; char szValue[256];
	
	if (g_bProtoBuf) {
		if (!bOverride) {
			PbSetString(hMsg, "name", "info");
			PbSetBool(hMsg, "show", bShow);
		}
		
		Handle hSubKey;
		
		do {
			hKv.GetSectionName(szKey, sizeof(szKey));
			hKv.GetString(NULL_STRING, szValue, sizeof(szValue), "");
			
			hSubKey = PbAddMessage(hMsg, "subkeys");
			
			PbSetString(hSubKey, "name", szKey);
			PbSetString(hSubKey, "str", szValue);
			
		} while (hKv.GotoNextKey(false));
		
	} else {
		BfWriteString(hMsg, "info");
		BfWriteByte(hMsg, bShow);
		
		int iKeyCount = 0;
		
		do {
			++iKeyCount;
		} while (hKv.GotoNextKey(false));
		
		BfWriteByte(hMsg, iKeyCount);
		
		if (iKeyCount > 0) {
			hKv.GoBack(); hKv.GotoFirstSubKey(false);
			do {
				hKv.GetSectionName(szKey, sizeof(szKey));
				hKv.GetString(NULL_STRING, szValue, sizeof(szValue), "");
				
				BfWriteString(hMsg, szKey);
				BfWriteString(hMsg, szValue);
			} while (hKv.GotoNextKey(false));
		}
	}
	
	if (!bOverride) {
		EndMessage();
	}
	
	delete hKv;
	
	if (!bCacheBuster && !bMotd) {
		g_bFirstMotd[iClient] = false;
	}
	
	return true;
}

stock bool IsValidClient(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients) {
		return false;
	}
	
	if (!IsClientInGame(iClient)) {
		return false;
	}
	
	if (IsFakeClient(iClient)) {
		return false;
	}
	
	return true;
}

stock bool IsClientImmune(int iClient)
{
	if (!IsValidClient(iClient)) {
		return true;
	}
	
	if (!g_bImmunityEnabled) {
		return false;
	}
	
	return CheckCommandAccess(iClient, "advertisement_immunity", ADMFLAG_RESERVATION);
}

stock bool CheckGameSpecificConditions()
{
	if (g_eVersion == Engine_CSGO) {
		if (GameRules_GetProp("m_bWarmupPeriod") == 1) {
			return true;
		}
	}
	
	return false;
}

stock bool AdShouldWait(int iClient)
{
	char szAuthId[64];
	
	if (!IsClientAuthorized(iClient) || !GetClientAuthId(iClient, AuthId_Steam2, szAuthId, sizeof(szAuthId), true) || StrContains(szAuthId, ":", false) == -1) {
		return true;
	}
	
	if (g_hFinishedTimer[iClient] != null) {
		return true;
	}
	
	int iTeam = GetClientTeam(iClient);
	int iClass = 0;
	
	if (g_bHasClasses) {
		iClass = GetEntProp(iClient, Prop_Send, "m_iClass");
	}
	
	if ((iTeam < 1 || (g_bHasClasses && iClass <= 0 && iTeam > 1)) && g_eGame != eGameNMRIH) {
		if (!g_bFirstMotd[iClient] || (g_bFirstMotd[iClient] && !g_bJoinAdverts)) {
			return true;
		}
	}
	
	if (g_bAdvertPlaying[iClient] || g_hFinishedTimer[iClient] != null || (g_iLastAdvertTime[iClient] > 0 && GetTime() - g_iLastAdvertTime[iClient] < 180)) {
		return true;
	}
	
	if (g_bWaitUntilDead && IsPlayerAlive(iClient) && (iTeam > 1 || g_eGame == eGameNMRIH) && (!g_bPhase && !g_bFirstMotd[iClient] && !g_bAdRequeue[iClient] && !CheckGameSpecificConditions())) {
		return true;
	}
	
	return false;
}

stock bool HasClientFinishedAds(int iClient)
{
	if (g_iAdvertTotal > 0 && !g_bFirstMotd[iClient] && g_iAdvertRequests[iClient] >= g_iAdvertTotal) {
		return true;
	}
	
	if (g_iAdvertTotal <= -1 && !g_bFirstMotd[iClient]) {
		return true;
	}
	
	if (!g_bFirstMotd[iClient] && g_fAdvertPeriod <= 0.0) {
		return true;
	}
	
	return false;
}

stock void GetServerIP()
{
	bool bGotIP = false;
	
	CheckExtensions();
	
	if (g_bSteamWorks || g_bSteamTools) {
		int iSIP[4];
		
		if (g_bSteamWorks) {
			SteamWorks_GetPublicIP(iSIP);
		} else if (g_bSteamTools) {
			Steam_GetPublicIP(iSIP);
		}
		
		Format(g_szServerIP, sizeof(g_szServerIP), "%d.%d.%d.%d", iSIP[0], iSIP[1], iSIP[2], iSIP[3]);
		
		if (!IsIPLocal(IPToLong(g_szServerIP))) {
			bGotIP = true;
		} else {
			strcopy(g_szServerIP, sizeof(g_szServerIP), "");
			bGotIP = false;
		}
	}
	
	if (!bGotIP) {
		ConVar hCvarIP = FindConVar("hostip");
		
		if (hCvarIP != null) {
			int iServerIP = hCvarIP.IntValue; bGotIP = !IsIPLocal(iServerIP);
			
			if (bGotIP) {
				Format(g_szServerIP, sizeof(g_szServerIP), "%d.%d.%d.%d", iServerIP >>> 24 & 255, iServerIP >>> 16 & 255, iServerIP >>> 8 & 255, iServerIP & 255);
			}
		}
	}
	
	if (!bGotIP) {
		VPP_FailState("There was an error fetching your server IP, the plugin has been disabled, please contact us for support!");
	}
	
	ConVar hCvarPort = FindConVar("hostport");
	
	if (hCvarPort != null) {
		g_iPort = hCvarPort.IntValue;
	}
}

stock bool FormatAdvertUrl(int iClient, char[] szInput, char[] szOutput)
{
	if (StrEqual(g_szVPPUrl, "", false)) {
		return false;
	}
	
	TrimString(g_szVPPUrl); StripQuotes(g_szVPPUrl);
	
	return strcopy(szOutput, 256, szInput) > 0;
}

stock bool IsRadio(const char[] szUrl)
{
	if (!g_bRadioResumation) {
		return false;
	}
	
	char szBuffer[256];
	
	for (int i = 0; i < g_alRadioStations.Length; i++) {
		g_alRadioStations.GetString(i, szBuffer, sizeof(szBuffer));
		
		if (StrContains(szUrl, szBuffer, false) == -1) {
			continue;
		}
		
		return true;
	}
	
	return false;
}

stock int IPToLong(const char[] szIP)
{
	char szPieces[4][4];
	
	if (ExplodeString(szIP, ".", szPieces, sizeof(szPieces), sizeof(szPieces[])) != 4) {
		return 0;
	}
	
	return (StringToInt(szPieces[0]) << 24 | StringToInt(szPieces[1]) << 16 | StringToInt(szPieces[2]) << 8 | StringToInt(szPieces[3]));
}

stock bool IsIPLocal(int iIP)
{
	if (167772160 <= iIP <= 184549375 || 2886729728 <= iIP <= 2887778303 || 3232235520 <= iIP <= 3232301055) {
		return true;
	}
	
	return false;
}

stock int LoadRadioStations()
{
	if (g_alRadioStations != null) {
		g_alRadioStations.Clear();
	} else {
		g_alRadioStations = new ArrayList(256);
	}
	
	LoadThirdPartyRadioStations();
	LoadPresetRadioStations();
	
	int iLoaded = g_alRadioStations.Length;
	
	VPP_Log(false, "%t", "Radios Loaded", iLoaded);
	
	return iLoaded;
}

stock bool SendAdvert(int iClient)
{
	if (HasClientFinishedAds(iClient) || g_hQueueTimer[iClient] != null) {
		return false;
	}
	
	DataPack dPack = new DataPack();
	dPack.WriteCell(GetClientUserId(iClient));
	dPack.WriteCell(true);
	
	if (QueryClientConVar(iClient, "cl_disablehtmlmotd", Query_MotdPlayAd, dPack) == QUERYCOOKIE_FAILED) {
		g_bAdRequeue[iClient] = true;
		delete dPack;
		return false;
	}
	
	return !g_bMotdDisabled[iClient];
}

stock void LoadPresetRadioStations()
{
	char szPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/vpp_adverts_radios.txt");
	
	if (!FileExists(szPath)) {
		return;
	}
	
	KeyValues hKv = new KeyValues("Radio Stations");
	
	if (!hKv.ImportFromFile(szPath)) {
		return;
	}
	
	hKv.GotoFirstSubKey();
	
	char szBuffer[256];
	do {
		hKv.GetString("url", szBuffer, sizeof(szBuffer));
		
		TrimString(szBuffer); StripQuotes(szBuffer); ReplaceString(szBuffer, sizeof(szBuffer), ";", "");
		
		if (g_alRadioStations.FindString(szBuffer) != -1) {
			continue;
		}
		
		g_alRadioStations.PushString(szBuffer);
		
	} while (hKv.GotoNextKey());
	
	delete hKv;
}

stock void LoadThirdPartyRadioStations()
{
	char szPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/radiovolume.txt");
	
	if (FileExists(szPath)) {
		KeyValues hKv = new KeyValues("Radio Stations");
		
		if (hKv.ImportFromFile(szPath)) {
			hKv.GotoFirstSubKey();
			
			char szBuffer[256];
			do {
				hKv.GetString("Stream URL", szBuffer, sizeof(szBuffer));
				
				TrimString(szBuffer); StripQuotes(szBuffer); ReplaceString(szBuffer, sizeof(szBuffer), ";", "");
				
				if (g_alRadioStations.FindString(szBuffer) != -1) {
					continue;
				}
				
				g_alRadioStations.PushString(szBuffer);
				
			} while (hKv.GotoNextKey());
			
			delete hKv;
		}
	}
	
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/vpp_adverts_radios_custom.txt");
	
	if (FileExists(szPath)) {
		KeyValues hKv = new KeyValues("Radio Stations");
		
		if (hKv.ImportFromFile(szPath)) {
			hKv.GotoFirstSubKey();
			
			char szBuffer[256];
			do {
				hKv.GetString("url", szBuffer, sizeof(szBuffer));
				
				TrimString(szBuffer); StripQuotes(szBuffer); ReplaceString(szBuffer, sizeof(szBuffer), ";", "");
				
				if (g_alRadioStations.FindString(szBuffer) != -1) {
					continue;
				}
				
				g_alRadioStations.PushString(szBuffer);
				
			} while (hKv.GotoNextKey());
			
			delete hKv;
		}
	}
}

stock void CheckForUpdates()
{
	if (g_bUpdating) {
		return;
	}
	
	g_bUpdating = EasyHTTP(UPDATE_URL, GET, INVALID_HANDLE, VersionRecieved, _);
}

stock void CheckForConflictingPlugins()
{
	if (FindPluginByFile("vgui_cache_buster.smx") != null) {
		VPP_Log(true, "Plugin vgui_cache_buster.smx will break things completely, we have implemented our own cache buster which replaces this plugin, please remove it.");
	}
}

stock void VPP_Log(bool bError = false, const char[] szMessage, any...)
{
	char szBuffer[512]; VFormat(szBuffer, sizeof(szBuffer), szMessage, 3);
	LogToFile(g_szLogFile, szBuffer);
	
	if (bError) {
		LogError(szBuffer);
	}
}

stock void VPP_FailState(const char[] szMessage, any...)
{
	char szBuffer[512]; VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
	LogToFile(g_szLogFile, szBuffer);
	SetFailState(szBuffer);
}

stock void CheckExtensions()
{
	EasyHTTPCheckExtensions();
	
	if (!g_bSteamWorks && !g_bCURL && !g_bSockets && !g_bSteamTools) {
		VPP_FailState("\nThis plugin requires ATLEAST ONE of these extensions installed:\n\
			SteamWorks - https://forums.alliedmods.net/showthread.php?t=229556\n\
			SteamTools - http://forums.alliedmods.net/showthread.php?t=129763\n\
			cURL - http://forums.alliedmods.net/showthread.php?t=152216\n\
			Socket - http://forums.alliedmods.net/showthread.php?t=67640");
	}
}

// Credits https://forums.alliedmods.net/showpost.php?p=2112007&postcount=9
stock void ClearMotd(DataPack dPack)
{
	if (dPack == null) {
		return;
	}
	
	dPack.Reset();
	
	int iUserId = dPack.ReadCell();
	int iClient = GetClientOfUserId(iUserId);
	bool bCacheBuster = view_as<bool>(dPack.ReadCell());
	delete dPack;
	
	if (!IsValidClient(iClient)) {
		return;
	}
	
	if (g_bAdvertPlaying[iClient]) {
		return;
	}
	
	if (g_bAdvertCleared[iClient] && !bCacheBuster) {
		return;
	}
	
	Handle hMsg = StartMessageOne("VGUIMenu", iClient);
	
	if (hMsg == null) {
		if (bCacheBuster) {
			Timer_SendCacheBuster(null, iUserId);
		}
		return;
	}
	
	if (g_bProtoBuf) {
		PbSetString(hMsg, "name", "info");
		PbSetBool(hMsg, "show", false);
		
		Handle hSubKey;
		
		hSubKey = PbAddMessage(hMsg, "subkeys");
		
		PbSetString(hSubKey, "name", "title");
		PbSetString(hSubKey, "str", "Clear Motd");
		
		hSubKey = PbAddMessage(hMsg, "subkeys");
		
		PbSetString(hSubKey, "name", "type");
		PbSetString(hSubKey, "str", "0");
		
		hSubKey = PbAddMessage(hMsg, "subkeys");
		
		PbSetString(hSubKey, "name", "msg");
		PbSetString(hSubKey, "str", "");
		
		hSubKey = PbAddMessage(hMsg, "subkeys");
		
		PbSetString(hSubKey, "name", "cachebuster");
		PbSetString(hSubKey, "str", bCacheBuster ? "true" : "false");
	} else {
		BfWriteString(hMsg, "info");
		BfWriteByte(hMsg, false);
		BfWriteByte(hMsg, 4);
		
		BfWriteString(hMsg, "title");
		BfWriteString(hMsg, "Clear Motd");
		
		BfWriteString(hMsg, "type");
		BfWriteString(hMsg, "");
		
		BfWriteString(hMsg, "msg");
		BfWriteString(hMsg, "");
		
		BfWriteString(hMsg, "cachebuster");
		BfWriteString(hMsg, bCacheBuster ? "true" : "false");
	}
	
	EndMessage();
}

public int MenuHandler(Menu mMenu, MenuAction maAction, int iParam1, int iParam2) {  } 