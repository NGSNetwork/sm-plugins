#pragma semicolon 1

#include <sourcemod>
#include <store>

//New Syntax
#pragma newdecls required

#define PLUGIN_NAME "[Store] Refunds Module"
#define PLUGIN_DESCRIPTION "Refunds module for the Sourcemod Store."
#define PLUGIN_VERSION_CONVAR "store_refunds_version"

//Config Globals
float g_refundPricePercentage = 0.5;
bool g_confirmItemRefund = true;
bool g_ShowMenuDescriptions = true;
bool g_showMenuItemDescriptions = true;

char g_currencyName[64];

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = STORE_AUTHORS,
	description = PLUGIN_DESCRIPTION,
	version = STORE_VERSION,
	url = STORE_URL
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("store.phrases");
	
	CreateConVar(PLUGIN_VERSION_CONVAR, STORE_VERSION, PLUGIN_NAME, FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_DONTRECORD);
	
	LoadConfig();
}

public void Store_OnCoreLoaded()
{
	Store_AddMainMenuItem("Refund", "Refund Description", _, OnMainMenuRefundClick, 6);
}

public void OnConfigsExecuted()
{    
	Store_GetCurrencyName(g_currencyName, sizeof(g_currencyName));
}

public void Store_OnDatabaseInitialized()
{
	Store_RegisterPluginModule(PLUGIN_NAME, PLUGIN_DESCRIPTION, PLUGIN_VERSION_CONVAR, STORE_VERSION);
}

void LoadConfig() 
{
	Handle kv = CreateKeyValues("root");
	
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/store/refund.cfg");
	
	if (!FileToKeyValues(kv, path)) 
	{
		CloseHandle(kv);
		SetFailState("Can't read config file %s", path);
	}

	char menuCommands[255];
	KvGetString(kv, "refund_commands", menuCommands, sizeof(menuCommands), "!refund /refund !sell /sell");
	Store_RegisterChatCommands(menuCommands, ChatCommand_OpenRefund);
	
	g_refundPricePercentage = KvGetFloat(kv, "refund_price_percentage", 0.5);
	g_confirmItemRefund = view_as<bool>KvGetNum(kv, "confirm_item_refund", 1);
	g_ShowMenuDescriptions = view_as<bool>KvGetNum(kv, "show_menu_descriptions", 1);
	g_showMenuItemDescriptions = view_as<bool>KvGetNum(kv, "show_menu_item_descriptions", 1);

	CloseHandle(kv);
	
	Store_AddMainMenuItem("Refund", "Refund Description", _, OnMainMenuRefundClick, 6);
}

public void OnMainMenuRefundClick(int client, const char[] value)
{
	OpenRefundMenu(client);
}

public void ChatCommand_OpenRefund(int client)
{
	OpenRefundMenu(client);
}

void OpenRefundMenu(int client)
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
		return;
	}
		
	Handle menu = CreateMenu(RefundMenuSelectHandle);
	SetMenuTitle(menu, "%T\n \n", "Refund", client);
	
	bool bNoCategories = true;
	for (int category = 0; category < count; category++)
	{
		char requiredPlugin[STORE_MAX_REQUIREPLUGIN_LENGTH];
		Store_GetCategoryPluginRequired(ids[category], requiredPlugin, sizeof(requiredPlugin));
		
		if (strlen(requiredPlugin) == 0 || !Store_IsItemTypeRegistered(requiredPlugin))
		{
			continue;
		}
			
		char sDisplayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetCategoryDisplayName(ids[category], sDisplayName, sizeof(sDisplayName));

		char sDescription[STORE_MAX_DESCRIPTION_LENGTH];
		Store_GetCategoryDescription(ids[category], sDescription, sizeof(sDescription));

		char sDisplay[sizeof(sDisplayName) + 1 + sizeof(sDescription)];
		Format(sDisplay, sizeof(sDisplay), "%s", sDisplayName);
		
		if (g_ShowMenuDescriptions)
		{
			Format(sDisplay, sizeof(sDisplay), "%s\n%s", sDisplayName, sDescription);
		}
		
		char sItem[12];
		IntToString(ids[category], sItem, sizeof(sItem));
		
		AddMenuItem(menu, sItem, sDisplay);
		bNoCategories = false;
	}
	
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, 0);
	
	if (bNoCategories)
	{
		CPrintToChat(client, "%t%t", "Store Tag Colored", "No categories available");
	}
}

public int RefundMenuSelectHandle(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
			{
				char sMenuItem[64];
				GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem));
				OpenRefundCategory(client, StringToInt(sMenuItem));
			}
		case MenuAction_Cancel:
			{
				if (slot == MenuCancel_ExitBack)
				{
					Store_OpenMainMenu(client);
				}
			}
		case MenuAction_End: CloseHandle(menu);
	}
}

