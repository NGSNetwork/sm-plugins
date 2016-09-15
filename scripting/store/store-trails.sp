#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <store>
#include <smjansson>
#include <tf2>
#include <tf2_stocks>

enum Trail
{
	String:TrailName[STORE_MAX_NAME_LENGTH],
	String:TrailMaterial[PLATFORM_MAX_PATH],
	Float:TrailLifetime,
	Float:TrailWidth,
	Float:TrailEndWidth,
	TrailFadeLength,
	TrailColor[4],
	TrailModelIndex
}

int g_trails[1024][Trail];
int g_trailCount;

char g_game[32];

Handle g_trailsNameIndex = INVALID_HANDLE;
Handle g_trailTimers[MAXPLAYERS+1];
int g_SpriteModel[MAXPLAYERS + 1];

/**
 * Called before plugin is loaded.
 * 
 * @param myself    The plugin handle.
 * @param late      True if the plugin was loaded after map change, false on map start.
 * @param error     Error message if load failed.
 * @param err_max   Max length of the error message.
 *
 * @return          APLRes_Success for load success, APLRes_Failure or APLRes_SilentFailure otherwise.
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("ZR_IsClientHuman"); 
	MarkNativeAsOptional("ZR_IsClientZombie"); 

	return APLRes_Success;
}

public Plugin myinfo = {
	name        = "[Store] Trails",
	author      = "alongub",
	description = "Trails component for [Store]",
	version     = "1.1-alpha",
	url         = "https://github.com/alongubkin/store"
}

/**
 * Plugin is loading.
 */
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("store.phrases");
	
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("player_death", PlayerDeath);
	HookEvent("player_team", PlayerTeam);
	HookEvent("round_end", RoundEnd);

	GetGameFolderName(g_game, sizeof(g_game));

	Store_RegisterItemType("trails", OnEquip, LoadItem);
}

/** 
 * Called when a new API library is loaded.
 */
public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "store-inventory"))
	{
		Store_RegisterItemType("trails", OnEquip, LoadItem);
	}	
}

/**
 * Map is starting
 */
public void OnMapStart()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		g_SpriteModel[client] = -1;
	}

	for (int item = 0; item < g_trailCount; item++)
	{
		if (strcmp(g_trails[item][TrailMaterial], "") != 0 && (FileExists(g_trails[item][TrailMaterial]) || FileExists(g_trails[item][TrailMaterial], true)))
		{
			char _sBuffer[PLATFORM_MAX_PATH];
			strcopy(_sBuffer, sizeof(_sBuffer), g_trails[item][TrailMaterial]);
			g_trails[item][TrailModelIndex] = PrecacheModel(_sBuffer);
			AddFileToDownloadsTable(_sBuffer);
			ReplaceString(_sBuffer, sizeof(_sBuffer), ".vmt", ".vtf", false);
			AddFileToDownloadsTable(_sBuffer);
		}
	}
}

/**
 * The map is ending.
 */
public void OnMapEnd()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (g_trailTimers[client] != INVALID_HANDLE)
		{
			CloseHandle(g_trailTimers[client]);
			g_trailTimers[client] = INVALID_HANDLE;
		}

		g_SpriteModel[client] = -1;
	}
}

public void Store_OnReloadItems() 
{
	if (g_trailsNameIndex != INVALID_HANDLE)
		CloseHandle(g_trailsNameIndex);
		
	g_trailsNameIndex = CreateTrie();
	g_trailCount = 0;
}

public void LoadItem(const char[] itemName, const char[] attrs)
{
	strcopy(g_trails[g_trailCount][TrailName], STORE_MAX_NAME_LENGTH, itemName);
		
	SetTrieValue(g_trailsNameIndex, g_trails[g_trailCount][TrailName], g_trailCount);
	
	Handle json = json_load(attrs);
	json_object_get_string(json, "material", g_trails[g_trailCount][TrailMaterial], PLATFORM_MAX_PATH);

	g_trails[g_trailCount][TrailLifetime] = json_object_get_float(json, "lifetime")
	; 
	if (g_trails[g_trailCount][TrailLifetime] == 0.0)
		g_trails[g_trailCount][TrailLifetime] = 1.0;

	g_trails[g_trailCount][TrailWidth] = json_object_get_float(json, "width");

	if (g_trails[g_trailCount][TrailWidth] == 0.0)
		g_trails[g_trailCount][TrailWidth] = 15.0;

	g_trails[g_trailCount][TrailEndWidth] = json_object_get_float(json, "endwidth"); 

	if (g_trails[g_trailCount][TrailEndWidth] == 0.0)
		g_trails[g_trailCount][TrailEndWidth] = 6.0;

	g_trails[g_trailCount][TrailFadeLength] = json_object_get_int(json, "fadelength"); 

	if (g_trails[g_trailCount][TrailFadeLength] == 0)
		g_trails[g_trailCount][TrailFadeLength] = 1;

	Handle color = json_object_get(json, "color");

	if (color == INVALID_HANDLE)
	{
		g_trails[g_trailCount][TrailColor] = { 255, 255, 255, 255 };
	}
	else
	{
		for (int i = 0; i < 4; i++)
			g_trails[g_trailCount][TrailColor][i] = json_array_get_int(color, i);

		CloseHandle(color);
	}

	CloseHandle(json);

	if (strcmp(g_trails[g_trailCount][TrailMaterial], "") != 0 && (FileExists(g_trails[g_trailCount][TrailMaterial]) || FileExists(g_trails[g_trailCount][TrailMaterial], true)))
	{
		char _sBuffer[PLATFORM_MAX_PATH];
		strcopy(_sBuffer, sizeof(_sBuffer), g_trails[g_trailCount][TrailMaterial]);
		g_trails[g_trailCount][TrailModelIndex] = PrecacheModel(_sBuffer);
		AddFileToDownloadsTable(_sBuffer);
		ReplaceString(_sBuffer, sizeof(_sBuffer), ".vmt", ".vtf", false);
		AddFileToDownloadsTable(_sBuffer);
	}
	
	g_trailCount++;
}

