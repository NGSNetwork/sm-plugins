#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION  "1.0.0"

public Plugin myinfo = {
	name = "[NGS] Store Additions",
	author = "TheXeon",
	description = "Restart the server automagically :D",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.net/"
}

ConVar cvarEnabled;
ConVar cvarUptimeRequirement;
Handle autoRestartTimer;

public void OnPluginStart()
{
	cvarEnabled = CreateConVar("sm_ngsar_enabled", "1", "Enable autorestart on no players.", 0, true, 0.0, true, 1.0);
	cvarUptimeRequirement = CreateConVar("sm_ngsar_uptime_requirement", "16", "How many hours the server should have since first connection to allow a restart.");
	AutoExecConfig(true, "autorestart");
}

public void OnClientPostAdminCheck(int client)
{
	if (autoRestartTimer != null && IsValidClient(client))
	{
		KillTimer(autoRestartTimer);
		autoRestartTimer = null;
	}
}

public void OnClientDisconnect_Post(int client)
{
	if (cvarEnabled.BoolValue && GetClientCount() == 0 && RoundToZero(GetGameTime() / 3600) > cvarUptimeRequirement.IntValue)
	{
		autoRestartTimer = CreateTimer(30.0, AutoRestartTimer);
	}
}

public Action AutoRestartTimer(Handle timer, any dummy)
{
	ServerCommand("_restart");
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