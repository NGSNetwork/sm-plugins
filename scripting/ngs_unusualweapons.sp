#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <morecolors>
// requires our version (with methodmap) of tf2items
#include <tf2items>
#include <tf2idb>
#include <unusual>
#undef REQUIRE_PLUGIN
#include <freak_fortress_2>


#define PLUGIN_NAME         "Unusual"
#define PLUGIN_AUTHOR       "Erreur 500"
#define PLUGIN_DESCRIPTION	"Add Unusual effects on your weapons"
#define PLUGIN_VERSION      "2.19"
#define PLUGIN_CONTACT      "erreur500@hotmail.fr"
#define EFFECTSFILE			"unusual_list.cfg"
#define PERMISSIONFILE		"unusual_permissions.cfg"

#define IDIL_IDLE 		0
#define IDIL_START 		1
#define IDIL_WAIT 		2
#define IDIL_REQUEST 	3

enum ItemData
{
	e_ItemID,
	e_EffectID,
	e_QualityID,
}
int ClientItemData[MAXPLAYERS+1][10][ItemData];

char SteamUsed[MAXPLAYERS+1][64];
char ClientSteamID[MAXPLAYERS+1][64];
char EffectsList[PLATFORM_MAX_PATH];
char PermissionsFile[PLATFORM_MAX_PATH];

int Effect[MAXPLAYERS+1];
int Quality[MAXPLAYERS+1];
int ClientItems[MAXPLAYERS+1];
int NbOfEffect[MAXPLAYERS+1];
int ItemDataInLoad[MAXPLAYERS+1] 	= {0, ...};

bool SQLite 						= false;
bool IsFF2Enabled 					= false;
bool StopItemLoading[MAXPLAYERS+1] 	= {false, ...};
bool AT_Choice_add[MAXPLAYERS+1]	= {false, ...};

int Permission[22] 					= {0, ...};
int FlagsList[21] 					= {ADMFLAG_RESERVATION, ADMFLAG_GENERIC, ADMFLAG_KICK, ADMFLAG_BAN, ADMFLAG_UNBAN, ADMFLAG_SLAY, ADMFLAG_CHANGEMAP, ADMFLAG_CONVARS, ADMFLAG_CONFIG, ADMFLAG_CHAT, ADMFLAG_VOTE, ADMFLAG_PASSWORD, ADMFLAG_RCON, ADMFLAG_CHEATS, ADMFLAG_CUSTOM1, ADMFLAG_CUSTOM2, ADMFLAG_CUSTOM3, ADMFLAG_CUSTOM4, ADMFLAG_CUSTOM5, ADMFLAG_CUSTOM6, ADMFLAG_ROOT};

Handle db 							= null;
ConVar c_tag						= null;
ConVar c_TeamRest					= null;
ConVar c_PanelFlag					= null;
ConVar c_FF2						= null;
TF2Item g_hItem 					= null;



public Plugin myinfo =
{
    name        = PLUGIN_NAME,
    author      = PLUGIN_AUTHOR,
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    url         = PLUGIN_CONTACT
};

public void OnPluginStart()
{
	CreateConVar("unusual_version", PLUGIN_VERSION, "Unusual version", FCVAR_NOTIFY|FCVAR_REPLICATED);
	c_tag			= CreateConVar("unusual_tag", 	"1", "Enable 'unusual' tag", 0, true, 0.0, true, 1.0);
	c_TeamRest		= CreateConVar("unusual_team_restriction", 	"0", "0 = no restriction, 1 = red, 2 = blue can't have unusual effects", 0, true, 0.0, true, 2.0);
	c_PanelFlag		= CreateConVar("unusual_panel_flag", 	"0", "0 = ADMFLAG_ROOT, 1 = ADMFLAG_GENERIC", 0, true, 0.0, true, 1.0);
	c_FF2			= CreateConVar("unusual_fix_ff2boss", 	"1", "0 = boss can have unusual effects, 1 = boss can't", 0, true, 0.0, true, 1.0);

	RegConsoleCmd("unusual", OpenMenu, "Get unusual effect on your weapons");
	RegAdminCmd("unusual_control", ControlPlayer, ADMFLAG_GENERIC);
	RegAdminCmd("unusual_permissions", reloadPermissions, ADMFLAG_GENERIC);

	LoadTranslations("unusual.phrases");

	Connect();
	BuildPath(Path_SM, EffectsList, sizeof(EffectsList), "configs/%s", EFFECTSFILE);
	BuildPath(Path_SM, PermissionsFile,sizeof(PermissionsFile),"configs/%s", PERMISSIONFILE);

	char PlayerInfo[64];
	for(int i=1; i<MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			GetClientAuthId(i, AuthId_Steam2, PlayerInfo, sizeof(PlayerInfo));
			strcopy(ClientSteamID[i], 64, PlayerInfo);
		}

		for(int j=0; j<10; j++)
			ClientItemData[i][j][e_ItemID] = -1;
	}

	g_hItem = new TF2Item(OVERRIDE_ATTRIBUTES | PRESERVE_ATTRIBUTES);
	g_hItem.NumAttributes = 1;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("UE_RemoveEffect", Native_RemoveEffect);
	CreateNative("UE_RemovePlayerEffects", Native_RemovePlayerEffects);
	CreateNative("UE_GetUnusualEffectPermission", Native_GetUnusualEffectPermission);
	CreateNative("UE_SetUnusualEffectPermission", Native_SetUnusualEffectPermission);

	return APLRes_Success;
}

public void OnMapStart()
{
	if(LoadPermissions())
	{
		LogMessage("Unusual effects permissions loaded !");
		if(LibraryExists("freak_fortress_2"))
			IsFF2Enabled = FF2_IsFF2Enabled();
	}
	else
	{
		LogMessage("Error while charging permissions !");
		IsFF2Enabled = false;
	}
}

public void OnConfigsExecuted()
{
	if(c_tag.BoolValue)
		TagsCheck("unusual");
}

stock void TagsCheck(const char[] tag)
{
	ConVar hTags = FindConVar("sv_tags");
	char tags[255];
	hTags.GetString(tags, sizeof(tags));

	if (!(StrContains(tags, tag, false)>-1))
	{
		char newTags[255];
		Format(newTags, sizeof(newTags), "%s,%s", tags, tag);
		hTags.SetString(newTags);
	}
	delete hTags;
}

