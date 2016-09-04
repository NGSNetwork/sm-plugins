//Keeping in mind almost all of this is converted from Damizean's TF2 Equipment
//Manager, uh... Good luck and happy reading!
// *********************************************************************************
// PREPROCESSOR
// *********************************************************************************
#pragma newdecls required
#pragma semicolon 1			  // Force strict semicolon mode.

// *********************************************************************************
// INCLUDES
// *********************************************************************************
#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <clientprefs>
#include <morecolors>

// *********************************************************************************
// CONSTANTS
// *********************************************************************************
// ---- Plugin-related constants ---------------------------------------------------
#define PLUGIN_NAME				"[NGS] PerClass Special Models"
#define PLUGIN_AUTHOR			"FlaminSarge (based on Damizean's TF2 Equipment Manager) / TheXeon"
#define PLUGIN_VERSION			"1.0.0"
#define PLUGIN_CONTACT			"http://forums.alliedmods.net/"
#define CVAR_FLAGS				FCVAR_NOTIFY

//#define DEBUG					// Uncomment this for debug.information

// ---- Items management -----------------------------------------------------------
#define MAX_ITEMS				256
#define MAX_SLOTS				1
#define MAX_LENGTH				256

// ---- Wearables flags ------------------------------------------------------------
#define PLAYER_ADMIN				(1 << 0)		// Player is admin.
#define PLAYER_OVERRIDE				(1 << 1)		// Player is overriding the restrictions of the items.
#define PLAYER_LOCK					(1 << 2)		// Player has it's equipment locked

#define FLAG_ADMIN_ONLY				(1 << 0)		// Only admins can use this item.
#define FLAG_USER_DEFAULT			(1 << 1)		// This is the forced default for users.
#define FLAG_ADMIN_DEFAULT			(1 << 2)		// This is the forced default for admins.
#define FLAG_HIDDEN					(1 << 3)		// Hidden from list
#define FLAG_INVISIBLE				(1 << 4)		// Invisible! INVISIBLE!
#define FLAG_NO_ANIM				(1 << 5)
#define FLAG_HIDE_HATS				(1 << 6)
#define FLAG_REQUIRES_STEAMID		(1 << 7)
#define FLAG_HIDE_WEAPONS			(1 << 8)		//Not in use yet

// ---- Bodygroup setting flags ----------------------------------------------------
#define FLAG_HIDE_SCOUT_HAT			(1 << 0)
#define FLAG_HIDE_SCOUT_HEADPHONES	(1 << 1)
#define FLAG_HIDE_SCOUT_FEET		(1 << 2)
#define FLAG_HIDE_SCOUT_DOGTAGS		(1 << 3)

#define FLAG_SHOW_SOLDIER_ROCKET	(1 << 4)
#define FLAG_HIDE_SOLDIER_HELMET	(1 << 5)
#define FLAG_HIDE_SOLDIER_GRENADES	(1 << 6)

#define FLAG_HIDE_PYRO_HEAD			(1 << 7)
#define FLAG_HIDE_PYRO_GRENADES		(1 << 8)

#define FLAG_SHOW_DEMO_SMILE		(1 << 9)
#define FLAG_HIDE_DEMO_FEET			(1 << 10)

#define FLAG_HIDE_HEAVY_HANDS		(1 << 11)

#define FLAG_HIDE_ENGINEER_HELMET	(1 << 12)
#define FLAG_SHOW_ENGINEER_ARM		(1 << 13)

#define FLAG_HIDE_MEDIC_BACKPACK	(1 << 14)

#define FLAG_SHOW_SNIPER_ARROWS		(1 << 15)
#define FLAG_HIDE_SNIPER_HAT		(1 << 16)
#define FLAG_SHOW_SNIPER_DARTS		(1 << 17)

#define FLAG_SHOW_SPY_MASK			(1 << 18)

// classes and teams
#define CLASS_UNKNOWN				(1 << 0)
#define CLASS_SCOUT					(1 << 1)
#define CLASS_SNIPER				(1 << 2)
#define CLASS_SOLDIER				(1 << 3)
#define CLASS_DEMOMAN				(1 << 4)
#define CLASS_MEDIC					(1 << 5)
#define CLASS_HEAVY					(1 << 6)
#define CLASS_PYRO					(1 << 7)
#define CLASS_SPY					(1 << 8)
#define CLASS_ENGINEER				(1 << 9)
#define CLASS_ALL					(0b1111111111)

//First two unused
#define TEAM_UNASSIGNED				(1 << 0)
#define TEAM_SPECTATOR				(1 << 1)
#define TEAM_RED					(1 << 2)
#define TEAM_BLU					(1 << 3)

// ---- Engine flags ---------------------------------------------------------------
#define EF_BONEMERGE				(1 << 0)
#define EF_BRIGHTLIGHT				(1 << 1)
#define EF_DIMLIGHT					(1 << 2)
#define EF_NOINTERP					(1 << 3)
#define EF_NOSHADOW					(1 << 4)
#define EF_NODRAW					(1 << 5)
#define EF_NORECEIVESHADOW			(1 << 6)
#define EF_BONEMERGE_FASTCULL		(1 << 7)
#define EF_ITEM_BLINK				(1 << 8)
#define EF_PARENT_ANIMATES			(1 << 9)

