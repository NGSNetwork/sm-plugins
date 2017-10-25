#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>
#define PLUGIN_VERSION "1.0.3"

ConVar BleedChance;
//new Handle:BleedTime;

public Plugin myinfo = {
	name             = "[TF2] Chance Break Bottle",
	author         = "DarthNinja / TheXeon",
	description     = "Chance for bottles to break.",
	version         = PLUGIN_VERSION,
	url             = "DarthNinja.com"
};

public void OnPluginStart( )
{
	CreateConVar("sm_bbb_version", PLUGIN_VERSION, "TF2 Player Stats", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	BleedChance = CreateConVar("sm_bbb_chance", "0.6", "Chance to inflict bleed, 1.00 = 100%, 0.50 = 50%, etc");
	//BleedTime = CreateConVar("sm_bbb_time", "5.0", "Seconds to inflict bleed for", FCVAR_PLUGIN);

	// RegAdminCmd("sm_break", BottleBreak, ADMFLAG_SLAY, "Breaks your Bottle");

	//Lateload support
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
	}

	LoadTranslations("common.phrases");
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (damagetype == 4 || !IsValidClient(victim) || !IsValidClient(attacker) || victim == attacker)
		return Plugin_Continue;	//Bleed Damage

	float iBleedChance = BleedChance.FloatValue;
	float iRoll = GetRandomFloat();
	if (iBleedChance >= iRoll)
	{
		int iWeapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon"); //Bottle should still be active if it was just used
		if (!IsValidEntity(iWeapon))
			return Plugin_Continue;
			
		int iItemID = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
		
		if (iItemID != 1 && iItemID != 191)
			return Plugin_Continue;	//Not a bottle
		
		if (GetEntProp(iWeapon, Prop_Send, "m_bBroken") != 1)
			SetEntProp(iWeapon, Prop_Send, "m_bBroken", 1);	//Bottle isnt broken
	}
	return Plugin_Continue;
}
/*
public Action:BottleBreak(client, args)
{
	if (!IsClientInGame(client))
	{
		ReplyToCommand(client, "You must be ingame!");
		return Plugin_Handled;
	}

	//	1	= Bottle
	//	191	= Upgradeable Bottle

	//new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	new iWeapon = GetPlayerWeaponSlot(client, 2);
	new iItemID = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");

	if (iItemID != 1 && iItemID != 191)
	{
		ReplyToCommand(client, "You do not have a bottle to break!");
		return Plugin_Handled;
	}

	ReplyToCommand(client, "Your bottle has been broken!");
	SetEntProp(iWeapon, Prop_Send, "m_bBroken", 1)
	return Plugin_Handled;
}*/

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