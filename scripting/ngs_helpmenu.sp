#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2>
#include <advanced_motd>
#include <morecolors>

#define PLUGIN_VERSION "1.0.0"
#define STEAMCOMMUNITY_PROFILESURL "https://steamcommunity.com/profiles/"

Menu helpMenu;
Menu serverRulesMenu;
Menu serverCommandsMainMenu;
Menu serverCommandsSubMenu;

public Plugin myinfo = {
	name = "[NGS] Help Menu",
	author = "TheXeon",
	description = "A help menu for NGS.",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.net"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_helpmenu", CommandHelpMenu, "Usage: sm_helpmenu");
	LoadTranslations("common.phrases");
	
	helpMenu = new Menu(HelpMenuHandler);
	helpMenu.SetTitle("=== NGS Help Menu ===");
	helpMenu.AddItem("serverrules", "Server rules!");
	helpMenu.AddItem("servercommands", "Server commands!");
	helpMenu.AddItem("extrasettings", "Change some extra settings!");
	
	serverRulesMenu = new Menu(ServerRulesMenuHandler);
	serverRulesMenu.SetTitle("=== NGS Server Rules ===");
	serverRulesMenu.AddItem("rule1", "Don\'t scam!");
	serverRulesMenu.AddItem("rule2", "Don\'t hack!");
	SetMenuExitBackButton(serverRulesMenu, true);
	
	serverCommandsMainMenu = new Menu(ServerCommandsMenuHandler);
	serverCommandsMainMenu.SetTitle("=== NGS Server Commands ===");
	serverCommandsMainMenu.AddItem("players", "Player Commands!");
	serverCommandsMainMenu.AddItem("donors", "Donor Commands!");
	SetMenuExitBackButton(serverCommandsMainMenu, true);
	
	serverCommandsSubMenu = new Menu(ServerCommandsSubMenuHandler);
}

public Action CommandHelpMenu(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	helpMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int HelpMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		if (StrEqual(info, "serverrules", false))
		{
			serverRulesMenu.Display(param1, MENU_TIME_FOREVER);
		}
		else if (StrEqual(info, "servercommands", false))
		{
			serverCommandsMainMenu.Display(param1, MENU_TIME_FOREVER);
		}
		else if (StrEqual(info, "bamoptout", false))
			FakeClientCommand(param1, "!dontbamboozleme");
	}
}

public int ServerRulesMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		helpMenu.Display(param1, MENU_TIME_FOREVER);
	}
	else if(action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		if (StrEqual(info, "bamoptout", false))
			FakeClientCommand(param1, "!dontbamboozleme");
	}
}

public int ServerCommandsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		helpMenu.Display(param1, MENU_TIME_FOREVER);
	}
	else if(action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		if (StrEqual(info, "players", false))
		{
			FillCommands(true);
			serverCommandsSubMenu.Display(param1, MENU_TIME_FOREVER);
		}
		else if (StrEqual(info, "donors", false))
		{
			FillCommands(false);
			serverCommandsSubMenu.Display(param1, MENU_TIME_FOREVER);
		}
	}
}

public int ServerCommandsSubMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		serverCommandsMainMenu.Display(param1, MENU_TIME_FOREVER);
	}
	else if(action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		if (StrEqual(info, "bamoptout", false))
			FakeClientCommand(param1, "!dontbamboozleme");
	}
}

public void FillCommands(bool regularPlayers)
{
	serverCommandsSubMenu.RemoveAllItems();
	char command[MAX_BUFFER_LENGTH], description[MAX_BUFFER_LENGTH], buffer[MAX_BUFFER_LENGTH];
	int flags;
	Handle hIterator = GetCommandIterator();
	if (regularPlayers)
	{
		serverCommandsSubMenu.SetTitle("=== NGS Player Commands ===");
		while (ReadCommandIterator(hIterator, command, sizeof(command), flags, description, sizeof(description)))
		{
			if (flags == 0)
			{
				Format(buffer, sizeof(buffer), "%s - %s", command, description);
				serverCommandsSubMenu.AddItem(command, buffer);
			}
		}
	}
	else
	{
		serverCommandsSubMenu.SetTitle("=== NGS Donor Commands ===");
		while (ReadCommandIterator(hIterator, command, sizeof(command), flags, description, sizeof(description)))
		{
			if (flags & ADMFLAG_RESERVATION)
			{
				Format(buffer, sizeof(buffer), "%s - %s", command, description);
				serverCommandsSubMenu.AddItem(command, buffer);
			}
		}
	}
	CloseHandle(hIterator);
}

public bool IsValidClient(int client)
{
	if(client > 4096) client = EntRefToEntIndex(client);
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsFakeClient(client)) return false;
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}