public void OnClientAuthorized(int iClient, const char[] auth)
{
	strcopy(ClientSteamID[iClient], 64, auth);
	for(int j=0; j<10;j++)
			ClientItemData[iClient][j][e_ItemID] = -1;
}

void Connect()
{
	if (SQL_CheckConfig("unusual"))
	{
		SQL_TConnect(Connected, "unusual");
	}
	else
	{
		char error[255];
		SQLite = true;

		KeyValues kv = new KeyValues("");
		kv.SetString("driver", "sqlite");
		kv.SetString("database", "unusual");
		db = SQL_ConnectCustom(kv, error, sizeof(error), false);
		delete kv;

		if (db == null)
			LogMessage("Loading : Failed to connect: %s", error);
		else
		{
			LogMessage("Loading : Connected to SQLite Database");
			CreateDbSQLite();
		}
	}
}

public void Connected(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("Failed to connect! Error: %s", error);
		LogMessage("Loading : Failed to connect! Error: %s", error);
		SetFailState("SQL Error.  See error logs for details.");
		return;
	}

	LogMessage("Loading : Connected to MySQL Database");
	SQL_TQuery(hndl, SQLErrorCheckCallback, "SET NAMES 'utf8'");
	db = hndl;
	SQL_CreateTables();
}

void SQL_CreateTables()
{
	int len = 0;
	char query[512];
	len += Format(query[len], sizeof(query)-len, "CREATE TABLE IF NOT EXISTS `unusual_data` (");
	len += Format(query[len], sizeof(query)-len, "`ue_ID` int(10) unsigned NOT NULL AUTO_INCREMENT, ");
	len += Format(query[len], sizeof(query)-len, "`user_steamID` VARCHAR(64) NOT NULL, ");
	len += Format(query[len], sizeof(query)-len, "`item_ID` int(11) NOT NULL DEFAULT '-1', ");
	len += Format(query[len], sizeof(query)-len, "`effect_ID` int(11) NOT NULL DEFAULT '-1', ");
	len += Format(query[len], sizeof(query)-len, "`quality_ID` int(11) NOT NULL DEFAULT '-1', ");
	len += Format(query[len], sizeof(query)-len, "PRIMARY KEY (`ue_ID`)");
	len += Format(query[len], sizeof(query)-len, ") ENGINE=InnoDB DEFAULT CHARSET=latin1 AUTO_INCREMENT=1;");
	if (SQL_FastQuery(db, query)) // Bad, unthreaded TODO
		LogMessage("Loading : Table Created");
}

void CreateDbSQLite()
{
	int len = 0;
	char query[512];
	len += Format(query[len], sizeof(query)-len, "CREATE TABLE IF NOT EXISTS `unusual_data` (");
	len += Format(query[len], sizeof(query)-len, " `ID` INTEGER PRIMARY KEY AUTOINCREMENT,");
	len += Format(query[len], sizeof(query)-len, " `user_steamID` VARCHAR(64),");
	len += Format(query[len], sizeof(query)-len, " `item_ID` INTEGER DEFAULT -1,");
	len += Format(query[len], sizeof(query)-len, " `effect_ID` INTEGER DEFAULT -1,");
	len += Format(query[len], sizeof(query)-len, " `quality_ID` INTEGER DEFAULT -1");
	len += Format(query[len], sizeof(query)-len, ");");
	if(SQL_FastQuery(db, query))
		LogMessage("Loading : Table Created");
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (!StrEqual("", error))
	{
		LogError("SQL Error: %s", error);
	}
}


//--------------------------------------------------------------------------------------
//							Control
//--------------------------------------------------------------------------------------


stock int GetClientID(char PlayerSteamID[64])
{
	if(StrEqual(PlayerSteamID, ""))
		return -1;

	int iClient = -1;
	for(int i=1; i<MaxClients; i++)
		if(IsValidClient(i))
			if(StrEqual(ClientSteamID[i], PlayerSteamID))
			{
				iClient = i;
				continue;
			}

	return iClient;
}

stock bool IsValidClient(int iClient)
{
	if (iClient <= 0) return false;
	if (iClient > MaxClients) return false;
	return IsClientInGame(iClient);
}

public Action OpenMenu(int iClient, int Args)
{
	FirstMenu(iClient);
	return Plugin_Handled;
}

public Action ControlPlayer(int iClient, int Args)
{
	for(int i=1; i<MaxClients; i++)
		if(IsClientInGame(i))
			Updating(i);

	if(IsValidClient(iClient))
		PrintToChat(iClient,"All Players have been controlled !");
	else
		LogMessage("All Players have been controlled !");
	return Plugin_Handled;
}

public Action reloadPermissions(int iClient, int Args)
{
	if(LoadPermissions())
	{
		if(IsValidClient(iClient))
			PrintToChat(iClient,"Unusual effects permissions reloaded !");
		else
			LogMessage("Unusual effects permissions reloaded !");
	}
	else
	{
		if(IsValidClient(iClient))
			PrintToChat(iClient,"Error while recharging permissions !");
		else
			LogMessage("Error while recharging permissions !");
	}
	return Plugin_Handled;
}

bool LoadPermissions()
{
	KeyValues kv;
	kv = new KeyValues("Unusual_permissions");
	if(!kv.ImportFromFile(PermissionsFile))
	{
		LogError("Can't open %s file",PERMISSIONFILE);
		delete kv;
		return false;
	}

	kv.GotoFirstSubKey(true);
	Permission[0]  = kv.GetNum("0", 0);
	Permission[1]  = kv.GetNum("a", 0);
	Permission[2]  = kv.GetNum("b", 0);
	Permission[3]  = kv.GetNum("c", 0);
	Permission[4]  = kv.GetNum("d", 0);
	Permission[5]  = kv.GetNum("e", 0);
	Permission[6]  = kv.GetNum("f", 0);
	Permission[7]  = kv.GetNum("g", 0);
	Permission[8]  = kv.GetNum("h", 0);
	Permission[9]  = kv.GetNum("i", 0);
	Permission[10] = kv.GetNum("j", 0);
	Permission[11] = kv.GetNum("k", 0);
	Permission[12] = kv.GetNum("l", 0);
	Permission[13] = kv.GetNum("m", 0);
	Permission[14] = kv.GetNum("n", 0);
	Permission[15] = kv.GetNum("o", 0);
	Permission[16] = kv.GetNum("p", 0);
	Permission[17] = kv.GetNum("q", 0);
	Permission[18] = kv.GetNum("r", 0);
	Permission[19] = kv.GetNum("s", 0);
	Permission[20] = kv.GetNum("t", 0);
	Permission[21] = kv.GetNum("z", 0);
	delete kv;
	return true;
}

