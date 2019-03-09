#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <multicolors>

#include <sdkhooks>
#include <adminmenu>
#include <smartdm>

//Store Includes
#include <store/store-core>
#include <store/store-loadouts>
#include <store/store-logging>

#pragma newdecls required

#define PLUGIN_NAME "[Store] Gifting Module"
#define PLUGIN_DESCRIPTION "Gifting module for the Sourcemod Store."
#define PLUGIN_VERSION_CONVAR "store_gifting_version"

#define MAX_CREDIT_CHOICES 100

enum Present
{
	Present_Owner,
	String:Present_Data[64]
}

enum GiftAction
{
	GiftAction_Send,
	GiftAction_Drop
}

enum GiftRequest
{
	bool:GiftRequestActive,
	GiftRequestSender,
	GiftType:GiftRequestType,
	GiftRequestValue
}

int g_giftRequests[MAXPLAYERS + 1][GiftRequest];

enum GiftType
{
	GiftType_Credits,
	GiftType_Item
}

//Config Variables
stock bool g_ShowMenuDescriptions;
bool g_showMenuItemDescriptions;
int g_creditChoices[MAX_CREDIT_CHOICES];
bool g_drop_enabled = false;
char g_itemModel[PLATFORM_MAX_PATH];
char g_creditsModel[PLATFORM_MAX_PATH];
int g_itemMenuOrder;

int g_spawnedPresents[2048][Present];
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

	CreateConVar(PLUGIN_VERSION_CONVAR, STORE_VERSION, PLUGIN_NAME, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);

	LoadConfig("Gifting", "configs/store/gifting.cfg");
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

	g_ShowMenuDescriptions = view_as<bool>(KvGetNum(hKV, "show_menu_descriptions", 1));
	g_showMenuItemDescriptions = view_as<bool>(KvGetNum(hKV, "show_items_menu_descriptions", 1));

	char creditChoicesString[255];
	KvGetString(hKV, "credits_choices", creditChoicesString, sizeof(creditChoicesString), "10 20 30 50 70 90 100 120 150 180 200 250 300 400 500 600 700 800 900 1000 1200 1400 1500 1600 1800 2000 3000 4000 5000 6000 7000 8000 9000 10000");

	char creditChoices[MAX_CREDIT_CHOICES][10];
	int choices = ExplodeString(creditChoicesString, " ", creditChoices, sizeof(creditChoices), sizeof(creditChoices[]));

	for (int i = 0; i < choices; i++)
	{
		g_creditChoices[i] = StringToInt(creditChoices[i]);
	}

	g_drop_enabled = view_as<bool>(KvGetNum(hKV, "drop_enabled", 0));

	if (g_drop_enabled)
	{
		KvGetString(hKV, "itemModel", g_itemModel, sizeof(g_itemModel));
		KvGetString(hKV, "creditsModel", g_creditsModel, sizeof(g_creditsModel));

		if (strlen(g_itemModel) == 0 || !FileExists(g_itemModel, true))
		{
			switch (GetEngineVersion())
			{
				case Engine_CSS:strcopy(g_itemModel, sizeof(g_itemModel), "models/items/cs_gift.mdl");
				case Engine_TF2:strcopy(g_itemModel, sizeof(g_itemModel), "models/items/tf_gift.mdl");
				case Engine_DODS:strcopy(g_itemModel, sizeof(g_itemModel), "models/items/dod_gift.mdl");
				default:strcopy(g_itemModel, sizeof(g_itemModel), "models/items/tf_gift.mdl");
			}
		}

		if (strlen(g_creditsModel) == 0 || !FileExists(g_creditsModel, true))
		{
			strcopy(g_creditsModel, sizeof(g_creditsModel), g_itemModel);
		}
	}

	if (KvJumpToKey(hKV, "Commands"))
	{
		char sBuffer[256];
		KvGetString(hKV, "gifting_commands", sBuffer, sizeof(sBuffer), "!gift /gift");
		Store_RegisterChatCommands(sBuffer, ChatCommand_Gift);

		KvGetString(hKV, "accept_commands", sBuffer, sizeof(sBuffer), "!accept /accept");
		Store_RegisterChatCommands(sBuffer, ChatCommand_Accept);

		KvGetString(hKV, "cancel_commands", sBuffer, sizeof(sBuffer), "!cancel /cancel");
		Store_RegisterChatCommands(sBuffer, ChatCommand_Cancel);

		if (g_drop_enabled)
		{
			KvGetString(hKV, "drop_commands", sBuffer, sizeof(sBuffer), "!drop /drop");
			Store_RegisterChatCommands(sBuffer, ChatCommand_Drop);
		}
	}

	g_itemMenuOrder = KvGetNum(hKV, "menu_item_order", 5);

	CloseHandle(hKV);

	Store_AddMainMenuItem("Gift", "Gift Description", _, OnMainMenuGiftClick, g_itemMenuOrder);

	Store_LogInformational("Store Config '%s' Loaded: %s", sName, sFile);
}

