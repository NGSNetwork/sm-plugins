#include <sourcemod>
#include <tf2_stocks>
#include <sdktools>
#include <timers>
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
int eLocationSet = 0;
int eventStart = 0;
new Float:eLocation[3];


public Action Command_StartEvent(int client, int args) {
	if (eventStart == 0 && eLocationSet == 1) {
		if (eLocationSet == 1){
			eventStart = 1;
			PrintToChatAll("\x04[Event]The spycrab event has been started, do !JoinEvent to join!");
			return Plugin_Handled;
		}
		else {
			PrintToChat(client,"\x04[Event]There is no location set.");
			return Plugin_Handled;
	}
	} else {
		PrintToChat(client, "\x04[Event]There's already an event running!")
		return Plugin_Handled;
	}
}

public Action Command_StopEvent(int client, int args) {
	if ( eventStart == 1) {
		PrintToChatAll("\x04[Event]The event joining time is over.");
		eventStart = 0;
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
	if (eventStart == 1) {
		if(TF2_GetClientTeam(client) == TFTeam_Blue) {
		TF2_SetPlayerClass(client, TFClass_Spy);
		TF2_RespawnPlayer(client);
		
		TeleportEntity(client, eLocation, NULL_VECTOR, NULL_VECTOR);
		return Plugin_Handled;
		
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
	
}

