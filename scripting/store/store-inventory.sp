#pragma semicolon 1

#include <sourcemod>
#include <multicolors>

//Store Includes
#include <store/store-core>
#include <store/store-inventory>
#include <store/store-loadouts>
#include <store/store-logging>

#pragma newdecls required

#define PLUGIN_NAME "[Store] Inventory Module"
#define PLUGIN_DESCRIPTION "Inventory module for the Sourcemod Store."
#define PLUGIN_VERSION_CONVAR "store_inventory_version"

//Config Globals
bool g_showEmptyCategories;
bool g_showMenuDescriptions;
bool g_showItemsMenuDescriptions;
int g_itemMenuOrder;

Handle g_itemTypes;
Handle g_itemTypeNameIndex;

char g_currencyName[64];

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
	CreateNative("Store_OpenInventory", Native_OpenInventory);
	CreateNative("Store_OpenInventoryCategory", Native_OpenInventoryCategory);

	CreateNative("Store_RegisterItemType", Native_RegisterItemType);
	CreateNative("Store_IsItemTypeRegistered", Native_IsItemTypeRegistered);

	CreateNative("Store_CallItemAttrsCallback", Native_CallItemAttrsCallback);

	RegPluginLibrary("store-inventory");
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("store.phrases");

	CreateConVar(PLUGIN_VERSION_CONVAR, STORE_VERSION, PLUGIN_NAME, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);

	g_itemTypes = CreateArray();
	g_itemTypeNameIndex = CreateTrie();

	LoadConfig("Inventory", "configs/store/inventory.cfg");
}

public void OnConfigsExecuted()
{
	Store_GetCurrencyName(g_currencyName, sizeof(g_currencyName));
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

	char menuCommands[255];
	KvGetString(hKV, "inventory_commands", menuCommands, sizeof(menuCommands), "!inventory /inventory !inv /inv");
	Store_RegisterChatCommands(menuCommands, ChatCommand_OpenInventory);

	g_showEmptyCategories = view_as<bool>(KvGetNum(hKV, "show_empty_categories", 0));
	g_showMenuDescriptions = view_as<bool>(KvGetNum(hKV, "show_menu_descriptions", 1));
	g_showItemsMenuDescriptions = view_as<bool>(KvGetNum(hKV, "show_items_menu_descriptions", 1));
	g_itemMenuOrder = KvGetNum(hKV, "menu_item_order", 4);

	CloseHandle(hKV);

	Store_AddMainMenuItem("Inventory", "Inventory Description", _, OnMainMenuInventoryClick, g_itemMenuOrder);

	Store_LogInformational("Store Config '%s' Loaded: %s", sName, sFile);
}

public void OnMainMenuInventoryClick(int client, const char[] value)
{
	OpenInventory(client);
}

public void ChatCommand_OpenInventory(int client)
{
	OpenInventory(client);
}

void OpenInventory(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
	{
		return;
	}

	Store_GetCategories(GetCategoriesCallback, true, "", GetClientUserId(client));
}