public void OnMapStart()
{
	if (g_drop_enabled)
	{
		PrecacheModel(g_itemModel, true);
		Downloader_AddFileToDownloadsTable(g_itemModel);

		if (!StrEqual(g_itemModel, g_creditsModel))
		{
			PrecacheModel(g_creditsModel, true);
			Downloader_AddFileToDownloadsTable(g_creditsModel);
		}
	}
}

public void DropGetCreditsCallback(int credits, any hPack)
{
	ResetPack(hPack);

	int client = GetClientOfUserId(ReadPackCell(hPack));
	int needed = ReadPackCell(hPack);

	CloseHandle(hPack);

	if (credits >= needed)
	{
		Store_RemoveCredits(GetSteamAccountID(client), needed, DropGiveCreditsCallback, GetClientOfUserId(client));
	}
	else
	{
		CPrintToChat(client, "%t%t", "Store Tag Colored", "Not enough credits", g_currencyName);
	}
}

public void DropGiveCreditsCallback(int accountId, int credits, bool bIsNegative, any data)
{
	int client = GetClientOfUserId(data);

	char sValue[32];
	Format(sValue, sizeof(sValue), "credits,%d", credits);

	CPrintToChat(client, "%t%t", "Store Tag Colored", "Gift Credits Dropped", credits, g_currencyName);

	int present = SpawnPresent(client, g_creditsModel);

	if (present != -1)
	{
		strcopy(g_spawnedPresents[present][Present_Data], 64, sValue);
		g_spawnedPresents[present][Present_Owner] = client;
	}
}

public void OnMainMenuGiftClick(int client, const char[] value)
{
	OpenGiftingMenu(client);
}

public void OnClientDisconnect(int client)
{
	g_giftRequests[client][GiftRequestActive] = false;
}

public void ChatCommand_Gift(int client)
{
	OpenGiftingMenu(client);
}

public void ChatCommand_Accept(int client)
{
	if (!g_giftRequests[client][GiftRequestActive])
	{
		return;
	}

	if (g_giftRequests[client][GiftRequestType] == GiftType_Credits)
	{
		GiftCredits(g_giftRequests[client][GiftRequestSender], client, g_giftRequests[client][GiftRequestValue]);
	}
	else
	{
		GiftItem(g_giftRequests[client][GiftRequestSender], client, g_giftRequests[client][GiftRequestValue]);
	}

	g_giftRequests[client][GiftRequestActive] = false;
}

public void ChatCommand_Cancel(int client)
{
	if (g_giftRequests[client][GiftRequestActive])
	{
		g_giftRequests[client][GiftRequestActive] = false;
		CPrintToChat(client, "%t%t", "Store Tag Colored", "Gift Cancel");
	}
}

public void ChatCommand_Drop(int client, const char[] command, const char[] args)
{
	if (strlen(args) <= 0)
	{
		if (command[0] == 0x2F)
		{
			CPrintToChat(client, "%tUsage: %s <%s>", "Store Tag Colored", command, g_currencyName);
		}
		else
		{
			CPrintToChatAll("%tUsage: %s <%s>", "Store Tag Colored", command, g_currencyName);
		}

		return;
	}

	int credits = StringToInt(args);

	if (credits < 1)
	{
		if (command[0] == 0x2F)
		{
			CPrintToChat(client, "%t%d is not a valid amount!", "Store Tag Colored", credits);
		}
		else
		{
			CPrintToChatAll("%t%d is not a valid amount!", "Store Tag Colored", credits);
		}

		return;
	}

	Handle hPack = CreateDataPack();
	WritePackCell(hPack, GetClientUserId(client));
	WritePackCell(hPack, credits);

	Store_GetCredits(GetSteamAccountID(client), DropGetCreditsCallback, hPack);
}