bool isAuthorized(int iClient, bool Strict)
{
	int Limit = GetLimit(GetUserFlagBits(iClient));

	if(Limit == -1)
		return true;

	if(Strict && NbOfEffect[iClient] < Limit)			return true;
	else if(!Strict && NbOfEffect[iClient] <= Limit)  return true;
	else											return false;
}

int GetLimit(int flags)
{
	int Limit 	= 0;
	int i 		= 0;

	if(flags == 0)				// Without flag
		return Permission[0];

	do // With flag, detect best limit.
	{
		if( (flags & FlagsList[i]) && ((Limit < Permission[i+1]) || (Permission[i+1] == -1)) )
			Limit = Permission[i+1];
		i++;
	}while(Limit != -1 && i<21);
	return Limit;
}

//--------------------------------------------------------------------------------------
//							Update Effects
//--------------------------------------------------------------------------------------

public void OnClientDisconnect(int iClient)
{
	if(!IsValidClient(iClient)) return;

	ClientSteamID[iClient] = "-1";

	for(int i=0; i<10; i++)
		ClientItemData[iClient][i][e_ItemID] = -1;
}

void Updating(int iClient)
{
	char buffer[128];
	Format(buffer, sizeof(buffer), "SELECT COUNT(`user_steamID`) AS NB FROM unusual_data WHERE `user_steamID` = '%s'", ClientSteamID[iClient]);
	SQL_TQuery(db, T_ClientControl, buffer, iClient);
}

public void T_ClientControl(Handle owner, Handle hndl, const char[] error, any iClient) // Control nbr of client effect (quota)
{
	if(!SQL_GetRowCount(hndl))
	{
		NbOfEffect[iClient] = 0;
		return;
	}

	while(SQL_FetchRow(hndl))
		NbOfEffect[iClient] = SQL_FetchInt(hndl,0);

	if(!isAuthorized(iClient, false))
	{
		CPrintToChat(iClient, "%t", "Sent6");
		RemoveEffect(iClient, ClientSteamID[iClient], "-1");
	}
	else // Control if player can still have scpefic UE
	{
		char buffer[128];
		Format(buffer, sizeof(buffer), "SELECT DISTINCT `effect_ID` FROM unusual_data WHERE `user_steamID` = '%s'", ClientSteamID[iClient]);
		SQL_TQuery(db, T_ClientControl2, buffer, iClient);
	}
}

public void T_ClientControl2(Handle owner, Handle hndl, const char[] error, any iClient) // Control each UE used by client
{
	if(!SQL_GetRowCount(hndl))
		return;

	KeyValues kv = new KeyValues("Unusual_effects");
	if(!FileToKeyValues(kv, EffectsList))
	{
		LogError("[UNUSUAL] Could not open file %s", EFFECTSFILE);
		CloseHandle(kv);
		return;
	}

	int EffectID;
	char EffectFlag[2];
	char str_EffectID[8];

	while(SQL_FetchRow(hndl))
	{
		EffectID = SQL_FetchInt(hndl,0); 	// return an effect ID that client use

		Format(str_EffectID, sizeof(str_EffectID), "%i", EffectID);
		if(!kv.JumpToKey(str_EffectID, false))
		{
			LogMessage("DB contain effectID that do not exist: %i", EffectID);
			kv.Rewind();
			continue;
		}

		kv.GetString("flag", EffectFlag, sizeof(EffectFlag));
		kv.Rewind();

		if(!IsClientUEAllowed(iClient, EffectFlag)) // If client can't use this effect => remove it
		{
			char buffer[128];
			Format(buffer, sizeof(buffer), "SELECT `item_ID` FROM unusual_data WHERE `user_steamID` = '%s' AND `effect_ID` = %i", ClientSteamID[iClient], EffectID);
			SQL_TQuery(db, T_ClientRemoveEffect, buffer, iClient);
		}
	}

	delete kv;
}

public void T_ClientRemoveEffect(Handle owner, Handle hndl, const char[] error, any iClient) // Remove each item with the no allowed UE
{
	if(!SQL_GetRowCount(hndl))
		return;

	while(SQL_FetchRow(hndl))
	{
		char str_ItemID[10];
		Format(str_ItemID, sizeof(str_ItemID), "%i", SQL_FetchInt(hndl,0));

		RemoveEffect(iClient, ClientSteamID[iClient], str_ItemID);
	}
}

stock int FixItemSlot(int iItemDefinitionIndex, TFClassType Class)
{
	/* Fix ShotGun Festive and Gun Mettle Skin for engineer*/
	if(Class == TFClass_Engineer)
	{
		if(iItemDefinitionIndex == 1141) return 0;
		if(iItemDefinitionIndex == 15003) return 0;
		if(iItemDefinitionIndex == 15016) return 0;
		if(iItemDefinitionIndex == 15044) return 0;
		if(iItemDefinitionIndex == 15047) return 0;
	}

	/* Fix ShotGun Festive and Gun Mettle Skin for other class*/
	if(iItemDefinitionIndex == 1141) return 1;
	if(iItemDefinitionIndex == 15003) return 1;
	if(iItemDefinitionIndex == 15016) return 1;
	if(iItemDefinitionIndex == 15044) return 1;
	if(iItemDefinitionIndex == 15047) return 1;

	return -1;
}