public void GetCategoriesCallback(int[] ids, int count, any data)
{
	int client = GetClientOfUserId(data);

	if (!client)
	{
		return;
	}

	if (count < 1)
	{
		CPrintToChat(client, "%t%t", "Store Tag Colored", "No categories available");
		Store_OpenMainMenu(client);
		return;
	}

	Handle hMenu = CreateMenu(InventoryMenuSelectHandle);
	SetMenuTitle(hMenu, "%T%T%s\n \n", "Store Menu Title", client, "Store Menu Inventory Menu", client, Store_ClientIsDeveloper(client) ? "[Dev]" : "");

	Handle hPack = CreateDataPack();

	for (int i = 0; i < count; i++)
	{
		char requiredPlugin[STORE_MAX_REQUIREPLUGIN_LENGTH];
		Store_GetCategoryPluginRequired(ids[i], requiredPlugin, sizeof(requiredPlugin));

		if (strlen(requiredPlugin) != 0 && !Store_IsItemTypeRegistered(requiredPlugin))
		{
			continue;
		}

		ResetPack(hPack, true);
		WritePackCell(hPack, GetClientUserId(client));
		WritePackCell(hPack, ids[i]);
		WritePackCell(hPack, hMenu);
		PrintToServer("Contents: %i - %i", GetClientUserId(client), ids[i]);

		Handle filter = CreateTrie();
		SetTrieValue(filter, "category_id", ids[i]);
		SetTrieValue(filter, "flags", GetUserFlagBits(client));

		Store_GetUserItems(filter, GetSteamAccountID(client), Store_GetClientLoadout(client), GetItemsForCategoryCallback, hPack);
	}

	CloseHandle(hPack);

	if (GetMenuItemCount(hMenu) < 1)
	{
		AddMenuItem(hMenu, "", "No Categories Available", ITEMDRAW_DISABLED);
	}

	SetMenuExitBackButton(hMenu, true);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public int GetItemsForCategoryCallback(int accountId, int[] ids, bool[] equipped, int[] itemCount, int count, int loadoutId, any data)
{
	ResetPack(data);

	int client = GetClientOfUserId(ReadPackCell(data));
	int categoryId = ReadPackCell(data);
	Handle hMenu = ReadPackCell(data);
	PrintToServer("Unpacked: %N - %i", client, categoryId);

	if (client <= 0 || !IsClientInGame(client) || !g_showEmptyCategories && count <= 0)
	{
		return;
	}

	char sDisplayName[STORE_MAX_DISPLAY_NAME_LENGTH];
	Store_GetCategoryDisplayName(categoryId, sDisplayName, sizeof(sDisplayName));

	char sDescription[STORE_MAX_DESCRIPTION_LENGTH];
	Store_GetCategoryDescription(categoryId, sDescription, sizeof(sDescription));

	char sDisplay[sizeof(sDisplayName) + 1 + sizeof(sDescription)];
	Format(sDisplay, sizeof(sDisplay), "%s", sDisplayName);

	if (g_showMenuDescriptions)
	{
		Format(sDisplay, sizeof(sDisplay), "%s\n%s", sDisplay, sDescription);
	}

	char sItem[12];
	IntToString(categoryId, sItem, sizeof(sItem));

	AddMenuItem(hMenu, sItem, sDisplay);
}

public int InventoryMenuSelectHandle(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMenuItem[64];
			GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem));
			OpenInventoryCategory(client, StringToInt(sMenuItem));
		}
		case MenuAction_Cancel:
		{
			if (slot == MenuCancel_ExitBack)
			{
				Store_OpenMainMenu(client);
			}
		}
	}
}

void OpenInventoryCategory(int client, int categoryId, int slot = 0)
{
	Handle hPack = CreateDataPack();
	WritePackCell(hPack, GetClientUserId(client));
	WritePackCell(hPack, categoryId);
	WritePackCell(hPack, slot);

	if (!Store_ClientIsDeveloper(client))
	{
		Handle filter = CreateTrie();
		SetTrieValue(filter, "category_id", categoryId);
		SetTrieValue(filter, "flags", GetUserFlagBits(client));

		Store_GetUserItems(filter, GetSteamAccountID(client), Store_GetClientLoadout(client), GetUserItemsCallback, hPack);
	}
	else
	{
		Store_GetItems(INVALID_HANDLE, GetItemsCallback, true, "", hPack);
	}
}

