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
Menu menuHome, menuPunishments, menuSpecificPunishments, menuTips, menuCommands, menuPlayerSelect;
int chatsPunishEscalation[16] =  {30, 60, 240, 1440, 10080, 0};
int banPunishEscalation[16] =  {10080, 0};

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
		Database.Connect(OnDatabaseConnected, "autowarnpunisher");
	else
		Database.Connect(OnDatabaseConnected, "default");
	return APLRes_Success;
}

public void OnDatabaseConnected(Database db, const char[] error, any data)
{
	if (db == null)
	{
		SetFailState("Could not connect to AutoWarnPunishr DB: %s", error);
	}
	else
	{
		awpDB = db;
		awpDB.SetCharset("utf8");
		awpDB.Query(OnGenericTableCreated, "CREATE TABLE IF NOT EXISTS `awp_players` (id int(11) NOT NULL AUTO_INCREMENT, auth varchar(32), type varchar(32), number int(11) NOT NULL, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
		awpDB.Query(OnGenericTableCreated, "CREATE TABLE IF NOT EXISTS `awp_punishments` (index int(11) NOT NULL AUTO_INCREMENT, type varchar(32) NOT NULL, category varchar(32) NOT NULL, countedByCategory int(1), use varchar(32) NOT NULL, command varchar(128), enabled int(1), PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
		awpDB.Query(OnCategoriesTableCreated, "CREATE TABLE IF NOT EXISTS `awp_categories` (index int(11) NOT NULL AUTO_INCREMENT, category varchar(32), displayname varchar(32), escalation varchar(128), enabled int(1), PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
	}
}

public void OnGenericTableCreated(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		SetFailState("Unable to create table: %s", error);
	}
}

public void OnCategoriesTableCreated(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		SetFailState("Unable to create table: %s", error);
	}
	db.Query(OnQueryCategories, "SELECT * FROM `awp_categories` ORDER BY `index` ASC");
}

public void OnQueryCategories(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		SetFailState("Unable to query database. %s", error);
	}
	
	// Punishments Menu
	menuPunishments = new Menu(PunishmentsMenuHandler);
	menuPunishments.SetTitle("=== NGS Punishments: Choose Category ===");
	menuPunishments.ExitBackButton = true;
	char info[32], displayName[32];
	while (results.FetchRow())
	{
		if (!results.FetchInt(3)) continue;
		results.FetchString(1, info, sizeof(info));
		results.FetchString(2, displayName, sizeof(displayName));
		menuPunishments.AddItem(info, displayName);
	}
}

//public void OnQueryPlayerPunishments(Database db, DBResultSet results, const char[] error, any data) THIS IS FOR BUILDING THE SUBMENU
//{
//	if (results == null)
//	{
//		SetFailState("Unable to query database. %s", error);
//	}
//	
//	// Punishments Menu
//	menuPunishments = new Menu(PunishmentsMenuHandler);
//	menuPunishments.SetTitle("=== NGS Punishments: Choose Category ===");
//	menuPunishments.ExitBackButton = true;
//	char info[32], displayName[32];
//	while (results.FetchRow())
//	{
//		if (!results.FetchInt(3)) continue;
//		results.FetchString(1, info, sizeof(info));
//		results.FetchString(2, displayName, sizeof(displayName));
//		menuPunishments.AddItem(info, displayName);
//	}
//}

public void OnQueryPlayerPunishments(Database db, DBResultSet results, const char[] error, DataPack data)
{
	if (results == null)
	{
		SetFailState("Unable to query database. %s", error);
	}
	char type[32], steamID[32];
	int punishmentEscalation = results.AffectedRows;
	data.Reset();
	int userid = data.ReadCell();
	data.ReadString(type, sizeof(type));
	data.ReadString(steamID, sizeof(steamID));
	delete data;
	
	// if (!IsValidClient(GetClientOfUserId(userid))) return; // TODO: Invalid client handling
	
	DataPack pack = new DataPack();
	pack.WriteCell(userid);
	pack.WriteString(type);
	pack.WriteCell(punishmentEscalation);
	pack.WriteString(steamID);
	
	char query[128];
	Format(query, sizeof(query), "SELECT * FROM awp_punishments WHERE type='%s';", type);
	db.Query(OnGetPunishmentTypeInfo, query, pack);
	delete data;
}

public void OnGetPunishmentTypeInfo(Database db, DBResultSet results, const char[] error, DataPack data)
{
	if (results == null)
	{
		SetFailState("Unable to query database. %s", error);
	}
	data.Reset();
	
	char type[32], steamID[32];
	int userid = data.ReadCell();
	data.ReadString(type, sizeof(type));
	int punishmentEscalation = data.ReadCell();
	data.ReadString(steamID, sizeof(steamID));
	delete data;
	
	if (!results.AffectedRows)
	{
		SetFailState("Could not find type info for type [%s]!", type);
	}
	
	char category[32];
	results.FetchRow();
	results.FetchString(2, category, sizeof(category));
	
	DataPack pack = new DataPack();
	pack.WriteCell(userid);
	pack.WriteString(type);
	pack.WriteCell(punishmentEscalation);
	pack.WriteString(category);
	pack.WriteString(steamID);
	
	char query[128];
	Format(query, sizeof(query), "SELECT * FROM awp_categories WHERE category='%s';", category);
	db.Query(OnGetCategoryInfo, query, pack);
}

