#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <store>
#include <chat-processor>
#include <smjansson>
//#include <multicolors>

enum Title
{
	String:TitleName[STORE_MAX_NAME_LENGTH],
	String:TitleText[64]
}
enum NameColor
{
	String:NameColorName[STORE_MAX_NAME_LENGTH],
	String:NameColorText[64]
}
enum ChatColor
{
	String:ChatColorName[STORE_MAX_NAME_LENGTH],
	String:ChatColorText[64]
}

int g_titles[1024][Title];
int g_namecolors[1024][NameColor];
int g_chatcolors[1024][ChatColor];

int g_titleCount = 0;
int g_namecolorCount = 0;
int g_chatcolorCount = 0;

int g_clientTitles[MAXPLAYERS + 1] = { -1, ... };
int g_clientNameColors[MAXPLAYERS+1] = { -1, ... };
int g_clientChatColors[MAXPLAYERS+1] = { -1, ... };

StringMap g_titlesNameIndex, g_namecolorsNameIndex, g_chatcolorsNameIndex;

bool g_databaseInitialized = false;

public Plugin myinfo = {
	name        = "[Store] Chat",
	author      = "Panduh",
	description = "A combination of Titles, Name Colors, and Chat Colors for [Store]",
	version     = "1.1.0",
	url         = "http://forums.alliedmodders.com/"
};

/**
 * Plugin is loading.
 */
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("store.phrases");
	
	if (LibraryExists("store-inventory"))
	{
		Store_RegisterItemType("title", OnTitleLoad, OnTitleLoadItem);
		Store_RegisterItemType("namecolor", OnNameEquip, OnLoadNameItem);
		Store_RegisterItemType("chatcolor", OnChatEquip, OnLoadChatItem);
	}
}

/** 
 * Called when a new API library is loaded.
 */
public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "store-inventory"))
	{
		Store_RegisterItemType("title", OnTitleLoad, OnTitleLoadItem);
		Store_RegisterItemType("namecolor", OnNameEquip, OnLoadNameItem);
		Store_RegisterItemType("chatcolor", OnChatEquip, OnLoadChatItem);
	}	
}

public void Store_OnDatabaseInitialized()
{
	g_databaseInitialized = true;
}

public void OnClientPostAdminCheck(int client)
{
	if (!g_databaseInitialized || !IsValidClient(client))
		return;

	g_clientTitles[client] = -1;
	g_clientNameColors[client] = -1;
	g_clientChatColors[client] = -1;
	
	int accountId = GetSteamAccountID(client);
	if (accountId == 0) return;
	
	int clientLoadout = Store_GetClientLoadout(client);
	int clientSerial = GetClientSerial(client);

	Store_GetEquippedItemsByType(accountId, "title", clientLoadout, OnGetPlayerTitle, clientSerial);
	Store_GetEquippedItemsByType(accountId, "namecolor", clientLoadout, OnGetPlayerNameColor, clientSerial);
	Store_GetEquippedItemsByType(accountId, "chatcolor", clientLoadout, OnGetPlayerChatColor, clientSerial);
}

public void Store_OnClientLoadoutChanged(int client)
{
	g_clientTitles[client] = -1;
	g_clientNameColors[client] = -1;
	g_clientChatColors[client] = -1;
	
	int accountId = GetSteamAccountID(client);
	if (accountId == 0) return;
	
	int clientLoadout = Store_GetClientLoadout(client);
	int clientSerial = GetClientSerial(client);
	
	Store_GetEquippedItemsByType(accountId, "title", clientLoadout, OnGetPlayerTitle, clientSerial);
	Store_GetEquippedItemsByType(accountId, "namecolor", clientLoadout, OnGetPlayerNameColor, clientSerial);
	Store_GetEquippedItemsByType(accountId, "chatcolor", clientLoadout, OnGetPlayerChatColor, clientSerial);
}

public void Store_OnReloadItems() 
{
	if (g_titlesNameIndex != null)
		delete g_titlesNameIndex;
		
	g_titlesNameIndex = new StringMap();
	g_titleCount = 0;

	if (g_namecolorsNameIndex != null)
		delete g_namecolorsNameIndex;
		
	g_namecolorsNameIndex = new StringMap();
	g_namecolorCount = 0;
	
	if (g_chatcolorsNameIndex != null)
		 delete g_chatcolorsNameIndex;
		
	g_chatcolorsNameIndex = new StringMap();
	g_chatcolorCount = 0;
}

