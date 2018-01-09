#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2items>
#include <tf2_stocks>
#include <friendly>
#include <multicolors>

#tryinclude <steamtools>

#define PLUGIN_NAME		 	"[NGS] PortalMod Gun"
#define PLUGIN_AUTHOR	   	"Erreur 500 / TheXeon"
#define PLUGIN_DESCRIPTION	"Play tf2 with portalgun !"
#define PLUGIN_VERSION	  	"1.0"
#define PLUGIN_CONTACT	  	"https://www.neogenesisnetwork.net"

#define PORTAL				"models/portals/portal.mdl"
#define PORTALGUN_CLASSNAME	"tf_weapon_pistol_scout"
#define	PORTALGUN_OLD_ID	23
#define PORTALGUN_ID		"9876"



int g_iViewModelp, FlagImmunity = -1;
int PlayerTeam[MAXPLAYERS+1] 		= {-1, ...};		// Player team

bool IsChell[MAXPLAYERS+1]		= {false, ...};		// Is player have the PortalGun
bool ChellClass[9]				= {true, ...};
bool CanAttack[MAXPLAYERS+1]	= {true, ...};		// Can use left-click ?
bool CanAttack2[MAXPLAYERS+1]	= {true, ...};		// Can use right-click ?
bool CanTP[MAXPLAYERS+1]		= {true, ...};		// Allow player to be teleported.

ConVar cvarEnabled, cvarBreakable, cvarPerLife, cvarOnlyMine, cvarWall, cvarProp, cvarFlag, cvarPortalHealth, cvarClass[9];
#if defined _steamtools_included 
ConVar cvarGameDesc;
#endif


enum PortalInfo
{
	ID,
	Float:vec_Angle[3],
	Float:vec_Pos[3],
	Float:P_Health,
}

int g_Portal[MAXPLAYERS+1][2][PortalInfo];


public Plugin myinfo = {
	name		= PLUGIN_NAME,
	author	  	= PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version	 	= PLUGIN_VERSION,
	url		 	= PLUGIN_CONTACT
}

