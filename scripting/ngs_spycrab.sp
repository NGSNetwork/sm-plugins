/**
* TheXeon
* ngs_spycrab.sp
*
* Files:
* addons/sourcemod/plugins/ngs_spycrab.smx
* addons/sourcemod/configs/crablocations.cfg
*
* Dependencies:
* sdkhooks.inc, adminmenu.inc, multicolors.inc, tf2_stocks.inc,
* ngsutils.inc, ngsupdater.inc
*/
#include <sdkhooks>
#include <adminmenu>
#include <multicolors>
#include <tf2_stocks>
#include <ngsutils>
#include <ngsupdater>

//// Obviously inspired by Erreur 500
//enum CrabData
//{
//	Challenger,
//	bool:Enabled,
//	Score,
//	SMTimer:MovementTimer,
//	TimesTaunted,
//	Deads,
//	ClassRestrict,
//	GodMod,
//	bool:HeadShot,
//	TimeLeft,
//	CSprite,
//	SpriteParent,
//	bool:HideSprite,
//}

ConVar mapNameContains;
KeyValues mapLocations;

bool spycrabInProgress, spycrabMenuInUse;
//int playerCrabData[MAXPLAYERS + 1][CrabData];
int firstClient = -1, secondClient = -1, firstClientScore, secondClientScore,
	firstClientTimesTaunted, secondClientTimesTaunted, hudTextChannel;
float firstClientOrigin[3], secondClientOrigin[3];
TFTeam firstClientTeam, secondClientTeam;

SMTimer firstClientMovement, secondClientMovement;

public Plugin myinfo = {
	name = "[NGS] Spycrab Suite",
	author = "TheXeon / EasyE",
	description = "Automate a spycrab with people.",
	version = "1.1.0",
	url = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_spycrab", CommandCrab, "Displays spycrab target menu.");
	RegConsoleCmd("sm_crab", CommandCrab, "Displays spycrab target menu.");
	RegAdminCmd("sm_cancelcrab", CommandCancelCrab, ADMFLAG_GENERIC, "Cancels the spycrab.");
	RegAdminCmd("sm_reloadcrab", CommandReloadCrabConfig, ADMFLAG_GENERIC, "Reloads the map config file.");

	mapNameContains = CreateConVar("sm_spycrab_config_contains", "1", "Whether map names in config will be checked partially or fully.");
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("player_disconnect", OnPlayerDisconnect, EventHookMode_Pre);

	LoadConfig();
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
			secondClientOrigin[i] = StringToFloat(secondClientVector[i]);\
		}
	}
	else
	{
		LogError("Invalidly formatted location string in config file around Section \'%s\'. Make sure it is a comma separated 3d vector!", sectionName);
	}
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
	if (spycrabInProgress)
	{
		CReplyToCommand(client, "{LIGHTGREEN}[Crab]{DEFAULT} There is currently another spycrab happening.");
	}
	else if (spycrabMenuInUse)
	{
		CReplyToCommand(client, "{LIGHTGREEN}[Crab]{DEFAULT} The spycrab menu is currently being used by someone else right now.");
	}
	else if (firstClientOrigin[0] == NULL_VECTOR[0])
	{
		CReplyToCommand(client, "{LIGHTGREEN}[Crab]{DEFAULT} The map is not configured for this plugin, notify an admin!");
	}
	else
	{
		Menu spycrabMenu = new Menu(SpycrabMenuHandler);
		spycrabMenu.SetTitle("Select a player:");
		AddTargetsToMenu(spycrabMenu, 0, true, true);
		spycrabMenu.Display(client, 20);
		spycrabMenuInUse = true;
	}
	return Plugin_Handled;
}

public Action CommandCancelCrab(int client, int args)
{
	if (!spycrabInProgress)
		CReplyToCommand(client, "{LIGHTGREEN}[Crab]{DEFAULT} There isn\'t any spycrab going on right now.");
	else
		ResetSpycrabClients(true);
	return Plugin_Handled;
}

