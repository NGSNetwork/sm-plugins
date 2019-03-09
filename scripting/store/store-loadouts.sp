#pragma semicolon 1

#include <sourcemod>
#include <multicolors>
#include <store/store-stocks>

#undef REQUIRE_EXTENSIONS
#include <tf2_stocks>

//Store Includes
#include <store/store-core>
#include <store/store-loadouts>
#include <store/store-logging>

#pragma newdecls required

#define PLUGIN_NAME "[Store] Loadouts Module"
#define PLUGIN_DESCRIPTION "Loadouts module for the Sourcemod Store."
#define PLUGIN_VERSION_CONVAR "store_loadouts_version"

//Config Globals
stock int g_maxLoadouts;
int g_itemMenuOrder;

Handle g_clientLoadoutChangedForward;
char g_game[STORE_MAX_LOADOUTGAME_LENGTH];
int g_clientLoadout[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = STORE_AUTHORS,
	description = PLUGIN_DESCRIPTION,
	version = STORE_VERSION,
	url = STORE_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Store_OpenLoadoutMenu", Native_OpenLoadoutMenu);
	CreateNative("Store_GetClientLoadout", Native_GetClientLoadout);
	CreateNative("Store_SetClientLoadout", Native_SetClientLoadout);

	g_clientLoadoutChangedForward = CreateGlobalForward("Store_OnClientLoadoutChanged", ET_Event, Param_Cell);

	RegPluginLibrary("store-loadouts");
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("store.phrases");

	CreateConVar(PLUGIN_VERSION_CONVAR, STORE_VERSION, PLUGIN_NAME, FCVAR_REPLICATED | FCVAR_SPONLY | FCVAR_DONTRECORD);

	GetGameFolderName(g_game, sizeof(g_game));

	HookEvent("player_spawn", Event_PlayerSpawn);

	AddCommandListener(OnMOTDClose, "closed_htmlpage");

	LoadConfig("Loadouts", "configs/store/loadout.cfg");
}

public void Store_OnDatabaseInitialized()
{
	Store_GetLoadouts(INVALID_HANDLE, INVALID_FUNCTION, false);

	Store_RegisterPluginModule(PLUGIN_NAME, PLUGIN_DESCRIPTION, PLUGIN_VERSION_CONVAR, STORE_VERSION);
}

void LoadConfig(const char[] sName, const char[] sFile)
{
	Handle hKV = CreateKeyValues(sName);

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), sFile);

	if (!FileToKeyValues(hKV, sPath))
	{
		CloseHandle(hKV);
		SetFailState("Can't read config file %s", sPath);
	}

	char menuCommands[255];
	KvGetString(hKV, "loadout_commands", menuCommands, sizeof(menuCommands), "!loadout /loadout");
	Store_RegisterChatCommands(menuCommands, ChatCommand_OpenLoadout);

	g_maxLoadouts = KvGetNum(hKV, "loadouts_amount", 3);
	g_itemMenuOrder = KvGetNum(hKV, "menu_item_order", 10);

	CloseHandle(hKV);

	Store_AddMainMenuItem("Loadout", "Loadout Description", _, OnMainMenuLoadoutClick, g_itemMenuOrder);

	Store_LogInformational("Store Config '%s' Loaded: %s", sName, sFile);
}

public void ChatCommand_OpenLoadout(int client)
{
	OpenLoadoutMenu(client);
}

public void OnMainMenuLoadoutClick(int client, const char[] value)
{
	OpenLoadoutMenu(client);
}

public Action OnMOTDClose(int client, const char[] command, int argc)
{
	Store_QueryEquippedLoadout(GetSteamAccountID(client), OnReceiveClientLoadout, GetClientUserId(client));
}

public void OnReceiveClientLoadout(int accountId, int id, any data)
{
	int client = GetClientOfUserId(data);

	g_clientLoadout[client] = id;
}

public void Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsFakeClient(client))
	{
		return;
	}

	if (g_clientLoadout[client] == 0 || !IsLoadoutAvailableFor(client, g_clientLoadout[client]))
	{
		Store_GetClientLoadouts(GetSteamAccountID(client), OnFindOptimalLoadout, GetClientUserId(client));
		//RetrieveFirstLoadout(client);
	}
}