public void OnPluginStart()
{
	LogMessage("[PORTALMOD] Loading ...");
	
	CreateConVar("portalgun_version", PLUGIN_VERSION, "portalgun version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	cvarEnabled  = CreateConVar("portalgun_enable", 	"1", 	"Enable or disable portalgun ?", 0, true, 0.0, true, 1.0);
	cvarBreakable = CreateConVar("portalgun_breakable", "1", 	"Projectiles can destroy portals.", 0, true, 0.0, true, 1.0);
	cvarPortalHealth = CreateConVar("portalgun_health", "500", 	"Amount of portal health.", 0, true, 0.0);
	cvarPerLife	  = CreateConVar("portalgun_per_life",	"1", 	"Destroy player portals when he dies", 0, true, 0.0, true, 1.0);
	cvarOnlyMine  = CreateConVar("portalgun_only_mine",	"1", 	"Player can only use their own portals", 0, true, 0.0, true, 1.0);
	cvarWall  	  = CreateConVar("portalgun_wall",		"1.0", 	"Pourcentage (1.0 to 0.1) to check if the wall is plane. (0.0 = no check)", 0, true, 0.0, true, 1.0);
	cvarProp  	  = CreateConVar("portalgun_prop",		"0", 	"Can spawn portal on prop_dynamic and prop_physics?", 0, true, 0.0, true, 1.0);
	
	cvarFlag	  = CreateConVar("portalgun_flag", 		"a", 	"Flag allow to receive the portalgun (else -1)", 0);
	cvarClass[0]  = CreateConVar("portalgun_scout", 	"1", 	"Can scout receive the portalgun?", 0, true, 0.0, true, 1.0);
	cvarClass[1]  = CreateConVar("portalgun_sniper", 	"1", 	"Can sniper receive the portalgun?", 0, true, 0.0, true, 1.0);
	cvarClass[2]  = CreateConVar("portalgun_soldier", 	"1", 	"Can soldier receive the portalgun?", 0, true, 0.0, true, 1.0);
	cvarClass[3]  = CreateConVar("portalgun_demoman", 	"1", 	"Can demoman receive the portalgun?", 0, true, 0.0, true, 1.0);
	cvarClass[4]  = CreateConVar("portalgun_medic", 	"1", 	"Can medic receive the portalgun?", 0, true, 0.0, true, 1.0);
	cvarClass[5]  = CreateConVar("portalgun_heavy", 	"1", 	"Can heavy receive the portalgun?", 0, true, 0.0, true, 1.0);
	cvarClass[6]  = CreateConVar("portalgun_pyro", 		"1", 	"Can pyro receive the portalgun?", 0, true, 0.0, true, 1.0);
	cvarClass[7]  = CreateConVar("portalgun_spy", 		"1", 	"Can spy receive the portalgun?", 0, true, 0.0, true, 1.0);
	cvarClass[8]  = CreateConVar("portalgun_engineer", 	"1", 	"Can engineer receive the portalgun?", 0, true, 0.0, true, 1.0);
	
#if defined _steamtools_included 
	cvarGameDesc = CreateConVar("portalgun_game_desc", 	"1", 	"Change game description as PortalMod ?", 0, true, 0.0, true, 1.0);
#endif

	RegAdminCmd("sm_portalgun", GivePortalGun, ADMFLAG_RESERVATION, "Give Portal Gun");
	
	RegAdminCmd("sm_portalmod_reset", ResetPlugin, ADMFLAG_ROOT, "Reset all portals.");
	
	for(int i=0; i<9; i++)
		ChellClass[i] = GetConVarBool(cvarClass[i]);
	
	
	HookConVarChange(cvarFlag, CallBackCVarFlag);
	HookConVarChange(cvarClass[0], CallBackCVarClassScout);
	HookConVarChange(cvarClass[1], CallBackCVarClassSniper);
	HookConVarChange(cvarClass[2], CallBackCVarClassSoldier);
	HookConVarChange(cvarClass[3], CallBackCVarClassDemo);
	HookConVarChange(cvarClass[4], CallBackCVarClassMedic);
	HookConVarChange(cvarClass[5], CallBackCVarClassHeavy);
	HookConVarChange(cvarClass[6], CallBackCVarClassPyro);
	HookConVarChange(cvarClass[7], CallBackCVarClassSpy);
	HookConVarChange(cvarClass[8], CallBackCVarClassEngi);
	
	int iSpawn = -1;
	while ((iSpawn = FindEntityByClassname(iSpawn, "func_respawnroom")) != -1)
		SDKHook(iSpawn, SDKHook_StartTouch, SpawnStartTouch);
	
	HookEvent("player_spawn", EventPlayerSpawn);
	HookEvent("player_death", EventPlayerDeath);
	HookEvent("post_inventory_application", EventPlayerInventory);
	HookEvent("teamplay_round_start", EventRoundStart, EventHookMode_Pre);
	HookEvent("player_changeclass", EventPlayerchangeclass);
	HookEvent("player_team", EventPlayerTeamPost);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	#if defined _steamtools_included
	MarkNativeAsOptional("Steam_SetGameDescription");
	#endif
	
	CreateNative("GiveClientPortalGun", Native_GiveClientPortalGun);
	CreateNative("IsClientHasPortalGun", Native_IsClientHasPortalGun);
	CreateNative("RemoveClientPortalGun", Native_RemoveClientPortalGun);
	CreateNative("GetClientPortalEntRef", Native_GetClientPortalEntRef);
	
	return APLRes_Success;
}

public void OnPluginEnd()
{
	for (int i = 0; i < MaxClients; i++)
		for (int j=0; j < 2; j++)
			if(IsPortal(g_Portal[i][j][ID]))
				RemoveEdict(EntRefToEntIndex(g_Portal[i][j][ID]));
				
	for(int i = 1; i < MaxClients; i++)
		if(IsValidClient(i) && IsChell[i])
			RemovePortalGun(i);
}

public void CallBackCVarEnabled(ConVar cvar, char[] oldVal, char[] newVal)
{
	if(StrEqual(newVal, "0"))
	{
		LogMessage("[PORTALMOD] Disable !");
		OnPluginEnd();
	}
	else
	{
		LogMessage("[PORTALMOD] Enabled !");
		Initialisation(true);
	}
}

public void CallBackCVarFlag(ConVar cvar, char[] oldVal, char[] newVal)
{
	for(int i=0; i<MaxClients; i++)
		if(IsValidClient(i))
			if(GetUserFlagBits(i) & FlagImmunity)
				RemovePortalGun(i);
	
	GetImmunityFlag(newVal);
}

public void CallBackCVarClassScout(ConVar cvar, char[] oldVal, char[] newVal)
{
	int Value = StringToInt(newVal);
	ChellClass[0] = Value ? true:false;
	
	if(!Value)
		RemovePortalgunClass(TFClass_Scout);
}

public void CallBackCVarClassSniper(ConVar cvar, char[] oldVal, char[] newVal)
{
	int Value = StringToInt(newVal);
	ChellClass[1] = Value ? true:false;
	
	if(!Value)
		RemovePortalgunClass(TFClass_Sniper);
}

public void CallBackCVarClassSoldier(ConVar cvar, char[] oldVal, char[] newVal)
{
	int Value = StringToInt(newVal);
	ChellClass[2] = Value ? true:false;
	
	if(!Value)
		RemovePortalgunClass(TFClass_Soldier);
}

public void CallBackCVarClassDemo(ConVar cvar, char[] oldVal, char[] newVal)
{
	int Value = StringToInt(newVal);
	ChellClass[3] = Value ? true:false;
	
	if(!Value)
		RemovePortalgunClass(TFClass_DemoMan);
}

public void CallBackCVarClassMedic(ConVar cvar, char[] oldVal, char[] newVal)
{
	int Value = StringToInt(newVal);
	ChellClass[4] = Value ? true:false;
	
	if(!Value)
		RemovePortalgunClass(TFClass_Medic);
}

public void CallBackCVarClassHeavy(ConVar cvar, char[] oldVal, char[] newVal)
{
	int Value = StringToInt(newVal);
	ChellClass[5] = Value ? true:false;
	
	if(!Value)
		RemovePortalgunClass(TFClass_Heavy);
}

public void CallBackCVarClassPyro(ConVar cvar, char[] oldVal, char[] newVal)
{
	int Value = StringToInt(newVal);
	ChellClass[6] = Value ? true:false;
	
	if(!Value)
		RemovePortalgunClass(TFClass_Pyro);
}

public void CallBackCVarClassSpy(ConVar cvar, char[] oldVal, char[] newVal)
{
	int Value = StringToInt(newVal);
	ChellClass[7] = Value ? true:false;
	
	if(!Value)
		RemovePortalgunClass(TFClass_Spy);
}

public void CallBackCVarClassEngi(ConVar cvar, char[] oldVal, char[] newVal)
{
	int Value = StringToInt(newVal);
	ChellClass[8] = Value ? true:false;
	
	if(!Value)
		RemovePortalgunClass(TFClass_Engineer);
}


public void OnMapStart()
{	
	
	if(!cvarEnabled.BoolValue)
	{
		LogMessage("[PORTALMOD] Disable !");
		return;
	}
	
	char newVal[2];
	GetConVarString(cvarFlag, newVal, sizeof(newVal));
	GetImmunityFlag(newVal);
	
	// PortalGun ---
	
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_portalgun.vmt");
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_portalgun.vtf");
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_portalgun_exponent.vtf");
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_portalgun_glass.vmt");
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_portalgun_glass.vtf");
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_portalgun_lightwarp.vtf");
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_portalgun_mask.vtf");
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_portalgun_normal.vtf");
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_portalgun2.vmt");
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_portalgun2.vtf");
	
	AddFileToDownloadsTable("models/Weapons/v_portalgun.dx80.vtx");
	AddFileToDownloadsTable("models/Weapons/v_portalgun.dx90.vtx");
	AddFileToDownloadsTable("models/Weapons/v_portalgun.sw.vtx");
	AddFileToDownloadsTable("models/Weapons/v_portalgun.vvd");
	AddFileToDownloadsTable("models/Weapons/v_portalgun.mdl");

	g_iViewModelp = PrecacheModel("models/Weapons/v_portalgun.mdl");

	
	// Portals ---

	AddFileToDownloadsTable("materials/models/portals/portal_1.vmt");
	AddFileToDownloadsTable("materials/models/portals/portal_1.vtf");
	AddFileToDownloadsTable("materials/models/portals/portal_2.vmt");
	AddFileToDownloadsTable("materials/models/portals/portal_2.vtf");
	AddFileToDownloadsTable("materials/models/portals/portal_3.vmt");
	AddFileToDownloadsTable("materials/models/portals/portal_3.vtf");
	AddFileToDownloadsTable("materials/models/portals/portal_4.vmt");
	AddFileToDownloadsTable("materials/models/portals/portal_4.vtf");
	
	AddFileToDownloadsTable("models/portals/portal.dx80.vtx");
	AddFileToDownloadsTable("models/portals/portal.dx90.vtx");
	AddFileToDownloadsTable("models/portals/portal.sw.vtx");
	AddFileToDownloadsTable("models/portals/portal.vvd");
	AddFileToDownloadsTable("models/portals/portal.mdl");
	
	PrecacheModel(PORTAL);
	
	
	
	// Sounds ---
	
	AddFileToDownloadsTable("sound/portalmod_gun/weapons/portalgun/portalgun_shoot_blue1.mp3");
	AddFileToDownloadsTable("sound/portalmod_gun/weapons/portalgun/portalgun_shoot_red1.mp3");
	AddFileToDownloadsTable("sound/portalmod_gun/weapons/portalgun/portal_open1.mp3");
	AddFileToDownloadsTable("sound/portalmod_gun/weapons/portalgun/portal_open2.mp3");
	AddFileToDownloadsTable("sound/portalmod_gun/weapons/portalgun/portal_open3.mp3");
	AddFileToDownloadsTable("sound/portalmod_gun/weapons/portalgun/portal_close1.mp3");
	AddFileToDownloadsTable("sound/portalmod_gun/weapons/portalgun/portal_close2.mp3");
	AddFileToDownloadsTable("sound/portalmod_gun/weapons/portalgun/portal_fizzle2.mp3");
	AddFileToDownloadsTable("sound/portalmod_gun/weapons/portalgun/portal_invalid_surface3.mp3");
	AddFileToDownloadsTable("sound/portalmod_gun/player/portal_exit1.mp3");
	AddFileToDownloadsTable("sound/portalmod_gun/player/portal_exit2.mp3");
	AddFileToDownloadsTable("sound/portalmod_gun/player/portal_enter1.mp3");
	AddFileToDownloadsTable("sound/portalmod_gun/player/portal_enter2.mp3");

	PrecacheSound("portalmod_gun/weapons/portalgun/portalgun_shoot_blue1.mp3");
	PrecacheSound("portalmod_gun/weapons/portalgun/portalgun_shoot_red1.mp3");
	PrecacheSound("portalmod_gun/weapons/portalgun/portal_open1.mp3");
	PrecacheSound("portalmod_gun/weapons/portalgun/portal_open2.mp3");
	PrecacheSound("portalmod_gun/weapons/portalgun/portal_open3.mp3");
	PrecacheSound("portalmod_gun/weapons/portalgun/portal_close1.mp3");
	PrecacheSound("portalmod_gun/weapons/portalgun/portal_close2.mp3");
	PrecacheSound("portalmod_gun/weapons/portalgun/portal_fizzle2.mp3");
	PrecacheSound("portalmod_gun/weapons/portalgun/portal_invalid_surface3.mp3");
	PrecacheSound("portalmod_gun/player/portal_exit1.mp3");
	PrecacheSound("portalmod_gun/player/portal_exit2.mp3");
	PrecacheSound("portalmod_gun/player/portal_enter1.mp3");
	PrecacheSound("portalmod_gun/player/portal_enter2.mp3");
	

	Initialisation(true);
	
	TagsCheck("PortalMod");
}

void Initialisation(bool FirstTime=false)
{
	for(int i=1; i< MaxClients; i++)
	{
		if(FirstTime)
		{
			g_Portal[i][0][ID] = -1;
			g_Portal[i][1][ID] = -1;
		}
		
		ChellInitialisation(i);
		
		if(IsClientInGame(i))
			PlayerTeam[i]  = GetClientTeam(i)-2;
		else
			PlayerTeam[i] = -1;
			
		if(FirstTime && IsValidClient(i))
			SDKHook(i, SDKHook_WeaponSwitch, OnWeaponSwitch);
	

		CanTP[i] = true;
		CanTP[i] = true;
	}
}

void ChellInitialisation(int client)
{
	for(int j=0; j<2; j++)
	{
		if(IsPortal(g_Portal[client][j][ID]))
			RemoveEdict(EntRefToEntIndex(g_Portal[client][j][ID]));
		g_Portal[client][j][ID] = -1;
		
		for(int k=0; k<3; k++)
			g_Portal[client][j][vec_Pos][k] = 0.0;
	}	
	
	CanAttack[client] 		= true;
	CanAttack2[client] 		= true;
}

public void OnMapEnd()
{
	for(int i=0; i<MaxClients; i++)
		ChellInitialisation(i);
}

#if defined _steamtools_included 
public void OnConfigsExecuted()
{
	if(cvarGameDesc.IntValue)
	{
		char gameDesc[64];
		Format(gameDesc, sizeof(gameDesc), "PortalMod %s beta", PLUGIN_VERSION);
		Steam_SetGameDescription(gameDesc);
	}
}
#endif

void TagsCheck(const char[] tag)
{
	ConVar hTags = FindConVar("sv_tags");
	char tags[255];
	hTags.GetString(tags, sizeof(tags));

	if (!(StrContains(tags, tag, false)> -1))
	{
		char newTags[255];
		Format(newTags, sizeof(newTags), "%s,%s", tags, tag);
		hTags.SetString(newTags);
		hTags.GetString(tags, sizeof(tags));
	}
	delete hTags;
}

stock bool IsValidClient(int iClient)
{
	if (iClient <= 0) return false;
	if (iClient > MaxClients) return false;
	return IsClientInGame(iClient);
}

stock int GetEntType(int entityRef)
{
	for(int i=0; i<MaxClients+1; i++)
		for(int j=0; j<2; j++)
			if(EntRefToEntIndex(g_Portal[i][j][ID]) == EntRefToEntIndex(entityRef))
				return j;
	return -1; //no type
}

stock bool CanBeChell(int client)
{
	// Check is client class is allowed
	TFClassType Class = TF2_GetPlayerClass(client);
	if(Class >= TFClass_Scout && Class <= TFClass_Engineer)
	{	
		if(!ChellClass[TFClassTypeToInt(Class) -1])
		{
			PrintToChat(client, "[PORTALMOD] This class is not allowed to receive a PortalGun!");
			return false;
		}
	}
	
	// Check is client team is allowed
	if(PlayerTeam[client] > 1 || PlayerTeam[client] < 0)
	{
		PrintToChat(client, "[PORTALMOD] Invalid team! Go in BLU or RED team.");
		return false;
	}
	
	// Check if client flag is allowed
	// TODO: Revise this to use overrides
	int flags = GetUserFlagBits(client);
	if(flags & ADMFLAG_GENERIC || flags & ADMFLAG_ROOT)
		return true;
		
	if(FlagImmunity == -1)
		return true;
	
	if(flags & FlagImmunity)
		return true;
			
	return false;
}

void GetImmunityFlag(const char[] Value)
{
	int FlagsList[21]	= {ADMFLAG_RESERVATION, ADMFLAG_GENERIC, ADMFLAG_KICK, ADMFLAG_BAN, ADMFLAG_UNBAN, ADMFLAG_SLAY, ADMFLAG_CHANGEMAP, ADMFLAG_CONVARS, ADMFLAG_CONFIG, ADMFLAG_CHAT, ADMFLAG_VOTE, ADMFLAG_PASSWORD, ADMFLAG_RCON, ADMFLAG_CHEATS, ADMFLAG_CUSTOM1, ADMFLAG_CUSTOM2, ADMFLAG_CUSTOM3, ADMFLAG_CUSTOM4, ADMFLAG_CUSTOM5, ADMFLAG_CUSTOM6, ADMFLAG_ROOT};
	char FlagsLetter[21][2] = {"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "z"};
	for(int i=0; i<21; i++)
	{
		if(StrEqual(Value, FlagsLetter[i]))
		{
			FlagImmunity = FlagsList[i];
			return;
		}
	}
	
	FlagImmunity = -1;
}

stock int TFClassTypeToInt(TFClassType Class)
{
	if(Class < TFClass_Scout || Class > TFClass_Engineer) return 0;
	
//	int ClassInt = 1;
//	while(Class != view_as<TFClassType>(ClassInt))  ClassInt++;
	
	// TODO: Is this meant to be view_as<int>? ^^
	
//	return ClassInt;
	return view_as<int>(Class);
}


/////////////////////////////////////////////////////////////////////////////////////////////
//							Events Zone
////////////////////////////////////////////////////////////////////////////////////////////


public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "func_respawnroom", false))
		SDKHook(entity, SDKHook_StartTouch, SpawnStartTouch);
}