// ---- Game bodygroups ------------------------------------------------------------
#define BODYGROUP_SCOUT_HAT				(1 << 0)
#define BODYGROUP_SCOUT_HEADPHONES		(1 << 1)
#define BODYGROUP_SCOUT_SHOESSOCKS		(1 << 2)
#define BODYGROUP_SCOUT_DOGTAGS			(1 << 3)

#define BODYGROUP_SOLDIER_ROCKET		(1 << 0)
#define BODYGROUP_SOLDIER_HELMET		(1 << 1)
#define BODYGROUP_SOLDIER_MEDAL			(1 << 2)
#define BODYGROUP_SOLDIER_GRENADES		(1 << 3)

#define BODYGROUP_PYRO_HEAD				(1 << 0)
#define BODYGROUP_PYRO_GRENADES			(1 << 1)

#define BODYGROUP_DEMO_SMILE			(1 << 0)
#define BODYGROUP_DEMO_SHOES			(1 << 1)

#define BODYGROUP_HEAVY_HANDS			(1 << 0)

#define BODYGROUP_ENGINEER_HELMET		(1 << 0)
#define BODYGROUP_ENGINEER_ARM			(1 << 1)

#define BODYGROUP_MEDIC_BACKPACK		(1 << 0)

#define BODYGROUP_SNIPER_ARROWS			(1 << 0)
#define BODYGROUP_SNIPER_HAT			(1 << 1)
#define BODYGROUP_SNIPER_BULLETS		(1 << 2)

#define BODYGROUP_SPY_MASK				(1 << 0)

// *********************************************************************************
// VARIABLES
// *********************************************************************************

// ---- Player variables -----------------------------------------------------------
int g_iPlayerItem[MAXPLAYERS+1] = { -1, ... };
int g_iPlayerFlags[MAXPLAYERS+1];
int g_iPlayerBGroups[MAXPLAYERS+1];
bool g_bRotationTauntSet[MAXPLAYERS + 1] = { false, ... };
TFClassType g_iPlayerSpawnClass[MAXPLAYERS + 1] = { TFClass_Unknown, ... };

// ---- Item variables -------------------------------------------------------------

int g_iItemCount;
char g_strItemName[MAX_ITEMS][MAX_LENGTH];
char g_strItemModel[MAX_ITEMS][PLATFORM_MAX_PATH];
int g_iItemFlags[MAX_ITEMS];
int g_iItemBodygroupFlags[MAX_ITEMS];
int g_iItemClasses[MAX_ITEMS];
int g_iItemTeams[MAX_ITEMS];
char g_strItemAdmin[MAX_ITEMS][256];
char g_strItemSteamID[MAX_ITEMS][2048];

// ---- Cvars ----------------------------------------------------------------------
ConVar g_hCvarVersion;
ConVar g_hCvarAdminFlags;
ConVar g_hCvarAdminOverride;
ConVar g_hCvarAnnounce;
ConVar g_hCvarAnnouncePlugin;
ConVar g_hCvarForceDefaultOnUsers;
ConVar g_hCvarForceDefaultOnAdmins;
ConVar g_hCvarDelayOnSpawn;
ConVar g_hCvarBlockTriggers;
ConVar g_hCvarFileList;

// ---- Others ---------------------------------------------------------------------
//_: tag stops compiler warnings
Handle g_hCookies[TFClassType] = { view_as<int>(INVALID_HANDLE), ... };

//bool g_bAdminOnly	  = false;
bool g_bAdminOverride  = false;
bool g_bAnnounce	   = false;
bool g_bAnnouncePlugin = false;
bool g_bForceUsers	 = false;
bool g_bForceAdmins	= false;
bool g_bBlockTriggers  = false;
float g_fSpawnDelay	= 0.0;
char g_strAdminFlags[32];
char g_strConfigFilePath[PLATFORM_MAX_PATH];

Handle g_hMenuMain   = null;

// *********************************************************************************
// PLUGIN
// *********************************************************************************
public Plugin myinfo = {
	name		= PLUGIN_NAME,
	author	  = PLUGIN_AUTHOR,
	description = PLUGIN_NAME,
	version	 = PLUGIN_VERSION,
	url		 = PLUGIN_CONTACT
};
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	//morecolors.inc should really just be a plugin at this point
	MarkNativeAsOptional("GetUserMessageType");
	MarkNativeAsOptional("PbSetInt");
	MarkNativeAsOptional("PbSetBool");
	MarkNativeAsOptional("PbSetString");
	MarkNativeAsOptional("PbAddString");
	return APLRes_Success;
}
// *********************************************************************************
// METHODS
// *********************************************************************************

// =====[ BASIC PLUGIN MANAGEMENT ]========================================

