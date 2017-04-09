#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <sdktools>
#include <morecolors>

bool eLocationSet = false;
bool eventStart = false;
bool s1 = false;
bool s2 = false;
bool s3 = false;
bool s4 = false;
bool s5 = false;
int eventClass = 1;
float eLocation[3];

Menu eventMenu;
Menu configureEventMenu;
Menu stripMenu;
Menu disableMenu;

ConVar funstuffEnable;

public Plugin myinfo = {
	name = "Event Manager",
	author = "EasyE / TheXeon",
	description = "Events plugin for NGS",
	version = "1.0.5",
	url = "https://neogenesisnetwork.net/"
}


public void OnPluginStart()
{
	// Commands
	RegAdminCmd("sm_stopevent", Command_StopEvent, ADMFLAG_GENERIC, "Closes the joining time for the event");
	RegAdminCmd("sm_setlocation", Command_SetLocation, ADMFLAG_GENERIC, "Set's the location where players will teleport to");
	RegAdminCmd("sm_event", Command_EventMenu, ADMFLAG_GENERIC, "Menu interface for event manager plugin");
	RegAdminCmd("sm_eventmenu", Command_EventMenu, ADMFLAG_GENERIC, "Menu interface for event manager plugin");
	RegConsoleCmd("sm_joinevent", Command_JoinEvent, "When an event is started, use this to join it!");
	
	// Menus
	eventMenu = new Menu(EventMenuHandler);
	eventMenu.SetTitle("=== Event Menu ===");
	eventMenu.AddItem("startevent", "Start an event");
	eventMenu.AddItem("configureevent", "Congifure event settings");
	eventMenu.AddItem("stopevent", "Stop event");
	eventMenu.AddItem("disablestuff", "Disable stuff");
	
	configureEventMenu = new Menu(ConfigureMenuHandler);
	configureEventMenu.SetTitle("=== Event Types ===");
	ConfigureMenuBuilder();
	SetMenuExitBackButton(configureEventMenu, true);
	
	stripMenu = new Menu(StripMenuHandler);
	stripMenu.SetTitle("=== Strip Weapons ===");
	StripMenuBuilder();
	SetMenuExitBackButton(stripMenu, true);
	
	disableMenu = new Menu(DisableMenuHandler);
	disableMenu.SetTitle("=== Disable Things ===");
	SetMenuExitBackButton(disableMenu, true);
	
	// ConVars
	funstuffEnable = CreateConVar("sm_funstuff_enable", "1", "Disables/enables interupting fun stuff items");
}

public void OnAllPluginsLoaded()
{
	DisableMenuBuilder();
}
/********************************************
			Command Callbacks
********************************************/

public Action Command_EventMenu(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	eventMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public Action Command_StopEvent(int client, int args)
{
	if (eventStart)
	{
		CPrintToChatAll("{GREEN}[Event]{DEFAULT} The event joining time is over.");
		eventStart = false;
	} 
	else
	{
		CPrintToChat(client, "{GREEN}[Event]{DEFAULT} There is no event to stop.");
	}
	return Plugin_Handled;
}

public Action Command_SetLocation(int client, int args)
{
	if(eventStart) {
		CPrintToChatAll("{GREEN}[Event]{Default} You can not modify event parameters while an event is running");
		return Plugin_Handled;
	}
	GetClientAbsOrigin(client, eLocation);
	eLocationSet = true;
	CReplyToCommand(client, "{GREEN}[Event]{DEFAULT} Location has been set.");
	return Plugin_Handled;
}

public Action Command_JoinEvent(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	if (eventStart)
	{
		if (TF2_GetClientTeam(client) == TFTeam_Blue)
		{
			SetEventClass(client);
			WeaponStripper(client);
			TeleportEntity(client, eLocation, NULL_VECTOR, NULL_VECTOR);
		}
		else
		{
			CPrintToChat(client,"{GREEN}[Event]{DEFAULT} Please join blu team to join the event.");
		}
	}
	else
	{
		CPrintToChat(client, "{GREEN}[Event]{DEFAULT} There is no event available to join.");
	}
	return Plugin_Handled;
}


/********************************************
			Menu Handlers
********************************************/

public int EventMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		eventMenu.GetItem(param2, info, sizeof(info));
		if (StrEqual(info, "startevent", false))
		{
			if (eventStart == true) 
				CPrintToChat(param1, "{GREEN}[Event]{Default} There is already an event running.");
			else if(eLocationSet == false) 
				CPrintToChat(param1, "{GREEN}[Event]{Default} Event location has not been set.");
			else
			{
				CPrintToChatAll("{GREEN}[Event]{Default} An event has been started, do !joinevent to join!");
				eventStart = true;
			}
		}
			
		if (StrEqual(info, "configureevent", false))
			configureEventMenu.Display(param1, MENU_TIME_FOREVER);
		else if (StrEqual(info, "stopevent", false))
			FakeClientCommand(param1, "sm_stopevent");
		else if(StrEqual(info, "disablestuff", false)) 
			disableMenu.Display(param1, MENU_TIME_FOREVER);
	}
}