void OpenGiftingMenu(int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
		{
			continue;
		}

		if (g_giftRequests[i][GiftRequestActive] && g_giftRequests[i][GiftRequestSender] == client)
		{
			CPrintToChat(client, "%t%t", "Store Tag Colored", "Gift Active Session");
			return;
		}
	}

	Handle menu = CreateMenu(GiftTypeMenuSelectHandle);
	SetMenuTitle(menu, "%T%T\n \n", "Store Menu Title", client, "Store Menu Gifting Menu", client);

	char item[32];
	Format(item, sizeof(item), "%T", "Item", client);

	AddMenuItem(menu, "credits", g_currencyName);
	AddMenuItem(menu, "item", item);

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int GiftTypeMenuSelectHandle(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[12];
			GetMenuItem(menu, slot, sInfo, sizeof(sInfo));

			bool bType = StrEqual(sInfo, "credits");

			switch (g_drop_enabled)
			{
				case true:OpenChooseActionMenu(client, bType ? GiftType_Credits : GiftType_Item);
				case false:OpenChoosePlayerMenu(client, bType ? GiftType_Credits : GiftType_Item);
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

void OpenChooseActionMenu(int client, GiftType giftType)
{
	Handle menu = CreateMenu(ChooseActionMenuSelectHandle);
	SetMenuTitle(menu, "%T", "Gift Delivery Method", client);

	char s_giftType[32];
	switch (giftType)
	{
		case GiftType_Credits:strcopy(s_giftType, sizeof(s_giftType), "credits");
		case GiftType_Item:strcopy(s_giftType, sizeof(s_giftType), "item");
	}

	char send[32]; char drop[32];
	Format(send, sizeof(send), "%s,send", s_giftType);
	Format(drop, sizeof(drop), "%s,drop", s_giftType);

	char methodSend[32]; char methodDrop[32];
	Format(methodSend, sizeof(methodSend), "%T", "Gift Method Send", client);
	Format(methodDrop, sizeof(methodDrop), "%T", "Gift Method Drop", client);

	AddMenuItem(menu, send, methodSend);
	AddMenuItem(menu, drop, methodDrop);

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int ChooseActionMenuSelectHandle(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char values[32];
			GetMenuItem(menu, slot, values, sizeof(values));

			char brokenValues[2][32];
			ExplodeString(values, ",", brokenValues, sizeof(brokenValues), sizeof(brokenValues[]));

			GiftType giftType;

			if (StrEqual(brokenValues[0], "credits"))
			{
				giftType = GiftType_Credits;
			}
			else if (StrEqual(brokenValues[0], "item"))
			{
				giftType = GiftType_Item;
			}

			if (StrEqual(brokenValues[1], "send"))
			{
				OpenChoosePlayerMenu(client, giftType);
			}
			else if (StrEqual(brokenValues[1], "drop"))
			{
				switch (giftType)
				{
					case GiftType_Item:OpenSelectItemMenu(client, GiftAction_Drop, -1);
					case GiftType_Credits:OpenSelectCreditsMenu(client, GiftAction_Drop, -1);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (slot == MenuCancel_ExitBack)
			{
				OpenGiftingMenu(client);
			}
		}
		case MenuAction_End:CloseHandle(menu);
	}
}

void OpenChoosePlayerMenu(int client, GiftType giftType)
{
	Store_DisplayClientsMenu(client, giftType == GiftType_Credits ? ChoosePlayerCreditsMenuSelectHandle : ChoosePlayerItemMenuSelectHandle);
}

public int ChoosePlayerCreditsMenuSelectHandle(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMenuItem[64];
			GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem));
			OpenSelectCreditsMenu(client, GiftAction_Send, GetClientOfUserId(StringToInt(sMenuItem)));
		}
		case MenuAction_Cancel:
		{
			if (slot == MenuCancel_ExitBack)
			{
				OpenGiftingMenu(client);
			}
		}
		case MenuAction_End:CloseHandle(menu);
	}
}

public int ChoosePlayerItemMenuSelectHandle(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMenuItem[64];
			GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem));
			OpenSelectItemMenu(client, GiftAction_Send, GetClientOfUserId(StringToInt(sMenuItem)));
		}
		case MenuAction_Cancel:
		{
			if (slot == MenuCancel_ExitBack)
			{
				OpenGiftingMenu(client);
			}
		}
		case MenuAction_End:CloseHandle(menu);
	}
}