// ------------------------------------------------------------------------
// OnPluginStart()
// ------------------------------------------------------------------------
// At plugin start, create and hook all the proper events to manage the
// wearable items.
// ------------------------------------------------------------------------
public void OnPluginStart()
{

	LoadTranslations("common.phrases");

	// Plugin is TF2 only, so make sure it's ran on TF
	char strModName[32]; 
	GetGameFolderName(strModName, sizeof(strModName));
	if (!StrEqual(strModName, "tf"))
	{
		SetFailState("[SM] PerClass Models is only for TF2.");
		return;
	}

	// Create plugin cvars
	g_hCvarVersion				= CreateConVar("tf_playermodels_version", PLUGIN_VERSION, PLUGIN_NAME, CVAR_FLAGS|FCVAR_SPONLY);

	// Create cookies; the _: tags are just to stop compiler warnings, and shouldn't cause an issue
	g_hCookies[TFClass_DemoMan]		= view_as<int>(RegClientCookie("tf_modelmanager_demoman", "", CookieAccess_Protected));
	g_hCookies[TFClass_Engineer]	= view_as<int>(RegClientCookie("tf_modelmanager_engineer", "", CookieAccess_Protected));
	g_hCookies[TFClass_Heavy]		= view_as<int>(RegClientCookie("tf_modelmanager_heavy", "", CookieAccess_Protected));
	g_hCookies[TFClass_Medic]		= view_as<int>(RegClientCookie("tf_modelmanager_medic", "", CookieAccess_Protected));
	g_hCookies[TFClass_Pyro]		= view_as<int>(RegClientCookie("tf_modelmanager_pyro", "", CookieAccess_Protected));
	g_hCookies[TFClass_Scout]		= view_as<int>(RegClientCookie("tf_modelmanager_scout", "", CookieAccess_Protected));
	g_hCookies[TFClass_Sniper]		= view_as<int>(RegClientCookie("tf_modelmanager_sniper", "", CookieAccess_Protected));
	g_hCookies[TFClass_Soldier]		= view_as<int>(RegClientCookie("tf_modelmanager_soldier", "", CookieAccess_Protected));
	g_hCookies[TFClass_Spy]			= view_as<int>(RegClientCookie("tf_modelmanager_spy", "", CookieAccess_Protected));

	// Register console commands
	RegAdminCmd("tf_models_equip",	Cmd_EquipItem,		 ADMFLAG_CHEATS, "Forces to equip a model onto a client.");

	// Hook the proper events and cvars
	HookEvent("post_inventory_application", Event_EquipItem,  EventHookMode_Post);
	HookEvent("player_spawn", Event_RemoveItem,  EventHookMode_Post);
	HookConVarChange(g_hCvarAdminFlags,		   Cvar_UpdateCfg);
	HookConVarChange(g_hCvarAdminOverride,		Cvar_UpdateCfg);
	HookConVarChange(g_hCvarAnnounce,			 Cvar_UpdateCfg);
	HookConVarChange(g_hCvarAnnouncePlugin,	   Cvar_UpdateCfg);
	HookConVarChange(g_hCvarForceDefaultOnUsers,  Cvar_UpdateCfg);
	HookConVarChange(g_hCvarForceDefaultOnAdmins, Cvar_UpdateCfg);
	HookConVarChange(g_hCvarDelayOnSpawn,		 Cvar_UpdateCfg);

	// Load translations for this plugin
	LoadTranslations("tf2_modelmanager.phrases");

	// Execute configs.
	AutoExecConfig(true, "tf2_modelmanager");
}

// ------------------------------------------------------------------------
// OnPluginEnd()
// ------------------------------------------------------------------------
public void OnPluginEnd()
{
	// Destroy all entities for everyone, if possible.
	for (int client=1; client<=MaxClients; client++)
	{
		if (!IsValidClient(client)) continue;
		if (g_iPlayerItem[client] == -1) continue;
		SetVariantString("");
		AcceptEntityInput(client, "SetCustomModel");
	}
}

// ------------------------------------------------------------------------
// Event_RemoveItem()
// ------------------------------------------------------------------------
// On player's death destroy the entity that's meant to be visible for the
// other players.
// ------------------------------------------------------------------------
public void Event_RemoveItem(Handle hEvent, char[] strName, bool bDontBroadcast)
{
	int flags = GetEventInt(hEvent, "death_flags");
	if (flags & TF_DEATHFLAG_DEADRINGER) return;
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	Item_Remove(client);
}

// ------------------------------------------------------------------------
// OnConfigsExecuted()
// ------------------------------------------------------------------------
public void OnConfigsExecuted()
{
	// Determine if the version of the cfg is the correct one
	char strVersion[16]; GetConVarString(g_hCvarVersion, strVersion, sizeof(strVersion));
	if (!StrEqual(strVersion, PLUGIN_VERSION, false))
	{
		LogError("[TF2] Model Manager: WARNING- Your config file might be outdated! This may lead to conflicts with \
		the plugin and non-working cfg. Fix this by backing up then deleting your current config and changing the \
		map. It'll generate a new config with the default cfg, after which you can put in your settings.");
	}
	SetConVarString(g_hCvarVersion, PLUGIN_VERSION);
	// Force Cfg update
	Cvar_UpdateCfg(null, "", "");
}

