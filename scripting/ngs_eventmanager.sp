#include <sourcemod>
#include <tf2_stocks>
#include <sdktools>

public Plugin myinfo = 
{
	name = "Event Manager",
	author = "EasyE",
	description = "Event manager made for ngs",
	version = "1",
	url = "https://neogenesisnetwork.net/"
};
/*General description on how the plugin works:
	First, the player with admin privileges types !setlocation, the players position is then stored for later use.
	Then !startevent (1 for spycrab, 2 for sharks and minnows) advertises in the chat to type !joinevent
	The players that type !joinevent will be set to the proper class, and teleported to the event location. If
	they are on red team, they will be told to join blu(May change in later version of the plugin)
	!stopevent can be used to prevent players from joining the event.
*/

//Declaring variables for later use
bool eLocationSet = false;
bool eventStart = false;
int eventType = 0;
float eLocation[3];

Menu eventMenu;
Menu startMenu;

public void OnPluginStart()
{
	RegAdminCmd("sm_startevent", Command_StartEvent, ADMFLAG_GENERIC,"Starts the event. 1 for spycrab, 2 for sharks and minnows.");
	RegAdminCmd("sm_stopevent", Command_StopEvent, ADMFLAG_GENERIC, "Closes the joining time for the event");
	RegAdminCmd("sm_setlocation", Command_SetLocation, ADMFLAG_GENERIC, "Set's the location where players will teleport to");
	RegAdminCmd("sm_event", EventMenu, ADMFLAG_GENERIC, "Menu interface for event manager plugin");
	RegConsoleCmd("sm_joinevent", Command_JoinEvent, "When an event is started, use this to join it!");
	
	eventMenu = new Menu(EventMenuHandler);
	eventMenu.SetTitle("=== Event Menu ===");
	eventMenu.AddItem("setlocation", "Set event location");
	eventMenu.AddItem("startevent", "Start an event");
	eventMenu.AddItem("stopevent", "Stop event");
	
	startMenu = new Menu(StartMenuHandler);
	startMenu.SetTitle("=== Event Types ===");
	startMenu.AddItem("spycrab", "Spycrab");
	startMenu.AddItem("minnows", "Sharks and Minnowss");
}

public Action EventMenu(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	eventMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int EventMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	char info[32]
	eventMenu.GetItem(param2, info, sizeof(info));
	if (StrEqual(info, "setlocation", false)) {
		FakeClientCommand(param1, "sm_setlocation");
		eventMenu.Display(param1, MENU_TIME_FOREVER);
	}
	else if (StrEqual(info, "startevent", false)) {
		startMenu.Display(param1, MENU_TIME_FOREVER);
	}
	else if (StrEqual(info, "stopevent", false)) {
		FakeClientCommand(param1, "sm_stopevent");
	}
}

public int StartMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	char info[32]
	startMenu.GetItem(param2, info, sizeof(info));
	if (StrEqual(info, "spycrab", false)) {
		FakeClientCommand(param1, "sm_startevent 1");
	}
	else if(StrEqual(info, "minnows", false)) {
		FakeClientCommand(param1, "sm_startevent 2");
	}
}
/*Startevent:
	First, a check to see if an event is already running is done, if so it warns the player and stops the command.
	Then another check to see if a location has been set, if it hasn't, it warns the player and stops the command.
	If the player entered no arguments, it tells them to enter 1 for spycrab and 2 for sharks and minnows, then stops the command.
	Then, a switch case is run to advertise the correct event.
	
*/
public Action Command_StartEvent(int client, int args) {
	if (eventStart == false && eLocationSet) {
			char arg1[15];
			GetCmdArg(1, arg1, sizeof(arg1));
			eventType = StringToInt(arg1);
			if(args < 1) {
				PrintToChat(client, "\x04[Event] After !startevent, please enter 1 for spycrab, or 2 for sharks and minnows");
				return Plugin_Handled;
			}
			switch(eventType) {
				case 1: {
					eventStart = true;
					PrintToChatAll("\x04[Event] The spycrab event has been started, do !joinevent to join!");
					return Plugin_Handled;					
				}
				
				case 2: {
					eventStart = true;
					PrintToChatAll("\x04[Event] The Sharks and Minnows event has been started, do !joinevent to join!");
					return Plugin_Handled;	
				}
			}
	}
	else if (eLocationSet == false) {
		PrintToChat(client,"\x04[Event] There is no location set.");
		return Plugin_Handled;
	}	
	 else {
		PrintToChat(client, "\x04[Event] There's already an event running!")
		return Plugin_Handled;
	}

	return Plugin_Handled;
}
/*Stopevent:
	Prevents players from using !joinevent, but does not do anything to the players already joined.
*/
public Action Command_StopEvent(int client, int args) {
	if (eventStart) {
		PrintToChatAll("\x04[Event] The event joining time is over.");
		eventStart = false;
		eventType = 0;
		return Plugin_Handled;
	} else {
		PrintToChat(client, "\x04[Event] There is no event to stop.");
		return Plugin_Handled;
	}
}
/*Setlocation:
	Stores the players current location in eLocation, where the players will be teleported to.
	Also sets eLocationSet to true allowing !startevent to be run
*/
public Action Command_SetLocation(int client, int args) {
	GetClientAbsOrigin(client, eLocation);
	eLocationSet = true;
	PrintToChat(client, "\x04[Event] Location has been set.");
	return Plugin_Handled;
}
/*Joinevent:
	Checks if an event is available to join, if their are none, the player is warned and the command is stopped.
	If the player is on red, they are told to join blu, and the command is stopped.
	The function check client checks to see if they are a valid client.
	Switch case is run to set the players class, strip the appropiate weapons, equips the right one, and teleports the player to event location.
*/
public Action Command_JoinEvent(int client, int args) {
	if (eventStart == true) {
		if (TF2_GetClientTeam(client) == TFTeam_Blue) {
			switch(eventType) {
				case 1: {
					CheckClient(client);
					TF2_RespawnPlayer(client);
					TF2_SetPlayerClass(client, TFClass_Spy);
					TF2_RespawnPlayer(client);
					TF2_RemoveWeaponSlot(client, 0);
					TF2_RemoveWeaponSlot(client, 1);
					TeleportEntity(client, eLocation, NULL_VECTOR, NULL_VECTOR);
					return Plugin_Handled;
				}
				
				case 2: {
					CheckClient(client);
					TF2_RespawnPlayer(client);
					TF2_SetPlayerClass(client, TFClass_Scout);
					TF2_RespawnPlayer(client);
					TF2_RemoveWeaponSlot(client, 0);
					TF2_RemoveWeaponSlot(client, 1);
					TeleportEntity(client, eLocation, NULL_VECTOR, NULL_VECTOR);
					return Plugin_Handled;
				}
			}
		}
		else {
		PrintToChat(client,"\x04[Event] Please join blue team to join the event.");
		return Plugin_Handled;
		}
	}
	else {
		PrintToChat(client, "\x04[Event] There is no event available to join.");
		return Plugin_Handled;
	}
	return Plugin_Handled;
}


public void CheckClient(int client)
{
	if (IsValidClient(client) == false) return;
}

public bool IsValidClient (int client)
{
	if(client > 4096)
	{
		client = EntRefToEntIndex(client);
	}

	if(client < 1 || client > MaxClients) return false;

	if(!IsClientInGame(client)) return false;

	if(IsFakeClient(client)) return false;

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;

	return true;

}