void OpenSelectCreditsMenu(int client, GiftAction giftAction, int giftTo = -1)
{
	if (giftAction == GiftAction_Send && giftTo == -1)
	{
		return;
	}

	Handle menu = CreateMenu(CreditsMenuSelectItem);

	SetMenuTitle(menu, "Select %s:", g_currencyName);

	for (int i = 0; i < sizeof(g_creditChoices); i++)
	{
		if (g_creditChoices[i] == 0)
		{
			continue;
		}

		char text[48];
		IntToString(g_creditChoices[i], text, sizeof(text));

		char value[32];
		Format(value, sizeof(value), "%d,%d,%d", giftAction, giftTo, g_creditChoices[i]);

		AddMenuItem(menu, value, text);
	}

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int CreditsMenuSelectItem(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMenuItem[64];
			GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem));

			char values[3][16];
			ExplodeString(sMenuItem, ",", values, sizeof(values), sizeof(values[]));

			int giftAction = StringToInt(values[0]);
			int giftTo = StringToInt(values[1]);
			int credits = StringToInt(values[2]);

			Handle hPack = CreateDataPack();
			WritePackCell(hPack, GetClientUserId(client));
			WritePackCell(hPack, giftAction);
			WritePackCell(hPack, giftTo);
			WritePackCell(hPack, credits);

			Store_GetCredits(GetSteamAccountID(client), GetCreditsCallback, hPack);
		}
		case MenuAction_Cancel:
		{
			if (slot == MenuCancel_ExitBack)
			{
				OpenGiftingMenu(client);
			}
		}
		case MenuAction_End:CloseHandle(menu);
	}
}

public void GetCreditsCallback(int credits, any hPack)
{
	ResetPack(hPack);

	int client = GetClientOfUserId(ReadPackCell(hPack));
	GiftAction giftAction = view_as<GiftAction>(ReadPackCell(hPack));
	int giftTo = ReadPackCell(hPack);
	int giftCredits = ReadPackCell(hPack);

	CloseHandle(hPack);

	if (giftCredits > credits)
	{
		CPrintToChat(client, "%t%t", "Store Tag Colored", "Not enough credits", g_currencyName);
	}
	else
	{
		OpenGiveCreditsConfirmMenu(client, giftAction, giftTo, giftCredits);
	}
}

void OpenGiveCreditsConfirmMenu(int client, GiftAction giftAction, int giftTo, int credits)
{
	Handle menu = CreateMenu(CreditsConfirmMenuSelectItem);
	char sItem[32];

	switch (giftAction)
	{
		case GiftAction_Send:
		{
			char sName[MAX_NAME_LENGTH];
			GetClientName(giftTo, sName, sizeof(sName));

			SetMenuTitle(menu, "%T", "Gift Credit Confirmation", client, sName, credits, g_currencyName);
			Format(sItem, sizeof(sItem), "%d,%d,%d", giftAction, giftTo, credits);
		}
		case GiftAction_Drop:
		{
			SetMenuTitle(menu, "%T", "Drop Credit Confirmation", client, credits, g_currencyName);
			Format(sItem, sizeof(sItem), "%d,%d,%d", giftAction, giftTo, credits);
		}
	}

	AddMenuItem(menu, sItem, "Yes");
	AddMenuItem(menu, "", "No");

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int CreditsConfirmMenuSelectItem(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMenuItem[64];
			GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem));

			if (!StrEqual(sMenuItem, ""))
			{
				char values[3][16];
				ExplodeString(sMenuItem, ",", values, sizeof(values), sizeof(values[]));

				GiftAction giftAction = view_as<GiftAction>(StringToInt(values[0]));
				int giftTo = StringToInt(values[1]);
				int credits = StringToInt(values[2]);

				switch (giftAction)
				{
					case GiftAction_Send:AskForPermission(client, giftTo, GiftType_Credits, credits);
					case GiftAction_Drop:
					{
						Handle hPack = CreateDataPack();
						WritePackCell(hPack, GetClientUserId(client));
						WritePackCell(hPack, credits);

						Store_GetCredits(GetSteamAccountID(client), DropGetCreditsCallback, hPack);
					}
				}
			}
		}
		case MenuAction_DisplayItem:
		{
			char sDisplay[64];
			GetMenuItem(menu, slot, "", 0, _, sDisplay, sizeof(sDisplay));

			char buffer[255];
			Format(buffer, sizeof(buffer), "%T", sDisplay, client);

			return RedrawMenuItem(buffer);
		}
		case MenuAction_Cancel:
		{
			if (slot == MenuCancel_ExitBack)
			{
				OpenChoosePlayerMenu(client, GiftType_Credits);
			}
		}
		case MenuAction_End:CloseHandle(menu);
	}

	return false;
}