// ------------------------------------------------------------------------
// UpdateCfg()
// ------------------------------------------------------------------------
public void Cvar_UpdateCfg(Handle hHandle, char[] strOldVal, char[] strNewVal)
{
	g_bAdminOverride  = GetConVarBool(g_hCvarAdminOverride);
	g_bAnnounce	   = GetConVarBool(g_hCvarAnnounce);
	g_bAnnouncePlugin = GetConVarBool(g_hCvarAnnouncePlugin);
	g_bForceUsers	 = GetConVarBool(g_hCvarForceDefaultOnUsers);
	g_bForceAdmins	= GetConVarBool(g_hCvarForceDefaultOnAdmins);
	g_fSpawnDelay	 = GetConVarFloat(g_hCvarDelayOnSpawn);
	g_bBlockTriggers  = GetConVarBool(g_hCvarBlockTriggers);
	GetConVarString(g_hCvarAdminFlags, g_strAdminFlags, sizeof(g_strAdminFlags));
}

// ------------------------------------------------------------------------
// OnClientPutInServer()
// ------------------------------------------------------------------------
// When a client is put in server, greet the player and show off information
// about the plugin.
// ------------------------------------------------------------------------
public void OnClientPutInServer(int client)
{
	g_bRotationTauntSet[client] = false;
	g_iPlayerSpawnClass[client] = TFClass_Unknown;
	g_iPlayerFlags[client] = 0;
	g_iPlayerItem[client] = -1;
	g_iPlayerBGroups[client] = 0;
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if (condition == TFCond_Taunting && GetEntProp(client, Prop_Send, "m_bCustomModelRotates") && !g_bRotationTauntSet[client])
	{
		SetEntProp(client, Prop_Send, "m_bCustomModelRotates", 0);
		g_bRotationTauntSet[client] = true;
	}
}
public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if (condition == TFCond_Taunting && !GetEntProp(client, Prop_Send, "m_bCustomModelRotates") && g_bRotationTauntSet[client])
	{
		SetEntProp(client, Prop_Send, "m_bCustomModelRotates", 1);
		g_bRotationTauntSet[client] = false;
	}
}
// ------------------------------------------------------------------------
// Event_EquipItem()
// ------------------------------------------------------------------------
// On the player spawn (or any other event that requires re-equipment) we
// requip the items the player had selected. If none are found, we also check
// if we should force one upon the player.
// ------------------------------------------------------------------------
public void Event_EquipItem(Handle hEvent, char[] strName, bool bDontBroadcast)
{
	int userid = GetEventInt(hEvent, "userid");
	int client = GetClientOfUserId(userid);
	if (IsValidClient(client))
	{
		if (TF2_GetPlayerClass(client) != TFClass_Unknown && TF2_GetPlayerClass(client) != g_iPlayerSpawnClass[client])
		{
			Item_Remove(client);
		}
		g_iPlayerSpawnClass[client] = TF2_GetPlayerClass(client);
		CreateTimer(g_fSpawnDelay, Timer_EquipItem, userid, TIMER_FLAG_NO_MAPCHANGE);
		RemoveValveHat(client, true);
		HideWeapons(client, true);
	}
}

public Action Timer_EquipItem(Handle hTimer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsValidClient(client)) return Plugin_Continue;
	if (!IsPlayerAlive(client)) return Plugin_Continue;

	// Retrieve current player bodygroups status.
	g_iPlayerBGroups[client] = GetEntProp(client, Prop_Send, "m_nBody");

	// Retrieve the proper cookie value
	g_iPlayerItem[client] = Item_RetrieveSlotCookie(client);

	// Determine if the hats are still valid for the
	// client.
	if (!Item_IsWearable(client, g_iPlayerItem[client]))
	{
		Item_Remove(client);
		g_iPlayerItem[client] = Item_FindDefaultItem(client);
	}

	// Equip the player with the selected item.
	Item_Equip(client, g_iPlayerItem[client]);

	return Plugin_Continue;
}

// ------------------------------------------------------------------------
// OnClientDisconnect()
// ------------------------------------------------------------------------
// When the client disconnects, remove it's equipped items and reset all
// the flags.
// ------------------------------------------------------------------------
public void OnClientDisconnect(int client)
{
	Item_Remove(client, false);
	g_iPlayerFlags[client] = 0;
	g_bRotationTauntSet[client] = false;
	g_iPlayerSpawnClass[client] = TFClass_Unknown;
	g_iPlayerFlags[client] = 0;
	g_iPlayerBGroups[client] = 0;
}