public Store_ItemUseAction OnEquip(int client, int itemId, bool equipped)
{
	if (!IsValidClient(client) || !IsPlayerAlive(client))
	{
		return Store_DoNothing;
	}
	
	if (!IsPlayerAlive(client))
	{
		PrintToChat(client, "%s%t", STORE_PREFIX, "Equipped item apply next spawn");
		return Store_EquipItem;
	}
	
	char name[STORE_MAX_NAME_LENGTH];
	Store_GetItemName(itemId, name, sizeof(name));
	
	char loadoutSlot[STORE_MAX_LOADOUTSLOT_LENGTH];
	Store_GetItemLoadoutSlot(itemId, loadoutSlot, sizeof(loadoutSlot));
	
	KillTrail(client);

	if (equipped)
	{
		char displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "%s%t", STORE_PREFIX, "Unequipped item", displayName);

		return Store_UnequipItem;
	}
	else
	{		
		if (!Equip(client, name))
			return Store_DoNothing;
			
		char displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "%s%t", STORE_PREFIX, "Equipped item", displayName);

		return Store_EquipItem;
	}
}

public void OnClientDisconnect(int client)
{
	if (g_trailTimers[client] != INVALID_HANDLE)
	{
		CloseHandle(g_trailTimers[client]);
		g_trailTimers[client] = INVALID_HANDLE;
	}

	g_SpriteModel[client] = -1;
}

public Action PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsValidClient(client) && IsPlayerAlive(client)) 
	{
		if (g_trailTimers[client] != INVALID_HANDLE)
		{
			CloseHandle(g_trailTimers[client]);
			g_trailTimers[client] = INVALID_HANDLE;
		}

		g_SpriteModel[client] = -1;

		CreateTimer(1.0, GiveTrail, GetClientSerial(client));
	}
}

public void PlayerTeam(Handle Spawn_Event, const char[] Death_Name, bool Death_Broadcast )
{
	int client = GetClientOfUserId(GetEventInt(Spawn_Event,"userid"));
	
	if (GetClientTeam(client) == 1)
	{
		KillTrail(client);
	}
}

public Action PlayerDeath(Handle event, const char[] name,bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	KillTrail(client);
}

public Action RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (g_trailTimers[client] != INVALID_HANDLE)
		{
			CloseHandle(g_trailTimers[client]);
			g_trailTimers[client] = INVALID_HANDLE;
		}

		g_SpriteModel[client] = -1;
	}
}

public Action GiveTrail(Handle timer, any serial)
{
	int client = GetClientFromSerial(serial);
	if (client == 0)
		return Plugin_Handled;

	if (!IsPlayerAlive(client))
		return Plugin_Continue;
		
	Store_GetEquippedItemsByType(Store_GetClientAccountID(client), "trails", Store_GetClientLoadout(client), OnGetPlayerTrail, GetClientSerial(client));
	return Plugin_Handled;
}

public void Store_OnClientLoadoutChanged(int client)
{
	Store_GetEquippedItemsByType(Store_GetClientAccountID(client), "trails", Store_GetClientLoadout(client), OnGetPlayerTrail, GetClientSerial(client));
}

public void OnGetPlayerTrail(int[] ids, int count, any serial)
{
	int client = GetClientFromSerial(serial);
	
	if (!IsValidClient(client))
		return;
		
	KillTrail(client);
	
	for (int index = 0; index < count; index++)
	{
		char itemName[32];
		Store_GetItemName(ids[index], itemName, sizeof(itemName));
		
		Equip(client, itemName);
	}
}

