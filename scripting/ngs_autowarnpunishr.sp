#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>
#include <colorvariables>
#include <sourcebans>
#include <sourcecomms>

#define PLUGIN_VERSION "1.0.0"

ConVar cvarAWPVersion;
Database awpDB;
Menu menuHome, menuPunishments, menuSpecificPunishments, menuTips, menuCommands;
int chatsPunishEscalation[6] =  { 30, 60, 240, 1440, 10080, 0 };
int banPunishEscalation[3] =  { 10080, 0 };

public Plugin myinfo =  {
	name = "[NGS] AutoWarnPunishr", 
	author = "TheXeon", 
	description = "Introduces menu-based administration/escalation to NGS.", 
	version = PLUGIN_VERSION, 
	url = "https://www.neogenesisnetwork.net"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (SQL_CheckConfig("autowarnpunisher"))
		awpDB = SQL_Connect("autowarnpunisher", true, error, err_max);
	else
		awpDB = SQL_Connect("default", true, error, err_max);
	
	if (awpDB == INVALID_HANDLE)
		return APLRes_Failure;
	
	SQL_SetCharset(awpDB, "utf8");
	SQL_TQuery(awpDB, OnTableCreated, "CREATE TABLE IF NOT EXISTS `awp_punishments` (id int(11) NOT NULL AUTO_INCREMENT, auth varchar(32), type varchar(32), number int(11) NOT NULL, PRIMARY KEY (id)) ENGINE=InnoDB  DEFAULT CHARSET=utf8;");
	return APLRes_Success;
}

public void OnTableCreated(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == INVALID_HANDLE)
	{
		SetFailState("Unable to create table. %s", error);
	}
}

public void OnPluginStart()
{
	// Version CVAR and RESET
	cvarAWPVersion = CreateConVar("sm_ngs_autowarnpunishr_version", PLUGIN_VERSION, "Version of the plugin (used in some strings)");
	cvarAWPVersion.AddChangeHook(OnVersionCvarChanged);
	
	// Register commands for menus
	RegAdminCmd("sm_ngsadminmenu", CommandAdminMenuHome, ADMFLAG_GENERIC, "Usage: sm_ngsadminmenu");
	RegAdminCmd("sm_punishr", CommandPunishr, ADMFLAG_GENERIC, "Usage: sm_punishr <#userid|name> type");
	
	
	/******************
	*	  MENUES
	******************/
	
	// Main Menu
	menuHome = new Menu(MenuHomeHandler);
	menuHome.SetTitle("=== NGS Admin Menu ===");
	menuHome.AddItem("punishments", "Punishments!");
	menuHome.AddItem("admincommands", "Available commands!");
	menuHome.AddItem("tips", "Tips and Reminders!");
	
	/******************
	*	 SUBMENUES
	******************/
	
	// Punishments Menu
	menuPunishments = new Menu(PunishmentsMenuHandler);
	menuPunishments.SetTitle("=== NGS Punishments: Choose Broken Rule ===");
	menuPunishments.AddItem("gamemapexploits", "Game/Map Exploits!");
	menuPunishments.AddItem("hackingcheating", "Hacking/Cheating!");
	menuPunishments.AddItem("runningfrombet", "Running from bet!"); // TODO: Make this a tip
	menuPunishments.AddItem("voicetextspam", "Voice/Text Chat Spam)!");
	menuPunishments.AddItem("earrapenondj", "Earrape/Non-DJ Spam!");
	menuPunishments.AddItem("toxicity", "Toxicity (arguments, etc)!");
	menuPunishments.AddItem("cursing", "Cursing (slurs, excessive)!");
	menuPunishments.AddItem("shocksprays", "Shock/illegal-content sprays!");
	menuPunishments.AddItem("conversationtopics", "Political/Religious/etc beliefs!");
	menuPunishments.AddItem("adminimpersionation", "Admin impersonating!");
	menuPunishments.AddItem("begging", "Asking for donations/begging!");
	menuPunishments.AddItem("holdingpaidevents", "Hosting paid events/raffles/etc!");
	menuPunishments.ExitBackButton = true;
	
	// Punishments Sub-Menu (Specifics)
	menuSpecificPunishments = new Menu(PunishmentsSubMenuHandler);
	menuSpecificPunishments.SetTitle("=== NGS Punishments: Specify ===");
	menuSpecificPunishments.ExitBackButton = true;
	
	// Load translations
	LoadTranslations("common.phrases");
}

