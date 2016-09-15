#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "1.1"
#define GRAPPLER 1152

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

ConVar cEnabled;
bool bEnabled;

public Plugin myinfo = {
	name = "[NGS] Grappling Hook Restrictor",
	author = "Tak (Chaosxk) / TheXeon",
	description = "Allow grappling hook for donators only.",
	version = PLUGIN_VERSION,
	url = "https://matespastdates.servegame.com"
}

public void OnPluginStart()
{
	CreateConVar("sm_donorgrappler_version", "Version for donor grappler.", PLUGIN_VERSION, FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY);
	
	cEnabled = FindConVar("tf_grapplinghook_enable");
	
	cEnabled.AddChangeHook(OnConvarChanged);
	
	ExecuteLateLoad();
}

public void OnConfigsExecuted()
{
	bEnabled = cEnabled.BoolValue;
	//Removes grappler is plugin is late-loaded/refreshed during gameplay
	RemoveGrappler();
}

public void OnConvarChanged(Handle convar, char[] oldValue, char[] newValue) 
{
	if (StrEqual(oldValue, newValue, true))
		return;
		
	int iNewValue = !!StringToInt(newValue);
	
	if(convar == cEnabled)
	{
		bEnabled = view_as<bool>(iNewValue);
		RemoveGrappler();
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
}

public void ExecuteLateLoad()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
		SDKHook(i, SDKHook_WeaponCanUse, OnWeaponCanUse);
	}
}

public Action OnWeaponCanUse(int client, int weapon)
{
	if(!bEnabled)
		return Plugin_Continue;
	int index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");	
	
	if(index == GRAPPLER && !CheckCommandAccess(client, "sm_vipgrappler_override", ADMFLAG_RESERVATION, false))
		return Plugin_Handled;
		
	return Plugin_Continue;
}

public void RemoveGrappler()
{
	if(!bEnabled)
		return;
		
	//Can i get the grappling hook with GetClientWeaponSlot? Doesn't seem to work.
	int entity;
	while((entity = FindEntityByClassname(entity, "tf_weapon_grapplinghook")) != -1)
	{
		int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if(!CheckCommandAccess(owner, "sm_vipgrappler_override", ADMFLAG_RESERVATION, false))
		{
			SDKHooks_DropWeapon(owner, entity, NULL_VECTOR, NULL_VECTOR);
			AcceptEntityInput(entity, "kill");
		}
	}
}



/*
#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "1.1"
#define GRAPPLER 1152

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <friendly>

ConVar cEnabled;
bool bEnabled;

public Plugin myinfo = {
	name = "[NGS] Grappling Hook Restrictor",
	author = "Tak (Chaosxk) / TheXeon",
	description = "Allow grappling hook for donators only.",
	version = PLUGIN_VERSION,
	url = "https://matespastdates.servegame.com"
}

public void OnPluginStart()
{
	CreateConVar("sm_donorgrappler_version", "Version for donor grappler.", PLUGIN_VERSION, FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY);
	
	cEnabled = FindConVar("tf_grapplinghook_enable");
	
	cEnabled.AddChangeHook(OnConvarChanged);
	
	HookEvent("post_inventory_application", Event_RemoveGrapplingHook,  EventHookMode_Post);
}

public void OnConvarChanged(Handle convar, char[] oldValue, char[] newValue) 
{
	if (StrEqual(oldValue, newValue, true))
		return;
		
	int iNewValue = !!StringToInt(newValue);
	
	if(convar == cEnabled)
	{
		bEnabled = view_as<bool>(iNewValue);
	}
}

public void Event_RemoveGrapplingHook(Handle hEvent, char[] strName, bool bDontBroadcast) 
{ 
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid")); 
	if (!bEnabled || !IsValidClient(iClient)) return; 
	if (TF2Friendly_IsFriendly(iClient)) return;

	for (int iSlot = 0; iSlot < 8; iSlot++) 
	{ 
		int iWeapon = GetPlayerWeaponSlot(iClient, iSlot); 
		if (IsValidEntity(iWeapon) && GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") == GRAPPLER) 
		{ 
			SDKHooks_DropWeapon(iClient, iWeapon, NULL_VECTOR, NULL_VECTOR);
			AcceptEntityInput(iWeapon, "kill");
			break; 
		} 
	}
}

public bool IsValidClient (int client)
{
	if(client > 4096) client = EntRefToEntIndex(client);
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsFakeClient(client)) return false;
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}

*/