#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#undef REQUIRE_PLUGIN
#tryinclude <tf2pyroairjump>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION "1.2.5"

ConVar sm_tf2paj_version;
ConVar sm_tf2paj_enabled;
ConVar sm_tf2paj_prethink;
ConVar sm_tf2paj_zvelocity;

bool bPluginEnabled = true;
bool bOnPreThink = false;
float flZVelocity = 0.0;

float flNextSecondaryAttack[MAXPLAYERS+1];

Handle fwOnPyroAirBlast = INVALID_HANDLE;

public Plugin myinfo = {
	name = "[NGS] Pyro Airblast Jump",
	author = "Leonardo / TheXeon",
	description = "Allows a variable velocity for a pyro to jump off their airblast.",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.servegame.com"
}

public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] strError, int iMaxErrors)
{
    RegPluginLibrary("tf2pyroairjump");
    return APLRes_Success;
}

public void OnPluginStart()
{
	sm_tf2paj_version = CreateConVar("sm_tf2paj_version", PLUGIN_VERSION, "TF2 Pyro Airblast Jump plugin version", FCVAR_NOTIFY|FCVAR_REPLICATED);
	SetConVarString(sm_tf2paj_version, PLUGIN_VERSION, true, true);
	HookConVarChange(sm_tf2paj_version, OnConVarChanged_PluginVersion);
	
	sm_tf2paj_enabled = CreateConVar("sm_tf2paj_enabled", "1", "", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	HookConVarChange(sm_tf2paj_enabled, OnConVarChanged);
	
	sm_tf2paj_prethink = CreateConVar("sm_tf2paj_prethink", "0", "Use OnPreThink instead of OnGameFrame?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	HookConVarChange(sm_tf2paj_prethink, OnConVarChanged);
	
	sm_tf2paj_zvelocity = CreateConVar("sm_tf2paj_zvelocity", "350", "The velocity people are boosted at.");
	HookConVarChange(sm_tf2paj_zvelocity, OnConVarChanged);
	
	char strGameDir[8];
	GetGameFolderName(strGameDir, sizeof(strGameDir));
	if(!StrEqual(strGameDir, "tf", false) && !StrEqual(strGameDir, "tf_beta", false))
		SetFailState("THIS PLUGIN IS FOR TEAM FORTRESS 2 ONLY!");
	
	fwOnPyroAirBlast = CreateGlobalForward("TF2_OnPyroAirBlast", ET_Event, Param_Cell);
	
	for(int i = 0; i <= MAXPLAYERS; i++)
	{
		flNextSecondaryAttack[i] = GetGameTime();
		if(IsValidClient(i))
		{
			if(bOnPreThink)
				SDKHook(i, SDKHook_PreThink, OnPreThink);
			SDKHook(i, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
		}
	}
	AutoExecConfig(true, "pyroairjump");
}

public void OnConVarChanged_PluginVersion(Handle hConVar, const char[] strOldValue, const char[] strNewValue)
{
	if(strcmp(strNewValue, PLUGIN_VERSION, false) != 0)
		SetConVarString(hConVar, PLUGIN_VERSION, true, true);
}		

public void OnConVarChanged(Handle hConVar, const char[] strOldValue, const char[] strNewValue)
{
	OnConfigsExecuted();
}

public void OnConfigsExecuted()
{
	bPluginEnabled = GetConVarBool(sm_tf2paj_enabled);
	bOnPreThink = GetConVarBool(sm_tf2paj_prethink);
	for(int i = 1; i <= MaxClients; i++)
		if(IsValidClient(i))
		{
			if(bOnPreThink)
				SDKHook(i, SDKHook_PreThink, OnPreThink);
			else
				SDKUnhook(i, SDKHook_PreThink, OnPreThink);
		}
	flZVelocity = GetConVarFloat(sm_tf2paj_zvelocity);
}

public void OnClientPutInServer(int iClient)
{
	flNextSecondaryAttack[iClient] = GetGameTime();
	if(bOnPreThink)
		SDKHook(iClient, SDKHook_PreThink, OnPreThink);
	SDKHook(iClient, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
}

public void OnGameFrame()
{
	for(int i = 1; i <= MaxClients; i++)
		if(IsValidClient(i))
			OnPreThink(i);
}

public void OnPreThink(int iClient)
{
	if(!IsPlayerAlive(iClient))
		return;
	
	if(TF2_GetPlayerClass(iClient) != TFClass_Pyro)
		return;

	int iNextTickTime = RoundToNearest(FloatDiv(GetGameTime() , GetTickInterval())) + 5;
	SetEntProp(iClient, Prop_Data, "m_nNextThinkTick", iNextTickTime);
	
	float flSpeed = GetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed");
	if(flSpeed > 0.0 && flSpeed < 5.0)
		return;
	
	if(GetEntProp(iClient, Prop_Data, "m_nWaterLevel") > 1)
		return;
	
	if((GetClientButtons(iClient) & IN_ATTACK2) != IN_ATTACK2)
		return;

	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if(!IsValidEntity(iWeapon))
		return;
	
	char strClassname[32];
	GetEntityClassname(iWeapon, strClassname, sizeof(strClassname));
	if(!StrEqual(strClassname, "tf_weapon_flamethrower", false) && !StrEqual(strClassname, "tf_weapon_rocketlauncher_fireball", false))
		return;
	
	if((GetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack") - flNextSecondaryAttack[iClient]) <= 0.0)
		return;
	flNextSecondaryAttack[iClient] = GetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack");
	
	
	Action result;
	Call_StartForward(fwOnPyroAirBlast);
	Call_PushCell(iClient);
	Call_Finish(result);
	if(result == Plugin_Handled || result == Plugin_Stop)
		return;
	
	if((GetEntityFlags(iClient) & FL_ONGROUND) == FL_ONGROUND)
		return;
	
	if(!bPluginEnabled)
		return;
	
	float vecAngles[3], vecVelocity[3];
	GetClientEyeAngles(iClient, vecAngles);
	GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vecVelocity);
	vecAngles[0] = DegToRad(-1.0 * vecAngles[0]);
	vecAngles[1] = DegToRad(vecAngles[1]);
	vecVelocity[0] -= flZVelocity * Cosine(vecAngles[0]) * Cosine(vecAngles[1]);
	vecVelocity[1] -= flZVelocity * Cosine(vecAngles[0]) * Sine(vecAngles[1]);
	vecVelocity[2] -= flZVelocity * Sine(vecAngles[0]);
	TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vecVelocity);
}

public void OnWeaponSwitchPost(int iClient, int iWeapon)
{
	if(!IsValidClient(iClient) || !IsPlayerAlive(iClient) || !IsValidEntity(iWeapon))
		return;
	
	char strClassname[32];
	GetEntityClassname(iWeapon, strClassname, sizeof(strClassname));
	if(!StrEqual(strClassname, "tf_weapon_flamethrower", false) && !StrEqual(strClassname, "tf_weapon_rocketlauncher_fireball", false))
		return;
	
	flNextSecondaryAttack[iClient] = GetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack");
}

stock bool IsValidClient(int iClient)
{
	if(iClient <= 0) return false;
	if(iClient > MaxClients) return false;
	if(!IsClientConnected(iClient)) return false;
	return IsClientInGame(iClient);
}