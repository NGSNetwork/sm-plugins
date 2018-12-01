/**
* TheXeon
* ngs_hgrlimiter.sp
*
* Files:
* addons/sourcemod/plugins/ngs_hgrlimiter.smx
*
* Dependencies:
* hgr.inc, tf2_stocks.inc, multicolors.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#define SLOT_PRIMARY 0
#define SLOT_SECONDARY 1
#define SLOT_MELEE 2

#include <hgr>
#include <tf2_stocks>
#include <multicolors>
#include <ngsutils>
#include <ngsupdater>

bool inLimit[MAXPLAYERS + 1];

//--------------------//

public Plugin myinfo = {
	name = "[NGS] Hook Nerfer",
	author = "TheXeon",
	description = "Nerfs hooks for donors and above!",
	version = "1.1.1",
	url = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	HookEvent("post_inventory_application", EventInventory);
	LoadTranslations("common.phrases");
}

public Action HGR_OnClientHook(int client)
{
	KillBuildingsAndStrip(client);
	return Plugin_Continue;
}

public Action HGR_OnClientRope(int client)
{
	KillBuildingsAndStrip(client);
	return Plugin_Continue;
}

public void EventInventory(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	inLimit[client] = false;
}

stock void StripToMelee(int client)
{
	if (!IsValidClient(client, true))
	{
		return;
	}
	
	TF2_RemoveWeaponSlot(client, SLOT_PRIMARY);
	TF2_RemoveWeaponSlot(client, SLOT_SECONDARY);
	
	int iWeapon = GetPlayerWeaponSlot(client, SLOT_MELEE);
	if(iWeapon > MaxClients && IsValidEntity(iWeapon))
	{
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iWeapon);
	}
}

stock void KillBuildingsAndStrip(int client)
{
	if (inLimit[client]) return; // A bit of optimization
	if (TF2_GetPlayerClass(client) == TFClass_Engineer)
	{
		int iEnt = -1;
		while ((iEnt = FindEntityByClassname(iEnt, "obj_sentrygun")) != -1)
		{
			if (GetEntPropEnt(iEnt, Prop_Send, "m_hBuilder") == client)
			{
				SetVariantInt(1000);
				AcceptEntityInput(iEnt, "RemoveHealth");
			}
		}
	}
	StripToMelee(client);
	inLimit[client] = true;
	CPrintToChat(client, "{GREEN}[HGR]{DEFAULT} You have been stripped to melee.");
}