/**
* TheXeon
* ngs_donor_toolkit.sp
*
* Files:
* addons/sourcemod/plugins/ngs_donor_toolkit.smx
*
* Dependencies:
* sourcemod.inc, tf2attributes.inc, multicolors.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <sourcemod>
#include <tf2attributes>
#include <multicolors>
#include <ngsutils>
#include <ngsupdater>

bool VoicesEnabled[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[NGS] Donor/VIP Tools",
	author = "TheXeon",
	description = "VIP commands for NGS people.",
	version = "1.0.1",
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
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if (VoicesEnabled[client]) TF2Attrib_SetByName(client, "SPELL: Halloween voice modulation", 1.0);
}