public void OnEntityDestroyed(int entity)
{	
	if(!cvarEnabled.BoolValue)
		return;
		
	if(!IsValidEdict(entity))
		return;
		
	char ClassName[64];
	GetEdictClassname(entity, ClassName, sizeof(ClassName));
	//PrintToChatAll("des : %s",ClassName);
		
	if(StrEqual(ClassName, "tf_projectile_energy_ball"))	
	{
		char WeapName[12];
		GetEntPropString(entity, Prop_Data, "m_iName", WeapName, sizeof(WeapName)); //Is portalGun projectile ?
		if(StrContains(WeapName, PORTALGUN_ID, true) == -1)
			return;
		
		char WeapData[3][8];
		ExplodeString(WeapName, "_", WeapData, 3, 8);
		
		
		float Pos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", Pos);
		
		int client 		= GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
		int Type 		= StringToInt(WeapData[2]);
		
		if(Type == -1) return;
		if(!IsValidClient(client)) return;
		
		float v_Angle[3];
		for(int i=0; i<3; i++)
			v_Angle[i] = g_Portal[client][Type][vec_Angle][i];
		
		int iParticle 	= CreateEntityByName("info_particle_system");
		if (IsValidEdict(iParticle))
		{	
			if(!Type)
				DispatchKeyValue(iParticle, "effect_name", "medic_radiusheal_red_spiral");
			else
				DispatchKeyValue(iParticle, "effect_name", "medic_radiusheal_blue_spiral");
				
			//PrintToChatAll("clt: %i, type: %i, ent: %i", client, Type, entity);
			TeleportEntity(iParticle, Pos, v_Angle, NULL_VECTOR);
			DispatchSpawn(iParticle);
			ActivateEntity(iParticle);
			AcceptEntityInput(iParticle, "Start");
			
			CreateTimer(0.5, TimerDeleteParticule, EntIndexToEntRef(iParticle));
			createPortal(client, Type, Pos);
		}
	}
}

public void OnClientPutInServer(int client)
{
	if(cvarEnabled.BoolValue)
		SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
}

public void OnClientDisconnect(int client)
{
	if(!cvarEnabled.BoolValue)
		return;
		
	if(!IsValidClient(client))
		return;
		
	SDKUnhook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
}

public void EventPlayerSpawn(Event hEvent, char[] strName, bool bHidden)
{
	if(!cvarEnabled.BoolValue)
		return;
		
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if(!IsValidClient(client)) return;

	if(IsChell[client])
		GiveRevolver(client);
}

public void EventPlayerDeath(Event hEvent, const char[] strName, bool bHidden)
{
	if(!cvarEnabled.BoolValue)
		return;
	
	if(!cvarPerLife.BoolValue)
		return;
		
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if(!IsValidClient(client)) return;
	
	if(IsChell[client])
		ChellInitialisation(client);
}

public void EventPlayerInventory(Event hEvent, const char[] strName, bool bHidden)
{
	if(!cvarEnabled.BoolValue)
		return;
		
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	
	if(!IsValidClient(client)) return;
	if(!IsPlayerAlive(client)) return;
	if(IsChell[client])
		GiveRevolver(client);
}

public void EventRoundStart(Event hEvent, const char[] strName, bool bHidden)
{
	if(!cvarEnabled.BoolValue)
		return;
		
	for(int i=1; i<MaxClients; i++)
		if(IsValidClient(i) && IsChell[i])
			RemovePortalGun(i);
	
	Initialisation();
}

public void EventPlayerchangeclass(Event hEvent, const char[] strName, bool bHidden)
{
	if(!cvarEnabled.BoolValue)
		return;
		
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if(!IsValidClient(client))
		return;	
		
	//PrintToChat(client, "new: %i, Old: %i", GetEventInt(hEvent, "class"), TF2_GetPlayerClass(client));
	
	int flags = GetUserFlagBits(client);
	if(flags & ADMFLAG_GENERIC || flags & ADMFLAG_ROOT || flags & FlagImmunity)
		return;	
		
	/*** Is this class allowed to receive the PortalGun ? ***/
	TFClassType Class = view_as<TFClassType>(hEvent.GetInt("class"));
	if(Class >= TFClass_Scout && Class <= TFClass_Engineer)
	{
		if(!ChellClass[TFClassTypeToInt(Class) - 1])
		{
			PrintToChat(client, "[PORTALMOD] This class is not allowed to receive a PortalGun!");
			RemovePortalGun(client); // Remove player Portalgun
		}
	}	
}

public void EventPlayerTeamPost(Event hEvent, const char[] strName, bool bHidden)
{
	if(!cvarEnabled.BoolValue)
		return;
		
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	int Team = hEvent.GetInt("team");
	
	if(IsValidClient(client))
		PlayerTeam[client] = Team-2;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	int Type = -1;
	int client = -1;
	
	for(int i=0; i<MaxClients; i++)
		for(int j=0; j<2; j++)
			if(EntRefToEntIndex(g_Portal[i][j][ID]) == victim)
			{
				client = i;
				Type = j;
				continue;
			}
   
	if(!IsValidClient(client))
        return Plugin_Continue;
	
	//PrintToChat(attacker,"Damage: %f", damage);
	
	g_Portal[client][Type][P_Health] -= damage;
	if(g_Portal[client][Type][P_Health] <= 0.0)
	{
		if(IsValidEdict(victim)) RemoveEdict(victim);
			
		g_Portal[client][Type][ID] = -1;
		for(int k=0; k<3; k++)
			g_Portal[client][Type][vec_Pos][k] = 0.0;
			
		if(Type == 0 && IsValidEdict(EntRefToEntIndex(g_Portal[client][1][ID])))
			SetEntProp(EntRefToEntIndex(g_Portal[client][1][ID]), Prop_Send, "m_nSkin", GetEntType(g_Portal[client][1][ID]));
		else if(IsValidEdict(EntRefToEntIndex(g_Portal[client][0][ID])))
			SetEntProp(EntRefToEntIndex(g_Portal[client][0][ID]), Prop_Send, "m_nSkin", GetEntType(g_Portal[client][0][ID]));
			

		ClientCommand(client, "playgamesound portalmod_gun/weapons/portalgun/portal_fizzle2.mp3");
		int ActiveWeapon 	= GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		if(IsValidEntity(ActiveWeapon))
		{
			int idx	= GetEntProp(ActiveWeapon, Prop_Send, "m_iItemDefinitionIndex");
			if(idx == StringToInt(PORTALGUN_ID))
			{
				SetEntProp(GetEntPropEnt(client, Prop_Data, "m_hViewModel"), Prop_Send, "m_nSequence", 2);
				CreateTimer(0.1, TimerPortal, client);
			}
		}	
	}
	return Plugin_Continue;
}

public Action OnWeaponSwitch(int client, int weapon)
{
	if(!IsChell[client])
		return Plugin_Continue;
		
	TFClassType Class = TF2_GetPlayerClass(client);
	if(Class >= TFClass_Scout && Class <= TFClass_Engineer)
	{	
		if(!ChellClass[TFClassTypeToInt(Class) -1]) // Class not allowed => remove Portalgun
		{
			PrintToChat(client, "[PORTALMOD] This class is not allowed to receive a PortalGun!");
			RemovePortalGun(client); // Remove player Portalgun
			return Plugin_Continue;
		}
	}
	
	char ClassName[64];
	GetEdictClassname(weapon, ClassName, sizeof(ClassName));
	if(!StrEqual(ClassName, PORTALGUN_CLASSNAME))
		return Plugin_Continue;
	
	CreateTimer(0.01, TimerEquipPortalgun, client);
	return Plugin_Continue;
}  

