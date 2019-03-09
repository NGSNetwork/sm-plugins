#pragma semicolon 1

#include <sourcemod>
#include <multicolors>

//Store Includes
#include <store/store-core>
#include <store/store-inventory>
#include <store/store-loadouts>
#include <store/store-logging>
#include <store/store-shop>

#pragma newdecls required

#define PLUGIN_NAME "[Store] Shop Module"
#define PLUGIN_DESCRIPTION "Shop module for the Sourcemod Store."
#define PLUGIN_VERSION_CONVAR "store_shop_version"

//Config Globals
bool g_confirmItemPurchase;
bool g_showEmptyCategories;
bool g_ShowMenuDescriptions;
bool g_showMenuItemDescriptions;
bool g_allowBuyingDuplicates;
bool g_equipAfterPurchase;
char sPriority_Categories[256];
char sPriority_Items[256];
int g_itemMenuOrder;

char g_currencyName[64];
bool bShopLocked;

Handle g_buyItemForward;
Handle g_buyItemPostForward;
Handle g_openShopCmd;
Handle g_onShopStatus;

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
	CreateNative("Store_OpenShop", Native_OpenShop);
	CreateNative("Store_OpenShopCategory", Native_OpenShopCategory);

	CreateNative("Store_LockShop", Native_LockShop);
	CreateNative("Store_UnlockShop", Native_UnlockShop);
	CreateNative("Store_SetShopStatus", Native_SetShopStatus);
	CreateNative("Store_IsShopLocked", Native_IsShopLocked);

	g_buyItemForward = CreateGlobalForward("Store_OnBuyItem", ET_Event, Param_Cell, Param_Cell);
	g_buyItemPostForward = CreateGlobalForward("Store_OnBuyItem_Post", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_openShopCmd = CreateGlobalForward("Store_OnShopCmd", ET_Ignore, Param_Cell);
	g_onShopStatus = CreateGlobalForward("Store_OnShopStatusChange", ET_Ignore, Param_Cell, Param_Cell);

	RegPluginLibrary("store-shop");
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("store.phrases");

	CreateConVar(PLUGIN_VERSION_CONVAR, STORE_VERSION, PLUGIN_NAME, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);

	LoadConfig("Shop", "configs/store/shop.cfg");
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
	KvGetString(hKV, "shop_commands", menuCommands, sizeof(menuCommands), "!shop /shop");
	Store_RegisterChatCommands(menuCommands, ChatCommand_OpenShop);

	g_confirmItemPurchase = view_as<bool>(KvGetNum(hKV, "confirm_item_purchase", 0));
	g_showEmptyCategories = view_as<bool>(KvGetNum(hKV, "show_empty_categories", 0));
	g_ShowMenuDescriptions = view_as<bool>(KvGetNum(hKV, "show_menu_descriptions", 1));
	g_showMenuItemDescriptions = view_as<bool>(KvGetNum(hKV, "show_menu_item_descriptions", 1));
	g_allowBuyingDuplicates = view_as<bool>(KvGetNum(hKV, "allow_buying_duplicates", 0));
	g_equipAfterPurchase = view_as<bool>(KvGetNum(hKV, "equip_after_purchase", 1));

	if (KvJumpToKey(hKV, "Menu Sorting"))
	{
		if (KvJumpToKey(hKV, "Categories") && KvGotoFirstSubKey(hKV, false))
		{
			CreatePriorityString(hKV, sPriority_Categories, sizeof(sPriority_Categories));
			KvGoBack(hKV);
		}

		if (KvJumpToKey(hKV, "Items") && KvGotoFirstSubKey(hKV, false))
		{
			CreatePriorityString(hKV, sPriority_Items, sizeof(sPriority_Items));
			KvGoBack(hKV);
		}

		KvGoBack(hKV);
	}

	g_itemMenuOrder = KvGetNum(hKV, "menu_item_order", 2);

	CloseHandle(hKV);

	Store_AddMainMenuItem("Shop", "Shop Description", _, OnMainMenuShopClick, g_itemMenuOrder);

	Store_LogInformational("Store Config '%s' Loaded: %s", sName, sFile);
}