public void OnGetPlayerTitle(int[] titles, int count, any serial)
{
	int client = GetClientFromSerial(serial);
	
	if (client == 0)
		return;
		
	for (int index = 0; index < count; index++)
	{
		char itemName[STORE_MAX_NAME_LENGTH];
		Store_GetItemName(titles[index], itemName, sizeof(itemName));
		
		int title = -1;
		if (!g_titlesNameIndex.GetValue(itemName, title))
		{
			PrintToChat(client, "%s%t", STORE_PREFIX, "No item attributes");
			continue;
		}
		
		g_clientTitles[client] = title;
		break;
	}
}

public void OnGetPlayerNameColor(int[] titles, int count, any serial)
{
	int client = GetClientFromSerial(serial);
	
	if (client == 0)
		return;
		
	for (int index = 0; index < count; index++)
	{
		char itemName[STORE_MAX_NAME_LENGTH];
		Store_GetItemName(titles[index], itemName, sizeof(itemName));
		
		int namecolor = -1;
		if (!g_namecolorsNameIndex.GetValue(itemName, namecolor))
		{
			PrintToChat(client, "%s%t", STORE_PREFIX, "No item attributes");
			continue;
		}
		
		g_clientNameColors[client] = namecolor;
		break;
	}
}

public void OnGetPlayerChatColor(int[] titles, int count, any serial)
{
	int client = GetClientFromSerial(serial);
	
	if (client == 0)
		return;
		
	for (int index = 0; index < count; index++)
	{
		char itemName[STORE_MAX_NAME_LENGTH];
		Store_GetItemName(titles[index], itemName, sizeof(itemName));
		
		int chatcolor = -1;
		if (!g_chatcolorsNameIndex.GetValue(itemName, chatcolor))
		{
			PrintToChat(client, "%s%t", STORE_PREFIX, "No item attributes");
			continue;
		}
		
		g_clientChatColors[client] = chatcolor;
		break;
	}
}

public void OnTitleLoadItem(const char[] itemName, const char[] attrs)
{
	strcopy(g_titles[g_titleCount][TitleName], STORE_MAX_NAME_LENGTH, itemName);
		
	g_titlesNameIndex.SetValue(g_titles[g_titleCount][TitleName], g_titleCount);
	
	Handle json = json_load(attrs);	

	if (IsSource2009())
	{
		json_object_get_string(json, "colorful_text", g_titles[g_titleCount][TitleText], 64);
		CReplaceColorCodes(g_titles[g_titleCount][TitleText]);
	}
	/*
	else
	{
		json_object_get_string(json, "text", g_titles[g_titleCount][TitleText], 64);
		CFormat(g_titles[g_titleCount][TitleText], 64);
	}
	*/

	delete json;

	g_titleCount++;
}

public void OnLoadNameItem(const char[] itemName, const char[] attrs)
{
	strcopy(g_namecolors[g_namecolorCount][NameColorName], STORE_MAX_NAME_LENGTH, itemName);
		
	g_namecolorsNameIndex.SetValue(g_namecolors[g_namecolorCount][NameColorName], g_namecolorCount);
	
	Handle json = json_load(attrs);	
	
	if (IsSource2009())
	{
		json_object_get_string(json, "color", g_namecolors[g_namecolorCount][NameColorText], 64);
		CReplaceColorCodes(g_namecolors[g_namecolorCount][NameColorText]);
	}
	/*
	else
	{
		json_object_get_string(json, "text", g_namecolors[g_namecolorCount][NameColorText], 64);
		CFormat(g_namecolors[g_namecolorCount][NameColorText], 64);
	}
	*/

	delete json;

	g_namecolorCount++;
}

public void OnLoadChatItem(const char[] itemName, const char[] attrs)
{
	strcopy(g_chatcolors[g_chatcolorCount][ChatColorName], STORE_MAX_NAME_LENGTH, itemName);
		
	g_chatcolorsNameIndex.SetValue(g_chatcolors[g_chatcolorCount][ChatColorName], g_chatcolorCount);
	
	Handle json = json_load(attrs);	
	
	if (IsSource2009())
	{
		json_object_get_string(json, "color", g_chatcolors[g_chatcolorCount][ChatColorText], 64);
		CReplaceColorCodes(g_chatcolors[g_chatcolorCount][ChatColorText]);
	}

	delete json;

	g_chatcolorCount++;
}