void OpenRefundCategory(int client, int categoryId, int slot = 0)
{
	Handle hPack = CreateDataPack();
	WritePackCell(hPack, GetClientUserId(client));
	WritePackCell(hPack, categoryId);
	WritePackCell(hPack, slot);

	Handle filter = CreateTrie();
	SetTrieValue(filter, "is_refundable", 1);
	SetTrieValue(filter, "category_id", categoryId);

	Store_GetUserItems(filter, GetSteamAccountID(client), Store_GetClientCurrentLoadout(client), GetUserItemsCallback, hPack);
}

public void GetUserItemsCallback(int[] ids, bool[] equipped, int[] itemCount, int count, int loadoutId, any hPack)
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
		
	if (count == 0)
	{
		CPrintToChat(client, "%t%t", "Store Tag Colored", "No items in this category");
		OpenRefundMenu(client);
		
		return;
	}
	
	char categoryDisplayName[64];
	Store_GetCategoryDisplayName(categoryId, categoryDisplayName, sizeof(categoryDisplayName));
		
	Handle menu = CreateMenu(RefundCategoryMenuSelectHandle);
	SetMenuTitle(menu, "%T - %s\n \n", "Refund", client, categoryDisplayName);
	
	for (int item = 0; item < count; item++)
	{
		char sDisplayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(ids[item], sDisplayName, sizeof(sDisplayName));
		
		char sDescription[STORE_MAX_DESCRIPTION_LENGTH];
		Store_GetItemDescription(ids[item], sDescription, sizeof(sDescription));
		
		char sDisplay[4 + sizeof(sDisplayName) + sizeof(sDescription)+ 6];
		Format(sDisplay, sizeof(sDisplay), "%s", sDisplayName);
		
		if (itemCount[item] > 1)
		{
			Format(sDisplay, sizeof(sDisplay), "%s (%d)", sDisplay, itemCount[item]);
		}
		
		Format(sDisplay, sizeof(sDisplay), "%s - %d %s", sDisplay, RoundToZero(Store_GetItemPrice(ids[item]) * g_refundPricePercentage), g_currencyName);
		
		if (g_showMenuItemDescriptions && strlen(sDisplay) != 0)
		{
			Format(sDisplay, sizeof(sDisplay), "%s\n%s", sDisplay, sDescription);
		}
		
		char sItem[12];
		IntToString(ids[item], sItem, sizeof(sItem));
		
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

public int RefundCategoryMenuSelectHandle(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
			{
				char sMenuItem[64];
				GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem));
				
				switch (g_confirmItemRefund)
				{
					case true: DisplayConfirmationMenu(client, StringToInt(sMenuItem));
					case false: Store_RemoveUserItem(GetSteamAccountID(client), StringToInt(sMenuItem), OnRemoveUserItemComplete, GetClientUserId(client));
				}
			}
		case MenuAction_Cancel: OpenRefundMenu(client);
		case MenuAction_End: CloseHandle(menu);
	}
}

void DisplayConfirmationMenu(int client, int itemId)
{
	char displayName[64];
	Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));

	Handle menu = CreateMenu(ConfirmationMenuSelectHandle);
	SetMenuTitle(menu, "%T", "Item Refund Confirmation", client, displayName, RoundToZero(Store_GetItemPrice(itemId) * g_refundPricePercentage), g_currencyName);

	char value[8];
	IntToString(itemId, value, sizeof(value));

	AddMenuItem(menu, value, "Yes");
	AddMenuItem(menu, "no", "No");

	SetMenuExitButton(menu, false);
	DisplayMenu(menu, client, 0);  
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
					OpenRefundMenu(client);
				}
				else
				{
					Store_RemoveUserItem(GetSteamAccountID(client), StringToInt(sMenuItem), OnRemoveUserItemComplete, GetClientUserId(client));
				}
			}
		case MenuAction_DisplayItem:
			{
				char sDisplay[64];
				GetMenuItem(menu, slot, "", 0, _, sDisplay, sizeof(sDisplay));
				
				char buffer[255];
				Format(buffer, sizeof(buffer), "%T", sDisplay, client);
				
				return view_as<int>RedrawMenuItem(buffer);
			}
		case MenuAction_Cancel: OpenRefundMenu(client);
		case MenuAction_End: CloseHandle(menu);
	}

	return false;
}

public void OnRemoveUserItemComplete(int accountId, int itemId, any data)
{
	int client = GetClientOfUserId(data);

	if (!client)
	{
		return;
	}
	
	int credits = RoundToZero(Store_GetItemPrice(itemId) * g_refundPricePercentage);

	Handle hPack = CreateDataPack();
	WritePackCell(hPack, GetClientUserId(client));
	WritePackCell(hPack, itemId);

	Store_GiveCredits(accountId, credits, OnGiveCreditsComplete, hPack);
}

public void OnGiveCreditsComplete(int accountId, int credits, any hPack)
{
	ResetPack(hPack);

	int client = GetClientOfUserId(ReadPackCell(hPack));
	int itemId = ReadPackCell(hPack);

	CloseHandle(hPack);
	
	if (!client || !IsClientInGame(client))
	{
		return;
	}
	
	char displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
	Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
	CPrintToChat(client, "%t%t", "Store Tag Colored", "Refund Message", displayName, credits, g_currencyName);

	OpenRefundMenu(client);
}