void OpenLoadoutMenu(int client)
{
	char sToken[MAX_TOKEN_SIZE];
	Store_GetClientToken(client, sToken, sizeof(sToken));

	Handle hMenu = CreateMenu(MenuHandle_OpenLoadoutsMenu);
	SetMenuTitle(hMenu, "%T%T\n \n", "Store Menu Title", client, "Store Menu Loadouts Menu", client);

	AddMenuItem(hMenu, "Global", "Global Loadout Listings");
	AddMenuItem(hMenu, "Subscribed", "List Subscribed Loadouts");
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	AddMenuItem(hMenu, "Generate", "Generate a new Token");
	AddMenuItemFormat(hMenu, "", ITEMDRAW_DISABLED, "Current Token:\n%s", sToken);

	SetMenuExitBackButton(hMenu, true);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public int MenuHandle_OpenLoadoutsMenu(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMenuItem[64];
			GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem));

			Store_AccessType aquire = Access_Menus/*Store_GetGlobalAccessType() != Access_Both ? Store_GetGlobalAccessType() : Store_GetGlobalAccessType()*/;

			if (StrEqual(sMenuItem, "Global"))
			{
				ListGlobalLoadouts(client, aquire);
			}
			else if (StrEqual(sMenuItem, "Subscribed"))
			{
				OpenSubscriptions(client, aquire);
			}
			else if (StrEqual(sMenuItem, "Generate"))
			{
				Store_GenerateNewToken(client);
				OpenLoadoutMenu(client);
			}
		}
		case MenuAction_Cancel:
		{
			if (slot == MenuCancel_ExitBack)
			{
				Store_OpenMainMenu(client);
			}
		}
		case MenuAction_End:CloseHandle(menu);
	}
}

void ListGlobalLoadouts(int client, Store_AccessType access)
{
	switch (access)
	{
		case Access_Menus:
		{
			/*
			Handle filter = CreateTrie();
			SetTrieString(filter, "game", g_game);
			SetTrieValue(filter, "team", GetClientTeam(client));

			if (StrEqual(g_game, "tf"))
			{
				char className[10];
				TF2_GetClassName(TF2_GetPlayerClass(client), className, sizeof(className));
				SetTrieString(filter, "class", className);
			}

			Store_GetLoadouts(filter, OnGetGlobalLoadouts, true, GetClientUserId(client));
			*/
			Store_GetClientLoadouts(GetSteamAccountID(client), OnListAllLoadouts, GetClientUserId(client));
		}
		case Access_MOTDs:
		{
			DisplaySubscriptionsMOTD(client);
		}
	}
}

public void OnListAllLoadouts(int accountId, int[] ids, int count, any data)
{
	int client = GetClientOfUserId(data);

	if (client < 1 || count <= 0)
	{
		return;
	}

	Handle hMenu = CreateMenu(MenuHandle_DisplayGlobalLoadouts);
	SetMenuTitle(hMenu, "Your Loadouts for %s:", g_game);

	for (int i = 0; i < count; i++)
	{
		char displayName[32];
		Store_GetLoadoutDisplayName(ids[i], displayName, sizeof(displayName));

		char sID[32];
		IntToString(i, sID, sizeof(sID));

		AddMenuItem(hMenu, sID, displayName);
	}

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public void OnGetGlobalLoadouts(int[] ids, int count, any data)
{
	int client = GetClientOfUserId(data);

	if (client < 1)
	{
		return;
	}

	Handle hMenu = CreateMenu(MenuHandle_DisplayGlobalLoadouts);
	SetMenuTitle(hMenu, "Global Public Loadouts for %s:", g_game);

	for (int i = 0; i < count; i++)
	{
		char displayName[32];
		Store_GetLoadoutDisplayName(ids[i], displayName, sizeof(displayName));

		char sID[32];
		IntToString(i, sID, sizeof(sID));

		AddMenuItem(hMenu, sID, displayName);
	}

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public int MenuHandle_DisplayGlobalLoadouts(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMenuItem[64];
			GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem));


		}
		case MenuAction_Cancel:
		{
			if (slot == MenuCancel_ExitBack)
			{
				OpenLoadoutMenu(client);
			}
		}
		case MenuAction_End:CloseHandle(menu);
	}
}

bool IsLoadoutAvailableFor(int client, int loadout)
{
	char game[STORE_MAX_LOADOUTGAME_LENGTH];
	Store_GetLoadoutGame(loadout, game, sizeof(game));

	if (strlen(game) == 0 || !StrEqual(game, g_game))
	{
		return false;
	}

	if (StrEqual(g_game, "tf"))
	{
		char loadoutClass[STORE_MAX_LOADOUTCLASS_LENGTH];
		Store_GetLoadoutClass(loadout, loadoutClass, sizeof(loadoutClass));

		char className[10];
		TF2_GetClassName(TF2_GetPlayerClass(client), className, sizeof(className));

		if (strlen(loadoutClass) == 0 && !StrEqual(loadoutClass, className))
		{
			return false;
		}
	}

	int loadoutTeam = Store_GetLoadoutTeam(loadout);
	if (loadoutTeam != -1 && GetClientTeam(client) != loadoutTeam)
	{
		return false;
	}

	return true;
}