public Action TF2Items_OnGiveNamedItem(int iClient, char[] classname, int iItemDefinitionIndex, TF2Item &hItem)
{
	if(!IsValidClient(iClient))	return Plugin_Continue;
	if(IsFakeClient(iClient))	return Plugin_Continue;

	TF2Item tItem = view_as<TF2Item>(hItem);

	int TeamRestriction = c_TeamRest.IntValue;	// Team restriction
	if(GetClientTeam(iClient) == TeamRestriction+1)
		return Plugin_Continue;

	if(c_FF2.IntValue && IsFF2Enabled)	// Freak Fortress 2 boss security
		if(FF2_GetBossUserId() == iClient)
			return Plugin_Continue;

	if(iItemDefinitionIndex == 739 || iItemDefinitionIndex == 142) // Blacklisted weapon due to crash.
		return Plugin_Continue;

	if(StrEqual(classname, "tf_wearable"))
		return Plugin_Continue;

	char strItemDefSlot[3];
	Format(strItemDefSlot, sizeof(strItemDefSlot), "%i", TF2IDB_GetItemSlot(iItemDefinitionIndex));

	int ItemDefSlot = FixItemSlot(iItemDefinitionIndex, TF2_GetPlayerClass(iClient)); // TF2IDB_GetItemSlot() return a wrong slot for some items
	if(ItemDefSlot < 0)
		ItemDefSlot = StringToInt(strItemDefSlot);

	if(ItemDefSlot >= 10 || ItemDefSlot < 0)
		return Plugin_Continue;

	if(ClientItemData[iClient][ItemDefSlot][e_ItemID] != iItemDefinitionIndex)
	{
		//LogMessage("[%i] Loading item %i on slot %i state %i (old: %i)", iClient, iItemDefinitionIndex, ItemDefSlot, ItemDataInLoad[iClient], ClientItemData[iClient][ItemDefSlot][e_ItemID]);

		if(ItemDataInLoad[iClient] == IDIL_IDLE)
			ItemDataInLoad[iClient] = IDIL_START;
		else if(ItemDataInLoad[iClient] >= IDIL_REQUEST)
		{
			StopItemLoading[iClient] = true;
			ItemDataInLoad[iClient] = IDIL_START;
		}

		ClientItemData[iClient][ItemDefSlot][e_ItemID] 		= iItemDefinitionIndex;
		ClientItemData[iClient][ItemDefSlot][e_EffectID] 	= -1;
		ClientItemData[iClient][ItemDefSlot][e_QualityID] 	= -1;

		if(ItemDataInLoad[iClient] != IDIL_WAIT)
		{
			CreateTimer(0.2, TimerUpdateWeapon, iClient);
			ItemDataInLoad[iClient] = IDIL_WAIT;
		}

		return Plugin_Continue;
	}
	else if(ItemDataInLoad[iClient] == IDIL_IDLE && ClientItemData[iClient][ItemDefSlot][e_EffectID] > -1)
	{

		//LogMessage("[%i] Set item %i on slot %i effect %i quality %i", iClient, iItemDefinitionIndex, ItemDefSlot, ClientItemData[iClient][ItemDefSlot][e_EffectID], ClientItemData[iClient][ItemDefSlot][e_QualityID]);

		g_hItem.SetAttribute(0, 134, float(ClientItemData[iClient][ItemDefSlot][e_EffectID]));

		if(ClientItemData[iClient][ItemDefSlot][e_QualityID] > -1)
		{
			g_hItem.Quality = ClientItemData[iClient][ItemDefSlot][e_QualityID];

			tItem = g_hItem;
			//LogMessage("WEAPON %i, with %i for %i",iItemDefinitionIndex,ClientItemData[iClient][ItemDefSlot][e_EffectID],iClient);
			return Plugin_Changed;
		}
	}

	//LogMessage("[%i] No item %i on slot %i effect %i state %i", iClient, iItemDefinitionIndex, ItemDefSlot, ClientItemData[iClient][ItemDefSlot][e_EffectID], ItemDataInLoad[iClient]);
	return Plugin_Continue;

}

public Action TimerUpdateWeapon(Handle timer, any iClient)
{
	ItemDataInLoad[iClient] = IDIL_REQUEST;

	char itembuffer[1024] = "";
	for(int i=0; i<=GetMaximumNumberSlot(iClient); i++)
	{
		if(StrEqual(itembuffer, ""))
			Format(itembuffer, sizeof(itembuffer), "`item_ID` = '%i'", ClientItemData[iClient][i][e_ItemID]);
		else
			Format(itembuffer, sizeof(itembuffer), "%s OR `item_ID` = '%i'", itembuffer, ClientItemData[iClient][i][e_ItemID]);
	}

	if(StopItemLoading[iClient]) // Other items are currently loading
	{
		StopItemLoading[iClient] = false;
		ItemDataInLoad[iClient] = IDIL_IDLE;
		return;
	}

	char PlayerInfo[64];
	GetClientAuthId(iClient, AuthId_Steam2, PlayerInfo, sizeof(PlayerInfo));

	char buffer[1024];
	Format(buffer, sizeof(buffer), "SELECT  `item_ID`, `effect_ID`, `quality_ID` FROM unusual_data WHERE `user_steamID` = '%s' AND ( %s )", PlayerInfo, itembuffer);
	//LogMessage("%s", buffer);
	SQL_TQuery(db, T_UpdateClientItemDataSlot, buffer, iClient);
}

public void T_UpdateClientItemDataSlot(Handle owner, Handle hndl, const char[] error, any iClient)
{
	if(!SQL_GetRowCount(hndl))
	{
		ItemDataInLoad[iClient] = IDIL_IDLE;
		//LogMessage("Nothing in the DB!");
		return;
	}

	char strItemDefSlot[3];
	int ItemDefSlot;

	while(SQL_FetchRow(hndl))
	{
		Format(strItemDefSlot, sizeof(strItemDefSlot), "%i", TF2IDB_GetItemSlot(SQL_FetchInt(hndl, 0)));
		ItemDefSlot = FixItemSlot(SQL_FetchInt(hndl, 0), TF2_GetPlayerClass(iClient)); // TF2IDB_GetItemSlot() return a wrong slot for some items
		if(ItemDefSlot < 0)
			ItemDefSlot = StringToInt(strItemDefSlot);

		if(ItemDefSlot >= 10 || ItemDefSlot < 0)
		{
			ItemDataInLoad[iClient] = IDIL_IDLE;
			return;
		}

		if(StopItemLoading[iClient] == true) // Other items are currently loading
		{
			StopItemLoading[iClient] = false;
			ItemDataInLoad[iClient] = IDIL_IDLE;
			return;
		}

		if(ClientItemData[iClient][ItemDefSlot][e_ItemID] != SQL_FetchInt(hndl, 0))
		{
			ItemDataInLoad[iClient] = IDIL_IDLE;
			return;
		}

		ClientItemData[iClient][ItemDefSlot][e_EffectID]  = SQL_FetchInt(hndl, 1);
		ClientItemData[iClient][ItemDefSlot][e_QualityID] = SQL_FetchInt(hndl, 2);
		//LogMessage("item: %i, effect: %i, quality: %i", SQL_FetchInt(hndl,0), SQL_FetchInt(hndl,1), SQL_FetchInt(hndl,2));
	}

	UpdateWeapon(iClient);
}