bool Equip(int client, const char[] name)
{	
	KillTrail(client);

	int trail = -1;
	if (!GetTrieValue(g_trailsNameIndex, name, trail))
	{
		PrintToChat(client, "%s%t", STORE_PREFIX, "No item attributes");
		return false;
	}

	if (StrEqual(g_game, "csgo"))
	{
		EquipTrailTempEnts(client, trail);

		Handle pack;
		g_trailTimers[client] = CreateDataTimer(0.1, Timer_RenderBeam, pack, TIMER_REPEAT);

		WritePackCell(pack, GetClientSerial(client));
		WritePackCell(pack, trail);

		return true;
	}
	else
	{
		return EquipTrail(client, trail);
	}
}

bool EquipTrailTempEnts(int client, int trail)
{
	int entityToFollow = GetPlayerWeaponSlot(client, 2);
	if (entityToFollow == -1)
		entityToFollow = client;

	int color[4];
	Array_Copy(g_trails[client][TrailColor], color, sizeof(color));

	TE_SetupBeamFollow(entityToFollow, 
						g_trails[trail][TrailModelIndex], 
						0, 
						g_trails[trail][TrailLifetime], 
						g_trails[trail][TrailWidth], 
						g_trails[trail][TrailEndWidth], 
						g_trails[trail][TrailFadeLength], 
						color);
	TE_SendToAll();

	return true;
}

bool EquipTrail(int client, int trail)
{
	g_SpriteModel[client] = CreateEntityByName("env_spritetrail");

	if (!IsValidEntity(g_SpriteModel[client])) 
		return false;

	char strTargetName[MAX_NAME_LENGTH];
	GetClientName(client, strTargetName, sizeof(strTargetName));

	DispatchKeyValue(client, "targetname", strTargetName);
	DispatchKeyValue(g_SpriteModel[client], "parentname", strTargetName);
	DispatchKeyValueFloat(g_SpriteModel[client], "lifetime", g_trails[trail][TrailLifetime]);
	DispatchKeyValueFloat(g_SpriteModel[client], "endwidth", g_trails[trail][TrailEndWidth]);
	DispatchKeyValueFloat(g_SpriteModel[client], "startwidth", g_trails[trail][TrailWidth]);
	DispatchKeyValue(g_SpriteModel[client], "spritename", g_trails[trail][TrailMaterial]);
	DispatchKeyValue(g_SpriteModel[client], "renderamt", "255");

	char color[32];
	Format(color, sizeof(color), "%d %d %d %d", g_trails[trail][TrailColor][0], g_trails[trail][TrailColor][1], g_trails[trail][TrailColor][2], g_trails[trail][TrailColor][3]);

	DispatchKeyValue(g_SpriteModel[client], "rendercolor", color);
	DispatchKeyValue(g_SpriteModel[client], "rendermode", "5");

	DispatchSpawn(g_SpriteModel[client]);

	float Client_Origin[3];
	GetClientAbsOrigin(client,Client_Origin);
	Client_Origin[2] += 10.0; //Beam clips into the floor without this

	TeleportEntity(g_SpriteModel[client], Client_Origin, NULL_VECTOR, NULL_VECTOR);

	SetVariantString(strTargetName);
	AcceptEntityInput(g_SpriteModel[client], "SetParent"); 
	SetEntPropFloat(g_SpriteModel[client], Prop_Send, "m_flTextureRes", 0.05);

	return true;
}

public void TF2_OnConditionAdded(int client, TFCond cond)
{
    if (cond == TFCond_Cloaked)
        KillTrail(client);
}
 
public void TF2_OnConditionRemoved(int client, TFCond cond)
{
    if (cond == TFCond_Cloaked)
       Store_GetEquippedItemsByType(Store_GetClientAccountID(client), "trails", Store_GetClientLoadout(client), OnGetPlayerTrail, GetClientSerial(client));
       //EquipTrail(client);
}

void KillTrail(int client)
{
	if (g_trailTimers[client] != INVALID_HANDLE)
	{
		CloseHandle(g_trailTimers[client]);
		g_trailTimers[client] = INVALID_HANDLE;
	}

	if (g_SpriteModel[client] != -1 && IsValidEntity(g_SpriteModel[client]))
		AcceptEntityInput(g_SpriteModel[client],"kill");
		//RemoveEdict(g_SpriteModel[client]);

	g_SpriteModel[client] = -1;
}

public Action Timer_RenderBeam(Handle timer, Handle pack)
{
	ResetPack(pack);

	int client = GetClientFromSerial(ReadPackCell(pack));

	if (client == 0)
		return Plugin_Stop;

	float velocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);		

	bool isMoving = !(velocity[0] == 0.0 && velocity[1] == 0.0 && velocity[2] == 0.0);
	if (isMoving)
		return Plugin_Continue;

	EquipTrailTempEnts(client, ReadPackCell(pack));
	return Plugin_Continue;
}


/**
 * Copies a 1 dimensional static array.
 *
 * @param array			Static Array to copy from.
 * @param newArray		New Array to copy to.
 * @param size			Size of the array (or number of cells to copy)
 * @noreturn
 */
stock void Array_Copy(const any[] array, any[] newArray, int size)
{
	for (int i=0; i < size; i++) 
	{
		newArray[i] = array[i];
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