public void GetUserItemsCallback(int accountId, int[] ids, bool[] equipped, int[] itemCount, int count, int loadoutId, any hPack)
{
	ResetPack(hPack);

	int client = GetClientOfUserId(ReadPackCell(hPack));
	int categoryId = ReadPackCell(hPack);
	int slot = ReadPackCell(hPack);

	CloseHandle(hPack);

	if (!client || !IsClientInGame(client))
	{
		return;
	}

	if (count < 1)
	{
		CPrintToChat(client, "%t%t", "Store Tag Colored", "Inventory category is empty");
		OpenInventory(client);
		return;
	}

	char categoryDisplayName[64];
	Store_GetCategoryDisplayName(categoryId, categoryDisplayName, sizeof(categoryDisplayName));

	Handle menu = CreateMenu(InventoryCategoryMenuSelectHandle);
	SetMenuTitle(menu, "%T - %s%s\n \n", "Inventory", client, categoryDisplayName, Store_ClientIsDeveloper(client) ? "[Dev]" : "");

	for (int item = 0; item < count; item++)
	{
		char sDisplayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(ids[item], sDisplayName, sizeof(sDisplayName));

		char sDescription[STORE_MAX_DESCRIPTION_LENGTH];
		Store_GetItemDescription(ids[item], sDescription, sizeof(sDescription));

		char sDisplay[4 + sizeof(sDisplayName) + sizeof(sDescription) + 6];
		Format(sDisplay, sizeof(sDisplay), "%s", sDisplayName);

		if (equipped[item])
		{
			Format(sDisplay, sizeof(sDisplay), "[E] %s", sDisplay);
		}

		if (itemCount[item] > 1)
		{
			Format(sDisplay, sizeof(sDisplay), "%s (%d)", sDisplay, itemCount[item]);
		}

		if (g_showItemsMenuDescriptions)
		{
			Format(sDisplay, sizeof(sDisplay), "%s\n%s", sDisplay, sDescription);
		}

		char sItem[16];
		Format(sItem, sizeof(sItem), "%b,%d", equipped[item], ids[item]);

		AddMenuItem(menu, sItem, sDisplay);
	}

	SetMenuExitBackButton(menu, true);

	if (slot != 0)
	{
		DisplayMenuAtItem(menu, client, slot, MENU_TIME_FOREVER);
		return;
	}

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int GetItemsCallback(int[] ids, int count, any hPack)
{
	ResetPack(hPack);

	int client = GetClientOfUserId(ReadPackCell(hPack));
	int categoryId = ReadPackCell(hPack);

	CloseHandle(hPack);

	if (!client || !IsClientInGame(client))
	{
		return;
	}

	if (count == 0)
	{
		CPrintToChat(client, "%t%t", "Store Tag Colored", "No items in this category");
		OpenInventory(client);

		return;
	}

	char categoryDisplayName[64];
	Store_GetCategoryDisplayName(categoryId, categoryDisplayName, sizeof(categoryDisplayName));

	Handle menu = CreateMenu(ShopCategoryMenuSelectHandle);
	SetMenuTitle(menu, "%T - %s%s\n \n", "Shop", client, categoryDisplayName, Store_ClientIsDeveloper(client) ? "[Dev]" : "");

	for (int item = 0; item < count; item++)
	{
		char sDisplayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(ids[item], sDisplayName, sizeof(sDisplayName));

		char sDescription[STORE_MAX_DESCRIPTION_LENGTH];
		Store_GetItemDescription(ids[item], sDescription, sizeof(sDescription));

		char sDisplay[sizeof(sDisplayName) + sizeof(sDescription) + 5];
		Format(sDisplay, sizeof(sDisplay), "%s [%d %s]", sDisplayName, Store_GetItemPrice(ids[item]), g_currencyName);

		if (g_showMenuDescriptions)
		{
			Format(sDisplay, sizeof(sDisplay), "%s\n%s", sDisplay, sDescription);
		}

		char sItem[12];
		IntToString(ids[item], sItem, sizeof(sItem));

		AddMenuItem(menu, sItem, sDisplay);
	}

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int ShopCategoryMenuSelectHandle(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			MenuHandlerForItemSelect(menu, client, slot);
		}
		case MenuAction_Cancel:
		{
			if (slot == MenuCancel_ExitBack)
			{
				OpenInventory(client);
			}
		}
		case MenuAction_End:CloseHandle(menu);
	}
}

public int InventoryCategoryMenuSelectHandle(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			MenuHandlerForItemSelect(menu, client, slot);
		}
		case MenuAction_Cancel:OpenInventory(client);
		case MenuAction_End:CloseHandle(menu);
	}
}

void MenuHandlerForItemSelect(Handle menu, int client, int slot)
{
	char sMenuItem[64];
	GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem));

	char buffers[2][16];
	ExplodeString(sMenuItem, ",", buffers, sizeof(buffers), sizeof(buffers[]));

	bool equipped = view_as<bool>(StringToInt(buffers[0]));
	int id = StringToInt(buffers[1]);

	char name[STORE_MAX_NAME_LENGTH];
	Store_GetItemName(id, name, sizeof(name));

	char type[STORE_MAX_TYPE_LENGTH];
	Store_GetItemType(id, type, sizeof(type));

	char loadoutSlot[STORE_MAX_LOADOUTSLOT_LENGTH];
	Store_GetItemLoadoutSlot(id, loadoutSlot, sizeof(loadoutSlot));

	int itemTypeIndex = -1;
	GetTrieValue(g_itemTypeNameIndex, type, itemTypeIndex);

	if (itemTypeIndex == -1)
	{
		CPrintToChat(client, "%t%t", "Store Tag Colored", "Item type not registered", type);
		OpenInventoryCategory(client, Store_GetItemCategory(id));
		return;
	}

	Store_ItemUseAction callbackValue = Store_DoNothing;

	Handle itemType = GetArrayCell(g_itemTypes, itemTypeIndex);
	ResetPack(itemType);

	Handle plugin = view_as<Handle>(ReadPackCell(itemType));
	Store_ItemUseCallback callback = view_as<Store_ItemUseCallback>(ReadPackFunction(itemType));

	Call_StartFunction(plugin, callback);
	Call_PushCell(client);
	Call_PushCell(id);
	Call_PushCell(equipped);
	Call_Finish(callbackValue);

	if (callbackValue == Store_DoNothing)
	{
		return;
	}

	int auth = GetSteamAccountID(client);

	switch (callbackValue)
	{
		case Store_EquipItem:
		{
			if (strlen(loadoutSlot) != 0)
			{
				Store_SetItemEquippedState(auth, id, Store_GetClientLoadout(client), true, EquipItemCallback, GetClientUserId(client));
			}
		}
		case Store_UnequipItem:
		{
			if (strlen(loadoutSlot) != 0)
			{
				Store_SetItemEquippedState(auth, id, Store_GetClientLoadout(client), false, EquipItemCallback, GetClientUserId(client));
			}
		}
		case Store_DeleteItem:
		{
			Store_RemoveUserItem(auth, id, UseItemCallback, GetClientUserId(client));
		}
	}
}