void UpdateWeapon(int iClient)
{
	if(!IsValidClient(iClient))
	{
		ItemDataInLoad[iClient] = IDIL_IDLE;

		for(int i=0; i<10; i++)
		{
			ClientItemData[iClient][i][e_ItemID]    = -1;
			ClientItemData[iClient][i][e_EffectID]  = -1;
			ClientItemData[iClient][i][e_QualityID] = -1;
		}
		return;
	}

	int Clip[6] = {0, ...};
	int Ammo[6] = {0, ...};
	int SlotMax = GetMaximumNumberSlot(iClient);

	for(int i = 0; i<=SlotMax; i++)
	{
		Clip[i] = GetClip(iClient, i);
		Ammo[i] = GetAmmo(iClient, i);
		TF2_RemoveWeaponSlot(iClient, i);
	}

	//LogMessage("Regenerate player!")
	ItemDataInLoad[iClient] = IDIL_IDLE;
	TF2_RegeneratePlayer(iClient);

	int iHealth = GetClientHealth(iClient);
	if (iHealth < GetClientHealth(iClient))
		SetEntityHealth(iClient, iHealth);

	for(int i=0; i<=SlotMax; i++)
	{
		if(Clip[i] != -1 && Clip[i] < GetClip(iClient, i))
			SetClip(iClient, i, Clip[i]);
		if(Ammo[i] != -1 && Ammo[i] < GetAmmo(iClient, i))
			SetAmmo(iClient, i, Ammo[i]);
	}

	Updating(iClient);
}

int GetMaximumNumberSlot(int iClient)
{
	TFClassType Class = TF2_GetPlayerClass(iClient);
	if(Class <= TFClass_Unknown)
		return 0;

	int SlotMax = 2;
	if(Class == TFClass_Spy)
		SlotMax = 4;
	else if(Class == TFClass_Engineer)
		SlotMax = 5;

	return SlotMax;
}

stock int GetClip(int iClient, int WeapSlot)
{
	int weapon = GetPlayerWeaponSlot(iClient, WeapSlot);
	if(IsValidEntity(weapon))
	{
		int iAmmo = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
		return GetEntData(weapon, iAmmo);
	}
	return -1;
}

stock int GetAmmo(int iClient, int WeapSlot)
{
	int weapon = GetPlayerWeaponSlot(iClient, WeapSlot);
	if(IsValidEntity(weapon))
	{
		int iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		int iAmmo = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		return GetEntData(iClient, iAmmo+iOffset);
	}
	return -1;
}

stock void SetClip(int iClient, int WeapSlot, int newAmmo)
{
	int weapon = GetPlayerWeaponSlot(iClient, WeapSlot);
	if (IsValidEntity(weapon))
	{
		int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
		SetEntData(weapon, iAmmoTable, newAmmo, 4, true);
	}
}

stock void SetAmmo(int iClient, int WeapSlot, int newAmmo)
{
	int weapon = GetPlayerWeaponSlot(iClient, WeapSlot);
	if(IsValidEntity(weapon))
	{
		int iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		int iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		SetEntData(iClient, iAmmoTable+iOffset, newAmmo, 4, true);
	}
}

//--------------------------------------------------------------------------------------
//							Menu selection
//--------------------------------------------------------------------------------------

void FirstMenu(int iClient)
{
	if(IsValidClient(iClient))
	{
		int TeamRestriction = c_TeamRest.IntValue;
		if(GetClientTeam(iClient) == TeamRestriction+1)
		{
			if(TeamRestriction == 1)
			{
				CPrintToChat(iClient, "%t", "Sent1", "Red");
				return;
			}
			else if(TeamRestriction == 2)
			{
				CPrintToChat(iClient, "%t", "Sent1", "Blue");
				return;
			}
		}

		if(c_FF2.IntValue && IsFF2Enabled)	// Freak Fortress 2 boss security
			if(FF2_GetBossUserId() == iClient)
			{
				CPrintToChat(iClient, "%t", "Sent1", "Boss");
				return;
			}

		char PlayerInfo[64];
		GetClientAuthId(iClient, AuthId_Steam2, PlayerInfo, sizeof(PlayerInfo));
		strcopy(SteamUsed[iClient], 64, PlayerInfo);

		Menu Menu1 = new Menu(Menu1_1);
		Menu1.SetTitle("What do you want?");
		Menu1.AddItem("0", "Add/modify weapons");
		Menu1.AddItem("1", "Delete effects");
		Menu1.AddItem("2", "Show effects");

		if((c_PanelFlag.IntValue == 0 && (GetUserFlagBits(iClient) & ADMFLAG_ROOT)) || (c_PanelFlag.IntValue == 1 && ((GetUserFlagBits(iClient) & ADMFLAG_GENERIC) || (GetUserFlagBits(iClient) & ADMFLAG_ROOT)) ))
		{
			Menu1.AddItem("3", "Admin tools: Add/modify");
			Menu1.AddItem("4", "Admin tools: Delete");
		}

		Menu1.ExitButton = true;
		Menu1.Display(iClient, MENU_TIME_FOREVER);
	}
}

public int Menu1_1(Menu menu, MenuAction action, int iClient, int args)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Select)
	{
		if(args == 0)
			QualityMenu(iClient);
		else if(args == 1)
			DeleteWeapPanel(iClient);
		else if(args == 2)
		{
			FirstMenu(iClient);
		}
		else if(args == 3) // AT add/modify item
		{
			AT_Choice_add[iClient] = true;
			AT_OnlinePlayers_Menu(iClient);
		}
		else if(args == 4)	// AT delete item
		{
			AT_Choice_add[iClient] = false;
			AT_First_Menu(iClient);
		}
	}
}


//--------------------------------------------------------------------------------------
//							Remove Effect
//--------------------------------------------------------------------------------------


void DeleteWeapPanel(int iClient)
{
	char buffer[255];
	Format(buffer, sizeof(buffer), "SELECT `item_ID` FROM unusual_data WHERE `user_steamID` = '%s'", SteamUsed[iClient]);
	SQL_TQuery(db, T_DeleteWeapPanel, buffer, iClient);
}