// ------------------------------------------------------------------------
// Item_Equip
// ------------------------------------------------------------------------
// Equip the desired item onto a client.
// ------------------------------------------------------------------------
void Item_Equip(int client, int iItem)
{
	// Assert if the player is alive.
	if (!IsValidClient(client)) return;
	if (!Item_IsWearable(client, iItem)) return;

	// If the player's alive...
	if (IsPlayerAlive(client))
	{
		// Remove the previous entities if it's possible.
		Item_Remove(client, false);

		// If we're about to equip an invisible item, there's no need
		// to generate entities.
		if (!(g_iItemFlags[iItem] & FLAG_INVISIBLE))
		{
			SetVariantString(g_strItemModel[iItem]);
			AcceptEntityInput(client, "SetCustomModel");
			SetEntProp(client, Prop_Send, "m_bCustomModelRotates", !!(g_iItemFlags[iItem] & FLAG_NO_ANIM));
			SetEntProp(client, Prop_Send, "m_bUseClassAnimations", !(g_iItemFlags[iItem] & FLAG_NO_ANIM));
		}

		// Change player's item index
		g_iPlayerItem[client] = iItem;

		// Change the visible body parts.
		SetEntProp(client, Prop_Send, "m_nBody", CalculateBodyGroups(client));

		if (g_iItemFlags[iItem] & FLAG_HIDE_HATS) RemoveValveHat(client);
		if (g_iItemFlags[iItem] & FLAG_HIDE_WEAPONS) HideWeapons(client);
	}
}
void Item_Equip_Admin_Force(int client, int iItem)
{
	// Assert if the player is alive.
	if (!IsValidClient(client)) return;
	if (!Item_IsWearable_Admin_Force(client, iItem)) return;

	if (IsPlayerAlive(client))
	{
		// Remove the previous entities if it's possible.
		Item_Remove(client, false);

		// If we're about to equip an invisible item, there's no need
		// to generate entities.
		if (!(g_iItemFlags[iItem] & FLAG_INVISIBLE))
		{
			SetVariantString(g_strItemModel[iItem]);
			AcceptEntityInput(client, "SetCustomModel");
			SetEntProp(client, Prop_Send, "m_bCustomModelRotates", !!(g_iItemFlags[iItem] & FLAG_NO_ANIM));
			SetEntProp(client, Prop_Send, "m_bUseClassAnimations", !(g_iItemFlags[iItem] & FLAG_NO_ANIM));
		}

		// Change player's item index
		g_iPlayerItem[client] = iItem;

		// Change the visible body parts.
		SetEntProp(client, Prop_Send, "m_nBody", CalculateBodyGroups(client));

		if (g_iItemFlags[iItem] & FLAG_HIDE_HATS) RemoveValveHat(client);
		if (g_iItemFlags[iItem] & FLAG_HIDE_WEAPONS) HideWeapons(client);
	}
}

// ------------------------------------------------------------------------
// Item_Remove
// ------------------------------------------------------------------------
// Remove the item equipped at the selected slot.
// ------------------------------------------------------------------------
void Item_Remove(int client, bool bCheck = true)
{
	// Assert if the player is valid.
	if (bCheck == true && !IsValidClient(client)) return;
	if (g_iPlayerItem[client] == -1) return;
	if (IsValidClient(client))
	{
		SetVariantString("");
		AcceptEntityInput(client, "SetCustomModel");
		SetEntProp(client, Prop_Send, "m_bCustomModelRotates", 0);
		SetVariantString("ParticleEffectStop");
		AcceptEntityInput(client, "DispatchEffect");

		// Recalculate body groups, probably entirely unnecessary
		SetEntProp(client, Prop_Send, "m_nBody", CalculateBodyGroups(client));
	}
	g_iPlayerItem[client] = -1;
}

// ------------------------------------------------------------------------
// Item_ParseTeams()
// ------------------------------------------------------------------------
// Parses the wearable teams, duh.
// ------------------------------------------------------------------------
int Item_ParseTeams(char[] strTeams)
{
	int iFlags;
	if (StrContains(strTeams, "RED", false) != -1 ) iFlags |= TEAM_RED;
	if (StrContains(strTeams, "BLU", false) != -1) iFlags |= TEAM_BLU;
	if (StrContains(strTeams, "ALL", false) != -1)  iFlags |= TEAM_RED|TEAM_BLU;

	return iFlags;
}
// ------------------------------------------------------------------------
// Item_ParseAdmin()
// ------------------------------------------------------------------------
// Parses the admin overrides for an item.
// ------------------------------------------------------------------------
int Item_ParseAdmin(char[] destination, int size, char[] strOverrides)
{
	int count = ReplaceString(strOverrides, 256, " ", ";;");
	strcopy(destination, size, strOverrides);
	return count + 1;
}