void OpenSelectItemMenu(int client, GiftAction giftAction, int giftTo = -1)
{
	Handle hPack = CreateDataPack();
	WritePackCell(hPack, GetClientUserId(client));
	WritePackCell(hPack, giftAction);
	WritePackCell(hPack, giftTo);

	Handle filter = CreateTrie();
	SetTrieValue(filter, "is_tradeable", 1);

	Store_GetUserItems(filter, GetSteamAccountID(client), Store_GetClientLoadout(client), GetUserItemsCallback, hPack);
}

public void GetUserItemsCallback(int accountId, int[] ids, bool[] equipped, int[] itemCount, int count, int loadoutId, any hPack)
{
	ResetPack(hPack);

	int client = GetClientOfUserId(ReadPackCell(hPack));
	GiftAction giftAction = view_as<GiftAction>(ReadPackCell(hPack));
	int giftTo = ReadPackCell(hPack);

	CloseHandle(hPack);

	if (!client || !IsClientInGame(client))
	{
		return;
	}

	if (count == 0)
	{
		CPrintToChat(client, "%t%t", "Store Tag Colored", "No items");
		return;
	}

	Handle menu = CreateMenu(ItemMenuSelectHandle);
	SetMenuTitle(menu, "Select item:\n \n");

	for (int i = 0; i < count; i++)
	{
		char sDisplayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(ids[i], sDisplayName, sizeof(sDisplayName));

		char sDescription[STORE_MAX_DESCRIPTION_LENGTH];
		Store_GetItemDescription(ids[i], sDescription, sizeof(sDescription));

		char sDisplay[4 + sizeof(sDisplayName) + sizeof(sDescription) + 6];
		Format(sDisplay, sizeof(sDisplay), "%s", sDisplayName);

		if (itemCount[i] > 1)
		{
			Format(sDisplay, sizeof(sDisplay), "%s (%d)", sDisplay, itemCount[i]);
		}

		if (g_showMenuItemDescriptions)
		{
			Format(sDisplay, sizeof(sDisplay), "%s\n%s", sDisplay, sDescription);
		}

		char sItem[32];
		Format(sItem, sizeof(sItem), "%d,%d,%d", giftAction, giftTo, ids[i]);

		AddMenuItem(menu, sItem, sDisplay);
	}

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int ItemMenuSelectHandle(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMenuItem[64];
			GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem));
			OpenGiveItemConfirmMenu(client, sMenuItem);
		}
		case MenuAction_Cancel:OpenGiftingMenu(client);
		case MenuAction_End:CloseHandle(menu);
	}
}

void OpenGiveItemConfirmMenu(int client, const char[] sValue)
{
	char sValues[3][16];
	ExplodeString(sValue, ",", sValues, sizeof(sValues), sizeof(sValues[]));

	GiftAction giftAction = view_as<GiftAction>(StringToInt(sValues[0]));
	int giftTo = StringToInt(sValues[1]);
	int itemId = StringToInt(sValues[2]);

	char sName[MAX_NAME_LENGTH];
	GetClientName(giftTo, sName, sizeof(sName));

	char sDisplayName[STORE_MAX_DISPLAY_NAME_LENGTH];
	Store_GetItemDisplayName(itemId, sDisplayName, sizeof(sDisplayName));

	Handle menu = CreateMenu(ItemConfirmMenuSelectItem);
	switch (giftAction)
	{
		case GiftAction_Send:SetMenuTitle(menu, "%T", "Gift Item Confirmation", client, sName, sDisplayName);
		case GiftAction_Drop:SetMenuTitle(menu, "%T", "Drop Item Confirmation", client, sDisplayName);
	}

	AddMenuItem(menu, sValue, "Yes");
	AddMenuItem(menu, "", "No");

	SetMenuExitButton(menu, false);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int ItemConfirmMenuSelectItem(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMenuItem[64];
			GetMenuItem(menu, slot, sMenuItem, sizeof(sMenuItem));

			if (strlen(sMenuItem) != 0)
			{
				char values[3][16];
				ExplodeString(sMenuItem, ",", values, sizeof(values), sizeof(values[]));

				GiftAction giftAction = view_as<GiftAction>(StringToInt(values[0]));
				int giftTo = StringToInt(values[1]);
				int itemId = StringToInt(values[2]);

				switch (giftAction)
				{
					case GiftAction_Send:AskForPermission(client, giftTo, GiftType_Item, itemId);
					case GiftAction_Drop:
					{
						int present = SpawnPresent(client, g_itemModel);

						if (IsValidEntity(present))
						{
							char data[32];
							Format(data, sizeof(data), "item,%d", itemId);

							strcopy(g_spawnedPresents[present][Present_Data], 64, data);
							g_spawnedPresents[present][Present_Owner] = client;

							Store_RemoveUserItem(GetSteamAccountID(client), itemId, DropItemCallback, client);
						}
					}
				}
			}
		}
		case MenuAction_DisplayItem:
		{
			char sDisplay[64];
			GetMenuItem(menu, slot, "", 0, _, sDisplay, sizeof(sDisplay));

			char buffer[255];
			Format(buffer, sizeof(buffer), "%T", sDisplay, client);

			return RedrawMenuItem(buffer);
		}
		case MenuAction_Cancel:
		{
			if (slot == MenuCancel_ExitBack)
			{
				OpenGiftingMenu(client);
			}
		}
		case MenuAction_End:CloseHandle(menu);
	}

	return false;
}

