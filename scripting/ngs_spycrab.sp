#include <sourcemod>
#include <sdktools>
#include <adminmenu>
#include <morecolors>

public void OnPluginStart()
{
	RegConsoleCmd("sm_spycrab", Cmd_Crab, "Displays spycrab target menu.");
	RegConsoleCmd("sm_crab", Cmd_Crab, "Displays spycrab target menu.");
}

public Action Cmd_Crab(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	Menu spycrabMenu = new Menu(SpycrabMenuHandler);
	spycrabMenu.SetTitle("Select a player:");
	AddTargetsToMenu(spycrabMenu, 0);
	spycrabMenu.Display(client, MENU_TIME_FOREVER);
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
		CPrintToChatAll("{LIGHTGREEN}[CRAB]{DEFAULT }%N has challenged %N to a spycrab showdown!", param1, iTarget);
	}
}

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