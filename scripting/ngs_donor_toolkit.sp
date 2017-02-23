#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2attributes>
#include <morecolors>

#define PLUGIN_VERSION "1.0.0"

bool VoicesEnabled[MAXPLAYERS + 1];

//--------------------//

public Plugin myinfo = {
	name = "[NGS] VIP Tools",
	author = "TheXeon",
	description = "VIP commands for NGS people.",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.net"
}

public void OnPluginStart()
{
	RegAdminCmd("sm_voices", CommandVoices, ADMFLAG_RESERVATION, "Usage: sm_voices");
	HookEvent("post_inventory_application", OnPostInventoryApplication);
	LoadTranslations("common.phrases");
}

public void OnClientPutInServer(int client)
{ 
	VoicesEnabled[client] = false; 
}

public Action CommandVoices(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	VoicesEnabled[client] = !VoicesEnabled[client];
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Halloween voices %s!", VoicesEnabled[client] ? "enabled" : "disabled");
	if (VoicesEnabled[client]) TF2Attrib_SetByName(client, "SPELL: Halloween voice modulation", 1.0);
	else TF2Attrib_RemoveByName(client, "SPELL: Halloween voice modulation");
	return Plugin_Handled;
}

public void OnPostInventoryApplication(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (VoicesEnabled[client]) TF2Attrib_SetByName(client, "SPELL: Halloween voice modulation", 1.0);
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