public void OnVersionCvarChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	convar.SetString(PLUGIN_VERSION);
}

/*******************************************
*										   *
*			    CMD HANDLERS			   *
*										   *
*******************************************/

public Action CommandPunishr(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	
	if (args < 2)
	{
		CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Usage: sm_punishr <#userid|name> type");
		return Plugin_Handled;
	}
	char arg1[MAX_BUFFER_LENGTH], arg2[MAX_BUFFER_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	int target = FindTarget(client, arg1, true, false);
	if (!IsValidClient(target))return Plugin_Handled;
	
	char steamID[MAX_BUFFER_LENGTH], escapedID[MAX_BUFFER_LENGTH], escapedType[MAX_BUFFER_LENGTH], query[MAX_BUFFER_LENGTH];
	DBResultSet dbResult;
	GetClientAuthId(target, AuthId_Steam2, steamID, sizeof(steamID));
	
	SQL_EscapeString(awpDB, steamID, escapedID, sizeof(escapedID));
	SQL_EscapeString(awpDB, arg2, escapedType, sizeof(escapedType));
	
	if (StrEqual("textslur", arg2, false))
	{
		Format(query, sizeof(query), "SELECT number FROM awp_punishments WHERE type='%s' and auth='%s';", escapedType, escapedID);
		dbResult = SQL_Query(awpDB, query);
		if (SQL_GetRowCount(dbResult) < 1)
		{
			Format(query, sizeof(query), "INSERT INTO awp_punishments (auth, type, number) VALUES ('%s', '%s', '1');", escapedID, escapedType);
			SQL_FastQuery(awpDB, query);
		}
		else
		{
			// SQL_TConnect(
		}
	}	
	return Plugin_Handled;
}
	
public Action CommandAdminMenuHome(int client, int args)
{
	if (!IsValidClient(client))return Plugin_Handled;
	menuHome.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

/*******************************************
*										   *
*			  MENUES HANDLERS			   *
*										   *
*******************************************/
	
// Main menu handler
public int MenuHomeHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		if (StrEqual(info, "punishments", false))
			menuPunishments.Display(param1, MENU_TIME_FOREVER);
		else if (StrEqual(info, "admincommands", false))
			menuCommands.Display(param1, MENU_TIME_FOREVER); // TODO: Actually make menuCommands CommandIterator
		else if (StrEqual(info, "tips", false))
			menuTips.Display(param1, MENU_TIME_FOREVER);
	}
	// no delete because reuse of handle
}
	
public int PunishmentsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		menuHome.Display(param1, MENU_TIME_FOREVER);
	}
	else if (action == MenuAction_Select)
	{
		menuSpecificPunishments.RemoveAllItems();
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		if (StrEqual("gamemapexploits", info))
		{
			menuSpecificPunishments.AddItem("gameexploit", "Game Exploit!");
			menuSpecificPunishments.AddItem("mapexploit", "Map Exploit!");
		}
		else if (StrEqual("hackingcheating", info))
		{
			
		}
		menuSpecificPunishments.Display(param1, MENU_TIME_FOREVER);
	}
	// no delete because reuse of handle
}

public int PunishmentsSubMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	// TODO: Make it separate
	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		menuHome.Display(param1, MENU_TIME_FOREVER);
	}
	else if (action == MenuAction_Select)
	{
		menuSpecificPunishments.RemoveAllItems();
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		if (StrEqual("gamemapexploits", info))
		{
			menuSpecificPunishments.AddItem("gameexploit", "Game Exploit!");
			menuSpecificPunishments.AddItem("mapexploit", "Map Exploit!");
		}
		else if (StrEqual("hackingcheating", info))
		{
			
		}
		menuSpecificPunishments.Display(param1, MENU_TIME_FOREVER);
	}
	// no delete because reuse of handle
}

public bool IsValidClient(int client)
{
	if (client > 4096)client = EntRefToEntIndex(client);
	if (client < 1 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	if (IsFakeClient(client))return false;
	if (GetEntProp(client, Prop_Send, "m_bIsCoaching"))return false;
	return true;
}
	