#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>

#define VERSION "2.1"

public Plugin myinfo = {
	name = "[NGS] Killstreak",
	author = "Dr_Knuckles / Kredit / TheXeon",
	description = "Killstreak value toggler/changer",
	version = VERSION
};

ConVar hKillstreakAmount = null;
bool KSToggle[MAXPLAYERS + 1] = {};
int KSAmount[MAXPLAYERS + 1] = {};

//clientprefs
Handle hKSToggleCookie = null;
Handle hKSAmountCookie = null;

public OnPluginStart() {
	RegConsoleCmd("sm_ks", CommandKillstreak, "Set your killstreak.");
	RegConsoleCmd("sm_kson", CommandKillstreakToggleOn, "Enable plugin's killstreak.");
	RegConsoleCmd("sm_ksoff", CommandKillstreakToggleOff, "Disable plugin's killstreak.");
	hKSToggleCookie = RegClientCookie("killstreak_kstoggle", "Killstreak Toggle", CookieAccess_Protected);
	hKSAmountCookie = RegClientCookie("killstreak_ksamount", "Killstreak Amount", CookieAccess_Protected);

	hKillstreakAmount = CreateConVar("sm_killstreak_amount", "10", "Default Killstreak Amount", FCVAR_PLUGIN|FCVAR_NOTIFY);
	AutoExecConfig();
	CreateConVar("sm_ks_version", VERSION, "Killstreak modifier", FCVAR_PLUGIN|FCVAR_NOTIFY);
	HookEvent("player_spawn", Event_Spawn);

	for (int i = MaxClients; i > 0; --i) {
		if (!AreClientCookiesCached(i)) continue;
		OnClientCookiesCached(i);
	}
}

public OnClientCookiesCached(client) {
	int KSAmountValue = 0;
	bool bKSToggleValue = false;

	if (AreClientCookiesCached(client)) {
		//Get KSToggle boolean from clientprefs (if it exists)
		char sKSToggleCookieValue[5];
		GetClientCookie(client, hKSToggleCookie, sKSToggleCookieValue, sizeof(sKSToggleCookieValue));
		bKSToggleValue = StrEqual(sKSToggleCookieValue, "true");

		//Get KSAmount int from clientprefs (if it exists)
		char sKSAmountCookieValue[4];
		GetClientCookie(client, hKSAmountCookie, sKSAmountCookieValue, sizeof(sKSAmountCookieValue));
		KSAmountValue = StringToInt(sKSAmountCookieValue);
	}

	//Load them into local memory (faster)
	KSToggle[client] = bKSToggleValue;
	KSAmount[client] = KSAmountValue;

	refreshKillstreak(client);
}

public void OnClientDisconnect(client) {
	if (IsClientInGame(client)) {
		char sToggleValue[5];
		char sAmountValue[4];

		sToggleValue = KSToggle[client] ? "true" : "false";
		IntToString(KSAmount[client], sAmountValue, sizeof(sAmountValue));

		//Save clientprefs on disconnect
		SetClientCookie(client, hKSToggleCookie, sToggleValue);
		SetClientCookie(client, hKSAmountCookie, sAmountValue);
	}
}

public Action CommandKillstreak(client, args) {
	if(IsClientInGame(client) && IsPlayerAlive(client)) {
		char sAmount[4];
		GetCmdArg(1, sAmount, sizeof(sAmount));

		//Initialize amount to whatever the convar is
		KSAmount[client] = GetConVarInt(hKillstreakAmount);

		//If there's an argument for sm_ks, use that value instead
		if(strlen(sAmount) > 0) {
			KSToggle[client] = true;
			KSAmount[client] = StringToInt(sAmount);
			//but keep it between 0 and 100
			if(KSAmount[client] > 100) {
				KSAmount[client] = 100;
			}
			if(KSAmount[client] < 0) KSAmount[client] = 0;
		}
		//If there isn't an argument, invert the toggle
		else {
			KSToggle[client] = true;
		}
		
		//If the client set their killstreak to 0
		if(KSAmount[client] == 0) {
			KSToggle[client] = false;
		}

		//Update killstreak amount if the plugin is disabled
		if(!KSToggle[client]) {
			KSAmount[client] = 0;
		}

		//Set killstreak to argument value
		refreshKillstreak(client);

		//nofity client of changes
		if(KSAmount[client] > 0) {
			PrintToChat(client, "[SM] Killstreak set to %d.", KSAmount[client]);
		}
		else {
			PrintToChat(client, "[SM] Killstreak reset.");
		}
	}
	return Plugin_Handled;
}

public Action CommandKillstreakToggleOn(client, args) {
	if(IsClientInGame(client) && IsPlayerAlive(client)) 
	{
		//Initialize amount to whatever the convar is
		KSAmount[client] = GetConVarInt(hKillstreakAmount);
		KSToggle[client] = true;
		
		//Update killstreak amount if the plugin is disabled
		if(!KSToggle[client]) {
			KSAmount[client] = 0;
		}

		//Set killstreak to argument value
		refreshKillstreak(client);

		//nofity client of changes
		PrintToChat(client, "[SM] Killstreak set to %d.", KSAmount[client]);
	}
	return Plugin_Handled;
}

public Action CommandKillstreakToggleOff(client, args) {
	if(IsClientInGame(client) && IsPlayerAlive(client)) 
	{
		//Set to 0
		KSAmount[client] = 0;
		KSToggle[client] = false;

		//Set killstreak to argument value
		refreshKillstreak(client);

		//nofity client of changes
		PrintToChat(client, "[SM] Killstreak reset.");
	}
	return Plugin_Handled;
}

public Event_Spawn(Handle hEvent, char[] sName, bool bNoBroadcast) {
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (IsClientInGame(client) && IsPlayerAlive(client)) {
		refreshKillstreak(client);
	}
}

public refreshKillstreak(client) {
	if(IsValidEntity(client) && IsClientInGame(client) && !IsFakeClient(client)) {
		if(KSToggle[client] || KSAmount[client] == 0) {
			SetEntProp(client, Prop_Send, "m_nStreaks", KSAmount[client], _, 0);
		}
	}
}