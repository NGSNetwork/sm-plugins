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
Menu serverCommandsMenu;

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
	helpMenu.AddItem("serversettings", "Server settings!");
	helpMenu.AddItem("extrasettings", "Change some extra settings!");
	
	serverRulesMenu = new Menu(ServerRulesMenuHandler);
	serverRulesMenu.SetTitle("=== NGS Server Rules ===");
	serverRulesMenu.AddItem("rule1", "Don\'t scam!");
	serverRulesMenu.AddItem("rule2", "Don\'t hack!");
	serverRulesMenu.AddItem("serversettings", "Server settings!");
	serverRulesMenu.AddItem("extrasettings", "Change some extra settings!");
	// serverRulesMenu.ExitBackButton(true);
	SetMenuExitBackButton(serverRulesMenu, true);
	
	serverCommandsMenu = new Menu(ServerCommandsMenuHandler);
	serverCommandsMenu.SetTitle("=== NGS Server Commands ===");
	serverCommandsMenu.AddItem("dontbamboozleme", "Opt-out of bamboozlement.");
	serverCommandsMenu.AddItem("fp", "First Person.");
	serverCommandsMenu.AddItem("serversettings", "Server settings!");
	serverCommandsMenu.AddItem("extrasettings", "Change some extra settings!");
	// serverCommandsMenu.ExitBackButton(true);
	SetMenuExitBackButton(serverCommandsMenu, true);
}

public Action CommandHelpMenu(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	helpMenu.Display(client, MENU_TIME_FOREVER);
	LogMessage("Showing help menu.");
	return Plugin_Handled;
}

public int HelpMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		LogMessage("Selected in Help Menu!");
		char info[32];
		menu.GetItem(param1, info, sizeof(info));
		LogMessage("Selected in Help Menu: %s", info);
		if (StrEqual(info, "serverrules", false))
		{
			serverRulesMenu.Display(param1, MENU_TIME_FOREVER);
			LogMessage("Showing server rules menu.");
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
		LogMessage("Showing help menu from server rules menu.");
	}
	else if(action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param1, info, sizeof(info));
		LogMessage("Selected in server rules Menu: %s", info);
		if (StrEqual(info, "bamoptout", false))
			FakeClientCommand(param1, "!dontbamboozleme");
	}
}

public int ServerCommandsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		helpMenu.Display(param1, MENU_TIME_FOREVER);
		LogMessage("Showing help menu from server commands menu.");
	}
	else if(action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param1, info, sizeof(info));
		LogMessage("Selected in server commands Menu: %s", info);
		if (StrEqual(info, "bamoptout", false))
			FakeClientCommand(param1, "!dontbamboozleme");
	}
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