void CreatePriorityString(Handle hKV, char[] sPriority, int maxsize)
{
	Format(sPriority, maxsize, "ORDER BY ");

	do {
		char sName[256];
		KvGetSectionName(hKV, sName, sizeof(sName));

		char sValue[256];
		KvGetString(hKV, NULL_STRING, sValue, sizeof(sValue));

		char sSource[256];
		Format(sSource, sizeof(sSource), "%s %s, ", sValue, sName);

		StrCat(sPriority, maxsize, sSource);

	} while (KvGotoNextKey(hKV, false));
	KvGoBack(hKV);

	Format(sPriority, maxsize, "%s;", sPriority);
	ReplaceString(sPriority, maxsize, ", ;", ";");
}

void SetShopStatus(int client, bool bLocked)
{
	bShopLocked = bLocked;
	CReplyToCommand(client, "%t Store has been %s!", "Store Tag Colored", bShopLocked ? "enabled" : "disabled");

	Call_StartForward(g_onShopStatus);
	Call_PushCell(client);
	Call_PushCell(bLocked);
	Call_Finish();
}

public void OnMainMenuShopClick(int client, const char[] value)
{
	OpenShop(client);
}

public void ChatCommand_OpenShop(int client)
{
	OpenShop(client);
}

void OpenShop(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
	{
		return;
	}

	if (Store_ClientIsDeveloper(client))
	{
		CPrintToChat(client, "%t%t", "Store Tag Colored", "Cannot access while developer");
		Store_OpenMainMenu(client);
		return;
	}

	if (bShopLocked)
	{
		Handle hMenu = CreateMenu(ShopMenuSelectHandle);
		SetMenuTitle(hMenu, "%T%T\n \n", "Store Menu Title", client, "Store Menu Shop Menu", client);

		AddMenuItem(hMenu, "", "Store is currently locked, please check back later.", ITEMDRAW_DISABLED); //Translate

		SetMenuExitBackButton(hMenu, true);
		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
		return;
	}

	Store_GetCategories(GetCategoriesCallback, true, sPriority_Categories, GetClientUserId(client));
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

	Handle hMenu = CreateMenu(ShopMenuSelectHandle);
	SetMenuTitle(hMenu, "%T%T\n \n", "Store Menu Title", client, "Store Menu Shop Menu", client);

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

		Handle filter = CreateTrie();
		SetTrieValue(filter, "is_buyable", 1);
		SetTrieValue(filter, "category_id", ids[i]);
		SetTrieValue(filter, "flags", GetUserFlagBits(client));

		Store_GetItems(filter, GetItemsForCategoryCallback, true, sPriority_Items, hPack);
	}

	CloseHandle(hPack);

	if (GetMenuItemCount(hMenu) < 1)
	{
		AddMenuItem(hMenu, "", "No Categories Available", ITEMDRAW_DISABLED);
	}

	SetMenuExitBackButton(hMenu, true);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

	Call_StartForward(g_openShopCmd);
	Call_PushCell(client);
	Call_Finish();
}

public void GetItemsForCategoryCallback(int[] ids, int count, any hPack)
{
	ResetPack(hPack);

	int client = GetClientOfUserId(ReadPackCell(hPack));
	int categoryId = ReadPackCell(hPack);
	Handle hMenu = ReadPackCell(hPack);

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

	if (g_ShowMenuDescriptions)
	{
		Format(sDisplay, sizeof(sDisplay), "%s\n%s", sDisplay, sDescription);
	}

	char sItem[12];
	IntToString(categoryId, sItem, sizeof(sItem));

	AddMenuItem(hMenu, sItem, sDisplay, (Store_GetCategoryServerRestriction(categoryId) && !Store_ProcessCategory(Store_GetServerID(), categoryId)) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
}

public int ShopMenuSelectHandle(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMenuItem[64];
			GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem));
			OpenShopCategory(client, StringToInt(sMenuItem));
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

void OpenShopCategory(int client, int categoryId)
{
	Handle hPack = CreateDataPack();
	WritePackCell(hPack, GetClientUserId(client));
	WritePackCell(hPack, categoryId);

	Handle filter = CreateTrie();
	SetTrieValue(filter, "is_buyable", 1);
	SetTrieValue(filter, "category_id", categoryId);
	SetTrieValue(filter, "flags", GetUserFlagBits(client));

	Store_GetItems(filter, GetItemsCallback, true, sPriority_Items, hPack);
}