// ------------------------------------------------------------------------
// Item_IsWearable()
// ------------------------------------------------------------------------
// Determines if the selected item is wearable by a player (that means,
// the player has the right admin level, is the correct class, etc. These
// Cfg can be overriden if the player has the override flag, though.
// ------------------------------------------------------------------------
bool Item_IsWearable(int client, int item)
{
	// If the selected item is not valid, it can't be wearable! Rargh!
	if (item < 0 || item >= g_iItemCount)
		return false;

	// Determine if the client has the override flag, let them do ANYTHING.
	if (g_iPlayerFlags[client] & PLAYER_OVERRIDE)
		return true;

	if (!ClientHasItemAccess(client, item))
		return false;
	if (g_bAdminOverride && CheckCommandAccess(client, "tf_models_admin_override_access", ADMFLAG_ROOT, true))
		return true;

	if (!(Client_ClassFlags(client) & g_iItemClasses[item]))
		return false;
	if (!(Client_TeamFlags(client) & g_iItemTeams[item]))
		return false;

	char strSteamID[20];
	GetClientAuthId(client, AuthId_Steam2, strSteamID, sizeof(strSteamID));
	if (g_strItemSteamID[item][0] != '\0' && StrContains(g_strItemSteamID[item], strSteamID, false) == -1)
		return false;

	// Success!
	return true;
}
// Client must have ALL of the overrides present in the override stuff.
stock bool ClientHasItemAccess(int client, int item)
{
	char strBuffers[16][32];	//16 overrides should be enough, neh?
	int count = ExplodeString(g_strItemAdmin[item], ";;", strBuffers, 16, 32);
	for (int i = 0; i < count; i++)
	{
		if (strBuffers[i][0] == '\0') continue;	//ignore screwups in the config if somebody put nine spaces between the flags
		if (!CheckCommandAccess(client, strBuffers[i], 0))
			return false;
	}
	return true;
}
bool Item_IsWearable_Admin_Force(int client, int item)
{
	// If the selected item is not valid, it can't be wearable! Rargh!
	if (item < 0 || item >= g_iItemCount)
		return false;

	if (g_iPlayerFlags[client] & PLAYER_OVERRIDE)
		return true;

	if (!(Client_ClassFlags(client) & g_iItemClasses[item]))
		return false;
	if (!(Client_TeamFlags(client) & g_iItemTeams[item]))
		return false;

	// Success!
	return true;
}
// ------------------------------------------------------------------------
// Item_FindDefaultItem()
// ------------------------------------------------------------------------
int Item_FindDefaultItem(int client)
{
	int iFlagsFilter;
	if (g_bForceAdmins && IsUserAdmin(client))	iFlagsFilter = FLAG_ADMIN_DEFAULT;
	else if (g_bForceUsers)									iFlagsFilter = FLAG_USER_DEFAULT;

	if (iFlagsFilter)
	{
		for (int j=0; j<g_iItemCount; j++)
		{
			if (!(g_iItemFlags[j] & iFlagsFilter)) continue;
			if (!Item_IsWearable(client, j))	  continue;

			return j;
		}
	}

	return -1;
}

// ------------------------------------------------------------------------
// Item_RetrieveSlotCookie()
// ------------------------------------------------------------------------
int Item_RetrieveSlotCookie(int client)
{
	if (IsFakeClient(client)) return -1;
	// If the cookies aren't cached, return.
	if (!AreClientCookiesCached(client)) return -1;

	// Retrieve current class
	TFClassType Class = TF2_GetPlayerClass(client);
	if (Class == TFClass_Unknown) return -1;

	// Retrieve the class cookie
	char strCookie[64];
	GetClientCookie(client, g_hCookies[Class], strCookie, sizeof(strCookie));

	// If it's void, return -1
	if (StrEqual(strCookie, "")) return -1;

	// Otherwise, return the cookie value
	return StringToInt(strCookie);
}

// ------------------------------------------------------------------------
// Item_SetSlotCookie()
// ------------------------------------------------------------------------
void Item_SetSlotCookie(int client)
{
	if (IsFakeClient(client)) return;
	// If the cookies aren't cached, return.
	if (!AreClientCookiesCached(client)) return;

	// Retrieve current class
	TFClassType Class;
	if (IsPlayerAlive(client)) Class = TF2_GetPlayerClass(client);
	else Class = view_as<TFClassType>(GetEntProp(client, Prop_Send, "m_iDesiredPlayerClass"));
	if (Class == TFClass_Unknown) return;

	// Set the class cookie
	char strCookie[64];
	IntToString(g_iPlayerItem[client], strCookie, sizeof(strCookie));
	SetClientCookie(client, g_hCookies[Class], strCookie);
}


// ------------------------------------------------------------------------
// Client_ClassFlags()
// ------------------------------------------------------------------------
// Calculates the current class flags and returns them
// ------------------------------------------------------------------------
int Client_ClassFlags(int client)
{
	TFClassType class;
	if (IsPlayerAlive(client)) class = TF2_GetPlayerClass(client);
	else class = view_as<TFClassType>(GetEntProp(client, Prop_Send, "m_iDesiredPlayerClass"));
	return (1 << (view_as<int>(class)));
}

// ------------------------------------------------------------------------
// Client_TeamFlags()
// ------------------------------------------------------------------------
// Calculates the current team flags and returns them
// ------------------------------------------------------------------------
int Client_TeamFlags(int client)
{
	return (1 << GetClientTeam(client));
}