public void SpawnStartTouch(int spawn, int entity)
{
	char ClassName[64];
	GetEdictClassname(entity, ClassName, sizeof(ClassName));
	if (StrEqual(ClassName,"tf_projectile_energy_ball"))
	{
		char WeapData[10];
		GetEntPropString(entity, Prop_Data, "m_iName", WeapData, sizeof(WeapData)); //Is portalGun projectile ?
		if(StrContains(WeapData, PORTALGUN_ID, true) == -1)
			return;
			
		RemoveEdict(entity);
		
		int client 	= GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
		if(IsValidClient(client))
		{
			ClientCommand(client, "playgamesound portalmod_gun/weapons/portalgun/portal_fizzle2.mp3");
			int ActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
			if(IsValidEntity(ActiveWeapon))
			{
				int idx	= GetEntProp(ActiveWeapon, Prop_Send, "m_iItemDefinitionIndex");
				if(idx == StringToInt(PORTALGUN_ID))
				{
					SetEntProp(GetEntPropEnt(client, Prop_Data, "m_hViewModel"), Prop_Send, "m_nSequence", 2);
					CreateTimer(0.1, TimerPortal, client);
				}
			}	
		}
	}
}


/////////////////////////////////////////////////////////////////////////////////////////////
//							Equip Weapon 
////////////////////////////////////////////////////////////////////////////////////////////


public Action GivePortalGun(int client, int Args)
{	
	if(!cvarEnabled.BoolValue) return Plugin_Handled;
	if(!IsValidClient(client)) return Plugin_Handled;
	if (!TF2Friendly_IsFriendly(client))
	{
		CReplyToCommand(client, "{OLIVE}[SM]{DEFAULT} Sorry, but you must be in friendly to use this!");
		return Plugin_Handled;
	}
	
	if(IsChell[client]) // If currently chell, remove portalgun
	{
		RemovePortalGun(client);
	}
	else // Set player as Chell
	{
		if(!CanBeChell(client)) return Plugin_Handled;
		
		IsChell[client] = true;
		GiveRevolver(client);
	}
	return Plugin_Handled;
}

void EquipPortalGun(int client)
{	
	if(PlayerTeam[client] > 1 || PlayerTeam[client] < 0)
		return;
	
	int WeaponID 	= GetPlayerWeaponSlot(client, 1);
	int WeaponModel = GetEntPropEnt(client, Prop_Data, "m_hViewModel");
	SetEntData(WeaponModel, FindSendPropInfo("CBaseCombatWeapon", "m_iWorldModelIndex"), g_iViewModelp, 4, true);
	SetEntData(WeaponModel, FindSendPropInfo("CBaseEntity", "m_nModelIndex"), g_iViewModelp, 4, true);
	
	SetEntProp(WeaponID, Prop_Send, "m_nModelIndexOverrides", g_iViewModelp, _, 1);
	SetEntProp(WeaponID, Prop_Send, "m_nModelIndexOverrides", GetEntProp(WeaponID, Prop_Send, "m_nModelIndex"), _, 0);
	
	SetEntProp(WeaponID, Prop_Send, "m_iEntityQuality", 10); 
	SetEntProp(WeaponID, Prop_Send, "m_iEntityLevel", 100);
	SetEntProp(WeaponID, Prop_Send, "m_nSkin", 0);

	SetEntProp(WeaponModel, Prop_Send, "m_nSequence", 3);
	
	CreateTimer(0.1, TimerPortal, client);
}

void GiveRevolver(int client)
{
	if(!IsValidClient(client)) return;
	if(PlayerTeam[client] < 0 || PlayerTeam[client] > 1) return;
	
	int flags = OVERRIDE_ATTRIBUTES;
	Handle newItem = TF2Items_CreateItem(flags);

	flags |= OVERRIDE_CLASSNAME;
	TF2Items_SetClassname(newItem, PORTALGUN_CLASSNAME);
	flags |= OVERRIDE_ITEM_DEF;
	TF2Items_SetItemIndex(newItem, PORTALGUN_OLD_ID);

	TF2Items_SetNumAttributes(newItem, 1);
	TF2Items_SetAttribute(newItem, 0, 280, 9.0);

	TF2Items_SetFlags(newItem, flags);	
	int WeaponID = GetPlayerWeaponSlot(client, 1);
	if(IsValidEdict(WeaponID))
	{
		RemovePlayerItem(client, WeaponID);
		RemoveEdict(WeaponID);
	}

	int entity = TF2Items_GiveNamedItem(client, newItem);
	delete newItem;	
	
	SetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex", StringToInt(PORTALGUN_ID));
	
	if(IsValidEntity(entity))
		EquipPlayerWeapon(client, entity);

	SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
	SetEntityRenderColor(entity, 255, 255, 255, 0);
}

void RemovePortalGun(int client)
{
	if(!IsValidClient(client))
		return;
		
	IsChell[client] = false;
	
	int Health = GetClientHealth(client);
	
	TF2_RemoveWeaponSlot(client, 1); // Remove PortalGun weapon
	ChellInitialisation(client);	 // Initialize player data and remove portal entities
	TF2_RegeneratePlayer(client);	 // Load Player secondary item	
	SetEntityHealth(client, Health); // Keep Health	
}

void RemovePortalgunClass(TFClassType Class)
{
	for(int i=1; i<MaxClients; i++)
		if(IsValidClient(i) && TF2_GetPlayerClass(i) == Class)
			RemovePortalGun(i);
}


/////////////////////////////////////////////////////////////////////////////////////////////
//							Weapon configs
////////////////////////////////////////////////////////////////////////////////////////////


