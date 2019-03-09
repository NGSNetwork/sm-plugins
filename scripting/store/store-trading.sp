#pragma semicolon 1

#include <sourcemod>
#include <multicolors>
#include <store/store-stocks>

//Store Includes
#include <store/store-core>
#include <store/store-loadouts>
#include <store/store-logging>

#pragma newdecls required

#define PLUGIN_NAME "[Store] Trading Module"
#define PLUGIN_DESCRIPTION "Trading module for the Sourcemod Store."
#define PLUGIN_VERSION_CONVAR "store_trading_version"

char sQuery_CreateTrade[] = "INSERT INTO `%s_trades` (sender_id, receiver_id, sender_items, receiver_items, status) VALUES ('%i', '%i', '%s', '%s', 'created');";

//Config Globals
int g_itemMenuOrder;

stock bool bIsSearching[MAXPLAYERS + 1];

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
	LogError("Trade module is unfinished and therefore shouldn't be running, please wait for an update.");
	return APLRes_Failure;
}

public void OnPluginStart()
{
	LoadTranslations("store.phrases");

	CreateConVar(PLUGIN_VERSION_CONVAR, STORE_VERSION, PLUGIN_NAME, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);

	LoadConfig("Trading", "configs/store/trading.cfg");
}

public void OnConfigsExecuted()
{

}

public void Store_OnDatabaseInitialized()
{
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

	char sCommand[255];
	KvGetString(hKV, "trade_commands", sCommand, sizeof(sCommand), "!trade /trade");
	Store_RegisterChatCommands(sCommand, ChatCommand_OpenTrade);

	g_itemMenuOrder = KvGetNum(hKV, "menu_item_order", 12);

	CloseHandle(hKV);

	Store_AddMainMenuItem("Trade", "Trade Description", _, OnMainMenuTradeClick, g_itemMenuOrder);

	Store_LogInformational("Store Config '%s' Loaded: %s", sName, sFile);
}

public void OnMainMenuTradeClick(int client, const char[] value)
{
	OpenTrade(client);
}

public void ChatCommand_OpenTrade(int client)
{
	OpenTrade(client);
}

void OpenTrade(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
	{
		return;
	}

	Handle hMenu = CreateMenu(MenuHandle_OpenTradesMenu);
	SetMenuTitle(hMenu, "%T%T\n \n", "Store Menu Title", client, "Store Menu Trades Menu", client);

	AddMenuItem(hMenu, "Manage", "Manage Trades");
	AddMenuItem(hMenu, "Start", "Start a Trade");

	SetMenuExitBackButton(hMenu, true);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public int MenuHandle_OpenTradesMenu(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMenuItem[64];
			GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem));

			if (StrEqual(sMenuItem, "Manage"))
			{

			}
			else if (StrEqual(sMenuItem, "Start"))
			{
				Store_DisplayClientsMenu(client, MenuHandler_PickClient);
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

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{

}

public int MenuHandler_PickClient(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMenuItem[64];
			GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem));
			int target = StringToInt(sMenuItem);

			Handle hPack = CreateDataPack();
			WritePackCell(hPack, GetClientUserId(client));
			WritePackCell(hPack, GetClientUserId(target));

			Store_GetUserItems(null, GetSteamAccountID(target), Store_GetClientLoadout(target), OnGetTargetItemsForTrade, hPack);
		}
		case MenuAction_Cancel:
		{
			if (slot == MenuCancel_ExitBack)
			{
				OpenTrade(client);
			}
		}
		case MenuAction_End:CloseHandle(menu);
	}
}