/*
void RetrieveFirstLoadout(int client)
{
	Handle filter = CreateTrie();
	SetTrieString(filter, "game", g_game);
	SetTrieValue(filter, "team", GetClientTeam(client));

	if (StrEqual(g_game, "tf"))
	{
		char className[10];
		TF2_GetClassName(TF2_GetPlayerClass(client), className, sizeof(className));
		SetTrieString(filter, "class", className);
	}

	Store_GetClientLoadouts(GetSteamAccountID(client), OnFindOptimalLoadout, GetClientUserId(client));
}
*/
public void OnFindOptimalLoadout(int accountId, int[] ids, int count, any data)
{
	int client = GetClientOfUserId(data);

	if (client != 0 && count > 0)
	{
		SaveEquippedLoadout(client, ids[0]);
	}
}

public int Native_OpenLoadoutMenu(Handle plugin, int params)
{
	OpenLoadoutMenu(GetNativeCell(1));
}

public int Native_GetClientLoadout(Handle plugin, int params)
{
	return g_clientLoadout[GetNativeCell(1)];
}

public int Native_SetClientLoadout(Handle plugin, int params)
{
	g_clientLoadout[GetNativeCell(1)] = GetNativeCell(2);
}

void TF2_GetClassName(TFClassType classType, char[] buffer, int maxlength)
{
	char TF2_ClassName[TFClassType][] =  { "", "scout", "sniper", "soldier", "demoman", "medic", "heavy", "pyro", "spy", "engineer" };
	strcopy(buffer, maxlength, TF2_ClassName[classType]);
}

void OpenSubscriptions(int client, Store_AccessType access)
{
	switch (access)
	{
		case Access_Menus:DisplaySubscriptionsMenu(client);
		case Access_MOTDs:DisplaySubscriptionsMOTD(client);
	}
}

void DisplaySubscriptionsMenu(int client)
{
	Store_GetClientLoadouts(GetSteamAccountID(client), GetLoadoutsCallback, client);
}

public void GetLoadoutsCallback(int accountId, int[] ids, int count, any client)
{
	Handle menu = CreateMenu(LoadoutMenuSelectHandle);
	SetMenuTitle(menu, "Loadout\n \n");

	for (int i = 0; i < count; i++)
	{
		char displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetLoadoutDisplayName(ids[i], displayName, sizeof(displayName));

		char itemText[sizeof(displayName) + 3];

		if (g_clientLoadout[client] == ids[i])
		{
			strcopy(itemText, sizeof(itemText), "[E] ");
		}

		Format(itemText, sizeof(itemText), "%s%s", itemText, displayName);

		char itemValue[8];
		IntToString(ids[i], itemValue, sizeof(itemValue));

		AddMenuItem(menu, itemValue, itemText);
	}

	if (count <= 0)
	{
		AddMenuItemFormat(menu, "", ITEMDRAW_DISABLED, "You aren't currently subscribed or own any loadouts at this time, better get to it!"); //Translate
	}

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int LoadoutMenuSelectHandle(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMenuItem[64];
			GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem));

			SaveEquippedLoadout(client, StringToInt(sMenuItem));

			Store_AccessType aquire = Access_Menus/*Store_GetGlobalAccessType() != Access_Both ? Store_GetGlobalAccessType() : Store_GetGlobalAccessType()*/;

			OpenSubscriptions(client, aquire);
		}
		case MenuAction_Cancel:
		{
			if (slot == MenuCancel_ExitBack)
			{
				OpenLoadoutMenu(client);
			}
		}
		case MenuAction_End:CloseHandle(menu);
	}
}

void DisplaySubscriptionsMOTD(int client)
{
	char sURL[256];
	Store_GetStoreBaseURL(sURL, sizeof(sURL));

	char sToken[MAX_TOKEN_SIZE];
	Store_GetClientToken(client, sToken, sizeof(sToken));

	char sEngine[64];
	GetGameFolderName(sEngine, sizeof(sEngine));

	Format(sURL, sizeof(sURL), "%s%s?token=%s&?game=%s&userid=%i&page=%s", sURL, POSTURL, sToken, sEngine, Store_GetClientUserID(client), STORE_POSTURL_LOADOUTS);
	Store_OpenMOTDWindow(client, "Store Loadouts Interface", sURL);
}

bool SaveEquippedLoadout(int client, int id)
{
	Store_SaveEquippedLoadout(GetSteamAccountID(client), id, OnSaveClientLoadoutID, GetClientUserId(client));
}

public void OnSaveClientLoadoutID(int accountId, int id, any data)
{
	int client = GetClientOfUserId(data);

	g_clientLoadout[client] = id;

	Call_StartForward(g_clientLoadoutChangedForward);
	Call_PushCell(client);
	Call_PushCell(id);
	Call_Finish();

	char sLoadoutName[STORE_MAX_LOADOUTNAME_LENGTH];
	Store_GetLoadoutDisplayName(id, sLoadoutName, sizeof(sLoadoutName));

	CPrintToChat(client, "You have successfully equipped loadout %s! [Loadout ID: %i]", sLoadoutName, id); //Translate
}
