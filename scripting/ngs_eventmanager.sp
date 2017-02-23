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

public void OnPluginStart()
{
	RegAdminCmd("sm_startevent", Command_StartEvent, ADMFLAG_GENERIC,"Starts the event");
	RegAdminCmd("sm_stopevent", Command_StopEvent, ADMFLAG_GENERIC, "Closes the joining time for the event");
	RegAdminCmd("sm_setlocation", Command_SetLocation, ADMFLAG_GENERIC, "Set's the location where players will teleport to");
	RegConsoleCmd("sm_joinevent", Command_JoinEvent, "When an event is started, use this to join it!");
}
int eventType = 0;
int eLocationSet = 0;
bool eventStart = false;
float eLocation[3];

public Action Command_StartEvent(int client, int args) {
	if (eventStart == false && eLocationSet == 1) {
			char arg1[15];
			GetCmdArg(1, arg1, sizeof(arg1));
			eventType = StringToInt(arg1);
			if(eventType == 1) {
				eventStart = true;
				PrintToChatAll("\x04[Event]The spycrab event has been started, do !joinevent to join!");
				return Plugin_Handled;
			}
			
			else if(eventType == 2) {
				eventStart = true;
				PrintToChatAll("\x04[Event]The Sharks and Minnows event has been started, do !joinevent to join!");
				return Plugin_Handled;
			}
			
			
	}
	else if (eLocationSet == 0) {
		PrintToChat(client,"\x04[Event]There is no location set.");
		return Plugin_Handled;
	}	
	 else {
		PrintToChat(client, "\x04[Event]There's already an event running!")
		return Plugin_Handled;
	}

	return Plugin_Handled;
}

public Action Command_StopEvent(int client, int args) {
	if (eventStart) {
		PrintToChatAll("\x04[Event]The event joining time is over.");
		eventStart = false;
		eventType = 0;
		eLocationSet = 0;
		return Plugin_Handled;
	} else {
		PrintToChat(client, "\x04[Event]There is no event to stop.");
		return Plugin_Handled;
	}
}

public Action Command_SetLocation(int client, int args) {
	GetClientAbsOrigin(client, eLocation);
	eLocationSet = 1;
	PrintToChat(client, "\x04[Event] Location has been set.");
	return Plugin_Handled;
}

public Action Command_JoinEvent(int client, int args) {
	if (eventStart == true) {
		if (TF2_GetClientTeam(client) == TFTeam_Blue) {
			switch(eventType) {
				case 1: {
					TF2_SetPlayerClass(client, TFClass_Spy);
					TF2_RespawnPlayer(client);
					TeleportEntity(client, eLocation, NULL_VECTOR, NULL_VECTOR);
				}
				
				case 2: {
					TF2_SetPlayerClass(client, TFClass_Scout);
					TF2_RespawnPlayer(client);
					TeleportEntity(client, eLocation, NULL_VECTOR, NULL_VECTOR);
				}
			}
		}
		else {
		PrintToChat(client,"\x04[Event]Please join blue team to join the event.");
		return Plugin_Handled;
		}
	}
	else {
		PrintToChat(client, "\x04[Event]There is no event available to join.");
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