public void T_DeleteWeapPanel(Handle owner, Handle hndl, const char[] error, any iClient)
{
	Menu YourItemsMenu = new Menu(YourItemsMenuAnswer);

	YourItemsMenu.SetTitle("What items?");

	if(!SQL_GetRowCount(hndl)) // nothing in db
	{
		CPrintToChat(iClient, "%t","Sent3");
		return;
	}

	int WeapID;
	char ItemsName[64];
	char strWeapID[10];

	YourItemsMenu.AddItem("-1", "All");

	while(SQL_FetchRow(hndl))
	{
		WeapID 	= SQL_FetchInt(hndl,0);
		Format(strWeapID, sizeof(strWeapID), "%i", WeapID);
		TF2IDB_GetItemName(WeapID, ItemsName, sizeof(ItemsName));
		YourItemsMenu.AddItem(strWeapID, ItemsName);
	}

	YourItemsMenu.ExitButton = true;
	YourItemsMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int YourItemsMenuAnswer(Menu menu, MenuAction action, int iClient, int args)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Select)
	{
		char WeapID[10];
		if (menu.GetItem(args, WeapID, sizeof(WeapID)))
		{
			if(IsValidClient(iClient))
				RemoveEffect(iClient, SteamUsed[iClient], WeapID);
		}
	}
}

bool RemoveEffect(int iClient, char PlayerSteamID[64], char[] WeapID)
{
	int clientControled = -1;

	clientControled = GetClientID(PlayerSteamID);


	if(StrEqual(WeapID, "-1"))	// remove player from the DB
	{
		char buffer[255];
		Format(buffer, sizeof(buffer), "DELETE FROM unusual_data WHERE `user_steamID` = '%s'", PlayerSteamID);
		SQL_TQuery(db, SQLErrorCheckCallback, buffer);

		if(clientControled != iClient && IsValidClient(iClient))
		{
			if(IsValidClient(clientControled))
				CPrintToChat(iClient, "%t","Sent11", clientControled);
			else
				CPrintToChat(iClient, "%t","Sent4", PlayerSteamID);
		}

		if(clientControled != -1)
		{
			for(int i=0; i<10; i++)
			{
				ClientItemData[clientControled][i][e_EffectID] = -1;
				ClientItemData[clientControled][i][e_QualityID] = -1;
			}

			if(IsValidClient(clientControled))
				CPrintToChat(clientControled, "%t","Sent10");
		}
	}
	else  // Remove this player item from BD
	{
		char buffer[255];
		Format(buffer, sizeof(buffer), "DELETE FROM unusual_data WHERE `user_steamID` = '%s' AND `item_ID` = %i", PlayerSteamID, StringToInt(WeapID));
		SQL_TQuery(db, SQLErrorCheckCallback, buffer);

		if(clientControled != iClient && IsValidClient(iClient))
			CPrintToChat(iClient, "%t", "Sent12", StringToInt(WeapID));

		if(clientControled != -1)
		{
			if(GetClientTeam(clientControled) == 2  || GetClientTeam(clientControled) == 3)
			{
				char strItemDefSlot[2];
				Format(strItemDefSlot, sizeof(strItemDefSlot), "%i", TF2IDB_GetItemSlot(StringToInt(WeapID)));
				int ItemDefSlot = FixItemSlot(StringToInt(WeapID), TF2_GetPlayerClass(clientControled)); // TF2IDB_GetItemSlot() return a wrong slot for some items
				if(ItemDefSlot < 0)
					ItemDefSlot = StringToInt(strItemDefSlot);

				ClientItemData[clientControled][ItemDefSlot][e_EffectID] = -1;
				ClientItemData[clientControled][ItemDefSlot][e_QualityID] = -1;
			}

			if(IsValidClient(clientControled))
				CPrintToChat(clientControled, "%t", "Sent12", StringToInt(WeapID));
		}
	}

	if(clientControled != -1)
	{
		if(GetClientTeam(clientControled) == 2 || GetClientTeam(clientControled) == 3)
			UpdateWeapon(clientControled);

		if(IsValidClient(iClient) && IsValidClient(clientControled))
			if(iClient == clientControled)
				DeleteWeapPanel(iClient);
			else
				FirstMenu(iClient);

	}
	return true;
}


//--------------------------------------------------------------------------------------
//							Quality + Effect
//--------------------------------------------------------------------------------------


void QualityMenu(int iClient)
{
	int clientControled = GetClientID(SteamUsed[iClient]);
	if(clientControled == -1)
	{
		CPrintToChat(iClient, "%t", "Sent9");
		return;
	}

	if(!isAuthorized(clientControled, true)) // Can have more unusual effects ?
	{
		CPrintToChat(iClient, "%t", "Sent7");
		FirstMenu(iClient);
		return;
	}

	int EntitiesID = GetEntPropEnt(clientControled, Prop_Data, "m_hActiveWeapon");
	if(EntitiesID < 0)
	{
		CPrintToChat(iClient, "%t", "Sent14");
		return;
	}

	ClientItems[iClient] = GetEntProp(EntitiesID, Prop_Send, "m_iItemDefinitionIndex");
	if(ClientItems[iClient] == 739 || ClientItems[iClient] == 142) // Blacklisted weapon due to crash.
	{
		CPrintToChat(iClient, "%t", "Sent13");
		FirstMenu(iClient);
		return;
	}

	char Title[64];
	char WeapName[64];
	Menu Qltymenu = new Menu(QltymenuAnswer);

	TF2IDB_GetItemName(ClientItems[iClient], WeapName, sizeof(WeapName));
	Format(Title, sizeof(Title), "Select a quality: %s",WeapName);
	Qltymenu.SetTitle(Title);

	Qltymenu.AddItem("0", "normal");
	Qltymenu.AddItem("1", "rarity1");
	Qltymenu.AddItem("2", "rarity2");
	Qltymenu.AddItem("3", "vintage");
	Qltymenu.AddItem("4", "rarity3");
	Qltymenu.AddItem("5", "rarity4");
	Qltymenu.AddItem("6", "unique");
	Qltymenu.AddItem("7", "community");
	Qltymenu.AddItem("8", "developer");
	Qltymenu.AddItem("9", "selfmade");
	Qltymenu.AddItem("10", "customized");
	Qltymenu.AddItem("11", "strange");
	Qltymenu.AddItem("12", "completed");
	Qltymenu.AddItem("13", "haunted");

	Qltymenu.ExitButton = true;
	Qltymenu.Display(iClient, MENU_TIME_FOREVER);
}

public int QltymenuAnswer(Menu menu, MenuAction action, int iClient, int args)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Select)
	{
		Quality[iClient] = args;
		PanelEffect(iClient);
	}
}