// ------------------------------------------------------------------------
// Cmd_EquipItem()
// ------------------------------------------------------------------------
// Force a client to equip an specific items.
// ------------------------------------------------------------------------
public Action Cmd_EquipItem(int client, int args)
{
	if (args < 2) { ReplyToCommand(client, "[TF2] Usage: tf_models_equip <#id|name> <item name>."); return Plugin_Handled; }
	char strArgs[128]; GetCmdArgString(strArgs, sizeof(strArgs));
	// Retrieve arguments
	char strTarget[32];
	int position = BreakString(strArgs, strTarget, sizeof(strTarget));
	if (position == -1) { ReplyToCommand(client, "[TF2] Usage: tf_models_equip <#id|name> <item name>."); return Plugin_Handled; }
	char strItem[128];
	strcopy(strItem, sizeof(strItem), strArgs[position]);

	int iItem = -1;

	// Check if item exists and if so, grab index
	char names[128];
	for (int i=0; i<g_iItemCount; i++)
	{
		else if (StrContains(g_strItemName[i], strItem, false) != -1)	//StrEqual(g_strItemName[i], strItem, false))
		{
			foundcount++;
			iItem = i;
			if (foundcount == 1) strcopy(names, sizeof(names), g_strItemName[i]);
			else
			{
				char buffer[32];
				Format(buffer, sizeof(buffer), ", %s", g_strItemName[i]);
				StrCat(names, sizeof(names), buffer);
			}
		}
	}

	// Apply to all targets
	char message[MAX_MESSAGE_LENGTH];
	for (int i = 0; i < iTargetCount; i++)
	{
		if (!IsValidClient(iTargetList[i])) continue;

		// Equip item and tell to client.
		Item_Equip_Admin_Force(iTargetList[i], iItem);
		Item_SetSlotCookie(iTargetList[i]);
		CPrintToChat(iTargetList[i], "%t", "Message_ForcedEquip", g_strItemName[iItem]);
	}

	return Plugin_Handled;
}

/*
// ------------------------------------------------------------------------
// Cmd_RemoveItem()
// ------------------------------------------------------------------------
public Action Cmd_RemoveItem(int client, int args)
{
	// Determine if the number of arguments is valid
	if (args < 1) { ReplyToCommand(client, "[TF2] Usage: tf_models_remove <#id|name>."); return Plugin_Handled; }

	// Retrieve arguments
	char strTarget[32]; GetCmdArg(1, strTarget, sizeof(strTarget));

	// Process the targets
	char strTargetName[MAX_TARGET_LENGTH];
	int iTargetList[MAXPLAYERS], iTargetCount;
	bool bTargetTranslate;

	if ((iTargetCount = ProcessTargetString(strTarget, client, iTargetList, MAXPLAYERS, COMMAND_FILTER_CONNECTED,
	strTargetName, sizeof(strTargetName), bTargetTranslate)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	// Apply to all targets
	for (int i = 0; i < iTargetCount; i++)
	{
		if (!IsValidClient(iTargetList[i])) continue;

		Item_Remove(iTargetList[i]);
		Item_SetSlotCookie(iTargetList[i]);
		CPrintToChat(iTargetList[i], "%t", "Message_ForcedRemove");
	}

	// Done
	return Plugin_Handled;
}
*/

stock bool IsUserAdmin(int client)
{
	int ibFlags = ReadFlagString(g_strAdminFlags);
	AdminId admin = GetUserAdmin(client);
	if (admin == INVALID_ADMIN_ID) return false;
	if (GetAdminFlags(admin, Access_Effective) & (ibFlags|ADMFLAG_ROOT))	return true;
	return false;
}

// ------------------------------------------------------------------------
// IsValidClient
// ------------------------------------------------------------------------
public bool IsValidClient (int client)
{
	if(client > 4096) client = EntRefToEntIndex(client);
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsFakeClient(client)) return false;
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}
// ------------------------------------------------------------------------
// FindEntityByClassnameSafe
// ------------------------------------------------------------------------
// By Exvel
// ------------------------------------------------------------------------
stock int FindEntityByClassnameSafe(int iStart, const char[] strClassname)
{
	while (iStart > -1 && !IsValidEntity(iStart)) iStart--;
	return FindEntityByClassname(iStart, strClassname);
}

