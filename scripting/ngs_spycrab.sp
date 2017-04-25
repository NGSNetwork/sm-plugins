#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <adminmenu>
#include <morecolors>
#include <tf2>
#include <tf2_stocks>

#define PLUGIN_VERSION "1.0.0"

bool spycrabInProgress, giveWeaponExists, spycrabMenuInUse;
int firstClient = -1, secondClient = -1, firstClientScore = 0, secondClientScore = 0, firstClientTimesTaunted, secondClientTimesTaunted, hudTextChannel;
float firstClientOrigin[3] =  {-5092.628906, -864.530823, -161.218689}, secondClientOrigin[3] = {-4915.655273, -865.145020, -154.218689};

Handle firstClientMovement = null, secondClientMovement = null;

public Plugin myinfo = {
	name = "[NGS] Spycrab Suite",
	author = "TheXeon / EasyE",
	description = "Automate a spycrab with people.",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.net"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_spycrab", CommandCrab, "Displays spycrab target menu.");
	RegConsoleCmd("sm_crab", CommandCrab, "Displays spycrab target menu.");
	RegAdminCmd("sm_cancelcrab", CommandCancelCrab, ADMFLAG_GENERIC, "Cancels the spycrab.");
	HookEvent("player_death", OnPlayerDeath);
}

public void OnMapStart()
{
	char mapName[MAX_BUFFER_LENGTH];
	GetCurrentMap(mapName, sizeof(mapName));
	if (StrContains(mapName, "trade_museum_final", false) == -1)
	{
		LogMessage("This is not the right map to run this on. This plugin currently only works on trade_museum_final.");
		char filename[256];
		GetPluginFilename(INVALID_HANDLE, filename, sizeof(filename));
		ServerCommand("sm plugins unload %s", filename);
	}
}

public Action CommandCrab(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	if (spycrabInProgress)
	{
		CReplyToCommand(client, "{LIGHTGREEN}[Crab]{DEFAULT} There is currently another spycrab happening.");
		return Plugin_Handled;
	}
	if (spycrabMenuInUse)
	{
		CReplyToCommand(client, "{LIGHTGREEN}[Crab]{DEFAULT} The spycrab menu is currently being used by someone else right now.");
		return Plugin_Handled;
	}
	Menu spycrabMenu = new Menu(SpycrabMenuHandler);
	spycrabMenu.SetTitle("Select a player:");
	AddTargetsToMenu(spycrabMenu, 0, true, true);
	spycrabMenu.Display(client, MENU_TIME_FOREVER);
	spycrabMenuInUse = true;
	return Plugin_Handled;
}

public Action CommandCancelCrab(int client, int args)
{
	if (client != firstClient && client != secondClient) return Plugin_Handled;
	if (!spycrabInProgress)
	{
		CReplyToCommand(client, "{LIGHTGREEN}[Crab]{DEFAULT} There isn\'t any spycrab going on right now.");
		return Plugin_Handled;
	}
	
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
			return;
		}
		CPrintToChatAll("{LIGHTGREEN}[Crab]{DEFAULT} %N has challenged %N to a spycrab showdown!", param1, iTarget);
		Menu acceptMenu = new Menu(AcceptMenuHandler);
		acceptMenu.SetTitle("Do you accept?");
		acceptMenu.AddItem("yes", "Yes!");
		acceptMenu.AddItem("no", "No!");
		acceptMenu.Display(iTarget, MENU_TIME_FOREVER);
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
		menu.GetItem(param2, answer, sizeof(answer));
		if (StrEqual(answer, "yes", false))
		{
			CPrintToChatAll("{LIGHTGREEN}[Crab]{DEFAULT} %N accepted %N\'s spycrab!", param1, firstClient);
			secondClient = param1;
			LogAction(secondClient, firstClient, "%N has accepted %N\'s spycrab.", secondClient, firstClient);
			StartSpyCrab();
			spycrabMenuInUse = false;
		}
		else
		{
			CPrintToChatAll("{LIGHTGREEN}[Crab]{DEFAULT} %N declined %N\'s spycrab!", param1, firstClient);
			ResetSpycrabClients();
			spycrabMenuInUse = false;
		}
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