public void OnGetCategoryInfo(Database db, DBResultSet results, const char[] error, DataPack data)
{
	if (results == null)
	{
		SetFailState("Unable to query database. %s", error);
	}
	data.Reset();
	
	char type[32], steamID[32], category[32];
	int userid = data.ReadCell();
	data.ReadString(type, sizeof(type));
	int punishmentEscalation = data.ReadCell();
	data.ReadString(category, sizeof(category));
	data.ReadString(steamID, sizeof(steamID));
	delete data;
	
	if (!results.AffectedRows)
	{
		SetFailState("Could not find category info for category [%s] type [%s]!", category, type);
	}
	
	
	char escalation[128], escalationSplit[32][128];
	results.FetchRow();
	if (!results.FetchInt(4))
	{
		LogMessage("This punishment is not enabled!");
		return;
	}
	results.FetchString(3, escalation, sizeof(escalation));
	int numStrings = ExplodeString(escalation, ",", escalationSplit, sizeof(escalationSplit), sizeof(escalationSplit[]));
	if (!numStrings)
	{
		LogError("There was no escalation found for category [%s]!", category);
		return;
	}
	
	int time = StringToInt(escalationSplit[punishmentEscalation]);
	if (StrEqual(escalationSplit[punishmentEscalation], "0") || time) // If they explicitly meant 0 or some time was given
	{
		// I dont know what to do here since I didnt get any info, rip me
	}
	else // fire out an event for keyword handling
	{
		
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
	
//	menuPunishments.AddItem("gamemapexploits", "Game/Map Exploits!");
//	menuPunishments.AddItem("hackingcheating", "Hacking/Cheating!");
//	menuPunishments.AddItem("runningfrombet", "Running from bet!"); // TODO: Make this a tip
//	menuPunishments.AddItem("voicetextspam", "Voice/Text Chat Spam)!");
//	menuPunishments.AddItem("earrapenondj", "Earrape/Non-DJ Spam!");
//	menuPunishments.AddItem("toxicity", "Toxicity (arguments, etc)!");
//	menuPunishments.AddItem("cursing", "Cursing (slurs, excessive)!");
//	menuPunishments.AddItem("shocksprays", "Shock/illegal-content sprays!");
//	menuPunishments.AddItem("conversationtopics", "Political/Religious/etc beliefs!");
//	menuPunishments.AddItem("adminimpersionation", "Admin impersonating!");
//	menuPunishments.AddItem("begging", "Asking for donations/begging!");
//	menuPunishments.AddItem("holdingpaidevents", "Hosting paid events/raffles/etc!");

	// Punishments Sub-Menu (Specifics)
//	menuSpecificPunishments = new Menu(PunishmentsSubMenuHandler);
//	menuSpecificPunishments.SetTitle("=== NGS Punishments: Specify ===");
//	menuSpecificPunishments.ExitBackButton = true;
//	
//	menuPlayerSelect = new Menu(PlayerSelectSubMenuHandler);
//	for (int i = 1; i <= MaxClients; i++)
//	{
//		if (IsValidClient(i))
//		{
//			char name[48], userID[16];
//			Format(userID, sizeof(userID), "%d", GetClientUserId(i));
//			Format(name, sizeof(name), "%N (%s)", i, userID);
//			menuPlayerSelect.AddItem(userID, name);
//		}
//	}
	
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
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_punishr <#userid|name> type");
		return Plugin_Handled;
	}
	char arg1[MAX_BUFFER_LENGTH], arg2[MAX_BUFFER_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	int target = FindTarget(client, arg1, true, false);
	if (!IsValidClient(target)) return Plugin_Handled;
	
	char steamID[MAX_BUFFER_LENGTH], escapedType[MAX_BUFFER_LENGTH], query[MAX_BUFFER_LENGTH];
	GetClientAuthId(target, AuthId_Steam2, steamID, sizeof(steamID));
	
	awpDB.Escape(arg2, escapedType, sizeof(escapedType));
	
	Format(query, sizeof(query), "SELECT * FROM awp_players WHERE type='%s' and auth='%s';", escapedType, steamID);
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(target));
	pack.WriteString(escapedType);
	pack.WriteString(steamID);
	awpDB.Query(OnQueryPlayerPunishments, query, pack);
//	if (SQL_GetRowCount(dbResult) < 1)
//	{
//		Format(query, sizeof(query), "INSERT INTO awp_punishments (auth, type, number) VALUES ('%s', '%s', '1');", escapedID, escapedType);
//		SQL_FastQuery(awpDB, query);
//	}
	return Plugin_Handled;
}
	
public Action CommandAdminMenuHome(int client, int args)
{
	if (!IsValidClient(client))return Plugin_Handled;
	menuHome.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

/********************************************
*                                           *
*              MENU HANDLERS                *
*                                           *
********************************************/
	
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
			// SourceBans_BanPlayer(param1, 
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