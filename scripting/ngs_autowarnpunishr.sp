#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>
#include <morecolors>
#include <sourcebans>
#include <sourcecomms>

#define PLUGIN_VERSION "1.0.0"

ConVar cvarAWPVersion;
Menu menuHome, menuPunishments, menuSpecificPunishments, menuTips;
int[] chatsSpamEscalation =  { 20, 30, 60, 1440, 10080, 0 };

//--------------------//

public Plugin myinfo = {
	name = "[NGS] AutoWarnPunishr",
	author = "TheXeon",
	description = "Introduces menu-based administration/escalation to NGS.",
	version = PLUGIN_VERSION,
	url = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	// Version CVAR and RESET
	cvarAWPVersion = CreateConVar("sm_ngs_autowarnpunishr_version", PLUGIN_VERSION, "Version of the plugin (used in some strings)");
	cvarAWPVersion.AddChangeHook(OnVersionCvarChanged);
	
	// Register commands for menus
	RegAdminCmd("sm_ngsadminmenu", CommandAdminMenuHome, ADMFLAG_GENERIC, "Usage: sm_ngsadminmenu");
	
	/*******************************************
	*
	*					MENUES
	*
	*******************************************/
	
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

public void OnClientPutInServer(int client)
{ 
	VoicesEnabled[client] = false; 
}

public Action CommandAdminMenuHome(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
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
			serverCommandsMainMenu.Display(param1, MENU_TIME_FOREVER);
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
		menuSpecificPunishments.Display(param1, MENU_TIME_FOREVER);
	}
	// no delete because reuse of handle
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
