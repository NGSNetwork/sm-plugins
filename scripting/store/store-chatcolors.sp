#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <store>
#include <scp>
#include <smjansson>
#include <morecolors>

enum ChatColor
{
	String:ChatColorName[STORE_MAX_NAME_LENGTH],
	String:ChatColorText[64]
}

int g_chatcolors[1024][ChatColor];
int g_chatcolorCount = 0;

int g_clientChatColors[MAXPLAYERS + 1] = {-1, ...};

Handle g_chatcolorsNameIndex = null;
bool g_databaseInitialized = false;

public Plugin myinfo = {
	name        = "[Store] Chat Colors",
	author      = "Panduh",
	description = "Chat Colors component for [Store]",
	version     = "1.1",
	url         = "http://forums.alliedmodders.com/"
}

/**
 * Plugin is loading.
 */
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("store.phrases");

	Store_RegisterItemType("chatcolor", OnEquip, LoadItem);
}

/** 
 * Called when a new API library is loaded.
 */
public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "store-inventory"))
	{
		Store_RegisterItemType("chatcolor", OnEquip, LoadItem);
	}	
}

public void Store_OnDatabaseInitialized()
{
	g_databaseInitialized = true;
}

/**
 * Called once a client is authorized and fully in-game, and 
 * after all post-connection authorizations have been performed.  
 *
 * This callback is gauranteed to occur on all clients, and always 
 * after each OnClientPutInServer() call.
 *
 * @param client		Client index.
 * @noreturn
 */
public void OnClientPostAdminCheck(int client)
{
	g_clientChatColors[client] = -1;
	if (!g_databaseInitialized)
		return;
		
	Store_GetEquippedItemsByType(Store_GetClientAccountID(client), "chatcolor", Store_GetClientLoadout(client), OnGetPlayerChatColor, GetClientSerial(client));
}

public void Store_OnClientLoadoutChanged(int client)
{
	g_clientChatColors[client] = -1;
	Store_GetEquippedItemsByType(Store_GetClientAccountID(client), "chatcolor", Store_GetClientLoadout(client), OnGetPlayerChatColor, GetClientSerial(client));
}

public void Store_OnReloadItems() 
{
	if (g_chatcolorsNameIndex != null)
		CloseHandle(g_chatcolorsNameIndex);
		
	g_chatcolorsNameIndex = CreateTrie();
	g_chatcolorCount = 0;
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
		if (!GetTrieValue(g_chatcolorsNameIndex, itemName, chatcolor))
		{
			PrintToChat(client, "%s%t", STORE_PREFIX, "No item attributes");
			continue;
		}
		
		g_clientChatColors[client] = chatcolor;
		break;
	}
}

public void LoadItem(const char[] itemName, const char[] attrs)
{
	strcopy(g_chatcolors[g_chatcolorCount][ChatColorName], STORE_MAX_NAME_LENGTH, itemName);
		
	SetTrieValue(g_chatcolorsNameIndex, g_chatcolors[g_chatcolorCount][ChatColorName], g_chatcolorCount);
	
	Handle json = json_load(attrs);	
	
	if (IsSource2009())
	{
		json_object_get_string(json, "color", g_chatcolors[g_chatcolorCount][ChatColorText], 64);
		CReplaceColorCodes(g_chatcolors[g_chatcolorCount][ChatColorText]);
	}
	else
	{
		json_object_get_string(json, "text", g_chatcolors[g_chatcolorCount][ChatColorText], 64);
		Format(g_chatcolors[g_chatcolorCount][ChatColorText], 64);
	}

	CloseHandle(json);

	g_chatcolorCount++;
}

public Store_ItemUseAction OnEquip(int client, int itemId, bool equipped)
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
		if (!GetTrieValue(g_chatcolorsNameIndex, name, chatcolor))
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

public Action OnChatMessage(int &author, Handle recipients, char[] name, char[] message)
{
	if (g_clientChatColors[author] != -1)
	{
		int MaxMessageLength = MAXLENGTH_MESSAGE - strlen(name) - 5;
		if(strlen(g_chatcolors[g_clientChatColors[author]][ChatColorText]) == 6)
		{
			Format(message, MaxMessageLength, "\x07%s%s", g_chatcolors[g_clientChatColors[author]][ChatColorText], message);
			return Plugin_Changed;
		}
		else if(strlen(g_chatcolors[g_clientChatColors[author]][ChatColorText]) == 8)
		{
			Format(message, MaxMessageLength, "\x08%s%s", g_chatcolors[g_clientChatColors[author]][ChatColorText], message);
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

stock bool IsSource2009()
{
	return (SOURCE_SDK_CSS <= GuessSDKVersion() < SOURCE_SDK_LEFT4DEAD);
}