public int ConfigureMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		configureEventMenu.GetItem(param2, info, sizeof(info));
		if (StrEqual(info, "setlocation", false))
		{
			FakeClientCommand(param1, "sm_setlocation");
			configureEventMenu.Display(param1, MENU_TIME_FOREVER);	
		}
		if (StrEqual(info, "class", false))
		{
			if(eventStart == false)
			{			
				if (eventClass < 9)eventClass = eventClass + 1;
				else eventClass = 1;
				ConfigureMenuBuilder();
				configureEventMenu.Display(param1, MENU_TIME_FOREVER);
			}
			else
			{
				CPrintToChat(param1, "{GREEN}[Event]{Default} You can not modify event parameters while an event is running.");
				configureEventMenu.Display(param1, MENU_TIME_FOREVER);
			}
		}
		if (StrEqual(info, "stripmenu", false))stripMenu.Display(param1, MENU_TIME_FOREVER);
		if (StrEqual(info, "startevent", false))
		{
			if (eventStart == true) 
				CPrintToChat(param1, "{GREEN}[Event]{Default} There is already an event running.");
			else if(eLocationSet == false) 
				CPrintToChat(param1, "{GREEN}[Event]{Default} Event location has not been set.");
			else
			{
				CPrintToChatAll("{GREEN}[Event]{Default} An event has been started, do !joinevent to join!");
				eventStart = true;
			}
		}
	}
}

public int StripMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		stripMenu.GetItem(param2, info, sizeof(info));
		if (StrEqual(info, "strip1", false))
		{
			if (s1)s1 = false;
			else s1 = true;
		}
		if (StrEqual(info, "strip2", false))
		{
			if (s2)s2 = false;
			else s2 = true;
		}
		if (StrEqual(info, "strip3", false))
		{
			if (s3)s3 = false;
			else s3 = true;
		}
		if (StrEqual(info, "strip4", false))
		{
			if (s4)s4 = false;
			else s4 = true;
		}
		if (StrEqual(info, "strip5", false))
		{
			if (s5)s5 = false;
			else s5 = true;
		}
		StripMenuBuilder();
		stripMenu.Display(param1, MENU_TIME_FOREVER);
	}
}
public int DisableMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select) 
	{
		char info[32];
		disableMenu.GetItem(param2, info, sizeof(info));
		if(StrEqual(info, "stopfun", false))
		{
			if (funstuffEnable.BoolValue) funstuffEnable.SetInt(0);
			else funstuffEnable.SetInt(1);
			DisableMenuBuilder();
			disableMenu.Display(param1, MENU_TIME_FOREVER);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		eventMenu.Display(param1, MENU_TIME_FOREVER);
	}
}


/********************************************
				Extras
********************************************/