public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) 
{ 
	if(PlayerTeam[client] < 0 || PlayerTeam[client] > 1)
		return Plugin_Changed;
		
	if((buttons & IN_ATTACK) || (buttons & IN_ATTACK2)) 
    { 
		int ActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		if(!IsValidEntity(ActiveWeapon))
			return Plugin_Changed;
			
		int idx	= GetEntProp(ActiveWeapon, Prop_Send, "m_iItemDefinitionIndex");
		if(idx == StringToInt(PORTALGUN_ID))
		{						
			float WeapPos[3];
			int WeaponModel = GetEntPropEnt(client, Prop_Data, "m_hViewModel");
			GetClientEyePosition(client, WeapPos);
			
			if(buttons & IN_ATTACK)
			{
				if(!CanAttack[client])
				{
					buttons = IN_CANCEL;
					return Plugin_Changed;
				}
				
				CanAttack[client] = false;
				EmitAmbientSound("portalmod_gun/weapons/portalgun/portalgun_shoot_blue1.mp3", 
                        WeapPos, 
                        SOUND_FROM_WORLD, 
                        SNDLEVEL_NORMAL, 
                        SND_NOFLAGS, 
                        SNDVOL_NORMAL, 
                        SNDPITCH_NORMAL, 
                        0.0); 
					
				SpawnBullet(client, 1);
				SetEntProp(WeaponModel, Prop_Send, "m_nSequence", 1);
				CreateTimer(0.1, TimerPortal, client);
				CreateTimer(0.4, TimerCanAttack, client);
			}
			else
			{
				if(!CanAttack2[client])
				{
					buttons = IN_CANCEL;
					return Plugin_Changed;
				}
				CanAttack2[client] = false;
				EmitAmbientSound("portalmod_gun/weapons/portalgun/portalgun_shoot_red1.mp3", 
                        WeapPos, 
                        SOUND_FROM_WORLD, 
                        SNDLEVEL_NORMAL, 
                        SND_NOFLAGS, 
                        SNDVOL_NORMAL, 
                        SNDPITCH_NORMAL, 
                        0.0);
						
				SpawnBullet(client, 0);
				SetEntProp(WeaponModel, Prop_Send, "m_nSequence", 1);
				CreateTimer(0.1, TimerPortal, client);
				CreateTimer(0.4, TimerCanAttack2, client);
			}
			buttons = IN_CANCEL;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

/////////////////////////////////////////////////////////////////////////////////////////////
//							Timers Zone
////////////////////////////////////////////////////////////////////////////////////////////

public Action TimerPortal(Handle timer, any client)
{
	int WeaponModel 	= GetEntPropEnt(client, Prop_Data, "m_hViewModel");
	SetEntProp(WeaponModel, Prop_Send, "m_nSequence", 0);
}

public Action TimerCanAttack2(Handle timer, any client)
{	
	CanAttack2[client] = true;
}

public Action TimerCanAttack(Handle timer, any client)
{	
	CanAttack[client] = true;
}

public Action TimerCanTP(Handle timer, any client)
{	
	CanTP[client] = true;
}

public Action TimerDeleteParticule(Handle timer, any particle)
{	
	if(IsValidEdict(EntRefToEntIndex(particle)))
		RemoveEdict(EntRefToEntIndex(particle));
}

public Action TimerEquipPortalgun(Handle timer, any client)
{	
	EquipPortalGun(client);
}


public void OnGameFrame()
{	
	if(!cvarEnabled.BoolValue)
		return;
		
	float Pos[3];
	float EyesPos[3];
	float result[3];
	int i,Type, k;
	bool stop;

	
	for(int client=1; client <= MaxClients; client++)
	{
		if(IsValidClient(client) && IsClientInGame(client) && !IsClientSourceTV(client) && (PlayerTeam[client] == 1 || PlayerTeam[client] == 0))
		{
			GetClientAbsOrigin(client, Pos);
			//PrintToChatAll("P-Ang: %f, %f ,%f",PlAngle[0], PlAngle[1], PlAngle[2]);
			
			i=1;
			stop = false;
			do	// for all player who has portal
			{
				if(IsValidClient(i) && IsClientInGame(i) && IsClientConnected(i) && IsChell[i])
				{
					if( (GetConVarBool(cvarOnlyMine) && i==client) || !GetConVarBool(cvarOnlyMine) ) // Check only my portal or all portal
					{
						Type=0;
						do	// for each portal type (=0 or 1)
						{
							if(IsPortal(g_Portal[i][Type][ID]))
							{
								for(k=0; k<3; k++) // Get distance between player and this portal
								{
									result[k] = FloatSub(g_Portal[i][Type][vec_Pos][k], Pos[k]);
									if(result[k] < 0)
										result[k] = -result[k];
									//PrintToChat(client,"%f",result[k]);
								}
								
								if(result[0] < 35.0 && result[1] < 35.0 && result[2] < 35.0 && CanTP[client])
								{
									//PrintToChat(client, "You're near %i portal %i",i,Type);
									if(Type == 1)
										k=0;
									else
										k=1;
										
									if(IsPortal(g_Portal[i][k][ID])) // Does it have a portal exit ?
									{
										if(GetRandomInt(0, 1) %1 == 0)							
											EmitAmbientSound("portalmod_gun/player/portal_enter1.mp3", 
												Pos, 
												SOUND_FROM_WORLD, 
												SNDLEVEL_NORMAL, 
												SND_NOFLAGS, 
												SNDVOL_NORMAL, 
												SNDPITCH_NORMAL, 
												0.0);
										else
											EmitAmbientSound("portalmod_gun/player/portal_enter2.mp3", 
												Pos, 
												SOUND_FROM_WORLD, 
												SNDLEVEL_NORMAL, 
												SND_NOFLAGS, 
												SNDVOL_NORMAL, 
												SNDPITCH_NORMAL, 
												0.0);
										tpPlayer(client, i, k, EntRefToEntIndex(g_Portal[i][Type][ID]));
										stop = true;
									}
								}
								else if(g_Portal[i][Type][vec_Angle][0] > 0.0)
								{
									GetClientEyePosition(client, EyesPos);
									for(k=0; k<3; k++)
									{
										result[k] = FloatSub(g_Portal[i][Type][vec_Pos][k], EyesPos[k]);
										if(result[k] < 0)
											result[k] = -result[k];
									}
									
									if(result[0] < 20.0 && result[1] < 20.0 && result[2] < 20.0 && CanTP[client])
									{
										if(Type == 1)
											k=0;
										else
											k=1;
											
										if(IsPortal(g_Portal[i][k][ID]))
										{
											if(GetRandomInt(0, 1) %1 == 0)							
												EmitAmbientSound("portalmod_gun/player/portal_enter1.mp3", 
													Pos, 
													SOUND_FROM_WORLD, 
													SNDLEVEL_NORMAL, 
													SND_NOFLAGS, 
													SNDVOL_NORMAL, 
													SNDPITCH_NORMAL, 
													0.0);
											else
												EmitAmbientSound("portalmod_gun/player/portal_enter2.mp3", 
													Pos, 
													SOUND_FROM_WORLD, 
													SNDLEVEL_NORMAL, 
													SND_NOFLAGS, 
													SNDVOL_NORMAL, 
													SNDPITCH_NORMAL, 
													0.0);
											tpPlayer(client, i, k, EntRefToEntIndex(g_Portal[i][Type][ID]));
											stop = true;
										}
									}
								}
							}
							Type++;
						}while(!stop && Type < 2);
					}
				}
				i++;
			}while(!stop && i < MaxClients);
			
		}
	}
}



/////////////////////////////////////////////////////////////////////////////////////////////
//							Portal Creation
////////////////////////////////////////////////////////////////////////////////////////////



public bool TraceEntityFilterPlayer(int entity, int contentsMask, any data) 
{
 	return entity > MAXPLAYERS;
}

public bool TraceEntityFilterEntities(int entity, int contentsMask, any data) 
{
	return entity > MaxClients;
}

void createPortal(int client, int Type, float Pos[3])
{
	if(!TestZone(Pos, client, Type))	//Isn't valid wall to spawn portal
	{	
		EmitAmbientSound("portalmod_gun/weapons/portalgun/portal_invalid_surface3.mp3", Pos, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
		ClientCommand(client, "playgamesound portalmod_gun/weapons/portalgun/portal_invalid_surface3.mp3");
		return; 
	}
	
	float v_Angle[3];
	for(int i=0; i<3; i++)
		v_Angle[i] = g_Portal[client][Type][vec_Angle][i];
	
	// If Portal already exist
	
	if(EntRefToEntIndex(g_Portal[client][Type][ID]) > 0 && IsPortal(g_Portal[client][Type][ID])) 
	{
		float OldPos[3];
		GetEntPropVector(EntRefToEntIndex(g_Portal[client][Type][ID]), Prop_Send, "m_vecOrigin", OldPos);
		int iParticle 	= CreateEntityByName("info_particle_system");
		if (IsValidEdict(iParticle))
		{		
			if(Type == 0)
				DispatchKeyValue(iParticle, "effect_name", "medic_radiusheal_red_spikes");
			else
				DispatchKeyValue(iParticle, "effect_name", "medic_radiusheal_blue_spikes");
				
			TeleportEntity(iParticle, OldPos, v_Angle, NULL_VECTOR);
			DispatchSpawn(iParticle);
			ActivateEntity(iParticle);
			AcceptEntityInput(iParticle, "Start");
			CreateTimer(0.5, TimerDeleteParticule, EntIndexToEntRef(iParticle));
		}
		
		if(GetRandomInt(0,1) %1 == 1)
		{
			EmitAmbientSound("portalmod_gun/weapons/portalgun/portal_close1.mp3", OldPos, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
			ClientCommand(client, "playgamesound portalmod_gun/weapons/portalgun/portal_close1.mp3");
		}
		else
		{
			EmitAmbientSound("portalmod_gun/weapons/portalgun/portal_close2.mp3", OldPos, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
			ClientCommand(client, "playgamesound portalmod_gun/weapons/portalgun/portal_close2.mp3");
		}
		
		RemoveEdict(EntRefToEntIndex(g_Portal[client][Type][ID]));
		g_Portal[client][Type][ID] = -1;
	}

	
	//Creation of the portal ---

	int pEnt =	CreateEntityByName("prop_dynamic");        
	if (pEnt == -1) 
	{ 
		LogMessage("item failed to create."); 
		return;
	}
	
	DispatchKeyValue(pEnt, "model", PORTAL);
	
	if( (Type == 0 && EntRefToEntIndex(g_Portal[client][1][ID]) == -1) || (Type == 1 && EntRefToEntIndex(g_Portal[client][0][ID]) == -1) )	// No second portal
		SetEntProp(pEnt, Prop_Send, "m_nSkin", Type);
	else
	{
		SetEntProp(pEnt, Prop_Send, "m_nSkin", Type+2);
		
		if(Type == 0)
			SetEntProp(EntRefToEntIndex(g_Portal[client][1][ID]), Prop_Send, "m_nSkin", GetEntType(g_Portal[client][1][ID]) +2);
		else
			SetEntProp(EntRefToEntIndex(g_Portal[client][0][ID]), Prop_Send, "m_nSkin", GetEntType(g_Portal[client][0][ID]) +2);
	}
	
	if(cvarBreakable.IntValue) // Enable portal damage
	{		
		g_Portal[client][Type][P_Health] = cvarPortalHealth.IntValue * 1.0;
		SDKHook(pEnt, SDKHook_OnTakeDamage, OnTakeDamage);
	}
	
	DispatchSpawn(pEnt);
	TeleportEntity(pEnt, Pos, v_Angle, NULL_VECTOR);
	
	/**** WHY DO YOU CRASH HERE !!!!!!!!!!! ****/
	int soundID; 
	/*soundID = GetRandomInt(0, 2) %3 +1;*/ // Server crash due to GetRandomInt call ...
	soundID = RandInt() %3 +1;
	//PrintToChat(client,"rand: %i", soundID);
	/***/
	
	char Adress[80];
	Format(Adress, sizeof(Adress), "portalmod_gun/weapons/portalgun/portal_open%i.mp3", soundID); 
	
	
	EmitAmbientSound(Adress, Pos, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
	Format(Adress, sizeof(Adress), "playgamesound %s", Adress);
	ClientCommand(client, Adress);
	

	g_Portal[client][Type][vec_Pos][0] 	= Pos[0];
	g_Portal[client][Type][vec_Pos][1] 	= Pos[1];
	g_Portal[client][Type][vec_Pos][2] 	= Pos[2];
	g_Portal[client][Type][ID]			= EntIndexToEntRef(pEnt);
}

bool TestZone(float Origin[3], int client, int Type)		// Test portal's wall if it's a valid zone 
{
	float AxeZ_Angle[3];
	float AxeY_Angle[3];
	float AxeX_Angle[3];
	float AxeZop_Angle[3];		// Z opposite axe
	float AxeYop_Angle[3];
	float AxeXop_Angle[3];
	float PosZ[3];
	float PosY[3];
	float PosX[3];
	float PosZop[3];
	float PosYop[3];
	float PosXop[3];
	float c_wall;
	
	c_wall = cvarWall.FloatValue;
	if(c_wall == 0.0) return true;
	
	// Create portal axe Z
	AxeZ_Angle[0] = g_Portal[client][Type][vec_Angle][0];
	AxeZ_Angle[1] = g_Portal[client][Type][vec_Angle][1];
	
	PosZ[0] = 50.0 * c_wall * Cosine((AxeZ_Angle[0]) * FLOAT_PI / 180) * Cosine((AxeZ_Angle[1]) * FLOAT_PI / 180) ;
	PosZ[1] = 50.0 * c_wall * Cosine((AxeZ_Angle[0]) * FLOAT_PI / 180) * Sine((AxeZ_Angle[1]) * FLOAT_PI / 180);
	PosZ[2] = 50.0 * c_wall * -Sine((AxeZ_Angle[0]) * FLOAT_PI / 180);
	PosZ[0] += Origin [0];
	PosZ[1] += Origin [1];
	PosZ[2] += Origin [2];
	
	
	// Create portal axe X
	AxeX_Angle[0] = g_Portal[client][Type][vec_Angle][0] - 90.0;
	AxeX_Angle[1] = g_Portal[client][Type][vec_Angle][1];	
		
	PosX[0] = 50.0 * c_wall * Cosine((AxeX_Angle[0]) * FLOAT_PI / 180) * Cosine((AxeX_Angle[1]) * FLOAT_PI / 180) ;
	PosX[1] = 50.0 * c_wall * Cosine((AxeX_Angle[0]) * FLOAT_PI / 180) * Sine((AxeX_Angle[1]) * FLOAT_PI / 180);
	PosX[2] = 50.0 * c_wall * -Sine((AxeX_Angle[0]) * FLOAT_PI / 180);
	PosX[0] += Origin [0];
	PosX[1] += Origin [1];
	PosX[2] += Origin [2];
	
	
	// Create portal axe Y
	AxeY_Angle[0] = 0.0;
	AxeY_Angle[1] = AxeX_Angle[1] + 90.0;
	
	PosY[0] = 50.0 * c_wall * Cosine((AxeY_Angle[0]) * FLOAT_PI / 180) * Cosine((AxeY_Angle[1]) * FLOAT_PI / 180) ;
	PosY[1] = 50.0 * c_wall * Cosine((AxeY_Angle[0]) * FLOAT_PI / 180) * Sine((AxeY_Angle[1]) * FLOAT_PI / 180);
	PosY[2] = 50.0 * c_wall * -Sine((AxeY_Angle[0]) * FLOAT_PI / 180);
	PosY[0] += Origin [0];
	PosY[1] += Origin [1];
	PosY[2] += Origin [2];
	
	
	// Create portal opposite axe X 
	AxeXop_Angle[0] = 0.0 - AxeX_Angle[0];
	AxeXop_Angle[1] = AxeX_Angle[1] - 180.0;	
	
	PosXop[0] = 50.0 * c_wall * Cosine((AxeXop_Angle[0]) * FLOAT_PI / 180) * Cosine((AxeXop_Angle[1]) * FLOAT_PI / 180) ;
	PosXop[1] = 50.0 * c_wall * Cosine((AxeXop_Angle[0]) * FLOAT_PI / 180) * Sine((AxeXop_Angle[1]) * FLOAT_PI / 180);
	PosXop[2] = 50.0 * c_wall * -Sine((AxeXop_Angle[0]) * FLOAT_PI / 180);
	PosXop[0] += Origin [0];
	PosXop[1] += Origin [1];
	PosXop[2] += Origin [2];

	
	// Create portal opposite axe y 
	AxeYop_Angle[0] = 0.0 - AxeY_Angle[0];
	AxeYop_Angle[1] = AxeY_Angle[1] - 180.0;
		
	PosYop[0] = 50.0 * c_wall * Cosine((AxeYop_Angle[0]) * FLOAT_PI / 180) * Cosine((AxeYop_Angle[1]) * FLOAT_PI / 180) ;
	PosYop[1] = 50.0 * c_wall * Cosine((AxeYop_Angle[0]) * FLOAT_PI / 180) * Sine((AxeYop_Angle[1]) * FLOAT_PI / 180);
	PosYop[2] = 50.0 * c_wall * -Sine((AxeYop_Angle[0]) * FLOAT_PI / 180);
	PosYop[0] += Origin [0];
	PosYop[1] += Origin [1];
	PosYop[2] += Origin [2];
	
	
	// Create portal opposite axe Z
	AxeZop_Angle[0] = 0.0 - g_Portal[client][Type][vec_Angle][0];
	AxeZop_Angle[1] = g_Portal[client][Type][vec_Angle][1] - 180.0;
	
	PosZop[0] = ( 50.0 * c_wall * Cosine((AxeZop_Angle[0]) * FLOAT_PI / 180) * Cosine((AxeZop_Angle[1]) * FLOAT_PI / 180) ) + PosZ[0];
	PosZop[1] = ( 50.0 * c_wall * Cosine((AxeZop_Angle[0]) * FLOAT_PI / 180) * Sine((AxeZop_Angle[1]) * FLOAT_PI / 180) ) + PosZ[1];
	PosZop[2] = ( 50.0 * c_wall * -Sine((AxeZop_Angle[0]) * FLOAT_PI / 180) ) + PosZ[2];

	
	// Distance beetween portal
	for(int i=0; i<MaxClients; i++)
		for(int j=0; j<2; j++)
			if(IsPortal(g_Portal[i][j][ID]) && !(i == client && j == Type))
			{
				float v_Pos[3];
				for(int k=0; k<3; k++)
					v_Pos[k] = g_Portal[i][j][vec_Pos][k];
				if(GetVectorDistance(Origin, v_Pos, true) < 8250.0) 
					return false;
			}
	
	
	// Is a valid zone ?
	
	
	bool Horizontal = false;
	if(	AxeZ_Angle[0] > 88.0 && AxeZ_Angle[0] < 92.0 ||
		AxeZ_Angle[0] > 268.0 && AxeZ_Angle[0] < 272.0)
		Horizontal = true;
	
	if(!IsValidPortalDistance(client, Origin, AxeZop_Angle, Horizontal, true)) 	return false;
	
	if(!IsValidPortalDistance(client, Origin, AxeZ_Angle, Horizontal)) 			return false;
	if(!IsValidPortalDistance(client, PosZ,   AxeX_Angle)) 						return false;
	if(!IsValidPortalDistance(client, PosZ,   AxeY_Angle)) 						return false;
	if(!IsValidPortalDistance(client, PosZ,   AxeXop_Angle)) 					return false;
	if(!IsValidPortalDistance(client, PosZ,   AxeYop_Angle)) 					return false;
		
	if(!IsValidPortalDistance(client, Origin, AxeX_Angle)) 						return false;
	if(!IsValidPortalDistance(client, PosX,   AxeY_Angle)) 						return false;
	if(!IsValidPortalDistance(client, PosX,   AxeZ_Angle, Horizontal)) 			return false;
	if(!IsValidPortalDistance(client, PosX,   AxeYop_Angle)) 					return false;
	if(!IsValidPortalDistance(client, PosX,   AxeZop_Angle, Horizontal, true)) 	return false;
	
	if(!IsValidPortalDistance(client, Origin, AxeY_Angle)) 						return false;
	if(!IsValidPortalDistance(client, PosY,   AxeX_Angle)) 						return false;
	if(!IsValidPortalDistance(client, PosY,   AxeZ_Angle, Horizontal))			return false;
	if(!IsValidPortalDistance(client, PosY,   AxeXop_Angle)) 					return false;
	if(!IsValidPortalDistance(client, PosY,   AxeZop_Angle, Horizontal, true)) 	return false;
	
	if(!IsValidPortalDistance(client, Origin, AxeXop_Angle)) 					return false;
	if(!IsValidPortalDistance(client, PosXop, AxeY_Angle)) 						return false;
	if(!IsValidPortalDistance(client, PosXop, AxeZ_Angle, Horizontal)) 			return false;
	if(!IsValidPortalDistance(client, PosXop, AxeYop_Angle)) 					return false;
	if(!IsValidPortalDistance(client, PosXop, AxeZop_Angle, Horizontal, true))	return false;
	
	if(!IsValidPortalDistance(client, Origin, AxeYop_Angle)) 					return false;
	if(!IsValidPortalDistance(client, PosYop, AxeX_Angle)) 						return false;
	if(!IsValidPortalDistance(client, PosYop, AxeZ_Angle, Horizontal)) 			return false;
	if(!IsValidPortalDistance(client, PosYop, AxeXop_Angle)) 					return false;
	if(!IsValidPortalDistance(client, PosYop, AxeZop_Angle, Horizontal, true)) 	return false;

	
	return true;
}

bool IsValidPortalDistance(int client, float Origin[3], float Angle[3], bool Horizontal=false, bool FloorDirection=false)
{
	Handle trace = null;
	float EndPos[3];
	
	trace = TR_TraceRayFilterEx(Origin, Angle, MASK_SOLID, RayType_Infinite, TraceEntityFilterEntities, client);		
	if (!TR_DidHit(trace)) 
	{
		delete trace;
		return false;
	}
	
	TR_GetEndPosition(EndPos, trace);
	//PrintToChatAll("dist   : %f",GetVectorDistance(EndPos, Origin, false));
	delete trace;
	
	float c_wall = cvarWall.FloatValue;
	
	if(!FloorDirection && Horizontal && GetVectorDistance(EndPos, Origin, false) < (100.0 * c_wall) )
		return false;
	else if(!FloorDirection && !Horizontal && GetVectorDistance(EndPos, Origin, false) < (70.0 * c_wall) )
		return false;
	else if(FloorDirection && GetVectorDistance(EndPos, Origin, false) > (2.0 / c_wall) )
		return false;	
	
	return true;
}

void SpawnBullet(int client, int type)
{
	float Pl_Angles[3], Pl_Origin[3];
	float EntityAgl[3];
	bool SpawnPortal = true;
	
	GetClientEyePosition(client, Pl_Origin);
	GetClientEyeAngles(client, Pl_Angles);
	
	Handle trace;
	trace = TR_TraceRayFilterEx(Pl_Origin, Pl_Angles, MASK_ALL, RayType_Infinite, TraceEntityFilterPlayer, client); //MASK_SOLID pour detecter les joueurs
	if (!TR_DidHit(trace)) 
	{
		delete trace;	
		return;
	}
	
	int EntColid = TR_GetEntityIndex(trace);
	TR_GetPlaneNormal(trace, EntityAgl);
	
	if(EntColid == -1)	// Invalid wall or entity => No portal spawn
		SpawnPortal = false;
	else
	{
		char EntClsName[64];
		GetEntityClassname(EntColid, EntClsName, sizeof(EntClsName));
		//LogMessage("EntColid: %i, Classname: %s", EntColid, EntClsName);
		
		if(StrEqual("func_door", EntClsName)) // No Portal on door !
			SpawnPortal = false;
		
		// Can spawn portal on prop_dynamic or physics ?
		if(!cvarProp.BoolValue && (StrEqual("prop_dynamic", EntClsName) || StrEqual("prop_physics", EntClsName))) 
			SpawnPortal = false;
			
	}
	delete trace;
	
	GetVectorAngles(EntityAgl, EntityAgl);	
	if(EntityAgl[1] == 0.0 && (EntityAgl[0] == 270.0 || EntityAgl[0] == 90.0))
		EntityAgl[1] = Pl_Angles[1];
	//PrintToChatAll("p_angl: %f, %f ,%f",EntityAgl[0], EntityAgl[1], EntityAgl[2]);	
	
	float RocketPos[3];
	float vBufferi[3];
	float Vel[3];
	char TargetName[10];
	
	GetAngleVectors(Pl_Angles, vBufferi, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vBufferi, Vel);
	ScaleVector(Vel, 2000.0);
	
	// Spawn PortalGun projectile ---
	int ent_rocket = CreateEntityByName("tf_projectile_energy_ball");
	SetEntData(ent_rocket, FindSendPropInfo("CTFProjectile_Rocket", "m_iTeamNum"), type+2, true);
	SetEntPropEnt(ent_rocket, Prop_Send, "m_hOwnerEntity", client);
	
	if(SpawnPortal)
		Format(TargetName, sizeof(TargetName), "%s_%i_%i", PORTALGUN_ID, client, type);
	else
		Format(TargetName, sizeof(TargetName), "%s_%i_-1", PORTALGUN_ID, client);
	DispatchKeyValue(ent_rocket, "targetname", TargetName);
	DispatchSpawn(ent_rocket);
	
	TeleportEntity(ent_rocket, Pl_Origin, Pl_Angles, Vel);
	
	//Add Particle on PortalGun projectile ---
	int iParticle = CreateEntityByName("info_particle_system");
	if(IsValidEdict(iParticle))
	{		
		if(type == 1)
			DispatchKeyValue(iParticle, "effect_name", "critgun_weaponmodel_blu");
		else
			DispatchKeyValue(iParticle, "effect_name", "critgun_weaponmodel_red");
		GetEntPropVector(ent_rocket, Prop_Send, "m_vecOrigin", RocketPos);
		TeleportEntity(iParticle, RocketPos, NULL_VECTOR, NULL_VECTOR);

		SetVariantString("!activator");
		AcceptEntityInput(iParticle, "SetParent", ent_rocket, iParticle, 0);	
		
		DispatchSpawn(iParticle);
		ActivateEntity(iParticle);
		AcceptEntityInput(iParticle, "Start");
	}   
	
	if(SpawnPortal)
	{
		g_Portal[client][type][vec_Angle][0] 	= EntityAgl[0];
		g_Portal[client][type][vec_Angle][1] 	= EntityAgl[1];
		g_Portal[client][type][vec_Angle][2]	= EntityAgl[2];
	}
}

bool IsPortal(int entRef)
{
	if(!IsValidEdict(EntRefToEntIndex(entRef)))
		return false;
		
	char ClassName[64];
	GetEdictClassname(EntRefToEntIndex(entRef), ClassName, sizeof(ClassName));
	if(!StrEqual("prop_dynamic",ClassName))
		return false;
		
	char modelname[128];
	GetEntPropString(EntRefToEntIndex(entRef), Prop_Data, "m_ModelName", modelname, 128);
	if(StrEqual(modelname, PORTAL))
		return true;
	else
		return false;
}


/////////////////////////////////////////////////////////////////////////////////////////////
//							Teleportation
////////////////////////////////////////////////////////////////////////////////////////////


float operator%(float oper1, float oper2)
{
	return oper1 - (oper2 * (oper1/oper2));
}

stock int RandInt()
{
	int a=1103515245, b=12345, m=2147483648;
	int nombre = GetTime();    	
	for(int i=0; i<15; i++){
		nombre = (a*nombre+ b) % m;
	}
	
	if(nombre < 0) nombre = -nombre;
	return nombre;
}

void tpPlayer(int client, int Pt_client, int type, int ID_Portal_A)
{
	float Pos[3];
	float EntAngle[3];
	float Pleye[3];
	float Velo[3];
	float Sph[3];
	float v_Angle[3];
	
	for(int i=0; i<3; i++)
		v_Angle[i] = g_Portal[Pt_client][GetEntType(ID_Portal_A)][vec_Angle][i];
	
	int Particle 	= CreateEntityByName("info_particle_system"); // Spawn Particle Portal A (enter)
	if (IsValidEdict(Particle))
	{		
		if(type == 0)
		{
			float v_Pos[3];
			for(int i=0; i<3; i++)
				v_Pos[i] = g_Portal[Pt_client][1][vec_Pos][i];
				
			DispatchKeyValue(Particle, "effect_name", "teleportedin_blue");
			TeleportEntity(Particle, v_Pos, v_Angle, NULL_VECTOR);
		}
		else
		{
			float v_Pos[3];
			for(int i=0; i<3; i++)
				v_Pos[i] = g_Portal[Pt_client][0][vec_Pos][i];
				
			DispatchKeyValue(Particle, "effect_name", "teleportedin_red");
			TeleportEntity(Particle, v_Pos, v_Angle, NULL_VECTOR);
		}

		DispatchSpawn(Particle);
		ActivateEntity(Particle);
		AcceptEntityInput(Particle, "Start");
		CreateTimer(0.5, TimerDeleteParticule, EntIndexToEntRef(Particle));
	}
	

	// data ---
	
	char ClassName[64];
	GetEdictClassname(EntRefToEntIndex(g_Portal[Pt_client][type][ID]), ClassName, sizeof(ClassName));
	
	if(!StrEqual("prop_dynamic",ClassName))
		return;
		
	GetEntPropVector(EntRefToEntIndex(g_Portal[Pt_client][type][ID]), Prop_Send, "m_vecOrigin", Pos);
	GetEntPropVector(EntRefToEntIndex(g_Portal[Pt_client][type][ID]), Prop_Data, "m_angRotation", EntAngle); 
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", Velo);
	GetClientEyeAngles(client, Pleye);

	
	//Calcul exit Position ---
	
	int Radius = 50;
	if(g_Portal[Pt_client][type][vec_Angle][0] > 268 )	//Sky direction
		Radius = 15;
	else if(g_Portal[Pt_client][type][vec_Angle][0] > 85.0 && g_Portal[Pt_client][type][vec_Angle][0] < 92.0)	//Floor direction
		Radius = 120;
		
	//	     Radius * Cos(rad phy) * sin(rad teta)
	Sph[0] = Radius * Cosine(EntAngle[0] * FLOAT_PI / 180) * Cosine(EntAngle[1] * FLOAT_PI / 180) ;
	Sph[1] = Radius * Cosine(EntAngle[0] * FLOAT_PI / 180) * Sine(EntAngle[1] * FLOAT_PI / 180);
	Sph[2] = Radius * -Sine(EntAngle[0] * FLOAT_PI / 180);
	Sph[0] += Pos [0];
	Sph[1] += Pos [1];
	Sph[2] += Pos [2];
	
	if(g_Portal[Pt_client][type][vec_Angle][0] >= 0.0 && g_Portal[Pt_client][type][vec_Angle][0] <= 5.0)
		Sph[2] -= 20.0;
		
	
	//Calcul exit angle ---
	
	float PrtA_Opp[3];
	float ExitAngle[3];
	float Diff[3];
	
	PrtA_Opp[0]	= 0.0 - g_Portal[Pt_client][GetEntType(ID_Portal_A)][vec_Angle][0];
	PrtA_Opp[1]	= g_Portal[Pt_client][GetEntType(ID_Portal_A)][vec_Angle][1] - 180.0;
	PrtA_Opp[2]	= 0.0;
	
	Diff[0] = Pleye[0] - PrtA_Opp[0];
	Diff[1] = Pleye[1] - PrtA_Opp[1];
	
	ExitAngle[0] = g_Portal[Pt_client][type][vec_Angle][0] - Diff[0];
	ExitAngle[1] = g_Portal[Pt_client][type][vec_Angle][1] - Diff[1];
	
	if(ExitAngle[0] > 90.0)
		ExitAngle[0] = ExitAngle[0] % 90.0;
	else if(ExitAngle[0] < 90.0)
		ExitAngle[0] = ExitAngle[0] % -90.0;
	
	if(ExitAngle[1] < 0.0)
		ExitAngle[1] += 360.0;
	else if(ExitAngle[1] > 180.0)
		ExitAngle[1] = ExitAngle[1] % 180.0;
	
	
	//Calcul exit velo ---
	
	float PlAngle[3];
	float VeloAngle[3];
	float Speed;
	float ExitVelo[3];
	
	Speed = GetVectorLength(Velo);
	GetVectorAngles(Velo, PlAngle);
	//PrintToChat(client, "vel: %f, %f, %f", Velo[0], Velo[1], Velo[2]);
	
	if(g_Portal[Pt_client][type][vec_Angle][0] > 88.0 && g_Portal[Pt_client][type][vec_Angle][0] < 92.0 ||
		g_Portal[Pt_client][type][vec_Angle][0] > 268.0 && g_Portal[Pt_client][type][vec_Angle][0] < 272.0)
	{
		Diff[0] = PlAngle[0] - PrtA_Opp[0];
		Diff[1] = PlAngle[1] - PrtA_Opp[1];
		
		VeloAngle[0] = g_Portal[Pt_client][type][vec_Angle][0] - Diff[0];
		VeloAngle[1] = g_Portal[Pt_client][type][vec_Angle][1] - Diff[1];
		
		if(VeloAngle[0] > 90.0)
			VeloAngle[0] = VeloAngle[0] % 90.0;
		
		if(VeloAngle[1] < 0.0)
			VeloAngle[1] += 360.0;
		else if(VeloAngle[1] > 180.0)
			VeloAngle[1] = VeloAngle[1] % 180.0;
	}
	else
	{
		for(int i = 0; i<2; i++)
			VeloAngle[i] = g_Portal[Pt_client][type][vec_Angle][i];
	}
	
	
	ExitVelo[0] = Speed * Cosine((VeloAngle[0]) * FLOAT_PI / 180) * Cosine((VeloAngle[1]) * FLOAT_PI / 180);
	ExitVelo[1] = Speed * Cosine((VeloAngle[0]) * FLOAT_PI / 180) * Sine((VeloAngle[1]) * FLOAT_PI / 180);
	ExitVelo[2] = Speed * -Sine((VeloAngle[0]) * FLOAT_PI / 180);
	
	ExitVelo[2] += Radius == 15 ? 100.0 : 0.0; // sky direction, give speed sky direction bonus to do bigger jump.
	
	// Speed Limit !
	
	float Div;
	float SpeedLimit = 1000.0;
	
	for(int i=0; i<3; i++)
	{
		if(ExitVelo[i] > SpeedLimit || ExitVelo[i] < -SpeedLimit)
		{
			Div = ExitVelo[i] / SpeedLimit;
			
			if(Div < 0.0)
				Div = 0.0 - Div;
			
			for(int j=0; j<3; j++)
				ExitVelo[j] /= Div;
			
			continue;
		}
	}
	
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", Pos);
	
	TeleportEntity(client, Sph, ExitAngle, ExitVelo);
	
	
	Particle 	= CreateEntityByName("info_particle_system");
	if (IsValidEdict(Particle))
	{		
		if(type == 0)
			DispatchKeyValue(Particle, "effect_name", "teleportedin_red");
		else
			DispatchKeyValue(Particle, "effect_name", "teleportedin_blue");
			
		float v_Angle2[3];
		float v_Pos2[3];
		for(int i=0; i<3; i++)
		{
			v_Angle2[i] = g_Portal[Pt_client][type][vec_Angle][i];
			v_Pos2[i] = g_Portal[Pt_client][type][vec_Pos][i];
		}
		
		TeleportEntity(Particle, v_Pos2, v_Angle2, NULL_VECTOR);
		DispatchSpawn(Particle);
		ActivateEntity(Particle);
		AcceptEntityInput(Particle, "Start");
		CreateTimer(0.5, TimerDeleteParticule, EntIndexToEntRef(Particle));
	}
	
	// Fix position
	/*
	new i=0;
	while(IsPlayerStuck(client) && i != 5)
	{
		PrintToChat(client,"You are stuck ! %i", i);
		Sph[2] -= 10.0;
		TeleportEntity(client, Sph, ExitAngle, ExitVelo);
		i++;
	}
	
	if(i >= 5)	// Where r u ???!
	{		
		TeleportEntity(client, Pos, Pleye, Velo);
		
		RemoveEdict(EntRefToEntIndex(g_Portal[Pt_client][type][ID]));
		g_Portal[Pt_client][type][ID] = -1;
		
		if(type == 0)
			SetEntProp(EntRefToEntIndex(g_Portal[Pt_client][1][ID]), Prop_Send, "m_nSkin", GetEntType(g_Portal[Pt_client][1][ID]));
		else
			SetEntProp(EntRefToEntIndex(g_Portal[Pt_client][0][ID]), Prop_Send, "m_nSkin", GetEntType(g_Portal[Pt_client][0][ID]));
			
		ClientCommand(Pt_client, "playgamesound portalmod_gun/weapons/portalgun/portal_fizzle2.mp3");
		new ActiveWeapon 	= GetEntPropEnt(Pt_client, Prop_Data, "m_hActiveWeapon");
		if(IsValidEntity(ActiveWeapon))
		{
			new idx	= GetEntProp(ActiveWeapon, Prop_Send, "m_iItemDefinitionIndex");
			if(idx == StringToInt(PORTALGUN_ID))
			{
				SetEntProp(GetEntPropEnt(Pt_client, Prop_Data, "m_hViewModel"), Prop_Send, "m_nSequence", 2);
				CreateTimer(0.1, TimerPortal, Pt_client);
			}
		}
	}
	else
	{*/
	CanTP[client] = false;
	CreateTimer(0.4, TimerCanTP, client);

	if(GetRandomInt(0, 1) %1 == 0)							
		EmitAmbientSound("portalmod_gun/player/portal_exit1.mp3", Sph, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
	else
		EmitAmbientSound("portalmod_gun/player/portal_exit2.mp3", Sph, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
	//}
}


/////////////////////////////////////////////////////////////////////////////////////////////
//							Reset PortalMod
////////////////////////////////////////////////////////////////////////////////////////////


public Action ResetPlugin(int client, int args)
{
	if(!cvarEnabled.BoolValue)
	{
		ReplyToCommand(client, "[PORTALMOD] Disabled !");
		return Plugin_Handled;
	}
	
	if(IsValidClient(client))
		PrintToChat(client, "[PORTALMOD] [0/2] Will be reset");
	else
		ReplyToCommand(client, "[PORTALMOD] [0/2] Will be reset");
	
	for(int i=1; i<MaxClients; i++)
		RemovePortalGun(i);
		
	if(IsValidClient(client))
		PrintToChat(client, "[PORTALMOD] [1/2] Portal Gun removed");
	else
		ReplyToCommand(client, "[PORTALMOD] [1/2] Portal Gun removed");
		
	char newVal[2];
	cvarFlag.GetString(newVal, sizeof(newVal));
	GetImmunityFlag(newVal);
	
	for(int i=0; i<9; i++)
		ChellClass[i] = GetConVarBool(cvarClass[i]);
		
	Initialisation();

	if(IsValidClient(client))
		PrintToChat(client, "[PORTALMOD] [2/2]  Initialisation : Done !");
	else
		ReplyToCommand(client, "[PORTALMOD] [2/2] Initialisation : Done !");
	
	return Plugin_Handled;
}


/////////////////////////////////////////////////////////////////////////////////////////////
//							Reset PortalMod
////////////////////////////////////////////////////////////////////////////////////////////


public int Native_GiveClientPortalGun(Handle plugin, int numParams)
{
	int client = GetNativeCell(1); 
	if(!IsValidClient(client)) 
	{
		LogMessage("[PORTALMOD] Error invalid client in Native GiveClientPortalGun()");
		return;
	}
	
	IsChell[client] = true;
	
	if(PlayerTeam[client] == 1 || PlayerTeam[client] == 0) // If valid team: Equip portalgun 
		GiveRevolver(client);
}

public int Native_IsClientHasPortalGun(Handle plugin, int numParams)
{
	int client = GetNativeCell(1); 
	if(!IsValidClient(client)) 
	{
		LogMessage("[PORTALMOD] Error invalid client in Native IsClientHasPortalGun()");
		return false;
	}
	
	if(!IsChell[client]) 
		return false;
		
	return true;
}

public int Native_RemoveClientPortalGun(Handle plugin, int numParams)
{
	int client = GetNativeCell(1); 
	if(!IsValidClient(client)) 
	{
		LogMessage("[PORTALMOD] Error invalid client in Native RemoveClientPortalGun()");
		return;
	}
	
	if(IsChell[client]) 
		RemovePortalGun(client);
}


public int Native_GetClientPortalEntRef(Handle plugin, int numParams)
{
	int client = GetNativeCell(1); 
	if(!IsValidClient(client)) 
	{
		LogMessage("[PORTALMOD] Error invalid client in Native GetClientPortalEntRef()");
		return -1;
	}
	
	int type = GetNativeCell(2);
	if(type > 1 || type < 0)
	{
		LogMessage("[PORTALMOD] Error invalid portal type in Native GetClientPortalEntRef()");
		return -1;
	}
	
	return g_Portal[client][type][ID];
}


