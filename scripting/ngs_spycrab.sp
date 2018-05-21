/**
* TheXeon
* ngs_spycrab.sp
*
* Files:
* addons/sourcemod/plugins/ngs_spycrab.smx
* addons/sourcemod/configs/crablocations.cfg
*
* Dependencies:
* clientprefs.inc, sdkhooks.inc, adminmenu.inc, multicolors.inc,
* tf2.inc, tf2_stocks.inc, ngsutils.inc, ngsupdater.inc, basecomm.inc,
* sourcecomms.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define LIBRARY_ADDED_FUNC LibraryAdded
#define LIBRARY_REMOVED_FUNC LibraryRemoved
#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <clientprefs>
#include <sdkhooks>
#include <adminmenu>
#include <multicolors>
#include <tf2>
#include <tf2_stocks>
#include <ngsutils>
#include <ngsupdater>

#undef REQUIRE_PLUGIN
#include <basecomm>
#include <sourcecomms>
#define REQUIRE_PLUGIN

// Obviously inspired by Erreur 500
enum CrabData
{
	Challenger,
	bool:IsEnabled,
	TimesCrabbed,
	SMTimer:MovementTimer,
	SMTimer:TauntTimer,
	TimesTaunted,
	UserId,
	TFTeam:Team,
	bool:IsFirstClient,
	bool:HasTaunted,
	CrabType:Type,
	Penalty,
}

enum CrabType
{
	Type_FirstToThreeWins,
	Type_FirstToThreeLoses
}

enum CrabStatus
{
	Status_Nothing,
	Status_IsCrabbing,
	Status_FinishedWinner,
	Status_FinishedLoser
}

int CrabCooldown[MAXPLAYERS + 1];
bool basecommExists, sourcecommsExists;

Cookie hideHudTextCookie;
ConVar mapNameContains;
KeyValues mapLocations;

bool spycrabInProgress, hideHudText[MAXPLAYERS + 1], crabRequestDisabled[MAXPLAYERS + 1];
int playerCrabData[MAXPLAYERS + 1][CrabData];
int hudTextChannel;
float firstClientOrigin[3], secondClientOrigin[3];

public Plugin myinfo = {
	name = "[NGS] Spycrab Suite",
	author = "TheXeon / EasyE",
	description = "Automate a spycrab with people.",
	version = "1.1.2",
	url = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_spycrab", CommandCrab, "Displays spycrab target menu.");
	RegConsoleCmd("sm_crab", CommandCrab, "Displays spycrab target menu.");
	RegConsoleCmd("sm_dontcrab", CommandDontCrab, "Disable receiving spycrab requests.");
	RegConsoleCmd("sm_nocrab", CommandDontCrab, "Disable receiving spycrab requests.");
	RegConsoleCmd("sm_hidecrab", CommandHideCrab, "Hide the on-screen display of text!");
	RegAdminCmd("sm_cancelcrab", CommandCancelCrab, ADMFLAG_GENERIC, "Cancels the spycrab.");
	RegAdminCmd("sm_reloadcrab", CommandReloadCrabConfig, ADMFLAG_GENERIC, "Reloads the map config file.");

	mapNameContains = CreateConVar("sm_spycrab_config_contains", "1", "Whether map names in config will be checked partially or fully.");
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("player_disconnect", OnPlayerDisconnect, EventHookMode_Pre);

	hideHudTextCookie = new Cookie("hidecrabtext", "Should we hide the crab text?", CookieAccess_Public);

	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidClient(iClient))
			OnClientPutInServer(iClient);

	if (GetEngineVersion() != Engine_TF2)
	{
		LogError("Attempting to run plugin on unsupported game!");
	}

	LoadConfig();
}

public void LibraryAdded(const char[] name)
{
	if (StrEqual(name, "basecomm", false))
	{
		basecommExists = true;
	}
	else if (StrEqual(name, "sourcecomms", false))
	{
		sourcecommsExists = true;
	}
}

public void LibraryRemoved(const char[] name)
{
	if (StrEqual(name, "basecomm", false))
	{
		basecommExists = false;
	}
	else if (StrEqual(name, "sourcecomms", false))
	{
		sourcecommsExists = false;
	}
}

public void OnClientPutInServer(int client)
{
	CrabCooldown[client] = 0;
	crabRequestDisabled[client] = false;
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientCookiesCached(int client)
{
	char sHideCookieValue[MAX_BUFFER_LENGTH];
	hideHudTextCookie.GetValue(client, sHideCookieValue, sizeof(sHideCookieValue));
	if (sHideCookieValue[0] != '\0' && StringToInt(sHideCookieValue) != 0)
	{
		hideHudText[client] = true;
	}
}

// Thank you Dr.Mckay and your CCC
public void LoadConfig()
{
	char configFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, configFile, sizeof(configFile), "configs/crablocations.cfg");
	if (!FileExists(configFile))
	{
		SetFailState("Missing config file (should be at %s)! Please get it from the repo!", configFile);
	}
	delete mapLocations;
	mapLocations = new KeyValues("Locations");
	if (!mapLocations.ImportFromFile(configFile))
	{
		SetFailState("Invalid config file at %s! Please fix it!", configFile);
	}
}

public void OnMapStart()
{
	char mapName[MAX_BUFFER_LENGTH];
	GetCurrentMap(mapName, sizeof(mapName));
	FindMapCoords(mapName);
}

void FindMapCoords(char[] mapName)
{
	firstClientOrigin = NULL_VECTOR;
	secondClientOrigin = NULL_VECTOR;
	char buffer[MAX_BUFFER_LENGTH];
	mapLocations.Rewind();
	if (!mapLocations.JumpToKey(mapName))
	{
		if (mapNameContains.BoolValue)
		{
			mapLocations.Rewind();
			mapLocations.GotoFirstSubKey();
			do
			{
				mapLocations.GetSectionName(buffer, sizeof(buffer));
				if (StrContains(mapName, buffer, false) != -1)
				{
					SetMapCoords(buffer);
					break;
				}
			}
			while (mapLocations.GotoNextKey());
		}
		else
		{
			LogError("Map %s is not in config file!", mapName);
		}
	}
	else
	{
		SetMapCoords(mapName);
	}
}

void SetMapCoords(char[] sectionName)
{
	char firstClientBuffer[MAX_BUFFER_LENGTH], secondClientBuffer[MAX_BUFFER_LENGTH],
		firstClientVector[3][MAX_BUFFER_LENGTH], secondClientVector[3][MAX_BUFFER_LENGTH];
	mapLocations.GetString("firstClient", firstClientBuffer, sizeof(firstClientBuffer));
	mapLocations.GetString("secondClient", secondClientBuffer, sizeof(secondClientBuffer));
	if (firstClientBuffer[0] != '\0' && secondClientBuffer[0] != '\0')
	{
		ExplodeString(firstClientBuffer, ",", firstClientVector, sizeof(firstClientVector), sizeof(firstClientVector[]));
		ExplodeString(secondClientBuffer, ",", secondClientVector, sizeof(secondClientVector), sizeof(secondClientVector[]));
		for (int i = 0; i < 3; i++)
		{
			firstClientOrigin[i] = StringToFloat(firstClientVector[i]);
			secondClientOrigin[i] = StringToFloat(secondClientVector[i]);
		}
	}
	else
	{
		LogError("Invalidly formatted location string in config file around Section \'%s\'. Make sure it is a comma separated 3d vector!", sectionName);
	}
}

public Action CommandDontCrab(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	crabRequestDisabled[client] = !crabRequestDisabled[client];
	CPrintToChat(client, "{GREEN}[Crab]{DEFAULT} You have {LIGHTGREEN}%s{DEFAULT} crab requests.", (crabRequestDisabled[client]) ? "disabled" : "enabled");
	return Plugin_Handled;
}

public Action CommandReloadCrabConfig(int client, int args)
{
	if (mapLocations == null)
	{
		CReplyToCommand(client, "The config file does not currently exist!");
	}
	else
	{
		char mapName[MAX_BUFFER_LENGTH];
		GetCurrentMap(mapName, sizeof(mapName));
		LoadConfig();
		FindMapCoords(mapName);
		CReplyToCommand(client, "Locations have been reloaded!");
	}
	return Plugin_Handled;
}

public Action CommandCrab(int client, int args)
{
	if (!IsValidClient(client, true)) return Plugin_Handled;
	if ((basecommExists && BaseComm_IsClientGagged(client)) || (sourcecommsExists && SourceComms_GetClientGagType(client) != bNot))
	{
		CPrintToChat(client, "{GREEN}[Crab]{DEFAULT} Sorry, you may not use Crab!");
		return Plugin_Handled;
	}
	int currentTime = GetTime();
	if (crabRequestDisabled[client])
	{
		CPrintToChat(client, "{GREEN}[Crab]{DEFAULT} You may not request crabs if requests are disabled. Use !dontcrab to reenable them!");
	}
	else if (currentTime - CrabCooldown[client] < 20)
	{
		CPrintToChat(client, "{GREEN}[Crab]{DEFAULT} You must wait {PURPLE}%d{DEFAULT} seconds to use this.", 20 - (currentTime - CrabCooldown[client]));
	}
	else if (spycrabInProgress)
	{
		CReplyToCommand(client, "{GREEN}[Crab]{DEFAULT} There is currently another spycrab happening.");
	}
	else if (firstClientOrigin[0] == NULL_VECTOR[0])
	{
		CReplyToCommand(client, "{GREEN}[Crab]{DEFAULT} The map is not configured for this plugin, notify an admin!");
	}
	else
	{
		CrabCooldown[client] = currentTime;
		Menu spycrabMenu = new Menu(SpycrabMenuHandler);
		spycrabMenu.SetTitle("Select a player:");
		AddTargetsToMenu(spycrabMenu, 0, true, true);
		spycrabMenu.Display(client, 20);
	}
	return Plugin_Handled;
}

public Action CommandHideCrab(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	hideHudTextCookie.SetValue(client, hideHudText[client] ? "0" : "1");
	hideHudText[client] = !hideHudText[client];
	CReplyToCommand(client, "{GREEN}[Crab]{DEFAULT} Crab info text has been set to {GREEN}%s{DEFAULT}!", hideHudText[client] ? "hide" : "show");
	return Plugin_Handled;
}

public Action CommandCancelCrab(int client, int args)
{
	if (!spycrabInProgress)
		CReplyToCommand(client, "{GREEN}[Crab]{DEFAULT} There isn\'t any spycrab going on right now.");
	else
		ResetSpycrabClients(true);
	return Plugin_Handled;
}

public int SpycrabMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char target[16];
		if (menu.GetItem(param2, target, sizeof(target)))
		{
			int targetUserId = StringToInt(target);
			int iTarget = GetClientOfUserId(targetUserId);
			if (param1 == iTarget)
			{
				CPrintToChat(param1, "{GREEN}[Crab]{DEFAULT} You may not target yourself!");
			}
			else if (spycrabInProgress)
			{
				CPrintToChat(param1, "{GREEN}[Crab]{DEFAULT} There is currently another spycrab happening.");
			}
			else if (crabRequestDisabled[iTarget])
			{
				CPrintToChat(param1, "{GREEN}[Crab]{DEFAULT} The person has disabled requests!");
			}
			else
			{
				CPrintToChatAll("{GREEN}[Crab]{DEFAULT} {LIGHTGREEN}%N{DEFAULT} has challenged {LIGHTGREEN}%N{DEFAULT} to a spycrab showdown!", param1, iTarget);
				Menu acceptMenu = new Menu(AcceptMenuHandler);
				acceptMenu.SetTitle("Do you accept?\nFirst to 3 loses.");
				acceptMenu.AddItem("yes", "Yes!");
				acceptMenu.AddItem("no", "No!");
				acceptMenu.Display(iTarget, 20);
				playerCrabData[param1][Challenger] = iTarget;
				playerCrabData[iTarget][Challenger] = param1;
			}
		}
	}
	if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int AcceptMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char answer[8];
		int firstClient = playerCrabData[param1][Challenger];
		if (spycrabInProgress)
		{
			CPrintToChat(param1, "{GREEN}[Crab]{DEFAULT} There is currently another spycrab happening.");
		}
		else if (menu.GetItem(param2, answer, sizeof(answer)) && IsValidClient(firstClient) && IsValidClient(param1))
		{
			if (StrEqual(answer, "yes", false))
			{
				CPrintToChatAll("{GREEN}[Crab]{DEFAULT} {LIGHTGREEN}%N{DEFAULT} accepted {LIGHTGREEN}%N{DEFAULT}\'s spycrab! First to 3 {FULLRED}loses{DEFAULT}.", param1, firstClient);
				LogAction(param1, firstClient, "%N has accepted %N\'s spycrab.", param1, firstClient);
				StartSpyCrab(param1);
			}
			else
			{
				CPrintToChatAll("{GREEN}[Crab]{DEFAULT} {LIGHTGREEN}%N{DEFAULT} declined {LIGHTGREEN}%N{DEFAULT}\'s spycrab!", param1, firstClient);
				CPrintToChat(param1, "{GREEN}[Crab]{DEFAULT} You can disable crab requests with !dontcrab or !nocrab.");
				LogAction(param1, firstClient, "%N has declined %N\'s spycrab.", param1, firstClient);
				ResetSpycrabClients(false, param1);
			}
		}
		else
		{
			ResetSpycrabClients(false, param1);
		}
	}
	if (action == MenuAction_Cancel)
	{
		CPrintToChatAll("{GREEN}[Crab]{DEFAULT} {LIGHTGREEN}%N{DEFAULT} declined {LIGHTGREEN}%N{DEFAULT}\'s spycrab!", param1, playerCrabData[param1][Challenger]);
		ResetSpycrabClients(false, param1);
	}
	if (action == MenuAction_End)
	{
		delete menu;
	}
}

public void StartSpyCrab(int client)
{
	spycrabInProgress = true;
	SetHudTextParams(0.0, 0.0, 22.0, 102, 51, 153, 255);
	hudTextChannel = ShowHudTextAll(-1, "Starting spycrab...");
	CPrintToChatAll("{GREEN}[Crab]{DEFAULT} Tip: You can hide the on-screen text with {CRIMSON}!hidecrab{DEFAULT}.");
	playerCrabData[client][IsFirstClient] = true;
	PreparePlayerForSpycrab(client);
	PreparePlayerForSpycrab(playerCrabData[client][Challenger]);
	PrintCrabDataToScreen(client);
}

void PreparePlayerForSpycrab(int client)
{
	if (!IsValidClient(client))
	{
		spycrabInProgress = false;
		return;
	}
	TF2_SetPlayerClass(client, TFClass_Spy);
	TF2_RemovePlayerDisguise(client);
	TF2_RegeneratePlayer(client);
	StripToPDA(client);
	int userid = GetClientUserId(client);
	if (playerCrabData[client][IsFirstClient])
	{
		TeleportEntity(client, firstClientOrigin, NULL_VECTOR, NULL_VECTOR);
	}
	else
	{
		TeleportEntity(client, secondClientOrigin, NULL_VECTOR, NULL_VECTOR);
	}
	playerCrabData[client][MovementTimer] = new SMTimer(3.0, TestSpycrabClientMov, userid, TIMER_REPEAT);
	playerCrabData[client][TauntTimer] = new SMTimer(12.0, TestSpycrabClientTaunt, userid, TIMER_REPEAT);
	playerCrabData[client][Team] = TF2_GetClientTeam(client);
	CPrintToChat(client, "{GREEN}[Crab]{DEFAULT} Ready, set, taunt!");
	playerCrabData[client][IsEnabled] = true;
	if (CommandExists("sm_tauntspeed"))
	{
		ServerCommand("sm_tauntspeed #%d 1.3", userid);
	}
}

public void StripToPDA(int client)
{
	if (CommandExists("sm_spycrabpda"))
	{
		TF2_RemoveAllWeapons(client);
		ServerCommand("sm_spycrabpda #%d", GetClientUserId(client));
	}
	else
	{
		// Taken from Shaders Allen's TF2_StripToMelee
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Building);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Item1);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Item2);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_PDA);

		int disguisekit = GetPlayerWeaponSlot(client, TFWeaponSlot_Grenade);

		if (IsValidEntity(disguisekit))
		{
			EquipPlayerWeapon(client, disguisekit);
		}
	}
}

void ResetSpycrabClients(bool endOfCrab = false, int client = -1)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			ShowHudText(i, hudTextChannel, "");
		}
		if (client == -1 && playerCrabData[i][IsEnabled])	// ugly and harder than saving client to global var
		{
			client = i;
		}
	}
	ResetClient(client, endOfCrab);
	ResetClient(playerCrabData[client][Challenger], endOfCrab);
	spycrabInProgress = false;
}

void ResetClient(int client, bool endOfCrab)
{
	if (endOfCrab)
	{
		if (IsValidClient(client))
		{
			TF2_RespawnPlayer(client);
			if (CommandExists("sm_tauntspeed"))
			{
				ServerCommand("sm_tauntspeed #%d 1", GetClientUserId(client));
			}
		}
	}
	delete playerCrabData[client][MovementTimer];
	delete playerCrabData[client][TauntTimer];
	playerCrabData[client][Penalty] = 0;
	playerCrabData[client][TimesCrabbed] = 0;
	playerCrabData[client][TimesTaunted] = 0;
	playerCrabData[client][IsFirstClient] = false;
	playerCrabData[client][IsEnabled] = false;
	playerCrabData[client][HasTaunted] = false;
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (spycrabInProgress && StrEqual(classname, "instanced_scripted_scene", false))
    {
    	SDKHook(entity, SDKHook_Spawn, OnSceneSpawned);
    }
}

public Action OnSceneSpawned(int entity)
{
	if (!spycrabInProgress) return;
	int client = GetEntPropEnt(entity, Prop_Data, "m_hOwner");
	if (!IsValidClient(client) || !playerCrabData[client][IsEnabled]) return;
	// SetHudTextParams(0.1, 0.5, 22.0, 102, 51, 153, 255);
	SetHudTextParams(0.1, 0.5, 22.0, 0, 255, 0, 255);
	char scenefile[128];
	GetEntPropString(entity, Prop_Data, "m_iszSceneFile", scenefile, sizeof(scenefile));
	if (StrContains(scenefile, "scenes/player/spy/low/taunt04", false) == -1 && StrContains(scenefile, "scenes/player/spy/low/taunt05", false) == -1 && StrContains(scenefile, "scenes/player/spy/low/taunt06", false) == -1) return;
	playerCrabData[client][TimesTaunted]++;
	int challenger = playerCrabData[client][Challenger];
	int absoluteTimesTaunted = abs(playerCrabData[client][TimesTaunted] - playerCrabData[challenger][TimesTaunted]);
	if (absoluteTimesTaunted > 1)
	{
		if (playerCrabData[client][TimesTaunted] > playerCrabData[challenger][TimesTaunted])
		{
			CPrintToChat(challenger, "{GREEN}[Crab]{DEFAULT} You must taunt %d more times for any more points to be counted.", absoluteTimesTaunted);
			CPrintToChat(client, "{GREEN}[Crab]{DEFAULT} {LIGHTGREEN}%N{DEFAULT} must taunt %d more times for any more points to be counted.", challenger, absoluteTimesTaunted);
			playerCrabData[client][TimesTaunted]--;
			return;
		}
	}
	if (StrEqual(scenefile, "scenes/player/spy/low/taunt05.vcd"))
	{
		playerCrabData[client][TimesCrabbed]++;
		CPrintToChatAll("{GREEN}[Crab]{DEFAULT} {LIGHTGREEN}%N{DEFAULT} just crabbed!", client);
	}
	int clientCrabs = playerCrabData[client][TimesCrabbed];
	int challengerCrabs = playerCrabData[challenger][TimesCrabbed];
	if (absoluteTimesTaunted == 0 && clientCrabs != challengerCrabs && (clientCrabs > 2 || challengerCrabs > 2))
	{
		int printClient = (clientCrabs > challengerCrabs) ? challenger : client;
		CPrintToChatAll("{GREEN}[Crab]{DEFAULT} We have a winner! Congrats to {LIGHTGREEN}%N{DEFAULT}.", printClient);
		LogMessage("%L has won the spycrab between them and %L.", printClient, playerCrabData[printClient][Challenger]);
		SMTimer.Make(3.5, ResetCrabOnWinTimer);
		return;
	}
	PrintCrabDataToScreen(client);
}

void PrintCrabDataToScreen(int client)
{
	int firstClient = playerCrabData[client][IsFirstClient] ? client : playerCrabData[client][Challenger];
	int secondClient = playerCrabData[firstClient][Challenger];
	SetHudTextParams(0.0, 0.0, 22.0, 102, 51, 153, 255);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && (!hideHudText[i] || playerCrabData[i][IsEnabled]))
		{
			ShowHudText(i, hudTextChannel, "[Taunted] / [Crabbed] / [Penalty]\n%N: %d / %d / %d\n%N: %d / %d / %d\nFirst to 3 loses.", firstClient,
				playerCrabData[firstClient][TimesTaunted], playerCrabData[firstClient][TimesCrabbed],
				playerCrabData[firstClient][Penalty], secondClient, playerCrabData[secondClient][TimesTaunted],
				playerCrabData[secondClient][TimesCrabbed], playerCrabData[secondClient][Penalty]);
		}
	}
}

public Action ResetCrabOnWinTimer(Handle timer)
{
	ResetSpycrabClients(true);
}

///////////////////////////////////
///////////// CHECKS //////////////
///////////////////////////////////

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if (spycrabInProgress && playerCrabData[client][IsEnabled] && condition == TFCond_Taunting)
	{
		playerCrabData[client][HasTaunted] = true;
	}
}

public Action OnPlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if (playerCrabData[client][IsEnabled])
	{
		if (spycrabInProgress)
		{
			LogMessage("%L may have just run from a spycrab!", client);
			CPrintToChatAll("{GREEN}[Crab]{DEFAULT} %L may have just run from a spycrab!", client);
			ResetSpycrabClients(true, client);
		}
	}
	return Plugin_Continue;
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!spycrabInProgress) return;
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if (IsValidClient(client) && playerCrabData[client][IsEnabled])
	{
		SMTimer.Make(0.2, OnPlayerDeathTimer, userid);
	}
}

public Action OnPlayerDeathTimer(Handle timer, any userid)
{
	float noMovement[3] = {0.0, 0.0, 0.0};
	int client = GetClientOfUserId(userid);
	if (!IsValidClient(client) && spycrabInProgress)
	{
		ResetSpycrabClients(false);
		return;
	}
	if (!playerCrabData[client][IsEnabled])
	{
		return;
	}
	if (TF2_GetClientTeam(client) != playerCrabData[client][Team])
	{
		TF2_ChangeClientTeam(client, playerCrabData[client][Team]);
	}
	TF2_SetPlayerClass(client, TFClass_Spy, false);
	TF2_RespawnPlayer(client);
	StripToPDA(client);
	if (playerCrabData[client][IsFirstClient]) TeleportEntity(client, firstClientOrigin, NULL_VECTOR, noMovement);
	else TeleportEntity(client, secondClientOrigin, NULL_VECTOR, noMovement);
}

void ClearCrabTeleportLocation(int client, float location[3])
{
	float clientlocation[3];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && client != i && playerCrabData[client][Challenger] != i)
		{
			GetClientAbsOrigin(i, clientlocation);
			if (GetVectorDistance(clientlocation, location, true) <= 10000.0)
			{
				FakeClientCommand(i, "explode");
			}
		}
	}
}

public Action TestSpycrabClientMov(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	float location[3], noMovement[3] = {0.0, 0.0, 0.0};
	GetClientAbsOrigin(client, location);
	if (playerCrabData[client][IsFirstClient])
	{
		if (GetVectorDistance(location, firstClientOrigin, true) > 10000.0)
		{
			ClearCrabTeleportLocation(client, firstClientOrigin);
			TeleportEntity(client, firstClientOrigin, NULL_VECTOR, noMovement);
			CPrintToChat(client, "{GREEN}[Crab]{DEFAULT} Please do not move!");
		}
	}
	else
	{
		if (GetVectorDistance(location, secondClientOrigin) > 100.0)
		{
			ClearCrabTeleportLocation(client, secondClientOrigin);
			TeleportEntity(client, secondClientOrigin, NULL_VECTOR, noMovement);
			CPrintToChat(client, "{GREEN}[Crab]{DEFAULT} Please do not move!");
		}
	}
}

public Action TestSpycrabClientTaunt(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (!playerCrabData[client][HasTaunted])
	{
		playerCrabData[client][Penalty]++;
		int clientpenalty = playerCrabData[client][Penalty];
		CPrintToChatAll("{GREEN}[Crab]{DEFAULT} {LIGHTGREEN}%N{DEFAULT} has been penalized for not taunting!", client);
		PrintCrabDataToScreen(client);
		if (clientpenalty >= 3 && clientpenalty > playerCrabData[playerCrabData[client][Challenger]][Penalty])
		{
			CPrintToChatAll("{GREEN}[Crab]{DEFAULT} {LIGHTGREEN}%N{DEFAULT} has forfeit for having too many penalties!", client);
			CPrintToChatAll("{GREEN}[Crab]{DEFAULT} We have a winner! Congrats to {LIGHTGREEN}%N{DEFAULT}.", playerCrabData[client][Challenger]);
			LogMessage("%L has won the spycrab between them and %L due to forfeit.", playerCrabData[client][Challenger], client);
			SMTimer.Make(3.5, ResetCrabOnWinTimer);
		}
	}
	else
	{
		playerCrabData[client][HasTaunted] = false;
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (spycrabInProgress && playerCrabData[client][IsEnabled] && impulse >= 221 && impulse <=239 && impulse != 230)
	{
		CPrintToChat(client, "{GREEN}[Crab]{DEFAULT} Please do not attempt to disguise!");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!IsValidClient(victim) || !IsValidClient(attacker)) return Plugin_Continue;
	if(spycrabInProgress && playerCrabData[victim][IsEnabled])
	{
		damage = 0.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}