public void SetEventClass(int client)
{
	TF2_RespawnPlayer(client);
	switch(eventClass) {
		case 1: {
			TF2_SetPlayerClass(client, TFClass_Scout);
		}
		case 2: {
			TF2_SetPlayerClass(client, TFClass_Soldier);
		}
		case 3: {
			TF2_SetPlayerClass(client, TFClass_Pyro);
		}
		case 4: {
			TF2_SetPlayerClass(client, TFClass_DemoMan);
		}
		case 5: {
			TF2_SetPlayerClass(client, TFClass_Heavy);
		}
		case 6: {
			TF2_SetPlayerClass(client, TFClass_Engineer);
		}
		case 7: {
			TF2_SetPlayerClass(client, TFClass_Medic);
		}
		case 8: {
			TF2_SetPlayerClass(client, TFClass_Sniper);
		}
		case 9: {
			TF2_SetPlayerClass(client, TFClass_Spy);
		}
	}
	TF2_RespawnPlayer(client);
}

public void WeaponStripper(int client)
{
	if (s1)TF2_RemoveWeaponSlot(client, 0);
	if (s2)TF2_RemoveWeaponSlot(client, 1);
	if (s3)TF2_RemoveWeaponSlot(client, 2);
	if (s4)TF2_RemoveWeaponSlot(client, 3);
	if (s5)TF2_RemoveWeaponSlot(client, 4);
}

public void DisableMenuBuilder()
{
	disableMenu.RemoveAllItems();
	char funstuffStatus[24];
	Format(funstuffStatus, sizeof(funstuffStatus), "funstuff: %s", funstuffEnable.BoolValue ? "Enabled" : "Disabled");
	disableMenu.AddItem("stopfun", funstuffStatus);
}

public void ConfigureMenuBuilder()
{
	configureEventMenu.RemoveAllItems();
	configureEventMenu.AddItem("setlocation", "Set event location");
	switch(eventClass) {
		case 1:	{
			configureEventMenu.AddItem("class", "Select class: Scout");
		}
		case 2: {
			configureEventMenu.AddItem("class", "Select class: Soldier");
		}
		case 3:	{
			configureEventMenu.AddItem("class", "Select class: Pyro");
		}
		case 4:	{
			configureEventMenu.AddItem("class", "Select class: Demo");
		}
		case 5:	{
			configureEventMenu.AddItem("class", "Select class: Heavy");
		}
		case 6:	{
			configureEventMenu.AddItem("class", "Select class: Engineer");
		}
		case 7:	{
			configureEventMenu.AddItem("class", "Select class: Medic");
		}
		case 8:	{
			configureEventMenu.AddItem("class", "Select class: Sniper");
		}
		case 9:	{
			configureEventMenu.AddItem("class", "Select class: Spy");
		}
	}
	configureEventMenu.AddItem("stripmenu", "Strip weapons");
	configureEventMenu.AddItem("startevent", "Start an event");
}

public void StripMenuBuilder()
{
	stripMenu.RemoveAllItems();
	char strip1Status[32], strip2Status[32], strip3Status[32], strip4Status[32], strip5Status[32];
	Format(strip1Status, sizeof(strip1Status), "Strip primary: %s", s1 ? "Enabled" : "Disabled");
	Format(strip2Status, sizeof(strip2Status), "Strip secondary: %s", s2 ? "Enabled" : "Disabled");
	Format(strip3Status, sizeof(strip3Status), "Strip melee: %s", s3 ? "Enabled" : "Disabled");
	Format(strip4Status, sizeof(strip4Status), "Strip PDA1: %s", s4 ? "Enabled" : "Disabled");
	Format(strip5Status, sizeof(strip5Status), "Strip PDA2: %s", s5 ? "Enabled" : "Disabled");
	
	stripMenu.AddItem("strip1", strip1Status);
	stripMenu.AddItem("strip2", strip2Status);
	stripMenu.AddItem("strip3", strip3Status);
	stripMenu.AddItem("strip4", strip4Status);
	stripMenu.AddItem("strip5", strip5Status);
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