public void GetItemsCallback(int[] ids, int count, any hPack)
{
	ResetPack(hPack);

	int client = GetClientOfUserId(ReadPackCell(hPack));
	int categoryId = ReadPackCell(hPack);

	CloseHandle(hPack);

	if (client <= 0 || !IsClientInGame(client))
	{
		return;
	}

	if (count == 0)
	{
		CPrintToChat(client, "%t%t", "Store Tag Colored", "No items in this category");
		OpenShop(client);

		return;
	}

	char categoryDisplayName[64];
	Store_GetCategoryDisplayName(categoryId, categoryDisplayName, sizeof(categoryDisplayName));

	Handle hMenu = CreateMenu(ShopCategoryMenuSelectHandle);
	SetMenuTitle(hMenu, "%T - %s\n \n", "Shop", client, categoryDisplayName);

	for (int i = 0; i < count; i++)
	{
		char sDisplayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(ids[i], sDisplayName, sizeof(sDisplayName));

		char sDescription[STORE_MAX_DESCRIPTION_LENGTH];
		Store_GetItemDescription(ids[i], sDescription, sizeof(sDescription));

		char sDisplay[sizeof(sDisplayName) + sizeof(sDescription) + 5];
		Format(sDisplay, sizeof(sDisplay), "%s [%d %s]", sDisplayName, Store_GetItemPrice(ids[i]), g_currencyName);

		if (g_showMenuItemDescriptions)
		{
			Format(sDisplay, sizeof(sDisplay), "%s\n%s", sDisplay, sDescription);
		}

		char sItem[12];
		IntToString(ids[i], sItem, sizeof(sItem));

		bool bShow = true;
		if (Store_GetItemServerRestriction(ids[i]) && !Store_ProcessItem(Store_GetServerID(), ids[i]))
		{
			bShow = false;
		}

		AddMenuItem(hMenu, sItem, sDisplay, bShow ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	SetMenuExitBackButton(hMenu, true);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public int ShopCategoryMenuSelectHandle(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMenuItem[64];
			GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem));
			DoBuyItem(client, StringToInt(sMenuItem));
		}
		case MenuAction_Cancel:
		{
			if (slot == MenuCancel_ExitBack)
			{
				OpenShop(client);
			}
		}
		case MenuAction_End:CloseHandle(menu);
	}
}

void DoBuyItem(int client, int itemId, bool confirmed = false, bool checkeddupes = false)
{
	if (g_confirmItemPurchase && !confirmed)
	{
		DisplayConfirmationMenu(client, itemId);
		return;
	}

	if (!g_allowBuyingDuplicates && !checkeddupes)
	{
		char itemName[STORE_MAX_NAME_LENGTH];
		Store_GetItemName(itemId, itemName, sizeof(itemName));

		Handle hPack = CreateDataPack();
		WritePackCell(hPack, GetClientUserId(client));
		WritePackCell(hPack, itemId);

		Store_GetUserItemsCount(GetSteamAccountID(client), itemName, DoBuyItem_ItemCountCallBack, hPack);
		return;
	}

	Action result = Plugin_Continue;

	Call_StartForward(g_buyItemForward);
	Call_PushCell(client);
	Call_PushCell(itemId);
	Call_Finish(result);

	if (result == Plugin_Handled || result == Plugin_Stop)
	{
		return;
	}

	Handle hPack = CreateDataPack();
	WritePackCell(hPack, GetClientUserId(client));
	WritePackCell(hPack, itemId);

	Store_BuyItem(GetSteamAccountID(client), itemId, OnBuyItemComplete, hPack);
}

public void DoBuyItem_ItemCountCallBack(int count, any hPack)
{
	ResetPack(hPack);

	int client = GetClientOfUserId(ReadPackCell(hPack));
	int itemId = ReadPackCell(hPack);

	CloseHandle(hPack);

	if (!client || !IsClientInGame(client))
	{
		return;
	}

	if (count > 1)
	{
		char displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		CPrintToChat(client, "%t%t", "Store Tag Colored", "Already purchased item", displayName);
	}

	DoBuyItem(client, itemId, true, true);
}

