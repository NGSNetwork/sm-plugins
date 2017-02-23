#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <morecolors>

#define PLUGIN_VERSION  "1.0.1"

public Plugin myinfo = {
	name = "[NGS] Pug Suite",
	author = "TheXeon",
	description = "Start and administrate a pug!",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.net/"
}

bool inPug, configurePug;
int Leader;
char format[MAX_BUFFER_LENGTH], league[MAX_BUFFER_LENGTH], map[MAX_BUFFER_LENGTH];

public void OnPluginStart()
{
	RegConsoleCmd("sm_pug", CommandPug, "Start or stop a pug as the leader!");
	RegConsoleCmd("sm_pugrcon", CommandPugRcon, "A pseudo-rcon for leaders!");
	LoadTranslations("common.phrases");
}

public Action CommandPug(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	configurePug = true;
	Menu menu = new Menu(StartMenuHandler);
	menu.SetTitle("Are you the leader?");
	menu.AddItem("yes", "Yes");
	menu.AddItem("no", "No");
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int StartMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(menu, param1, info, sizeof(info));
		if (StrEqual(info, "yes", false))
		{
			char playerName[MAX_NAME_LENGTH];
			GetClientName(param1, playerName, sizeof(playerName));
			CPrintToChatAll("{GREEN}[SM]{DEFAULT} {LIGHTGREEN}%s{DEFAULT} is now the leader.");
			Leader = GetSteamAccountID(param1);
			Menu menu2 = new Menu(ChooseFormatHandler);
			menu2.SetTitle("What format?");
			menu2.AddItem("4s", "4s");
			menu2.AddItem("6s", "6s");
			menu2.AddItem("Highlander", "Highlander");
			menu.Display(param1, MENU_TIME_FOREVER);
		}
		else if (StrEqual(info, "no", false))
		{
			delete menu; // TODO: Add in leader choose logic.
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (inPug) inPug = false;
		if (configurePug) configurePug = false;
	}
	else if (action == MenuAction_End)
	{
		if (inPug) inPug = false;
		if (configurePug) configurePug = false;
		delete menu;
	}
}

public int ChooseFormatHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(menu, param1, info, sizeof(info));
		
		Menu menu2 = new Menu(ChooseLeagueHandler);
		menu2.SetTitle("What league?");
		menu2.AddItem("UGC", "UGC");
		if (!StrEqual(info, "4s", false)) menu2.AddItem("ETF2L", "ETF2L");
		if (StrEqual(info, "6s", false))
		{
			menu2.AddItem("ESEA", "ESEA");
			menu2.AddItem("ozfortress", "ozfortress");
			menu2.AddItem("AsiaFortress", "AsiaFortress");
		}
		menu.Display(param1, MENU_TIME_FOREVER);
	}
	else if (action == MenuAction_Cancel)
	{
		if (inPug) inPug = false;
		if (configurePug) configurePug = false;
	}
	else if (action == MenuAction_End)
	{
		if (inPug) inPug = false;
		if (configurePug) configurePug = false;
		delete menu;
	}
}

public int ChooseLeagueHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(menu, param1, info, sizeof(info));
		strcopy(league, sizeof(league), info);
		
		Menu menu2 = new Menu(ChooseMapHandler);
		menu2.SetTitle("What map?");
		char path[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/competitivemaps.ini");
		if (!FileExists(path)) 
		{
			Handle fileHandle = OpenFile(path,"w");
			WriteFileString(fileHandle, "koth_product_rc8");
			CloseHandle(fileHandle);
		}
		Handle fileHandle = OpenFile(path, "r");
		while(!IsEndOfFile(fileHandle) && ReadFileLine(fileHandle,line,sizeof(line)))
		{
			menu2.AddItem(line, line);
		}
		CloseHandle(fileHandle);
		menu.Display(param1, MENU_TIME_FOREVER);
		menu.Display(param1, MENU_TIME_FOREVER);
	}
	else if (action == MenuAction_Cancel)
	{
		if (inPug) inPug = false;
		if (configurePug) configurePug = false;
	}
	else if (action == MenuAction_End)
	{
		if (inPug) inPug = false;
		if (configurePug) configurePug = false;
		delete menu;
	}
}

public int ChooseMapHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(menu, param1, info, sizeof(info));
		strcopy(format, sizeof(format), info);
		
		Menu menu2 = new Menu(ChooseCaptainHandler);
		menu2.SetTitle("Who are the captains?");
		menu.Display(param1, MENU_TIME_FOREVER);
	}
	else if (action == MenuAction_Cancel)
	{
		if (inPug) inPug = false;
		if (configurePug) configurePug = false;
	}
	else if (action == MenuAction_End)
	{
		if (inPug) inPug = false;
		if (configurePug) configurePug = false;
		delete menu;
	}
}

public bool IsValidClient (int client)
{
	if(client > 4096) client = EntRefToEntIndex(client);
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsFakeClient(client)) return false;
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}