public void StartSpyCrab()
{
	CPrintToChatAll("Starting spycrab!");
	spycrabInProgress = true;
	CPrintToChatAll("spycrabInProgress is %s", spycrabInProgress ? "true" : "false");
	// SetHudTextParams(0.1, 0.5, 22.0, 102, 51, 153, 255);
	SetHudTextParams(0.1, 0.5, 22.0, 0, 255, 0, 255);
	hudTextChannel = ShowHudText(firstClient, -1, "Starting spycrab...");
	// Have to double each command, bleh
	TF2_SetPlayerClass(firstClient, TFClass_Spy);
	TF2_SetPlayerClass(secondClient, TFClass_Spy);
	TF2_RemovePlayerDisguise(firstClient);
	TF2_RemovePlayerDisguise(secondClient);
	CPrintToChatAll("Firstclient = %N, secondclient = %N", firstClient, secondClient);
	TF2_RegeneratePlayer(firstClient);
	TF2_RegeneratePlayer(secondClient);
	StripToPDA(firstClient);
	StripToPDA(secondClient);
	TeleportEntity(firstClient, firstClientOrigin, NULL_VECTOR, NULL_VECTOR);
	TeleportEntity(secondClient, secondClientOrigin, NULL_VECTOR, NULL_VECTOR);
	firstClientMovement = CreateTimer(0.5, testFirstClientMov, INVALID_HANDLE, TIMER_REPEAT);
	secondClientMovement = CreateTimer(0.5, testSecondClientMov, INVALID_HANDLE, TIMER_REPEAT);
	if (CommandExists("sm_tauntspeed")) ServerCommand("sm_tauntspeed #%d 1.3", GetClientUserId(firstClient));
	if (CommandExists("sm_tauntspeed")) ServerCommand("sm_tauntspeed #%d 1.3", GetClientUserId(secondClient));
	if (firstClientMovement == null) CPrintToChatAll("FirstClientMovement is still null!");
	if (secondClientMovement == null) CPrintToChatAll("SecondClientMovement is still null!");
}

public void StripToPDA(int client)
{
	if (CommandExists("sm_spycrabpda"))
	{
		TF2_RemoveAllWeapons(client);
		ServerCommand("sm_spycrabpda #%d", GetClientUserId(client));
		CPrintToChatAll("%N has been stripped to PDA.", client);
	}
}

void ResetSpycrabClients(bool endOfCrab = false)
{
	CPrintToChatAll("Resetting spycrab clients!");
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i)) ShowHudText(i, hudTextChannel, "");
	}
	if (endOfCrab)
	{
		if (IsValidClient(firstClient))
		{
			TF2_RespawnPlayer(firstClient);
			if (CommandExists("sm_tauntspeed")) ServerCommand("sm_tauntspeed #%d 1", GetClientUserId(firstClient));
		}
		if (IsValidClient(secondClient)) 
		{
			TF2_RespawnPlayer(secondClient);
			if (CommandExists("sm_tauntspeed")) ServerCommand("sm_tauntspeed #%d 1", GetClientUserId(secondClient));
		}
	}
	firstClient = -1;
	secondClient = -1;
	if (firstClientMovement != null)
	{
		KillTimer(firstClientMovement);
		firstClientMovement = null;
	}
	if (secondClientMovement != null)
	{
		KillTimer(secondClientMovement);
		secondClientMovement = null;
	}
	firstClientScore = 0;
	secondClientScore = 0;
	firstClientTimesTaunted = 0;
	secondClientTimesTaunted = 0;
	spycrabInProgress = false;
}

public Action testFirstClientMov(Handle timer, any dummy)
{
	float location[3], noMovement[3] = {0.0, 0.0, 0.0};
	GetClientAbsOrigin(firstClient, location);
	if (GetVectorDistance(location, firstClientOrigin) > 100.0)
	{
		TeleportEntity(firstClient, firstClientOrigin, NULL_VECTOR, noMovement);
		CPrintToChat(firstClient, "{LIGHTGREEN}[Crab]{DEFAULT} Please do not move!");
	}
}

public Action testSecondClientMov(Handle timer, any dummy)
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
			return;
		}
		else
		{
			CPrintToChat(secondClient, "{LIGHTGREEN}[Crab]{DEFAULT} You must taunt %d more times for any more points to be counted.", absoluteTimesTaunted);
			CPrintToChat(firstClient, "{LIGHTGREEN}[Crab]{DEFAULT} %N must taunt %d more times for any more points to be counted.", secondClient, absoluteTimesTaunted);
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
			ResetSpycrabClients(true);
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
			ResetSpycrabClients(true);
		}
	}
}

///////////////////////////////////
///////////// CHECKS //////////////
///////////////////////////////////

public void OnClientDisconnect(int client)
{
	if ((client == firstClient || client == secondClient))
	{
		if (spycrabMenuInUse) spycrabMenuInUse = false;
		if (spycrabInProgress)
		{
			ResetSpycrabClients(true);
			LogMessage("%N just ran from a spycrab!", IsValidClient(firstClient) ? secondClient : firstClient);
			CPrintToChatAll("{LIGHTGREEN}[Crab]{DEFAULT} Someone just ran from a spycrab!", IsValidClient(firstClient) ? secondClient : firstClient);
		}
	}
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!spycrabInProgress) return;
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client == firstClient || client == secondClient)
	{
		CreateTimer(0.2, OnPlayerDeathTimer, client);
	}
}

public Action OnPlayerDeathTimer(Handle timer, any client)
{
	float noMovement[3] = {0.0, 0.0, 0.0};
	TF2_SetPlayerClass(client, TFClass_Spy, false);
	TF2_RespawnPlayer(client);
	StripToPDA(client);
	if (client == firstClient) TeleportEntity(firstClient, firstClientOrigin, NULL_VECTOR, noMovement);
	else TeleportEntity(secondClient, secondClientOrigin, NULL_VECTOR, noMovement);
}

stock int abs(int x) { return RoundFloat(FloatAbs(float(x))); }

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