public Store_ItemUseAction OnTitleLoad(int client, int itemId, bool equipped)
{
	char name[32];
	Store_GetItemName(itemId, name, sizeof(name));

	if (equipped)
	{
		g_clientTitles[client] = -1;
		
		char displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "%s%t", STORE_PREFIX, "Unequipped item", displayName);

		return Store_UnequipItem;
	}
	else
	{
		int title = -1;
		if (!g_titlesNameIndex.GetValue(name, title))
		{
			PrintToChat(client, "%s%t", STORE_PREFIX, "No item attributes");
			return Store_DoNothing;
		}
		
		g_clientTitles[client] = title;
		
		char displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "%s%t", STORE_PREFIX, "Equipped item", displayName);

		return Store_EquipItem;
	}
}

public Store_ItemUseAction OnNameEquip(int client, int itemId, bool equipped)
{
	char name[32];
	Store_GetItemName(itemId, name, sizeof(name));

	if (equipped)
	{
		g_clientNameColors[client] = -1;
		
		char displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "%s%t", STORE_PREFIX, "Unequipped item", displayName);

		return Store_UnequipItem;
	}
	else
	{
		int namecolor = -1;
		if (!g_namecolorsNameIndex.GetValue(name, namecolor))
		{
			PrintToChat(client, "%s%t", STORE_PREFIX, "No item attributes");
			return Store_DoNothing;
		}
		
		g_clientNameColors[client] = namecolor;
		
		char displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "%s%t", STORE_PREFIX, "Equipped item", displayName);

		return Store_EquipItem;
	}
}

public Store_ItemUseAction OnChatEquip(int client, int itemId, bool equipped)
{
	char name[32];
	Store_GetItemName(itemId, name, sizeof(name));

	if (equipped)
	{
		g_clientChatColors[client] = -1;
		
		char displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "%s%t", STORE_PREFIX, "Unequipped item", displayName);

		return Store_UnequipItem;
	}
	else
	{
		int chatcolor = -1;
		if (!g_chatcolorsNameIndex.GetValue(name, chatcolor))
		{
			PrintToChat(client, "%s%t", STORE_PREFIX, "No item attributes");
			return Store_DoNothing;
		}
		
		g_clientChatColors[client] = chatcolor;
		
		char displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "%s%t", STORE_PREFIX, "Equipped item", displayName);

		return Store_EquipItem;
	}
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
	bool bChanged;
	char sTitle[64];
	if (g_clientTitles[author] != -1)
	{
		bChanged = true;
		Format(sTitle, sizeof(sTitle), "%s \x03", g_titles[g_clientTitles[author]][TitleText]);		
	}
	else
		strcopy(sTitle, sizeof(sTitle), "");

	if (g_clientNameColors[author] != -1)
	{
		if(strlen(g_namecolors[g_clientNameColors[author]][NameColorText]) == 6)
		{
			bChanged = true;
			Format(name, MAXLENGTH_NAME, "%s\x07%s%s", sTitle, g_namecolors[g_clientNameColors[author]][NameColorText], name);
		}	
		else if(strlen(g_namecolors[g_clientNameColors[author]][NameColorText]) == 8)
		{
			bChanged = true;
			Format(name, MAXLENGTH_NAME, "%s\x08%s%s", sTitle, g_namecolors[g_clientNameColors[author]][NameColorText], name);
		}		
	}
	else if (g_clientTitles[author] != -1)
	{
		bChanged = true;
		Format(name, MAXLENGTH_NAME, "%s%s", sTitle, name);
	}
	
	if (g_clientChatColors[author] != -1)
	{
		int iMax = MAXLENGTH_MESSAGE - strlen(name) - 5;

		if(strlen(g_chatcolors[g_clientChatColors[author]][ChatColorText]) == 6)
		{
			bChanged = true;
			Format(message, iMax, "\x07%s%s", g_chatcolors[g_clientChatColors[author]][ChatColorText], message);
		}
		else if(strlen(g_chatcolors[g_clientChatColors[author]][ChatColorText]) == 8)
		{
			bChanged = true;
			Format(message, iMax, "\x08%s%s", g_chatcolors[g_clientChatColors[author]][ChatColorText], message);
		}
	}

	if(bChanged)
		return Plugin_Changed;
	
	return Plugin_Continue;
}

stock bool IsSource2009()
{
	return (SOURCE_SDK_CSS <= GuessSDKVersion() < SOURCE_SDK_LEFT4DEAD);
	
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