public void DropItemCallback(int accountId, int itemId, any client)
{
	char displayName[64];
	Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
	CPrintToChat(client, "%t%t", "Store Tag Colored", "Gift Item Dropped", displayName);
}

void AskForPermission(int client, int giftTo, GiftType giftType, int value)
{
	char sName[MAX_NAME_LENGTH];

	GetClientName(giftTo, sName, sizeof(sName));
	CPrintToChatEx(client, giftTo, "%t%t", "Store Tag Colored", "Gift Waiting to accept", client, sName);

	char what[64];
	switch (giftType)
	{
		case GiftType_Credits:Format(what, sizeof(what), "%d %s", value, g_currencyName);
		case GiftType_Item:Store_GetItemDisplayName(value, what, sizeof(what));
	}

	GetClientName(client, sName, sizeof(sName));
	CPrintToChatEx(giftTo, client, "%t%t", "Store Tag Colored", "Gift Request Accept", client, sName, what);

	g_giftRequests[giftTo][GiftRequestActive] = true;
	g_giftRequests[giftTo][GiftRequestSender] = client;
	g_giftRequests[giftTo][GiftRequestType] = giftType;
	g_giftRequests[giftTo][GiftRequestValue] = value;
}

void GiftCredits(int from, int to, int amount)
{
	Handle hPack = CreateDataPack();
	WritePackCell(hPack, from);
	WritePackCell(hPack, to);

	Store_RemoveCredits(GetSteamAccountID(from), amount, TakeCreditsCallback, hPack);
}

public void TakeCreditsCallback(int accountId, int credits, bool bIsNegative, any hPack)
{
	ResetPack(hPack);

	ReadPackCell(hPack);
	int to = ReadPackCell(hPack);

	Store_GiveCredits(GetSteamAccountID(to), credits, GiveCreditsCallback, hPack);
}

public void GiveCreditsCallback(int accountId, int credits, any hPack)
{
	ResetPack(hPack);

	int from = ReadPackCell(hPack);
	int to = ReadPackCell(hPack);

	CloseHandle(hPack);

	char sName[MAX_NAME_LENGTH];

	GetClientName(to, sName, sizeof(sName));
	CPrintToChatEx(from, to, "%t%t", "Store Tag Colored", "Gift accepted - sender", sName);

	GetClientName(from, sName, sizeof(sName));
	CPrintToChatEx(to, from, "%t%t", "Store Tag Colored", "Gift accepted - receiver", sName);
}

void GiftItem(int from, int to, int itemId)
{
	Handle hPack = CreateDataPack();
	WritePackCell(hPack, from);
	WritePackCell(hPack, to);
	WritePackCell(hPack, itemId);

	Store_RemoveUserItem(GetSteamAccountID(from), itemId, RemoveUserItemCallback, hPack);
}

public void RemoveUserItemCallback(int accountId, int itemId, any hPack)
{
	ResetPack(hPack);

	ReadPackCell(hPack);
	int to = ReadPackCell(hPack);

	Store_GiveItem(GetSteamAccountID(to), itemId, Store_Gift, GiveItemsCallback, hPack);
}

