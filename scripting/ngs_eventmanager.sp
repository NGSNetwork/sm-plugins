#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <sdktools>
#include <morecolors>

bool eLocationSet = false;
bool eventStart = false;
int eventType = 0;
float eLocation[3];

Menu eventMenu;
Menu startEventMenu;
Menu disableMenu;

ConVar necromashEnable;

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
	RegAdminCmd("sm_startevent", Command_StartEvent, ADMFLAG_GENERIC,"Starts the event. 1 for spycrab, 2 for sharks and minnows.");
	RegAdminCmd("sm_stopevent", Command_StopEvent, ADMFLAG_GENERIC, "Closes the joining time for the event");
	RegAdminCmd("sm_setlocation", Command_SetLocation, ADMFLAG_GENERIC, "Set's the location where players will teleport to");
	RegAdminCmd("sm_event", Command_EventMenu, ADMFLAG_GENERIC, "Menu interface for event manager plugin");
	RegAdminCmd("sm_eventmenu", Command_EventMenu, ADMFLAG_GENERIC, "Menu interface for event manager plugin");
	RegConsoleCmd("sm_joinevent", Command_JoinEvent, "When an event is started, use this to join it!");
	
	// Menus
	eventMenu = new Menu(EventMenuHandler);
	eventMenu.SetTitle("=== Event Menu ===");
	eventMenu.AddItem("startevent", "Start an event");
	eventMenu.AddItem("stopevent", "Stop event");
	eventMenu.AddItem("disablestuff", "Disable stuff");
	
	startEventMenu = new Menu(StartEventMenuHandler);
	startEventMenu.SetTitle("=== Event Types ===");
	startEventMenu.AddItem("spycrab", "Spycrab");
	startEventMenu.AddItem("minnows", "Sharks and Minnows");
	SetMenuExitBackButton(startEventMenu, true);
	
	disableMenu = new Menu(DisableMenuHandler);
	disableMenu.SetTitle("=== Disable Things ===");
	disableMenu.AddItem("stopsmash", "Disable necrosmash");
	SetMenuExitBackButton(disableMenu, true);
	
	// ConVar Hooks
	necromashEnable = FindConVar("sm_necromash_enable");
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

public Action Command_StartEvent(int client, int args)
{
	if (!eventStart && eLocationSet)
	{
		char arg1[15];
		GetCmdArg(1, arg1, sizeof(arg1));
		eventType = StringToInt(arg1);
		if(args < 1)
		{
			CPrintToChat(client, "{GREEN}[Event]{DEFAULT} After !startevent, please enter 1 for spycrab, or 2 for sharks and minnows");
			return Plugin_Handled;
		}
		switch(eventType)
		{
			case 1:
			{
				eventStart = true;
				CPrintToChatAll("{GREEN}[Event]{DEFAULT} The Spycrab event has been started, do !joinevent to join!");				
			}
			
			case 2:
			{
				eventStart = true;
				CPrintToChatAll("{GREEN}[Event]{DEFAULT} The Sharks and Minnows event has been started, do !joinevent to join!");
			}
		}
	}
	else if (!eLocationSet)
	{
		CPrintToChat(client,"{GREEN}[Event]{DEFAULT} There is no location set.");
	}	
	else
	{
		CPrintToChat(client, "{GREEN}[Event]{DEFAULT} There's already an event running!");
	}

	return Plugin_Handled;
}

public Action Command_StopEvent(int client, int args)
{
	if (eventStart)
	{
		CPrintToChatAll("{GREEN}[Event]{DEFAULT} The event joining time is over.");
		eventStart = false;
		eventType = 0;
	} 
	else
	{
		CPrintToChat(client, "{GREEN}[Event]{DEFAULT} There is no event to stop.");
	}
	return Plugin_Handled;
}

public Action Command_SetLocation(int client, int args)
{
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
			switch(eventType)
			{
				case 1:
				{
					TF2_RespawnPlayer(client);
					TF2_SetPlayerClass(client, TFClass_Spy, true, true);
					TF2_RespawnPlayer(client);
					TF2_RemoveWeaponSlot(client, 0);
					TF2_RemoveWeaponSlot(client, 1);
					TeleportEntity(client, eLocation, NULL_VECTOR, NULL_VECTOR);
				}
				
				case 2:
				{
					TF2_RespawnPlayer(client);
					TF2_SetPlayerClass(client, TFClass_Scout, true, true);
					TF2_RespawnPlayer(client);
					TF2_RemoveWeaponSlot(client, 0);
					TF2_RemoveWeaponSlot(client, 1);
					TeleportEntity(client, eLocation, NULL_VECTOR, NULL_VECTOR);
				}
			}
		}
		else
		{
			CPrintToChat(client,"{GREEN}[Event]{DEFAULT} Please join blue team to join the event.");
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
			startEventMenu.Display(param1, MENU_TIME_FOREVER);
		else if (StrEqual(info, "stopevent", false))
			FakeClientCommand(param1, "sm_stopevent");
		else if(StrEqual(info, "disablestuff", false)) 
			disableMenu.Display(param1, MENU_TIME_FOREVER);
	}
}

public int StartEventMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		startEventMenu.GetItem(param2, info, sizeof(info));
		if (StrEqual(info, "spycrab", false))
			FakeClientCommand(param1, "sm_startevent 1");
		else if (StrEqual(info, "minnows", false))
			FakeClientCommand(param1, "sm_startevent 2");
	}
}

public int DisableMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select) 
	{
		char info[32];
		disableMenu.GetItem(param2, info, sizeof(info));
		if(StrEqual(info, "stopsmash", false))
		{
			if (necromashEnable.BoolValue) necromashEnable.SetInt(0);
			else necromashEnable.SetInt(1);
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

public void DisableMenuBuilder()
{
	disableMenu.RemoveAllItems();
	char necromashStatus[MAX_BUFFER_LENGTH];
	Format(necromashStatus, sizeof(necromashStatus), "Necromash: %s", necromashEnable.BoolValue ? "Enabled" : "Disabled");
	disableMenu.AddItem("stopsmash", necromashStatus);
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