public int SpycrabMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char target[16];
		int iTarget;
		menu.GetItem(param2, target, sizeof(target));
		iTarget = GetClientOfUserId(StringToInt(target));
		if (param1 == iTarget)
		{
			CPrintToChat(param1, "{LIGHTGREEN}[Crab]{DEFAULT} You may not target yourself!");
			spycrabMenuInUse = false;
			return;
		}
		CPrintToChatAll("{LIGHTGREEN}[Crab]{DEFAULT} %N has challenged %N to a spycrab showdown!", param1, iTarget);
		Menu acceptMenu = new Menu(AcceptMenuHandler);
		acceptMenu.SetTitle("Do you accept?");
		acceptMenu.AddItem("yes", "Yes!");
		acceptMenu.AddItem("no", "No!");
		acceptMenu.Display(iTarget, 20);
		firstClient = param1;
	}
	if (action == MenuAction_End)
	{
		delete menu;
	}
	if (action == MenuAction_Cancel)
	{
		spycrabMenuInUse = false;
	}
}

public int AcceptMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char answer[8];
		if (menu.GetItem(param2, answer, sizeof(answer)))
		{
			if (StrEqual(answer, "yes", false))
			{
				CPrintToChatAll("{LIGHTGREEN}[Crab]{DEFAULT} %N accepted %N\'s spycrab!", param1, firstClient);
				secondClient = param1;
				LogAction(secondClient, firstClient, "%N has accepted %N\'s spycrab.", secondClient, firstClient);
				StartSpyCrab();
			}
			else
			{
				CPrintToChatAll("{LIGHTGREEN}[Crab]{DEFAULT} %N declined %N\'s spycrab!", param1, firstClient);
				ResetSpycrabClients();
			}
		}
		spycrabMenuInUse = false;
	}
	if (action == MenuAction_Cancel)
	{
		ResetSpycrabClients();
		spycrabMenuInUse = false;
	}
	if (action == MenuAction_End)
	{
		delete menu;
		spycrabMenuInUse = false;
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if ((client == firstClient || client == secondClient) && impulse >= 221 && impulse <=239 && impulse != 230)
	{
		CPrintToChat(client, "{LIGHTGREEN}[Crab]{DEFAULT} Please do not attempt to disguise!");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public void StartSpyCrab()
{
	spycrabInProgress = true;
	// SetHudTextParams(0.1, 0.5, 22.0, 102, 51, 153, 255);
	SetHudTextParams(0.1, 0.5, 22.0, 0, 255, 0, 255);
	hudTextChannel = ShowHudText(firstClient, -1, "Starting spycrab...");
	// Have to double each command, bleh
	TF2_SetPlayerClass(firstClient, TFClass_Spy);
	TF2_SetPlayerClass(secondClient, TFClass_Spy);
	TF2_RemovePlayerDisguise(firstClient);
	TF2_RemovePlayerDisguise(secondClient);
	TF2_RegeneratePlayer(firstClient);
	TF2_RegeneratePlayer(secondClient);
	StripToPDA(firstClient);
	StripToPDA(secondClient);
	TeleportEntity(firstClient, firstClientOrigin, NULL_VECTOR, NULL_VECTOR);
	TeleportEntity(secondClient, secondClientOrigin, NULL_VECTOR, NULL_VECTOR);
	firstClientMovement = new SMTimer(0.5, testFirstClientMov, _, TIMER_REPEAT);
	secondClientMovement = new SMTimer(0.5, testSecondClientMov, _, TIMER_REPEAT);
	firstClientTeam = TF2_GetClientTeam(firstClient);
	secondClientTeam = TF2_GetClientTeam(secondClient);
	if (CommandExists("sm_tauntspeed"))
	{
		ServerCommand("sm_tauntspeed #%d 1.3", GetClientUserId(firstClient));
		ServerCommand("sm_tauntspeed #%d 1.3", GetClientUserId(secondClient));
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

void ResetSpycrabClients(bool endOfCrab = false)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			ShowHudText(i, hudTextChannel, "");
		}
	}
	if (endOfCrab)
	{
		if (IsValidClient(firstClient))
		{
			TF2_RespawnPlayer(firstClient);
			if (CommandExists("sm_tauntspeed"))
			{
				ServerCommand("sm_tauntspeed #%d 1", GetClientUserId(firstClient));
			}
		}
		if (IsValidClient(secondClient))
		{
			TF2_RespawnPlayer(secondClient);
			if (CommandExists("sm_tauntspeed"))
			{
				ServerCommand("sm_tauntspeed #%d 1", GetClientUserId(secondClient));
			}
		}
	}
	firstClient = -1;
	secondClient = -1;
	delete firstClientMovement;
	delete secondClientMovement;
	firstClientScore = 0;
	secondClientScore = 0;
	firstClientTimesTaunted = 0;
	secondClientTimesTaunted = 0;
	spycrabInProgress = false;
}

public Action testFirstClientMov(Handle timer)
{
	float location[3], noMovement[3] = {0.0, 0.0, 0.0};
	GetClientAbsOrigin(firstClient, location);
	if (GetVectorDistance(location, firstClientOrigin) > 100.0)
	{
		TeleportEntity(firstClient, firstClientOrigin, NULL_VECTOR, noMovement);
		CPrintToChat(firstClient, "{LIGHTGREEN}[Crab]{DEFAULT} Please do not move!");
	}
}

public Action testSecondClientMov(Handle timer)
{
	float location[3], noMovement[3] = {0.0, 0.0, 0.0};
	GetClientAbsOrigin(secondClient, location);
	if (GetVectorDistance(location, secondClientOrigin) > 100.0)
	{
		TeleportEntity(secondClient, secondClientOrigin, NULL_VECTOR, noMovement);
		CPrintToChat(secondClient, "{LIGHTGREEN}[Crab]{DEFAULT} Please do not move!");
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (!StrEqual(classname, "instanced_scripted_scene", false)) return;
    SDKHook(entity, SDKHook_Spawn, OnSceneSpawned);
}

public Action OnSceneSpawned(int entity)
{
	if (!spycrabInProgress) return;
	int client = GetEntPropEnt(entity, Prop_Data, "m_hOwner");
	if (client != firstClient && client != secondClient) return;
	// SetHudTextParams(0.1, 0.5, 22.0, 102, 51, 153, 255);
	SetHudTextParams(0.1, 0.5, 22.0, 0, 255, 0, 255);
	char scenefile[128];
	GetEntPropString(entity, Prop_Data, "m_iszSceneFile", scenefile, sizeof(scenefile));
	if (StrContains(scenefile, "scenes/player/spy/low/taunt04", false) == -1 && StrContains(scenefile, "scenes/player/spy/low/taunt05", false) == -1 && StrContains(scenefile, "scenes/player/spy/low/taunt06", false) == -1) return;
	if (client == firstClient) firstClientTimesTaunted++;
	else if (client == secondClient) secondClientTimesTaunted++;
	int absoluteTimesTaunted = abs(secondClientTimesTaunted - firstClientTimesTaunted);
	if (absoluteTimesTaunted > 1)
	{
		if (secondClientTimesTaunted > firstClientTimesTaunted)
		{
			CPrintToChat(firstClient, "{LIGHTGREEN}[Crab]{DEFAULT} You must taunt %d more times for any more points to be counted.", absoluteTimesTaunted);
			CPrintToChat(secondClient, "{LIGHTGREEN}[Crab]{DEFAULT} %N must taunt %d more times for any more points to be counted.", firstClient, absoluteTimesTaunted);
			secondClientTimesTaunted--;
			return;
		}
		else
		{
			CPrintToChat(secondClient, "{LIGHTGREEN}[Crab]{DEFAULT} You must taunt %d more times for any more points to be counted.", absoluteTimesTaunted);
			CPrintToChat(firstClient, "{LIGHTGREEN}[Crab]{DEFAULT} %N must taunt %d more times for any more points to be counted.", secondClient, absoluteTimesTaunted);
			firstClientTimesTaunted--;
			return;
		}
	}
	if (StrEqual(scenefile, "scenes/player/spy/low/taunt05.vcd"))
	{
		if (client == firstClient) firstClientScore++;
		else if (client == secondClient) secondClientScore++;
		CPrintToChatAll("{LIGHTGREEN}[Crab]{DEFAULT} %N just crabbed!", client);
		if (absoluteTimesTaunted == 0 && (firstClientScore > 2 || secondClientScore > 2))
		{
			CPrintToChatAll("{LIGHTGREEN}[Crab]{DEFAULT} We have a winner! Congrats to %N.", (firstClientScore > secondClientScore) ? secondClient : firstClient);
			LogMessage("%N has won the spycrab between them and %N.", (firstClientScore > secondClientScore) ? secondClient : firstClient, (firstClientScore > secondClientScore) ? firstClient : secondClient)
			SMTimer.Make(3.5, ResetCrabOnWinTimer);
			return;
		}
		for (int i = 1; i <= MaxClients; i++)
			if (IsValidClient(i)) ShowHudText(i, hudTextChannel, "%N: %d / %d\n%N: %d / %d", firstClient, firstClientScore, firstClientTimesTaunted, secondClient, secondClientScore, secondClientTimesTaunted);
	}
	else
	{
		for (int i = 1; i <= MaxClients; i++)
			if (IsValidClient(i)) ShowHudText(i, hudTextChannel, "%N: %d / %d\n%N: %d / %d", firstClient, firstClientScore, firstClientTimesTaunted, secondClient, secondClientScore, secondClientTimesTaunted);
		if (firstClientScore > 2 || secondClientScore > 2)
		{
			CPrintToChatAll("{LIGHTGREEN}[Crab]{DEFAULT} We have a winner! Congrats to %N.", (firstClientScore > secondClientScore) ? secondClient : firstClient);
			LogMessage("%N has won the spycrab between them and %N.", (firstClientScore > secondClientScore) ? secondClient : firstClient, (firstClientScore > secondClientScore) ? firstClient : secondClient)
			SMTimer.Make(3.5, ResetCrabOnWinTimer);
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

public Action OnPlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if (client == firstClient || client == secondClient)
	{
		if (spycrabMenuInUse) spycrabMenuInUse = false;
		if (spycrabInProgress)
		{
			LogMessage("%L may have just run from a spycrab!", IsValidClient(firstClient) ? secondClient : firstClient);
			CPrintToChatAll("{LIGHTGREEN}[Crab]{DEFAULT} %L just ran from a spycrab!", IsValidClient(firstClient) ? secondClient : firstClient);
			ResetSpycrabClients(true);
		}
	}
	return Plugin_Continue;
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!spycrabInProgress) return;
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if (client == firstClient || client == secondClient)
	{
		SMTimer.Make(0.2, OnPlayerDeathTimer, userid);
	}
}

public Action OnPlayerDeathTimer(Handle timer, any userid)
{
	float noMovement[3] = {0.0, 0.0, 0.0};
	int client = GetClientOfUserId(userid);
	if (!IsValidClient(client))
	{
		ResetSpycrabClients(false);
		return;
	}
	if (client == firstClient && TF2_GetClientTeam(client) != firstClientTeam)
	{
		TF2_ChangeClientTeam(client, firstClientTeam);
	}
	else if (client == secondClient && TF2_GetClientTeam(client) != secondClientTeam)
	{
		TF2_ChangeClientTeam(client, secondClientTeam);
	}
	TF2_SetPlayerClass(client, TFClass_Spy, false);
	TF2_RespawnPlayer(client);
	StripToPDA(client);
	if (client == firstClient) TeleportEntity(firstClient, firstClientOrigin, NULL_VECTOR, noMovement);
	else TeleportEntity(secondClient, secondClientOrigin, NULL_VECTOR, noMovement);
}

stock int abs(int x) { return RoundToNearest(FloatAbs(float(x))); }