public void GiveItemsCallback(int accountId, any hPack)
{
	ResetPack(hPack);

	int from = ReadPackCell(hPack);
	int to = ReadPackCell(hPack);

	CloseHandle(hPack);

	char sName[MAX_NAME_LENGTH];

	GetClientName(to, sName, sizeof(sName));
	CPrintToChatEx(from, to, "%t%t", "Store Tag Colored", "Gift accepted - sender", sName);

	GetClientName(from, sName, sizeof(sName));
	CPrintToChatEx(to, from, "%t%t", "Store Tag Colored", "Gift accepted - receiver", sName);
}

int SpawnPresent(int owner, const char[] model)
{
	int present = CreateEntityByName("prop_physics_override");

	if (IsValidEntity(present))
	{
		char targetname[100];

		Format(targetname, sizeof(targetname), "gift_%i", present);

		DispatchKeyValue(present, "model", model);
		DispatchKeyValue(present, "physicsmode", "2");
		DispatchKeyValue(present, "massScale", "1.0");
		DispatchKeyValue(present, "targetname", targetname);
		DispatchSpawn(present);

		SetEntProp(present, Prop_Send, "m_usSolidFlags", 8);
		SetEntProp(present, Prop_Send, "m_CollisionGroup", 1);

		float pos[3];
		GetClientAbsOrigin(owner, pos);
		pos[2] += 16;

		TeleportEntity(present, pos, NULL_VECTOR, NULL_VECTOR);

		int rotator = CreateEntityByName("func_rotating");
		DispatchKeyValueVector(rotator, "origin", pos);
		DispatchKeyValue(rotator, "targetname", targetname);
		DispatchKeyValue(rotator, "maxspeed", "200");
		DispatchKeyValue(rotator, "friction", "0");
		DispatchKeyValue(rotator, "dmg", "0");
		DispatchKeyValue(rotator, "solid", "0");
		DispatchKeyValue(rotator, "spawnflags", "64");
		DispatchSpawn(rotator);

		SetVariantString("!activator");
		AcceptEntityInput(present, "SetParent", rotator, rotator);
		AcceptEntityInput(rotator, "Start");

		SetEntPropEnt(present, Prop_Send, "m_hEffectEntity", rotator);

		SDKHook(present, SDKHook_StartTouch, OnStartTouch);
	}

	return present;
}

public void OnStartTouch(int present, int client)
{
	if (!(0 < client <= MaxClients) || g_spawnedPresents[present][Present_Owner] == client)
	{
		return;
	}

	int rotator = GetEntPropEnt(present, Prop_Send, "m_hEffectEntity");

	if (rotator && IsValidEdict(rotator))
	{
		AcceptEntityInput(rotator, "Kill");
	}

	AcceptEntityInput(present, "Kill");

	char values[2][16];
	ExplodeString(g_spawnedPresents[present][Present_Data], ",", values, sizeof(values), sizeof(values[]));

	Handle hPack = CreateDataPack();
	WritePackCell(hPack, client);
	WritePackString(hPack, values[0]);

	if (StrEqual(values[0], "credits"))
	{
		Store_GiveCredits(GetSteamAccountID(client), StringToInt(values[1]), PickupGiveCallback_Credits, hPack);
	}
	else if (StrEqual(values[0], "item"))
	{
		int itemId = StringToInt(values[1]);
		WritePackCell(hPack, itemId);
		Store_GiveItem(GetSteamAccountID(client), itemId, Store_Gift, PickupGiveCallback_Items, hPack);
	}
}

public void PickupGiveCallback_Credits(int accountId, int credits, any hPack)
{
	ResetPack(hPack);

	int client = ReadPackCell(hPack);

	char itemType[32];
	ReadPackString(hPack, itemType, sizeof(itemType));

	if (StrEqual(itemType, "credits"))
	{
		CPrintToChat(client, "%t%t", "Store Tag Colored", "Gift Credits Found", credits, g_currencyName); //Translate
	}
}

public void PickupGiveCallback_Items(int accountId, any hPack)
{
	ResetPack(hPack);

	int client = ReadPackCell(hPack);

	char itemType[32];
	ReadPackString(hPack, itemType, sizeof(itemType));

	int itemId = ReadPackCell(hPack);

	if (StrEqual(itemType, "item"))
	{
		char displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));

		CPrintToChat(client, "%t%t", "Store Tag Colored", "Gift Item Found", displayName); //Translate
	}
}
