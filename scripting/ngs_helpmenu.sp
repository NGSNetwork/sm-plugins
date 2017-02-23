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

//--------------------//

public Plugin myinfo = {
	name = "[NGS] Player Tools",
	author = "TheXeon",
	description = "Player commands for NGS people.",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.servegame.com"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_helpmenu", CommandHelpMenu, "Usage: sm_helpmenu");
	LoadTranslations("common.phrases");
}

public Action CommandHelpMenu(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	
	Menu menu = new Menu(HelpMenuHandler);
	menu.SetTitle("=== NGS Help Menu ===");
	menu.AddItem("serverrules", "Server rules!");
	menu.AddItem("servercommands", "Server commands!");
	menu.AddItem("serversettings", "Server settings!");
	menu.AddItem("extrasettings", "Change some extra settings!");
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int HelpMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param1, info, sizeof(info));
		if (StrEqual(info, "serverrules", false))
		{
			FakeClientCommand(param1, "!settings");
		}
		else if (StrEqual(info, "bamoptout", false))
		{
			FakeClientCommand(param1, "!dontbamboozleme");
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int Handler_ItemSelection(Handle menu, MenuAction action, int client, int param) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	}
	if(action != MenuAction_Select) {
		return;
	}
	char selection[128];
	GetMenuItem(menu, param, selection, sizeof(selection));
	FakeClientCommand(client, "sm_pricecheck \"%s\"", selection);
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