public void OnGetTargetItemsForTrade(int accountId, int[] useritems, bool[] equipped, int[] useritemCount, int count, int loadoutId, any data)
{
	ResetPack(data);

	int client = GetClientOfUserId(ReadPackCell(data));
	int target = GetClientOfUserId(ReadPackCell(data));

	CloseHandle(data);

	if (client < 1 || target < 1)
	{
		return;
	}

	Handle hMenu = CreateMenu(MenuHandle_TargetItems);
	SetMenuTitle(hMenu, "Items you want:");

	for (int item = 0; item < count; item++)
	{
		int index = useritems[item];

		char displayName[32];
		Store_GetItemDisplayName(index, displayName, sizeof(displayName));

		char sDisplay[64];
		Format(sDisplay, sizeof(sDisplay), "%s - %s - %i", displayName, equipped[item] ? "Equipped" : "Not Equipped", useritemCount[item]);

		char sIndex[32];
		IntToString(index, sIndex, sizeof(sIndex));

		AddMenuItem(hMenu, sIndex, sDisplay);
	}

	PushMenuCell(hMenu, "Target", target);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public int MenuHandle_TargetItems(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMenuItem[64];
			GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem));

			int iItem = StringToInt(sMenuItem);
			int target = GetMenuCell(menu, "target");

			Handle hPack = CreateDataPack();
			WritePackCell(hPack, GetClientUserId(client));
			WritePackCell(hPack, GetClientUserId(target));
			WritePackCell(hPack, iItem);

			Store_GetUserItems(null, GetSteamAccountID(client), Store_GetClientLoadout(client), OnGetClientItemsForTrade, hPack);
		}
		case MenuAction_Cancel:
		{
			if (slot == MenuCancel_ExitBack)
			{
				OpenTrade(client);
			}
		}
		case MenuAction_End:CloseHandle(menu);
	}
}

public void OnGetClientItemsForTrade(int accountId, int[] useritems, bool[] equipped, int[] useritemCount, int count, int loadoutId, any data)
{
	ResetPack(data);

	int client = GetClientOfUserId(ReadPackCell(data));
	int target = GetClientOfUserId(ReadPackCell(data));
	int item2 = ReadPackCell(data);

	CloseHandle(data);

	if (client < 1 || target < 1)
	{
		return;
	}

	Handle hMenu = CreateMenu(MenuHandle_ClientItems);
	SetMenuTitle(hMenu, "Items you want to trade:");

	for (int item = 0; item < count; item++)
	{
		int index = useritems[item];

		char displayName[32];
		Store_GetItemDisplayName(index, displayName, sizeof(displayName));

		char sDisplay[64];
		Format(sDisplay, sizeof(sDisplay), "%s - %s - %i", displayName, equipped[item] ? "Equipped" : "Not Equipped", useritemCount[item]);

		char sIndex[32];
		IntToString(index, sIndex, sizeof(sIndex));

		AddMenuItem(hMenu, sIndex, sDisplay);
	}

	PushMenuCell(hMenu, "target", target);
	PushMenuCell(hMenu, "item", item2);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public int MenuHandle_ClientItems(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMenuItem[64];
			GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem));

			int iItem = StringToInt(sMenuItem);
			int target = GetMenuCell(menu, "target");
			int iTrade = GetMenuCell(menu, "item");

			CreateTrade(client, target, iItem, iTrade);
		}
		case MenuAction_Cancel:
		{
			if (slot == MenuCancel_ExitBack)
			{
				OpenTrade(client);
			}
		}
		case MenuAction_End:CloseHandle(menu);
	}
}

void CreateTrade(int client, int target, int item, int target_item)
{
	char sItem[32];
	IntToString(item, sItem, sizeof(sItem));

	char sTargetItem[32];
	IntToString(target_item, sTargetItem, sizeof(sTargetItem));

	char sQuery[2048];
	Format(sQuery, sizeof(sQuery), sQuery_CreateTrade, STORE_DATABASE_PREFIX, Store_GetClientUserID(client), Store_GetClientUserID(target), sItem, sTargetItem);
	Store_SQLTQuery(SQLCall_OnCreateTradeRequest, sQuery, GetClientUserId(client));
}

public void SQLCall_OnCreateTradeRequest(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		Store_LogError("SQL Error on SQLCall_OnCreateTradeRequest: %s", error);
		return;
	}

	int client = GetClientOfUserId(data);

	if (client > 0)
	{
		CPrintToChat(client, "Trade has been created!");
	}
}
