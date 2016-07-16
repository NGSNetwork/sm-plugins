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

public Action OnWeaponCanUse(int client, int weapon)
{
	if(!bEnabled)
		return Plugin_Continue;
	int index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	char playername[MAX_NAME_LENGTH];
	GetClientName(client, playername, sizeof(playername));
	
	if(index == GRAPPLER && !CheckCommandAccess(client, "sm_vipgrappler_override", ADMFLAG_RESERVATION, false) && StrContains(playername, "ngs", false) == -1)
		return Plugin_Handled;
		
	return Plugin_Continue;
}

void ExecuteLateLoad()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
		SDKHook(i, SDKHook_WeaponCanUse, OnWeaponCanUse);
	}
}

void RemoveGrappler()
{
	if(!bEnabled)
		return;
		
	//Can i get the grappling hook with GetClientWeaponSlot? Doesn't seem to work.
	int entity;
	while((entity = FindEntityByClassname(entity, "tf_weapon_grapplinghook")) != -1)
	{
		int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		char playername[MAX_NAME_LENGTH];
		GetClientName(owner, playername, sizeof(playername));
		if(!CheckCommandAccess(owner, "sm_vipgrappler_override", ADMFLAG_RESERVATION, false) && StrContains(playername, "ngs", false) == -1)
		{
			SDKHooks_DropWeapon(owner, entity, NULL_VECTOR, NULL_VECTOR);
			AcceptEntityInput(entity, "kill");
		}
	}
}