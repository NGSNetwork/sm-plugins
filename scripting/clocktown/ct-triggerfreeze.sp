#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION  "1.0.1"

int g_Immune[MAXPLAYERS+1];
int g_Frozen[MAXPLAYERS+1];
int g_InTrigger[MAXPLAYERS+1];
int g_ModelId[MAXPLAYERS+1];
float g_fFreezeTime[MAXPLAYERS+1];

Handle g_UnfreezeTimer[MAXPLAYERS+1];

ConVar g_cImmuneTime;
float g_fImmuneTime;

ConVar g_cModel;
char g_sModel[64];

ConVar g_cSound;
char g_sSound[64];

ConVar g_cEndSound;
char g_sEndSound[64];

public Plugin myinfo = {
	name = "[NGS] Trigger Freeze",
	author = "Panzer / TheXeon",
	description = "Replicates the frozen condition from Zelda OoT",
	version = PLUGIN_VERSION,
	url = "forums.alliedmodders.com"
}

public void OnPluginStart()
{
	// Cvars
	g_cImmuneTime = CreateConVar("sm_freeze_immunity_time", "2.0", "Sets the freeze immunity time");
	g_cModel = CreateConVar("sm_freeze_model", "models/majoras_mask/common/iceblock/mm_iceblock.mdl", "Sets the freeze model");
	g_cSound = CreateConVar("sm_freeze_start_sound", "majoras_mask/common/player_freeze.wav", "Sets the freeze start sound");
	g_cEndSound = CreateConVar("sm_freeze_end_sound", "majoras_mask/common/player_unfreeze.wav", "Sets the freeze end sound");
	
	// Hooks
	HookEntityOutput("trigger_multiple", "OnStartTouch", OnStartTouch);
	HookEntityOutput("trigger_multiple", "OnEndTouch", OnEndTouch);
	HookEvent("player_death", Event_PlayerDeath);
	HookConVarChange(g_cImmuneTime, ConVarChanged_TriggerFreeze);
}

public void Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (g_UnfreezeTimer[client] != INVALID_HANDLE)
	{
		CloseHandle(g_UnfreezeTimer[client]);
		g_UnfreezeTimer[client] = INVALID_HANDLE;
	}
	
	if (g_Frozen[client] && g_ModelId[client] != 0)
	{
		if (IsValidEdict(g_ModelId[client]))
			RemoveEdict(g_ModelId[client]);
			
		g_Frozen[client] = 0;
		g_ModelId[client] = -1;
		g_Immune[client] = 0;
		g_InTrigger[client] = 0;
		
		// Play sound
		float pos[3];
		GetClientEyePosition(client, pos);
		EmitSoundToAll(g_sEndSound, client, _);
	}
}

public void OnConfigsExecuted()
{
	g_fImmuneTime = GetConVarFloat(g_cImmuneTime);
	GetConVarString(g_cModel, g_sModel, sizeof(g_sModel));
	GetConVarString(g_cSound, g_sSound, sizeof(g_sSound));
	GetConVarString(g_cEndSound, g_sEndSound, sizeof(g_sEndSound));
	if (!StrEqual(g_sSound, ""))
		PrecacheSound(g_sSound);
	if (!StrEqual(g_sEndSound, ""))
		PrecacheSound(g_sEndSound);
}

public void ConVarChanged_TriggerFreeze(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cImmuneTime) 
		g_fImmuneTime = GetConVarFloat(g_cImmuneTime);
	else if (convar == g_cModel)
		GetConVarString(g_cModel, g_sModel, sizeof(g_sModel));
	else if (convar == g_cSound)
	{
		GetConVarString(g_cSound, g_sSound, sizeof(g_sSound));
		PrecacheSound(g_sSound);
	}
	else if (convar == g_cEndSound)
	{
		GetConVarString(g_cEndSound, g_sEndSound, sizeof(g_sEndSound));
		PrecacheSound(g_sEndSound);
	}
}

public void OnStartTouch(const char[] output, int caller, int activator, float delay)
{
	if (IsValidClient(activator) && IsPlayerAlive(activator))
	{
		// Get trigger targetname
		char triggerName[64];
		GetEntPropString(caller, Prop_Data, "m_iName", triggerName, sizeof(triggerName));
		
		// Store the targetname string in separate values
		char freezeVals[2][32];
		ExplodeString(triggerName, " ", freezeVals, sizeof(freezeVals), sizeof(freezeVals[]));
		
		// Freeze/Unfreeze the player
		if (StrEqual(freezeVals[0], "freeze"))
		{
			g_InTrigger[activator] = 1;
			g_fFreezeTime[activator] = StringToFloat(freezeVals[1]);
		}
		else if (StrEqual(freezeVals[0], "unfreeze"))
			Unfreeze(activator);
	}
}

public void OnEndTouch(const char[] output, int caller, int activator, float delay)
{
	g_InTrigger[activator] = 0;
	g_fFreezeTime[activator] = 0.0;
}

public void OnGameFrame()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidClient(client) && IsPlayerAlive(client))
		{
			if (!g_Immune[client] && g_InTrigger[client])
			{
				Freeze(client, g_fFreezeTime[client]);
				float pos[3];
				GetClientAbsOrigin(client, pos);
				g_ModelId[client] = SpawnProp(pos);
			}
			if (g_Frozen[client])
				SetEntPropFloat(client, Prop_Data, "m_flNextAttack", 9999999.0);
		}
	}
}

int SpawnProp(float pos[3])
{
	int ent = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(ent, "model", g_sModel);
	DispatchKeyValue(ent, "solid", "6");
	DispatchSpawn(ent);
	TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
	SetEntityMoveType(ent, MOVETYPE_VPHYSICS);
	return ent;
}  

void Freeze(int client, float time)
{
	// Don't freeze the player if they are immune
	if (g_Immune[client] == 1)
		return;
		
	// Give immunity/freeze
	g_Immune[client] = 1;
	g_Frozen[client] = 1;

	// Stop player
	SetEntityMoveType(client, MOVETYPE_NONE);
	
	// Play sound
	float pos[3];
	GetClientEyePosition(client, pos);
	EmitSoundToAll(g_sSound, client, _);

	// Create unfreeze timer
	g_UnfreezeTimer[client] = CreateTimer(time, Timer_Unfreeze, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Unfreeze(Handle timer, any client)
{
	if (g_Frozen[client])
	{
		Unfreeze(client);
		g_Frozen[client] = 0;
		CreateTimer(g_fImmuneTime, Timer_RemoveImmunity, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_RemoveImmunity(Handle timer, any client)
{
	g_Immune[client] = 0;
}

void Unfreeze(int client)
{
	if (IsClientInGame(client))
	{
		// Unfreeze
		SetEntityMoveType(client, MOVETYPE_WALK);
		SetEntPropFloat(client, Prop_Data, "m_flNextAttack", 0.0);
		
		// Reset velocity
		float vel[3] = {0.0, 0.0, 0.0};
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
		
		// Play sound
		float pos[3];
		GetClientEyePosition(client, pos);
		EmitSoundToAll(g_sEndSound, client, _);
		
		// Remove prop
		if (IsValidEdict(g_ModelId[client]))
			RemoveEdict(g_ModelId[client]);
		g_ModelId[client] = -1;
	}
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