// ------------------------------------------------------------------------
// CalculateBodyGroups
// ------------------------------------------------------------------------
int CalculateBodyGroups(int client)
{
	int iBodyGroups = g_iPlayerBGroups[client];
	int iItemGroups = 0;

	if (g_iPlayerItem[client] != -1)
		iItemGroups |= g_iItemBodygroupFlags[g_iPlayerItem[client]];
	TFClassType class = TF2_GetPlayerClass(client);
	switch(class)
	{
		case TFClass_Scout:
		{
			if (iItemGroups & FLAG_HIDE_SCOUT_HAT)			iBodyGroups |= BODYGROUP_SCOUT_HAT;
			if (iItemGroups & FLAG_HIDE_SCOUT_HEADPHONES)	iBodyGroups |= BODYGROUP_SCOUT_HEADPHONES;
			if (iItemGroups & FLAG_HIDE_SCOUT_FEET)			iBodyGroups |= BODYGROUP_SCOUT_SHOESSOCKS;
			if (iItemGroups & FLAG_HIDE_SCOUT_DOGTAGS)		iBodyGroups |= BODYGROUP_SCOUT_DOGTAGS;
		}
		case TFClass_Soldier:
		{
			if (iItemGroups & FLAG_SHOW_SOLDIER_ROCKET)		iBodyGroups |= BODYGROUP_SOLDIER_ROCKET;
			if (iItemGroups & FLAG_HIDE_SOLDIER_HELMET)		iBodyGroups |= BODYGROUP_SOLDIER_HELMET;
			if (iItemGroups & FLAG_HIDE_SOLDIER_GRENADES)	iBodyGroups |= BODYGROUP_SOLDIER_GRENADES;
		}
		case TFClass_Pyro:
		{
			if (iItemGroups & FLAG_HIDE_PYRO_HEAD)			iBodyGroups |= BODYGROUP_PYRO_HEAD;
			if (iItemGroups & FLAG_HIDE_PYRO_GRENADES)		iBodyGroups |= BODYGROUP_PYRO_GRENADES;
		}
		case TFClass_DemoMan:
		{
			if (iItemGroups & FLAG_SHOW_DEMO_SMILE)			iBodyGroups |= BODYGROUP_DEMO_SMILE;
			if (iItemGroups & FLAG_HIDE_DEMO_FEET)			iBodyGroups |= BODYGROUP_DEMO_SHOES;
		}
		case TFClass_Heavy:
		{
			if (iItemGroups & FLAG_HIDE_HEAVY_HANDS)			iBodyGroups = BODYGROUP_HEAVY_HANDS;
		}
		case TFClass_Engineer:
		{
			if (iItemGroups & FLAG_HIDE_ENGINEER_HELMET)		iBodyGroups |= BODYGROUP_ENGINEER_HELMET;
			if (iItemGroups & FLAG_SHOW_ENGINEER_ARM)		iBodyGroups |= BODYGROUP_ENGINEER_ARM;
		}
		case TFClass_Medic:
		{
			if (iItemGroups & FLAG_HIDE_MEDIC_BACKPACK)		iBodyGroups |= BODYGROUP_MEDIC_BACKPACK;
		}
		case TFClass_Sniper:
		{
			if (iItemGroups & FLAG_SHOW_SNIPER_ARROWS)		iBodyGroups |= BODYGROUP_SNIPER_ARROWS;
			if (iItemGroups & FLAG_HIDE_SNIPER_HAT)			iBodyGroups |= BODYGROUP_SNIPER_HAT;
			if (iItemGroups & FLAG_SHOW_SNIPER_DARTS)		iBodyGroups |= BODYGROUP_SNIPER_BULLETS;
		}
		case TFClass_Spy:
		{
			if (iItemGroups & FLAG_SHOW_SPY_MASK)			iBodyGroups |= BODYGROUP_SPY_MASK;
		}
	}

	return iBodyGroups;
}
stock void HideWeapons(int client, bool unhide = false)
{
	HideWeaponWearables(client, unhide);
	int m_hMyWeapons = FindSendPropInfo("CTFPlayer", "m_hMyWeapons");	

	for (int i = 0, weapon; i < 47; i += 4)
	{
		weapon = GetEntDataEnt2(client, m_hMyWeapons + i);
		char classname[64];
		if (weapon > MaxClients && IsValidEdict(weapon) && GetEdictClassname(weapon, classname, sizeof(classname)) && StrContains(classname, "weapon") != -1)
		{
			SetEntityRenderMode(weapon, (unhide ? RENDER_NORMAL : RENDER_TRANSCOLOR));
			SetEntityRenderColor(weapon, 255, 255, 255, (unhide ? 255 : 5));
		}
	}
}
stock void HideWeaponWearables(int client, bool unhide = false)
{
	int edict = MaxClients+1;
	while((edict = FindEntityByClassnameSafe(edict, "tf_wearable")) != -1)
	{
		char netclass[32];
		if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && strcmp(netclass, "CTFWearable") == 0)
		{
			int idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
			if (idx != 57 && idx != 133 && idx != 231 && idx != 444 && idx != 405 && idx != 608 && idx != 642) continue;
			if (GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client)
			{
				SetEntityRenderMode(edict, (unhide ? RENDER_NORMAL : RENDER_TRANSCOLOR));
				SetEntityRenderColor(edict, 255, 255, 255, (unhide ? 255 : 0));
			}
		}
	}
}
stock void RemoveValveHat(int client, bool unhide = false)
{
	int edict = MaxClients+1;
	while((edict = FindEntityByClassnameSafe(edict, "tf_wearable")) != -1)
	{
		char netclass[32];
		if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && strcmp(netclass, "CTFWearable") == 0)
		{
			int idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
			if (idx != 57 && idx != 133 && idx != 231 && idx != 444 && idx != 405 && idx != 608 && idx != 642 && GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client)
			{
				SetEntityRenderMode(edict, (unhide ? RENDER_NORMAL : RENDER_TRANSCOLOR));
				SetEntityRenderColor(edict, 255, 255, 255, (unhide ? 255 : 0));
			}
		}
	}
	edict = MaxClients+1;
	while((edict = FindEntityByClassnameSafe(edict, "tf_powerup_bottle")) != -1)
	{
		char netclass[32];
		if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && strcmp(netclass, "CTFPowerupBottle") == 0)
		{
			int idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
			if (idx != 57 && idx != 133 && idx != 231 && idx != 444 && idx != 405 && idx != 608 && idx != 642 && GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client)
			{
				SetEntityRenderMode(edict, (unhide ? RENDER_NORMAL : RENDER_TRANSCOLOR));
				SetEntityRenderColor(edict, 255, 255, 255, (unhide ? 255 : 0));
			}
		}
	}
}
