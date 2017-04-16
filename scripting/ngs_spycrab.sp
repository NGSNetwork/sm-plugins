#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <adminmenu>
#include <morecolors>
#include <tf2>
#include <tf2_stocks>

#define PLUGIN_VERSION "1.0.0"

bool spycrabInProgress;
int firstClient = -1, secondClient = -1, firstClientScore = 0, secondClientScore = 0, hudTextChannel, firstClientTimesTaunted, secondClientTimesTaunted;
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
	RegConsoleCmd("sm_spycrab", Cmd_Crab, "Displays spycrab target menu.");
	RegConsoleCmd("sm_crab", Cmd_Crab, "Displays spycrab target menu.");
}

public Action Cmd_Crab(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	if (spycrabInProgress)
	{
		CReplyToCommand(client, "{LIGHTGREEN}[Crab]{DEFAULT} There is currently another spycrab happening.");
		return Plugin_Handled;
	}
	Menu spycrabMenu = new Menu(SpycrabMenuHandler);
	spycrabMenu.SetTitle("Select a player:");
	AddTargetsToMenu(spycrabMenu, 0);
	spycrabMenu.Display(client, MENU_TIME_FOREVER);
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
}

public int AcceptMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char answer[4];
		menu.GetItem(param2, answer, sizeof(answer));
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
	if (action == MenuAction_End)
	{
		ResetSpycrabClients();
		delete menu;
	}
}

public void StartSpyCrab()
{
	spycrabInProgress = true;
	SetHudTextParams(0.1, 0.5, 20.0, 102, 51, 153, 255);
	hudTextChannel = ShowHudText(firstClient, -1, "\n");
	
	// Have to double each command, bleh
	TF2_SetPlayerClass(firstClient, TFClass_Spy);
	TF2_SetPlayerClass(secondClient, TFClass_Spy);
	TF2_RegeneratePlayer(firstClient);
	TF2_RegeneratePlayer(secondClient);
	StripToPDA(firstClient);
	StripToPDA(secondClient);
	TeleportEntity(firstClient, firstClientOrigin, NULL_VECTOR, NULL_VECTOR);
	TeleportEntity(secondClient, secondClientOrigin, NULL_VECTOR, NULL_VECTOR);
	firstClientMovement = CreateTimer(0.5, testFirstClientMov, INVALID_HANDLE, TIMER_REPEAT);
	secondClientMovement = CreateTimer(0.5, testSecondClientMov, INVALID_HANDLE, TIMER_REPEAT);
}

public void StripToPDA(int client)
{
	for (int i = 0; i < 3; i++) TF2_RemoveWeaponSlot(client, i);
	TF2_RemoveWeaponSlot(client, 4);
}

public void ResetSpycrabClients()
{
	if (IsValidClient(firstClient))
	{
		ShowHudText(firstClient, hudTextChannel, "");
	}
	if (IsValidClient(secondClient))
	{
		ShowHudText(secondClient, hudTextChannel, "");
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
	float location[3];
	GetClientAbsOrigin(firstClient, location);
	for (int i = 0; i < 3; i++)
	{
		if (location[i] != firstClientOrigin[i])
		{
			TeleportEntity(firstClient, firstClientOrigin, NULL_VECTOR, NULL_VECTOR);
			CPrintToChat(firstClient, "{LIGHTGREEN}[Crab]{DEFAULT} Please do not move!");
		}
	}
}

public Action testSecondClientMov(Handle timer, any dummy)
{
	float location[3];
	GetClientAbsOrigin(secondClient, location);
	for (int i = 0; i < 3; i++)
	{
		if (location[i] != secondClientOrigin[i])
		{
			TeleportEntity(secondClient, secondClientOrigin, NULL_VECTOR, NULL_VECTOR);
			CPrintToChat(secondClient, "{LIGHTGREEN}[Crab]{DEFAULT} Please do not move!");
		}
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
	if (client != firstClient || client != secondClient) return;
	char scenefile[128];
	GetEntPropString(entity, Prop_Data, "m_iszSceneFile", scenefile, sizeof(scenefile));
	if (client == firstClient) firstClientTimesTaunted++;
	else if (client == secondClient) secondClientTimesTaunted++;
	int absoluteTimesTaunted = abs(secondClientTimesTaunted - firstClientTimesTaunted);
	if (absoluteTimesTaunted > 1)
	{
		if (secondClientTimesTaunted > firstClientTimesTaunted)
		{
			CPrintToChat(firstClient, "{LIGHTGREEN}[Crab]{DEFAULT} You must taunt for any more points to be counted.");
			return;
		}
		else
		{
			CPrintToChat(secondClient, "{LIGHTGREEN}[Crab]{DEFAULT} You must taunt for any more points to be counted.");
			return;
		}
	}
	if (StrEqual(scenefile, "scenes/player/spy/low/taunt05.vcd"))
	{
		if (client == firstClient) secondClientScore++;
		else if (client == secondClient) firstClientScore++;
        
		if (absoluteTimesTaunted == 0 && (firstClientScore > 2 || secondClientScore > 2))
		{
			CPrintToChatAll("{LIGHTGREEN}[Crab]{DEFAULT} We have a winner! Congrats to %N.", (firstClientScore > secondClientScore) ? secondClient : firstClient);
			LogMessage("%N has won the spycrab between them and %N.", (firstClientScore > secondClientScore) ? secondClient : firstClient)
			ResetSpycrabClients();
		}
		ShowHudText(firstClient, hudTextChannel, "%N: %d\n%N: %d", firstClient, firstClientScore, secondClient, secondClientScore);
		ShowHudText(secondClient, hudTextChannel, "%N: %d\n%N: %d", firstClient, firstClientScore, secondClient, secondClientScore);
	}
	else
	{
		if (firstClientScore > 2 || secondClientScore > 2)
		{
			CPrintToChatAll("{LIGHTGREEN}[Crab]{DEFAULT} We have a winner! Congrats to %N.", (firstClientScore > secondClientScore) ? secondClient : firstClient);
			LogMessage("%N has won the spycrab between them and %N.", (firstClientScore > secondClientScore) ? secondClient : firstClient)
			ResetSpycrabClients();
		}
	}
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