void PanelEffect(int iClient)
{
	char EffectID[8];
	char EffectName[128];
	char EffectFlag[2];

	Menu UnusualMenu = new Menu(UnusualMenuAnswer);
	UnusualMenu.SetTitle("Select an unusual effect:");
	UnusualMenu.AddItem("0", "Show effects");

	KeyValues kv = new KeyValues("Unusual_effects");
	if(!kv.ImportFromFile(EffectsList))
	{
		LogError("[UNUSUAL] Could not open file %s", EFFECTSFILE);
		delete kv;
		return;
	}

	if(!kv.GotoFirstSubKey(true)) // First UE
	{
		LogMessage("ERROR: Can't find unusual effects in %s", EFFECTSFILE);
		delete kv;
		return;
	}

	do
	{
		kv.GetSectionName(EffectID, sizeof(EffectID));
		kv.GetString("name", EffectName, sizeof(EffectName));
		kv.GetString("flag", EffectFlag, sizeof(EffectFlag));

		if(IsClientUEAllowed(iClient, EffectFlag))
			UnusualMenu.AddItem(EffectID, EffectName);
	}
	while(kv.GotoNextKey(true)); // while there are UE

	delete kv;

	UnusualMenu.ExitButton = true;
	UnusualMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int UnusualMenuAnswer(Menu menu, MenuAction action, int iClient, int args)
{
	if(action == MenuAction_End)
	{
		delete menu;
	}
	else if(action == MenuAction_Select)
	{
		if(args == 0)
		{
			PanelEffect(iClient);
			return;
		}

		char strEffect[8];
		if (menu.GetItem(args, strEffect, sizeof(strEffect)))
		{
			Effect[iClient] = StringToInt(strEffect);
			if(IsValidClient(iClient)) AddUnusualEffect(iClient);
		}
	}
}

bool IsClientUEAllowed(int iClient, const char[] EffectFlag)
{
	if(StrEqual(EffectFlag, "0") || StrEqual(EffectFlag, "") || StrEqual(EffectFlag, "-1"))
		return true;

	int flag = GetUserFlagBits(iClient);
	if(flag & ADMFLAG_GENERIC || flag & ADMFLAG_ROOT)
		return true;

	if(flag & GetUEFlag(EffectFlag))
		return true;

	return false;
}

int GetUEFlag(const char[] Value)
{
	char FlagsLetter[21][2] = {"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "z"};

	for(int i=0; i<21; i++)
		if(StrEqual(Value, FlagsLetter[i]))
			return FlagsList[i];

	return -1;
}

void AddUnusualEffect(int iClient)
{
	if(ClientItems[iClient] < 0)	// Is Valid item ID
		return;

	if(ClientItems[iClient] == 739 || ClientItems[iClient] == 142) // Blacklisted weapon due to crash.
	{
		CPrintToChat(iClient, "%t", "Sent13");
		return;
	}

	if(TF2IDB_GetItemSlot(ClientItems[iClient]) >= view_as<TF2ItemSlot>(5))
		return;

	if(StrEqual(SteamUsed[iClient], ""))
		CPrintToChat(iClient, "%t", "Sent5");

	char buffer[255];
	Format(buffer, sizeof(buffer), "SELECT * FROM unusual_data WHERE `user_steamID` = '%s' AND `item_ID` = '%i'", SteamUsed[iClient], ClientItems[iClient]);
	SQL_TQuery(db, T_UpdateClient, buffer, iClient);
}

public void T_UpdateClient(Handle owner, Handle hndl, const char[] error, any iClient)
{
	int clientControled = GetClientID(SteamUsed[iClient]);
	if(clientControled == -1 || !IsValidClient(clientControled))
	{
		CPrintToChat(iClient, "%t", "Sent9");
		return;
	}

	if(!isAuthorized(clientControled, true))
	{
		CPrintToChat(iClient, "%t", "Sent7");
		return;
	}

	if(!SQL_GetRowCount(hndl))
	{
		char buffer[256];
		if(!SQLite)
		{
			Format(buffer, sizeof(buffer), "INSERT INTO unusual_data (`user_steamID`,`item_ID`,`effect_ID`,`quality_ID`) VALUES ('%s','%i','%i','%i')", SteamUsed[iClient], ClientItems[iClient], Effect[iClient], Quality[iClient]);
			SQL_TQuery(db, SQLErrorCheckCallback, buffer);
		}
		else
		{
			Format(buffer, sizeof(buffer), "INSERT INTO unusual_data VALUES ('%s','%i','%i','%i')", SteamUsed[iClient], ClientItems[iClient], Effect[iClient], Quality[iClient]);
			SQL_TQuery(db, SQLErrorCheckCallback, buffer);
		}

		if(IsValidClient(clientControled)) 	NbOfEffect[clientControled]++;
	}
	else
	{
		char buffer[256];
		while (SQL_FetchRow(hndl))
		{
			Format(buffer, sizeof(buffer), "UPDATE unusual_data SET `effect_ID` = %i, `quality_ID` = %i WHERE `user_steamID` = '%s' AND `item_ID` = %i", Effect[iClient], Quality[iClient], SteamUsed[iClient], ClientItems[iClient]);
			SQL_TQuery(db, SQLErrorCheckCallback, buffer);
		}
	}

	if(GetClientTeam(clientControled) == 2  || GetClientTeam(clientControled) == 3)
	{
		char strItemDefSlot[2];
		Format(strItemDefSlot, sizeof(strItemDefSlot), "%i", TF2IDB_GetItemSlot(ClientItems[iClient]));
		int ItemDefSlot = FixItemSlot(ClientItems[iClient], TF2_GetPlayerClass(clientControled)); // TF2IDB_GetItemSlot() return a wrong slot for some items
		if(ItemDefSlot < 0)
			ItemDefSlot = StringToInt(strItemDefSlot);

		ClientItemData[clientControled][ItemDefSlot][e_EffectID] = Effect[iClient];
		ClientItemData[clientControled][ItemDefSlot][e_QualityID] = Quality[iClient];
	}

	if(IsValidClient(clientControled))
		UpdateWeapon(clientControled);


	if(IsValidClient(iClient)) 			CPrintToChat(iClient, "%t", "Sent8");
	if(iClient != clientControled && IsValidClient(clientControled)) 	CPrintToChat(clientControled, "%t", "Sent8");

	if(IsValidClient(iClient) && IsValidClient(clientControled))
	{
		FirstMenu(iClient);
	}
}


//--------------------------------------------------------------------------------------
//							Admin tool menu
//--------------------------------------------------------------------------------------


void AT_First_Menu(int iClient)
{
	Menu AdMenu = new Menu(AT_First_Menu_Ans);
	AdMenu.SetTitle("Admin Tools: Which kind of player ?");

	AdMenu.AddItem("0", "Players on the server");
	AdMenu.AddItem("1", "Players from the BD");

	AdMenu.ExitButton = true;
	AdMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int AT_First_Menu_Ans(Menu menu, MenuAction action, int iClient, int args)
{
	if(action == MenuAction_End)
	{
		delete menu;
	}
	else if(action == MenuAction_Select)
	{
		if(args == 0)
			AT_OnlinePlayers_Menu(iClient);
		else
			AT_BDPlayers_Menu(iClient);
	}
}

void AT_OnlinePlayers_Menu(int iClient)
{
	Menu AdMenu = new Menu(AT_OnlinePlayers_Menu_Ans);
	char str_PlayerID[5];
	char str_PlayerName[128];
	int count = 0;
	AdMenu.SetTitle("Admin Tools: Player selection");

	for(int i=0; i<MaxClients; i++)
	{
		if(IsValidClient(i) && i != iClient && IsClientInGame(i) && !IsFakeClient(i))
		{
			Format(str_PlayerID, sizeof(str_PlayerID), "%d",i);
			GetClientName(i, str_PlayerName, sizeof(str_PlayerName));
			AdMenu.AddItem(str_PlayerID, str_PlayerName);
			count++;
		}
	}

	if(count == 0)
	{
		CPrintToChat(iClient, "%t", "Sent2");
		delete AdMenu;
		FirstMenu(iClient);
		return;
	}

	AdMenu.ExitButton = true;
	AdMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int AT_OnlinePlayers_Menu_Ans(Menu menu, MenuAction action, int iClient, int args)
{
	if(action == MenuAction_End)
	{
		delete menu;
	}
	else if(action == MenuAction_Select)
	{
		char str_PlayerID[5];
		char PlayerInfo[64];
		if (menu.GetItem(args, str_PlayerID, sizeof(str_PlayerID)))
		{
			GetClientAuthId(StringToInt(str_PlayerID), AuthId_Steam2, PlayerInfo, sizeof(PlayerInfo));
			strcopy(SteamUsed[iClient], 64, PlayerInfo);

			if(!IsValidClient(StringToInt(str_PlayerID)))
			{
				CPrintToChat(iClient, "%t", "Sent9");
				AT_OnlinePlayers_Menu(iClient);
			}
			else
			{
				if(AT_Choice_add[iClient])
					QualityMenu(iClient);
				else
					DeleteWeapPanel(iClient);
			}
		}
	}
}

void AT_BDPlayers_Menu(int iClient)
{
	char buffer[255];
	Format(buffer, sizeof(buffer), "SELECT DISTINCT `user_steamID` FROM unusual_data ORDER BY `user_steamID`");
	SQL_TQuery(db, AT_BDPlayers_Menu_2, buffer, iClient);
}

public void AT_BDPlayers_Menu_2(Handle owner, Handle hndl, const char[] error, any iClient)
{
	if(!SQL_GetRowCount(hndl))
	{
		CPrintToChat(iClient, "%t", "Sent2");
		FirstMenu(iClient);
		return;
	}

	Menu AdMenu = new Menu(AT_BDPlayers_Menu_Ans);
	AdMenu.SetTitle("Admin Tools: Player selection");

	char PlayerInfo[64];
	while(SQL_FetchRow(hndl))
	{
		SQL_FetchString(hndl, 0, PlayerInfo, sizeof(PlayerInfo));
		AdMenu.AddItem(PlayerInfo, PlayerInfo);
	}

	AdMenu.ExitButton = true;
	AdMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int AT_BDPlayers_Menu_Ans(Menu menu, MenuAction action, int iClient, int args)
{
	if(action == MenuAction_End)
	{
		delete menu;
	}
	else if(action == MenuAction_Select)
	{
		char PlayerInfo[64];
		if (menu.GetItem(args, PlayerInfo, sizeof(PlayerInfo)))
		{
			strcopy(SteamUsed[iClient], 64, PlayerInfo);

			DeleteWeapPanel(iClient);
		}
	}
}


//--------------------------------------------------------------------------------------
//							Native Functions
//--------------------------------------------------------------------------------------


public int Native_RemoveEffect(Handle plugin, int numParams)
{
	char PlayerSteamID[64];
	char WeapID[10];
	GetNativeString(1, PlayerSteamID, 64);

	if(GetNativeCell(2) < 0)
		return false;
	Format(WeapID, sizeof(WeapID), "%d", GetNativeCell(2));

	return RemoveEffect(-1, PlayerSteamID, WeapID);
}

public int Native_RemovePlayerEffects(Handle plugin, int numParams)
{
	char PlayerSteamID[64];
	GetNativeString(1, PlayerSteamID, 64);

	return RemoveEffect(-1, PlayerSteamID, "-1");
}

public int Native_GetUnusualEffectPermission(Handle plugin, int numParams)
{
	int Bit = GetNativeCell(1);

	if(Bit == -1)
		return Permission[0];

	int i=0;
	while(FlagsList[i] != Bit && i<21)
		i++;

	if(i < 21)
		return Permission[i+1];

	LogError("INVALID FLAGBIT !");
	return -2;
}

public int Native_SetUnusualEffectPermission(Handle plugin, int numParams)
{
	int Bit  = GetNativeCell(1);
	int Limit = GetNativeCell(2);

	if(Limit < -1)
	{
		LogError("INVALID LIMIT !");
		return false;
	}

	char FlagBitToLetter[22][2] = {"0", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "z"};
	KeyValues kv = new KeyValues("Unusual_permissions");
	if(!kv.ImportFromFile(PermissionsFile))
	{
		LogError("Can't open %s file", PERMISSIONFILE);
		delete kv;
		return false;
	}

	kv.GotoFirstSubKey(true);
	if(Bit == -1)
		kv.SetNum("0", Limit);
	else
	{
		int i=0;
		while(FlagsList[i] != Bit && i<21)
			i++;

		if(i<21)
			kv.SetNum(FlagBitToLetter[i+1], Limit);
		else
		{
			delete kv;
			LogError("INVALID FLAGBIT !");
			return false;
		}
	}

	kv.Rewind();
	if(!kv.ImportFromFile(PermissionsFile))
	{
		delete kv;
		LogError("Plugin ERROR : Can't save %s modifications !", PERMISSIONFILE);
		return false;
	}

	delete kv;
	return LoadPermissions();
}