void DisplayConfirmationMenu(int client, int itemId)
{
	char displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
	Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));

	Handle menu = CreateMenu(ConfirmationMenuSelectHandle);
	SetMenuTitle(menu, "%T", "Item Purchase Confirmation", client, displayName);

	char value[8];
	IntToString(itemId, value, sizeof(value));

	AddMenuItem(menu, value, "Yes");
	AddMenuItem(menu, "no", "No");

	SetMenuExitButton(menu, false);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int ConfirmationMenuSelectHandle(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMenuItem[64];
			GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem));

			if (StrEqual(sMenuItem, "no"))
			{
				OpenShop(client);
				return false;
			}

			DoBuyItem(client, StringToInt(sMenuItem), true);
		}
		case MenuAction_DisplayItem:
		{
			char sDisplay[64];
			GetMenuItem(menu, slot, "", 0, _, sDisplay, sizeof(sDisplay));

			char buffer[255];
			Format(buffer, sizeof(buffer), "%T", sDisplay, client);

			return RedrawMenuItem(buffer);
		}
		case MenuAction_Cancel:OpenShop(client);
		case MenuAction_End:CloseHandle(menu);
	}

	return false;
}

public void OnBuyItemComplete(bool success, any hPack)
{
	ResetPack(hPack);

	int client = GetClientOfUserId(ReadPackCell(hPack));
	int itemId = ReadPackCell(hPack);

	CloseHandle(hPack);

	if (!client || !IsClientInGame(client))
	{
		return;
	}

	if (!success)
	{
		CPrintToChat(client, "%t%t", "Store Tag Colored", "Not enough credits to buy", g_currencyName);
		return;
	}

	char displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
	Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
	CPrintToChat(client, "%t%t", "Store Tag Colored", "Item Purchase Successful", displayName);

	if (g_equipAfterPurchase)
	{
		Handle hMenu = CreateMenu(EquipAfterPurchaseMenuHandle);
		SetMenuTitle(hMenu, "%t", "Item Purchase Menu Title", displayName);

		char sItemID[64];
		IntToString(itemId, sItemID, sizeof(sItemID));

		AddMenuItem(hMenu, sItemID, "Yes");
		AddMenuItem(hMenu, "", "No");

		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	}
	else
	{
		OpenShop(client);
	}

	Call_StartForward(g_buyItemPostForward);
	Call_PushCell(client);
	Call_PushCell(itemId);
	Call_PushCell(success);
	Call_Finish();
}

public int EquipAfterPurchaseMenuHandle(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMenuItem[64]; char sDisplay[64];
			GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem), _, sDisplay, sizeof(sDisplay));

			if (StrEqual(sDisplay, "Yes"))
			{
				int loadout = Store_GetClientLoadout(client);
				int itemId = StringToInt(sMenuItem);

				Store_SetItemEquippedState(GetSteamAccountID(client), itemId, loadout, true, EquipItemCallback);

				char displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
				Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));

				CPrintToChat(client, "%t%t", "Store Tag Colored", "Item Purchase Equipped", displayName, loadout);
			}

			OpenShop(client);
		}
		case MenuAction_End:CloseHandle(menu);
	}
}

public void EquipItemCallback(int accountId, int itemId, int loadoutId, any data)
{

}

public int Native_OpenShop(Handle plugin, int params)
{
	OpenShop(GetNativeCell(1));
}

public int Native_OpenShopCategory(Handle plugin, int params)
{
	OpenShopCategory(GetNativeCell(1), GetNativeCell(2));
}

public int Native_LockShop(Handle plugin, int params)
{
	SetShopStatus(GetNativeCell(1), true);
}

public int Native_UnlockShop(Handle plugin, int params)
{
	SetShopStatus(GetNativeCell(1), false);
}

public int Native_SetShopStatus(Handle plugin, int params)
{
	SetShopStatus(GetNativeCell(1), GetNativeCell(2));
}

public int Native_IsShopLocked(Handle plugin, int params)
{
	return bShopLocked;
}