public void EquipItemCallback(int accountId, int itemId, int loadoutId, any data)
{
	int client = GetClientOfUserId(data);

	if (!client || !IsClientInGame(client))
	{
		return;
	}

	OpenInventoryCategory(client, Store_GetItemCategory(itemId));
}

public void UseItemCallback(int accountId, int itemId, any data)
{
	int client = GetClientOfUserId(data);

	if (!client || !IsClientInGame(client))
	{
		return;
	}

	OpenInventoryCategory(client, Store_GetItemCategory(itemId));
}

void RegisterItemType(const char[] type, Handle plugin, Store_ItemUseCallback useCallback, Store_ItemGetAttributesCallback attrsCallback = INVALID_FUNCTION)
{
	int itemType;
	if (GetTrieValue(g_itemTypeNameIndex, type, itemType))
	{
		CloseHandle(view_as<Handle>(GetArrayCell(g_itemTypes, itemType)));
	}

	Handle itemTypeHandle = CreateDataPack();
	WritePackCell(itemTypeHandle, plugin);
	WritePackFunction(itemTypeHandle, useCallback);
	WritePackFunction(itemTypeHandle, attrsCallback);
	WritePackString(itemTypeHandle, type);

	int index = PushArrayCell(g_itemTypes, itemTypeHandle);
	SetTrieValue(g_itemTypeNameIndex, type, index);
}

public int Native_OpenInventory(Handle plugin, int numParams)
{
	OpenInventory(GetNativeCell(1));
}

public int Native_OpenInventoryCategory(Handle plugin, int numParams)
{
	OpenInventoryCategory(GetNativeCell(1), GetNativeCell(2));
}

public int Native_RegisterItemType(Handle plugin, int numParams)
{
	char type[STORE_MAX_TYPE_LENGTH];
	GetNativeString(1, type, sizeof(type));
	RegisterItemType(type, plugin, view_as<Store_ItemUseCallback>(GetNativeFunction(2)), view_as<Store_ItemGetAttributesCallback>(GetNativeFunction(3)));
}

public int Native_IsItemTypeRegistered(Handle plugin, int params)
{
	char type[STORE_MAX_TYPE_LENGTH];
	GetNativeString(1, type, sizeof(type));

	int typeIndex;
	return GetTrieValue(g_itemTypeNameIndex, type, typeIndex);
}

public int Native_CallItemAttrsCallback(Handle plugin, int params)
{
	char type[STORE_MAX_TYPE_LENGTH];
	GetNativeString(1, type, sizeof(type));

	int typeIndex;
	if (!GetTrieValue(g_itemTypeNameIndex, type, typeIndex))
	{
		return false;
	}

	char name[STORE_MAX_NAME_LENGTH];
	GetNativeString(2, name, sizeof(name));

	char attrs[STORE_MAX_ATTRIBUTES_LENGTH];
	GetNativeString(3, attrs, sizeof(attrs));

	Handle hPack = GetArrayCell(g_itemTypes, typeIndex);
	ResetPack(hPack);

	Handle callbackPlugin = view_as<Handle>(ReadPackCell(hPack));

	ReadPackFunction(hPack);

	Store_ItemGetAttributesCallback callback = view_as<Store_ItemGetAttributesCallback>(ReadPackFunction(hPack));

	if (callback == INVALID_FUNCTION)
	{
		return false;
	}

	Call_StartFunction(callbackPlugin, callback);
	Call_PushString(name);
	Call_PushString(attrs);
	Call_Finish();

	return true;
}
