#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <store/store-stocks>

//Store Includes
#include <store/store-core>
#include <store/store-inventory>
#include <store/store-logging>

#pragma newdecls required

#define PLUGIN_NAME "[Store] Core Module"
#define PLUGIN_DESCRIPTION "Core module for the Sourcemod Store."
#define PLUGIN_VERSION_CONVAR "store_core_version"

#define MAX_MENU_ITEMS 32
#define MAX_CHAT_COMMANDS 100

char sQuery_Register[] = "INSERT INTO %s_users (auth, name, ip, credits, token, first_created, last_updated) VALUES ('%d', '%s', '%s', '%d', '%s', '%d', '%d') ON DUPLICATE KEY UPDATE name = '%s', ip = '%s', token = '%s', last_updated = '%d';";
char sQuery_GetClientUserID[] = "SELECT id FROM %s_users WHERE auth = '%d';";
char sQuery_GetCategories[] = "SELECT id, priority, display_name, description, require_plugin, enable_server_restriction FROM %s_categories %s;";
char sQuery_GetItems[] = "SELECT id, priority, name, display_name, description, type, loadout_slot, price, category_id, attrs, LENGTH(attrs) AS attrs_len, is_buyable, is_tradeable, is_refundable, flags, enable_server_restriction FROM %s_items %s;";
char sQuery_GetItemAttributes[] = "SELECT attrs, LENGTH(attrs) AS attrs_len FROM %s_items WHERE name = '%s';";
char sQuery_WriteItemAttributes[] = "UPDATE %s_items SET attrs = '%s}' WHERE name = '%s';";
char sQuery_GetLoadouts[] = "SELECT id, display_name, game, class, team FROM %s_loadouts;";
char sQuery_GetClientLoadouts[] = "SELECT loadout_id FROM %s_users_loadouts WHERE user_id = '%d';";
char sQuery_QueryEquippedLoadout[] = "SELECT eqp_loadout_id FROM %s_users WHERE auth = '%d';";
char sQuery_UpdateEquippedLoadout[] = "UPDATE %s_users SET eqp_loadout_id = '%d' WHERE auth = '%d';";
char sQuery_GetUserItems[] = "SELECT item_id, EXISTS(SELECT * FROM %s_items_loadouts WHERE %s_items_loadouts.item_id = %s_users_items.id AND %s_items_loadouts.loadout_id = %d) AS equipped, COUNT(*) AS count FROM %s_users_items INNER JOIN %s_users ON %s_users.id = %s_users_items.user_id INNER JOIN %s_items ON %s_items.id = %s_users_items.item_id WHERE %s_users.auth = %d AND ((%s_users_items.acquire_date IS NULL OR %s_items.expiry_time IS NULL OR %s_items.expiry_time = 0) OR (%s_users_items.acquire_date IS NOT NULL AND %s_items.expiry_time IS NOT NULL AND %s_items.expiry_time <> 0 AND DATE_ADD(%s_users_items.acquire_date, INTERVAL %s_items.expiry_time SECOND) > NOW()))";
char sQuery_GetUserItems_categoryId[] = "%s AND %s_items.category_id = %d";
char sQuery_GetUserItems_isBuyable[] = "%s AND %s_items.is_buyable = %b";
char sQuery_GetUserItems_isTradeable[] = "%s AND %s_items.is_tradeable = %b";
char sQuery_GetUserItems_isRefundable[] = "%s AND %s_items.is_refundable = %b";
char sQuery_GetUserItems_type[] = "%s AND %s_items.type = '%s'";
char sQuery_GetUserItems_GroupByID[] = "%s GROUP BY item_id;";
char sQuery_GetUserItemsCount[] = "SELECT COUNT(*) AS count FROM %s_users_items INNER JOIN %s_users ON %s_users.id = %s_users_items.user_id INNER JOIN %s_items ON %s_items.id = %s_users_items.item_id WHERE %s_items.name = '%s' AND %s_users.auth = %d;";
char sQuery_GetCredits[] = "SELECT credits FROM %s_users WHERE auth = %d;";
char sQuery_RemoveUserItem[] = "DELETE FROM %s_users_items WHERE %s_users_items.item_id = %d AND %s_users_items.user_id IN (SELECT %s_users.id FROM %s_users WHERE %s_users.auth = %d) LIMIT 1;";
char sQuery_EquipUnequipItem[] = "INSERT INTO %s_items_loadouts (loadout_id, item_id) SELECT %d AS loadout_id, %s_users_items.id FROM %s_users_items INNER JOIN %s_users ON %s_users.id = %s_users_items.user_id WHERE %s_users.auth = %d AND %s_users_items.item_id = %d LIMIT 1;";
char sQuery_UnequipItem[] = "DELETE %s_items_loadouts FROM %s_items_loadouts INNER JOIN %s_users_items ON %s_users_items.id = %s_items_loadouts.item_id INNER JOIN %s_users ON %s_users.id = %s_users_items.user_id INNER JOIN %s_items ON %s_items.id = %s_users_items.item_id WHERE %s_users.auth = %d AND %s_items.loadout_slot = (SELECT loadout_slot from %s_items WHERE %s_items.id = %d)";
char sQuery_UnequipItem_loadoutId[] = "%s AND %s_items_loadouts.loadout_id = %d;";
char sQuery_GetEquippedItemsByType[] = "SELECT %s_items.id FROM %s_users_items INNER JOIN %s_items ON %s_items.id = %s_users_items.item_id INNER JOIN %s_users ON %s_users.id = %s_users_items.user_id INNER JOIN %s_items_loadouts ON %s_items_loadouts.item_id = %s_users_items.id WHERE %s_users.auth = %d AND %s_items.type = '%s' AND %s_items_loadouts.loadout_id = %d;";
char sQuery_GiveCredits[] = "UPDATE %s_users SET credits = credits + %d WHERE auth = %d;";
char sQuery_RemoveCredits_Negative[] = "UPDATE %s_users SET credits = 0 WHERE auth = %d;";
char sQuery_RemoveCredits[] = "UPDATE %s_users SET credits = credits - %d WHERE auth = %d;";
char sQuery_GiveItem[] = "INSERT INTO %s_users_items (user_id, item_id, acquire_date, acquire_method) SELECT %s_users.id AS userId, '%d' AS item_id, NOW() as acquire_date, ";
char sQuery_GiveItem_Shop[] = "%s'shop'";
char sQuery_GiveItem_Trade[] = "%s'trade'";
char sQuery_GiveItem_Gift[] = "%s'gift'";
char sQuery_GiveItem_Admin[] = "%s'admin'";
char sQuery_GiveItem_Web[] = "%s'web'";
char sQuery_GiveItem_Unknown[] = "%sNULL";
char sQuery_GiveItem_End[] = "%s AS acquire_method FROM %s_users WHERE auth = %d;";
char sQuery_GiveCreditsToUsers[] = "UPDATE %s_users SET credits = credits + %d WHERE auth IN (";
char sQuery_GiveCreditsToUsers_End[] = "%s);";
char sQuery_RemoveCreditsFromUsers[] = "UPDATE %s_users SET credits = credits - %d WHERE auth IN (";
char sQuery_RemoveCreditsFromUsers_End[] = "%s);";
char sQuery_GiveDifferentCreditsToUsers[] = "UPDATE %s_users SET credits = credits + CASE auth";
char sQuery_GiveDifferentCreditsToUsers_accountIdsLength[] = "%s WHEN %d THEN %d";
char sQuery_GiveDifferentCreditsToUsers_End[] = "%s END WHERE auth IN (";
char sQuery_RemoveDifferentCreditsFromUsers[] = "UPDATE %s_users SET credits = credits - CASE auth";
char sQuery_RemoveDifferentCreditsFromUsers_accountIdsLength[] = "%s WHEN %d THEN %d";
char sQuery_RemoveDifferentCreditsFromUsers_End[] = "%s END WHERE auth IN (";
char sQuery_GetCreditsEx[] = "SELECT credits FROM %s_users WHERE auth = %d;";
char sQuery_RegisterPluginModule[] = "INSERT INTO %s_versions (mod_name, mod_description, mod_ver_convar, mod_ver_number, server_id, first_created, last_updated) VALUES ('%s', '%s', '%s', '%s', '%d', '%d', '%d') ON DUPLICATE KEY UPDATE mod_name = VALUES(mod_name), mod_description = VALUES(mod_description), mod_ver_convar = VALUES(mod_ver_convar), mod_ver_number = VALUES(mod_ver_number), server_id = VALUES(server_id), last_updated = '%d';";
char sQuery_CacheRestrictionsCategories[] = "SELECT category_id, server_id FROM %s_servers_categories;";
char sQuery_CacheRestrictionsItems[] = "SELECT item_id, server_id FROM %s_servers_items;";
char sQuery_GenerateNewToken[] = "UPDATE `%s_users` SET token = '%s' WHERE auth = '%d'";
char sQuery_LogToDatabase[] = "INSERT INTO %s_log (datetime, server_id, severity, location, message) VALUES (NOW(), '%i', '%s', '%s', '%s');";

char sQuery_CreateTable_Categories[] = "CREATE TABLE IF NOT EXISTS `%s_categories` ( `id` int(11) NOT NULL AUTO_INCREMENT, `priority` int(11) default NULL, `display_name` varchar(32) NOT NULL, `description` varchar(128) default NULL, `require_plugin` varchar(32) default NULL, `web_description` text default NULL, `web_color` varchar(10) default NULL, `enable_server_restriction` int(11) default 0, `first_created` bigint(11) default 0, `last_updated` bigint(11) default 0, PRIMARY KEY  (`id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;";
char sQuery_CreateTable_Items[] = "CREATE TABLE IF NOT EXISTS `%s_items` ( `id` int(11) NOT NULL AUTO_INCREMENT, `priority` int(11) default NULL, `name` varchar(32) NOT NULL, `display_name` varchar(32) NOT NULL, `description` varchar(128) default NULL, `web_description` text, `type` varchar(32) NOT NULL, `loadout_slot` varchar(32) default NULL, `price` int(11) NOT NULL, `category_id` int(11) NOT NULL, `attrs` text default NULL,  `is_buyable` tinyint(1) NOT NULL DEFAULT '1', `is_tradeable` tinyint(1) NOT NULL DEFAULT '1', `is_refundable` tinyint(1) NOT NULL DEFAULT '1', `expiry_time` int(11) NULL, `flags` varchar(11) default NULL, `enable_server_restriction` int(11) default 0, `first_created` bigint(11) default 0, `last_updated` bigint(11) default 0, PRIMARY KEY (`id`), UNIQUE KEY `name` (`name`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;";
char sQuery_CreateTable_Loadouts[] = "CREATE TABLE IF NOT EXISTS `%s_loadouts` ( `id` int(11) NOT NULL AUTO_INCREMENT, `display_name` varchar(32) NOT NULL, `game` varchar(32) default NULL, `class` varchar(32) default NULL, `team` int(11) default NULL, `first_created` bigint(11) default 0, `last_updated` bigint(11) default 0, PRIMARY KEY  (`id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;";
char sQuery_CreateTable_Users[] = "CREATE TABLE IF NOT EXISTS `%s_users` ( `id` int(11) NOT NULL AUTO_INCREMENT, `auth` int(11) NOT NULL, `name` varchar(32) NOT NULL, `ip` varchar(64) NOT NULL default '', `credits` int(11) NOT NULL, `token` varchar(%d) NOT NULL DEFAULT '', `first_created` bigint(11) default 0, `last_updated` bigint(11) default 0, PRIMARY KEY  (`id`), UNIQUE KEY `auth` (`auth`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;";
char sQuery_CreateTable_Users_Items[] = "CREATE TABLE IF NOT EXISTS `%s_users_items` ( `id` int(11) NOT NULL AUTO_INCREMENT, `user_id` int(11) NOT NULL, `item_id` int(11) NOT NULL, `acquire_date` DATETIME NULL, `acquire_method` ENUM('shop', 'trade', 'gift', 'admin', 'web') NULL, `first_created` bigint(11) default 0, `last_updated` bigint(11) default 0, PRIMARY KEY  (`id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;";
char sQuery_CreateTable_Users_Items_Loadouts[] = "CREATE TABLE IF NOT EXISTS `%s_users_items_loadouts` ( `id` int(11) NOT NULL AUTO_INCREMENT, `useritem_id` int(11) NOT NULL, `loadout_id` int(11) NOT NULL, `first_created` bigint(11) default 0, `last_updated` bigint(11) default 0, PRIMARY KEY  (`id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;";
char sQuery_CreateTable_Versions[] = "CREATE TABLE IF NOT EXISTS `%s_versions` ( `id` INT(11) NOT NULL AUTO_INCREMENT, `mod_name` VARCHAR(64) NOT NULL, `mod_description` VARCHAR(64) NULL DEFAULT NULL, `mod_ver_convar` VARCHAR(64) NULL DEFAULT NULL, `mod_ver_number` VARCHAR(64) NOT NULL, `server_id` VARCHAR(64) NOT NULL, `first_created` bigint(12) default 0, `last_updated` bigint(12) default 0, PRIMARY KEY (`id`), UNIQUE INDEX `UNIQUE PLUGIN ON SERVER` (`mod_ver_convar`, `server_id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;";
char sQuery_CreateTable_Servers_Categories[] = "CREATE TABLE IF NOT EXISTS `%s_servers_categories` ( `id` int(11) NOT NULL AUTO_INCREMENT, `category_id` int(11), `server_id` int(11), `first_created` bigint(11) default 0, `last_updated` bigint(11) default 0, PRIMARY KEY  (`id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;";
char sQuery_CreateTable_Servers_Items[] = "CREATE TABLE IF NOT EXISTS `%s_servers_items` ( `id` int(11) NOT NULL AUTO_INCREMENT, `item_id` int(11), `server_id` int(11), `first_created` bigint(11) default 0, `last_updated` bigint(11) default 0, PRIMARY KEY  (`id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;";

////////////////////
//Categories Data

/*
	0 = CategoryId
	1 = CategoryPriority
	2 = CategoryDisplayName
	3 = CategoryDescription
	4 = CategoryRequirePlugin
	5 = CategoryDisableServerRestriction
*/
Handle hArray_Categories;

////////////////////
//Items Data

/*
	0 = ItemId
	1 = ItemPriority
	2 = ItemName
	3 = ItemDisplayName
	4 = ItemDescription
	5 = ItemType
	6 = ItemLoadoutSlot
	7 = ItemPrice
	8 = ItemCategoryId
	9 = ItemIsBuyable
	10 = ItemIsTradeable
	11 = ItemIsRefundable
	12 = ItemFlags
	13 = ItemDisableServerRestriction
*/
Handle hArray_Items;

////////////////////
//Loadouts Data

/*
	0 = LoadoutId
	1 = LoadoutDisplayName
	2 = LoadoutGame
	3 = LoadoutClass
	4 = LoadoutTeam
*/

Handle hArray_Loadouts;

////////////////////
//Main Menu Data
enum MenuItem
{
	String:MenuItemDisplayName[32],
	String:MenuItemDescription[128],
	String:MenuItemValue[64],
	Handle:MenuItemPlugin,
	Store_MenuItemClickCallback:MenuItemCallback,
	MenuItemOrder,
	bool:MenuItemTranslate,
	bool:MenuItemDisabled
}

int g_menuItems[MAX_MENU_ITEMS + 1][MenuItem];
int g_menuItemCount;

////////////////////
//Chat Commands Data
enum ChatCommand
{
	String:ChatCommandName[32],
	Handle:ChatCommandPlugin,
	Store_ChatCommandCallback:ChatCommandCallback,
}

int g_chatCommands[MAX_CHAT_COMMANDS + 1][ChatCommand];
int g_chatCommandCount;

////////////////////
//Forwards
Handle g_dbInitializedForward;
Handle g_hOnChatCommandForward;
Handle g_hOnChatCommandPostForward;
Handle g_hOnCategoriessCacheLoaded;
Handle g_hOnItemsCacheLoaded;

////////////////////
//Config Globals
char g_baseURL[256];
DBPriority g_queryPriority;
bool g_motdSound;
bool g_motdFullscreen;
bool g_singleServerMode;
bool g_printSQLQueries;
char g_currencyName[64];
char g_sqlconfigentry[64];
bool g_showChatCommands;
int g_firstConnectionCredits;
bool g_showMenuDescriptions;
int g_serverID;
char g_tokenCharacters[256];
int g_tokenSize;
Store_AccessType g_accessTypes;

////////////////////
//Plugin Globals
bool bDeveloperMode[MAXPLAYERS + 1];
char sClientToken[MAXPLAYERS + 1][MAX_TOKEN_SIZE];

Handle g_hSQL;

Handle hCategoriesCache;
Handle hItemsCache;

////////////////////
//Plugin Info
public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = STORE_AUTHORS,
	description = PLUGIN_DESCRIPTION,
	version = STORE_VERSION,
	url = STORE_URL
};

////////////////////
//Plugin Functions

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Store_ReloadCacheStacks", Native_ReloadCacheStacks);
	CreateNative("Store_RegisterPluginModule", Native_RegisterPluginModule);
	CreateNative("Store_GetStoreBaseURL", Native_GetStoreBaseURL);
	CreateNative("Store_OpenMOTDWindow", Native_OpenMOTDWindow);
	CreateNative("Store_OpenMainMenu", Native_OpenMainMenu);
	CreateNative("Store_AddMainMenuItem", Native_AddMainMenuItem);
	CreateNative("Store_AddMainMenuItemEx", Native_AddMainMenuItemEx);
	CreateNative("Store_GetCurrencyName", Native_GetCurrencyName);
	CreateNative("Store_GetSQLEntry", Native_GetSQLEntry);
	CreateNative("Store_RegisterChatCommands", Native_RegisterChatCommands);
	CreateNative("Store_GetServerID", Native_GetServerID);
	CreateNative("Store_ClientIsDeveloper", Native_ClientIsDeveloper);
	CreateNative("Store_GetClientToken", Native_GetClientToken);
	CreateNative("Store_GenerateNewToken", Native_GenerateNewToken);

	CreateNative("Store_Register", Native_Register);
	CreateNative("Store_RegisterClient", Native_RegisterClient);
	CreateNative("Store_GetClientAccountID", Native_GetClientAccountID);
	CreateNative("Store_GetClientUserID", Native_GetClientUserID);
	CreateNative("Store_SaveClientToken", Native_SaveClientToken);
	CreateNative("Store_GetUserItems", Native_GetUserItems);
	CreateNative("Store_GetUserItemsCount", Native_GetUserItemsCount);
	CreateNative("Store_GetCredits", Native_GetCredits);
	CreateNative("Store_GetCreditsEx", Native_GetCreditsEx);
	CreateNative("Store_GiveCredits", Native_GiveCredits);
	CreateNative("Store_GiveCreditsToUsers", Native_GiveCreditsToUsers);
	CreateNative("Store_GiveDifferentCreditsToUsers", Native_GiveDifferentCreditsToUsers);
	CreateNative("Store_GiveItem", Native_GiveItem);
	CreateNative("Store_RemoveCredits", Native_RemoveCredits);
	CreateNative("Store_RemoveCreditsFromUsers", Native_RemoveCreditsFromUsers);
	CreateNative("Store_RemoveDifferentCreditsFromUsers", Native_RemoveDifferentCreditsFromUsers);
	CreateNative("Store_BuyItem", Native_BuyItem);
	CreateNative("Store_RemoveUserItem", Native_RemoveUserItem);
	CreateNative("Store_SetItemEquippedState", Native_SetItemEquippedState);
	CreateNative("Store_GetEquippedItemsByType", Native_GetEquippedItemsByType);

	CreateNative("Store_GetCategories", Native_GetCategories);
	CreateNative("Store_GetCategoryPriority", Native_GetCategoryPriority);
	CreateNative("Store_GetCategoryDisplayName", Native_GetCategoryDisplayName);
	CreateNative("Store_GetCategoryDescription", Native_GetCategoryDescription);
	CreateNative("Store_GetCategoryPluginRequired", Native_GetCategoryPluginRequired);
	CreateNative("Store_GetCategoryServerRestriction", Native_GetCategoryServerRestriction);
	CreateNative("Store_ProcessCategory", Native_ProcessCategory);

	CreateNative("Store_GetItems", Native_GetItems);
	CreateNative("Store_GetItemPriority", Native_GetItemPriority);
	CreateNative("Store_GetItemName", Native_GetItemName);
	CreateNative("Store_GetItemDisplayName", Native_GetItemDisplayName);
	CreateNative("Store_GetItemDescription", Native_GetItemDescription);
	CreateNative("Store_GetItemType", Native_GetItemType);
	CreateNative("Store_GetItemLoadoutSlot", Native_GetItemLoadoutSlot);
	CreateNative("Store_GetItemPrice", Native_GetItemPrice);
	CreateNative("Store_GetItemCategory", Native_GetItemCategory);
	CreateNative("Store_IsItemBuyable", Native_IsItemBuyable);
	CreateNative("Store_IsItemTradeable", Native_IsItemTradeable);
	CreateNative("Store_IsItemRefundable", Native_IsItemRefundable);
	CreateNative("Store_GetItemServerRestriction", Native_GetItemServerRestriction);
	CreateNative("Store_GetItemAttributes", Native_GetItemAttributes);
	CreateNative("Store_WriteItemAttributes", Native_WriteItemAttributes);
	CreateNative("Store_ProcessItem", Native_ProcessItem);

	CreateNative("Store_GetLoadouts", Native_GetLoadouts);
	CreateNative("Store_GetLoadoutDisplayName", Native_GetLoadoutDisplayName);
	CreateNative("Store_GetLoadoutGame", Native_GetLoadoutGame);
	CreateNative("Store_GetLoadoutClass", Native_GetLoadoutClass);
	CreateNative("Store_GetLoadoutTeam", Native_GetLoadoutTeam);
	CreateNative("Store_GetClientLoadouts", Native_GetClientLoadouts);
	CreateNative("Store_QueryEquippedLoadout", Native_QueryEquippedLoadout);
	CreateNative("Store_SaveEquippedLoadout", Native_SaveEquippedLoadout);

	CreateNative("Store_SQLTQuery", Native_SQLTQuery);
	CreateNative("Store_SQLEscapeString", Native_SQLEscapeString);
	CreateNative("Store_SQL_ExecuteTransaction", Native_SQL_ExecuteTransaction);
	CreateNative("Store_SQLLogQuery", Native_SQLLogQuery);

	CreateNative("Store_DisplayClientsMenu", Native_DisplayClientsMenu);
	CreateNative("Store_GetGlobalAccessType", Native_GetGlobalAccessType);

	g_dbInitializedForward = CreateGlobalForward("Store_OnDatabaseInitialized", ET_Ignore, Param_Cell);
	g_hOnChatCommandForward = CreateGlobalForward("Store_OnChatCommand", ET_Event, Param_Cell, Param_String, Param_String);
	g_hOnChatCommandPostForward = CreateGlobalForward("Store_OnChatCommand_Post", ET_Ignore, Param_Cell, Param_String, Param_String);
	g_hOnCategoriessCacheLoaded = CreateGlobalForward("Store_OnCategoriesCacheLoaded", ET_Ignore, Param_Array, Param_Cell);
	g_hOnItemsCacheLoaded = CreateGlobalForward("Store_OnItemsCacheLoaded", ET_Ignore, Param_Array, Param_Cell);

	RegPluginLibrary("store-core");
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("store.phrases");

	CreateConVar(PLUGIN_VERSION_CONVAR, STORE_VERSION, PLUGIN_NAME, FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_SPONLY|FCVAR_DONTRECORD);

	RegAdminCmd("sm_reloaditems", Command_ReloadItems, ADMFLAG_ROOT, "Reloads store item cache.");
	RegAdminCmd("sm_devmode", Command_DeveloperMode, ADMFLAG_ROOT, "Toggles developer mode on the client.");
	RegAdminCmd("sm_givecredits", Command_GiveCredits, ADMFLAG_ROOT, "Gives credits to a player.");
	RegAdminCmd("sm_removecredits", Command_RemoveCredits, ADMFLAG_ROOT, "Remove credits from a player.");

	hCategoriesCache = CreateArray();
	hItemsCache = CreateArray();

	hArray_Categories = CreateArray();
	hArray_Items = CreateArray();
	hArray_Loadouts = CreateArray();

	LoadConfig("Core", "configs/store/core.cfg");
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

	KvGetString(hKV, "base_url", g_baseURL, sizeof(g_baseURL), "http://www.yoururl.com/store");

	char sPrioString[32];
	KvGetString(hKV, "query_speed", sPrioString, sizeof(sPrioString), "Normal");

	if (StrEqual(sPrioString, "High", false))
	{
		g_queryPriority = DBPrio_High;
	}
	else if (StrEqual(sPrioString, "Normal", false))
	{
		g_queryPriority = DBPrio_Normal;
	}
	else if (StrEqual(sPrioString, "Low", false))
	{
		g_queryPriority = DBPrio_Low;
	}

	g_motdSound = view_as<bool>(KvGetNum(hKV, "motd_sounds", 1));
	g_motdFullscreen = view_as<bool>(KvGetNum(hKV, "motd_fullscreen", 1));
	g_singleServerMode = view_as<bool>(KvGetNum(hKV, "single_server", 0));
	g_printSQLQueries = view_as<bool>(KvGetNum(hKV, "show_sql_queries", 0));

	KvGetString(hKV, "currency_name", g_currencyName, sizeof(g_currencyName), "Credits");
	KvGetString(hKV, "sql_config_entry", g_sqlconfigentry, sizeof(g_sqlconfigentry), "default");

	if (KvJumpToKey(hKV, "Commands"))
	{
		char buffer[256];

		KvGetString(hKV, "mainmenu_commands", buffer, sizeof(buffer), "!store /store");
		Store_RegisterChatCommands(buffer, ChatCommand_OpenMainMenu);

		KvGetString(hKV, "credits_commands", buffer, sizeof(buffer), "!credits /credits");
		Store_RegisterChatCommands(buffer, ChatCommand_Credits);

		KvGoBack(hKV);
	}

	g_showChatCommands = view_as<bool>(KvGetNum(hKV, "show_chat_commands", 1));
	g_firstConnectionCredits = KvGetNum(hKV, "first_connection_credits", 0);
	g_showMenuDescriptions = view_as<bool>(KvGetNum(hKV, "show_menu_descriptions", 1));
	g_serverID = KvGetNum(hKV, "server_id", 1);

	KvGetString(hKV, "allowed_token_characters", g_tokenCharacters, sizeof(g_tokenCharacters), "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234556789");

	g_tokenSize = KvGetNum(hKV, "token_length", 32);

	if (g_tokenSize > MAX_TOKEN_SIZE)
	{
		g_tokenSize = MAX_TOKEN_SIZE;
		Store_LogWarning("Token size cannot be more than the size of %i, please fix this in configs. Setting to max value.", MAX_TOKEN_SIZE);
	}

	g_accessTypes = view_as<Store_AccessType>(KvGetNum(hKV, "system_access_types", 0));

	CloseHandle(hKV);

	if (g_singleServerMode)
	{
		Store_LogNotice("SINGLE SERVER MODE IS ON!");
	}

	Store_LogInformational("Store Config '%s' Loaded: %s", sName, sFile);

	if (IsServerProcessing())
	{
		ConnectSQL();
	}
	else
	{
		CreateTimer(2.0, CheckServerProcessing, _, TIMER_REPEAT);
	}
}

public Action CheckServerProcessing(Handle hTimer)
{
	if (!IsServerProcessing())
	{
		return Plugin_Continue;
	}

	ConnectSQL();
	return Plugin_Stop;
}

public void OnClientPostAdminCheck(int client)
{
	bDeveloperMode[client] = false;
	Store_RegisterClient(client, g_firstConnectionCredits);
}

public void OnClientDisconnect(int client)
{
	bDeveloperMode[client] = false;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (!IsClientInGame(client))
	{
		return Plugin_Continue;
	}

	char sArgsTrimmed[256];
	int sArgsLen = strlen(sArgs);

	if (sArgsLen >= 2 && sArgs[0] == '"' && sArgs[sArgsLen - 1] == '"')
	{
		strcopy(sArgsTrimmed, sArgsLen - 1, sArgs[1]);
	}
	else
	{
		strcopy(sArgsTrimmed, sizeof(sArgsTrimmed), sArgs);
	}

	char cmds[2][256];
	ExplodeString(sArgsTrimmed, " ", cmds, sizeof(cmds), sizeof(cmds[]), true);

	if (strlen(cmds[0]) <= 0)
	{
		return Plugin_Continue;
	}

	for (int i = 0; i < g_chatCommandCount; i++)
	{
		if (StrEqual(cmds[0], g_chatCommands[i][ChatCommandName], false))
		{
			Action result = Plugin_Continue;
			Call_StartForward(g_hOnChatCommandForward);
			Call_PushCell(client);
			Call_PushString(cmds[0]);
			Call_PushString(cmds[1]);
			Call_Finish(result);

			if (result == Plugin_Handled || result == Plugin_Stop)
			{
				return Plugin_Continue;
			}

			Call_StartFunction(g_chatCommands[i][ChatCommandPlugin], g_chatCommands[i][ChatCommandCallback]);
			Call_PushCell(client);
			Call_PushString(cmds[0]);
			Call_PushString(cmds[1]);
			Call_Finish();

			Call_StartForward(g_hOnChatCommandPostForward);
			Call_PushCell(client);
			Call_PushString(cmds[0]);
			Call_PushString(cmds[1]);
			Call_Finish();

			if (cmds[0][0] == 0x2F)
			{
				return Plugin_Handled;
			}

			if (g_showChatCommands)
			{
				return Plugin_Continue;
			}
		}
	}

	return Plugin_Continue;
}

public void ChatCommand_OpenMainMenu(int client)
{
	OpenMainMenu(client);
}

public void ChatCommand_Credits(int client)
{
	Store_GetCredits(GetSteamAccountID(client), OnCommandGetCredits, client);
}

public void OnCommandGetCredits(int credits, any client)
{
	CPrintToChat(client, "%t%t", "Store Tag Colored", "Store Menu Credits", credits, g_currencyName);
}

////////////////////
//Plugin Commands
public Action Command_ReloadItems(int client, int args)
{
	CReplyToCommand(client, "%t%t", "Store Tag Colored", "Reloading categories and items");

	if (!ReloadCacheStacks(client))
	{
		CReplyToCommand(client, "There was an error reloading categories & items, please check error logs."); //Translate
	}

	return Plugin_Handled;
}

public Action Command_DeveloperMode(int client, int args)
{
	bDeveloperMode[client] = bDeveloperMode[client] ? false : true;
	CPrintToChat(client, "%t%t", "Store Tag Colored", "Store Developer Toggled", bDeveloperMode[client] ? "ON" : "OFF");

	return Plugin_Handled;
}

public Action Command_GiveCredits(int client, int args)
{
	if (args < 2)
	{
		CReplyToCommand(client, "%t Usage: sm_givecredits <target-string> <credits>", "Store Tag Colored");
		return Plugin_Handled;
	}

	char target[64];
	GetCmdArg(1, target, sizeof(target));

	char sAmount[32];
	GetCmdArg(2, sAmount, sizeof(sAmount));
	int iMoney = StringToInt(sAmount);

	int target_list[MAXPLAYERS];
	char target_name[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int target_count = ProcessTargetString(target, 0, target_list, MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml);

	if (target_count <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	int[] accountIds = new int[target_count];
	int count;

	for (int i = 0; i < target_count; i++)
	{
		if (!IsClientInGame(target_list[i]) || IsFakeClient(target_list[i]))
		{
			continue;
		}

		accountIds[count] = GetSteamAccountID(target_list[i]);
		count++;

		CPrintToChat(target_list[i], "%t%t", "Store Tag Colored", "Received Credits", iMoney, g_currencyName);
	}

	Store_GiveCreditsToUsers(accountIds, count, iMoney);
	return Plugin_Handled;
}

public Action Command_RemoveCredits(int client, int args)
{
	if (args < 2)
	{
		CReplyToCommand(client, "%t Usage: sm_removecredits <target-string> <credits>", "Store Tag Colored");
		return Plugin_Handled;
	}

	char target[64];
	GetCmdArg(1, target, sizeof(target));

	char sAmount[32];
	GetCmdArg(2, sAmount, sizeof(sAmount));
	int iMoney = StringToInt(sAmount);

	int target_list[MAXPLAYERS];
	char target_name[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int target_count = ProcessTargetString(target, 0, target_list, MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml);

	if (target_count <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		if (!IsClientInGame(target_list[i]) || IsFakeClient(target_list[i]))
		{
			continue;
		}

		Store_RemoveCredits(GetSteamAccountID(target_list[i]), iMoney, OnRemoveCreditsCallback, GetClientUserId(client));
	}

	return Plugin_Handled;
}

public void OnRemoveCreditsCallback(int accountId, int credits, bool bIsNegative, any data)
{
	int client = GetClientOfUserId(data);

	if (client && IsClientInGame(client))
	{
		CPrintToChat(client, "%t%t", "Store Tag Colored", "Deducted Credits", credits, g_currencyName);

		if (bIsNegative)
		{
			CPrintToChat(client, "%t%t", "Store Tag Colored", "Deducted Credits Less Than Zero", g_currencyName);
		}
	}
}

////////////////////
//Functions
void AddMainMenuItem(bool bTranslate = true, const char[] displayName, const char[] description = "", const char[] value = "", Handle plugin = INVALID_HANDLE, Store_MenuItemClickCallback callback, int order = 32, bool bDisabled = false)
{
	int item;

	for (; item <= g_menuItemCount; item++)
	{
		if (item == g_menuItemCount || StrEqual(g_menuItems[item][MenuItemDisplayName], displayName))
		{
			break;
		}
	}

	strcopy(g_menuItems[item][MenuItemDisplayName], 32, displayName);
	strcopy(g_menuItems[item][MenuItemDescription], 128, description);
	strcopy(g_menuItems[item][MenuItemValue], 64, value);
	g_menuItems[item][MenuItemPlugin] = plugin;
	g_menuItems[item][MenuItemCallback] = callback;
	g_menuItems[item][MenuItemOrder] = order;
	g_menuItems[item][MenuItemTranslate] = bTranslate;
	g_menuItems[item][MenuItemDisabled] = bDisabled;

	if (item == g_menuItemCount)
	{
		g_menuItemCount++;
	}
}

void SortMainMenuItems()
{
	int sortIndex = sizeof(g_menuItems) - 1;

	for (int x = 0; x < g_menuItemCount; x++)
	{
		for (int y = 0; y < g_menuItemCount; y++)
		{
			if (g_menuItems[x][MenuItemOrder] < g_menuItems[y][MenuItemOrder])
			{
				g_menuItems[sortIndex] = g_menuItems[x];
				g_menuItems[x] = g_menuItems[y];
				g_menuItems[y] = g_menuItems[sortIndex];
			}
		}
	}
}

void OpenMainMenu(int client)
{
	SortMainMenuItems();
	Store_GetCredits(GetSteamAccountID(client), OnGetCreditsComplete, GetClientUserId(client));
}

public void OnGetCreditsComplete(int credits, any data)
{
	int client = GetClientOfUserId(data);

	if (!client)
	{
		return;
	}

	Handle menu = CreateMenu(MainMenuSelectHandle);
	SetMenuTitle(menu, "%T%T\n%T\n \n", "Store Menu Title", client, "Store Menu Main Menu", client, STORE_VERSION, "Store Menu Credits", client, g_currencyName, credits);

	for (int item = 0; item < g_menuItemCount; item++)
	{
		char sDisplay[MAX_MESSAGE_LENGTH];
		switch (g_showMenuDescriptions)
		{
			case true:
			{
				switch (g_menuItems[item][MenuItemTranslate])
				{
					case true: Format(sDisplay, sizeof(sDisplay), "%T\n%T", g_menuItems[item][MenuItemDisplayName], client, g_menuItems[item][MenuItemDescription], client);
					case false: Format(sDisplay, sizeof(sDisplay), "%s\n%s", g_menuItems[item][MenuItemDisplayName], g_menuItems[item][MenuItemDescription]);
				}
			}
			case false:
			{
				switch (g_menuItems[item][MenuItemTranslate])
				{
					case true: Format(sDisplay, sizeof(sDisplay), "%T", g_menuItems[item][MenuItemDisplayName], client);
					case false: Format(sDisplay, sizeof(sDisplay), "%s", g_menuItems[item][MenuItemDisplayName]);
				}
			}
		}

		AddMenuItem(menu, g_menuItems[item][MenuItemValue], sDisplay, g_menuItems[item][MenuItemDisabled] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MainMenuSelectHandle(Handle menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			Call_StartFunction(g_menuItems[slot][MenuItemPlugin], g_menuItems[slot][MenuItemCallback]);
			Call_PushCell(client);
			Call_PushString(g_menuItems[slot][MenuItemValue]);
			Call_Finish();
		}
		case MenuAction_End: CloseHandle(menu);
	}
}

void GenerateRandomToken(char[] sToken)
{
	String_GetRandom(sToken, MAX_TOKEN_SIZE, g_tokenSize, g_tokenCharacters);
}

bool RegisterCommands(Handle plugin, const char[] commands, Store_ChatCommandCallback callback)
{
	if (g_chatCommandCount >= MAX_CHAT_COMMANDS)
	{
		return false;
	}

	char splitcommands[32][32];
	int count;

	count = ExplodeString(commands, " ", splitcommands, sizeof(splitcommands), sizeof(splitcommands[]));

	if (count <= 0)
	{
		return false;
	}

	if (g_chatCommandCount + count >= MAX_CHAT_COMMANDS)
	{
		return false;
	}

	for (int i = 0; i < g_chatCommandCount; i++)
	{
		for (int n = 0; n < count; n++)
		{
			if (StrEqual(splitcommands[n], g_chatCommands[i][ChatCommandName], false))
			{
				return false;
			}
		}
	}

	for (int i = 0; i < count; i++)
	{
		strcopy(g_chatCommands[g_chatCommandCount][ChatCommandName], 32, splitcommands[i]);
		g_chatCommands[g_chatCommandCount][ChatCommandPlugin] = plugin;
		g_chatCommands[g_chatCommandCount][ChatCommandCallback] = callback;

		g_chatCommandCount++;
	}

	return true;
}

void Register(int accountId, const char[] name = "", int credits = 0, const char[] token = "", const char[] ip = "")
{
	if (!IsDatabaseConnected())
	{
		Store_LogError("Error registering accountID '%i' under the name '%s', not connected to database.", accountId, name);
		return;
	}

	Store_LogInformational("Registering accountId %i in the database!", accountId);

	char safeName[2 * MAX_NAME_LENGTH + 1];
	SQL_EscapeString(g_hSQL, name, safeName, sizeof(safeName));

	int time = GetTime();

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_Register, STORE_DATABASE_PREFIX, accountId, safeName, ip, credits, token, time, time, safeName, ip, token, time);
	Store_Local_TQuery("Register", SQLCall_Registration, sQuery, accountId);
}

void RegisterClient(int client, int credits = 0)
{
	if (!IsClientInGame(client) || IsFakeClient(client))
	{
		return;
	}

	Store_LogInformational("Registering client %N with %i credits.", client, credits);

	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));

	char sToken[MAX_TOKEN_SIZE];
	Store_GetClientToken(client, sToken, sizeof(sToken));

	char sIP[MAX_NAME_LENGTH];
	GetClientIP(client, sIP, sizeof(sIP));

	Register(GetSteamAccountID(client), sName, credits, sToken, sIP);
}

public void SQLCall_Registration(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		Store_LogError("SQL Error on SQLCall_Registration: %s", error);
		return;
	}

	Store_LogInformational("Registration processing successful with accountId %i!", data);
}

bool GetCategories(int client = 0, Store_GetItemsCallback callback = INVALID_FUNCTION, Handle plugin = null, bool loadFromCache = true, char[] sPriority = "", any data = 0)
{
	int iSize = GetArraySize(hArray_Categories);

	if (loadFromCache)
	{
		int[] categories = new int[iSize];
		int count = 0;

		for (int i = 0; i < iSize; i++)
		{
			Handle hArray = GetArrayCell(hArray_Categories, i);
			categories[count] = GetArrayCell(hArray, 0);
			count++;
		}

		if (callback != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, callback);
			Call_PushArray(categories, count);
			Call_PushCell(count);
			Call_PushCell(data);
			Call_Finish();
		}

		Call_StartForward(g_hOnCategoriessCacheLoaded);
		Call_PushArray(categories, count);
		Call_PushCell(count);
		Call_Finish();

		Store_LogDebug("Cache for categories has been loaded successfully with %i entries.", iSize);

		return true;
	}
	else
	{
		Store_LogDebug("Refreshing cache called for categories.");

		Handle hPack = CreateDataPack();
		WritePackFunction(hPack, callback);
		WritePackCell(hPack, plugin);
		WritePackCell(hPack, data);
		WritePackCell(hPack, client);

		char sQuery[MAX_QUERY_SIZE];
		Format(sQuery, sizeof(sQuery), sQuery_GetCategories, STORE_DATABASE_PREFIX, sPriority);
		Store_Local_TQuery("GetCategories", SQLCall_RetrieveCategories, sQuery, hPack);
	}

	return true;
}

public void SQLCall_RetrieveCategories(Handle owner, Handle hndl, const char[] error, any data)
{
	ResetPack(data);

	Store_GetItemsCallback callback = view_as<Store_GetItemsCallback>(ReadPackFunction(data));
	Handle plugin = view_as<Handle>(ReadPackCell(data));
	int arg = ReadPackCell(data);
	int client = GetClientOfUserId(ReadPackCell(data));

	CloseHandle(data);

	if (hndl == null)
	{
		Store_LogError("SQL Error on GetCategories: %s", error);
		return;
	}

	ClearArray2(hArray_Categories);

	while (SQL_FetchRow(hndl))
	{
		Handle hArray = CreateArray(ByteCountToCells(1024));

		char sDisplayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		SQL_FetchString(hndl, 2, sDisplayName, sizeof(sDisplayName));

		char sDescription[STORE_MAX_DESCRIPTION_LENGTH];
		SQL_FetchString(hndl, 3, sDescription, sizeof(sDescription));

		char sRequiredPlugin[STORE_MAX_REQUIREPLUGIN_LENGTH];
		SQL_FetchString(hndl, 4, sRequiredPlugin, sizeof(sRequiredPlugin));

		PushArrayCell(hArray, SQL_FetchInt(hndl, 0));	//CategoryId
		PushArrayCell(hArray, SQL_FetchInt(hndl, 1));	//CategoryPriority
		PushArrayString(hArray, sDisplayName);			//CategoryDisplayName
		PushArrayString(hArray, sDescription);			//CategoryDescription
		PushArrayString(hArray, sRequiredPlugin);		//CategoryRequirePlugin
		PushArrayCell(hArray, SQL_FetchInt(hndl, 5));	//CategoryDisableServerRestriction

		//Push the array handle into the global categories array.
		PushArrayCell(hArray_Categories, hArray);
	}

	Store_LogDebug("Categories SQL has successfully loaded with %i entries!", SQL_GetRowCount(hndl));

	GetCategories(client, callback, plugin, true, "", arg);
}

int GetCategoryIndex(int id)
{
	for (int i = 0; i < GetArraySize(hArray_Categories); i++)
	{
		Handle hArray = GetArrayCell(hArray_Categories, i);

		if (GetArrayCell(hArray, 0) == id)
		{
			return i;
		}
	}

	return -1;
}

bool GetItems(int client = 0, Handle filter = null, Store_GetItemsCallback callback = INVALID_FUNCTION, Handle plugin = null, bool loadFromCache = true, const char[] sPriority = "", any data = 0)
{
	int iSize = GetArraySize(hArray_Items);

	if (loadFromCache)
	{
		int categoryId; bool isBuyable; bool isTradeable; bool isRefundable; char type[STORE_MAX_TYPE_LENGTH]; int flags;
		bool categoryFilter; bool buyableFilter; bool tradeableFilter; bool refundableFilter; bool typeFilter; bool flagsFilter;

		if (filter != null)
		{
			categoryFilter = GetTrieValue(filter, "category_id", categoryId);
			buyableFilter = GetTrieValue(filter, "is_buyable", isBuyable);
			tradeableFilter = GetTrieValue(filter, "is_tradeable", isTradeable);
			refundableFilter = GetTrieValue(filter, "is_refundable", isRefundable);
			typeFilter = GetTrieString(filter, "type", type, sizeof(type));
			flagsFilter = GetTrieValue(filter, "flags", flags);

			CloseHandle(filter);
		}

		int[] items = new int[iSize];

		int count = 0;

		for (int i = 0; i < iSize; i++)
		{
			Handle hArray = GetArrayCell(hArray_Items, i);

			char sItemType[STORE_MAX_TYPE_LENGTH];
			GetArrayString(hArray, 5, sItemType, sizeof(sItemType));

			if ((!categoryFilter || categoryId == GetArrayCell(hArray, 8)) && (!buyableFilter || isBuyable == GetArrayCell(hArray, 9)) && (!tradeableFilter || isTradeable == GetArrayCell(hArray, 10)) && (!refundableFilter || isRefundable == GetArrayCell(hArray, 11)) && (!typeFilter || StrEqual(type, sItemType)) && (!flagsFilter || !GetArrayCell(hArray, 12) || (flags & GetArrayCell(hArray, 12))))
			{
				items[count] = GetArrayCell(hArray, 0);
				count++;
			}
		}

		if (callback != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, callback);
			Call_PushArray(items, count);
			Call_PushCell(count);
			Call_PushCell(data);
			Call_Finish();
		}

		Call_StartForward(g_hOnItemsCacheLoaded);
		Call_PushArray(items, count);
		Call_PushCell(count);
		Call_Finish();

		Store_LogDebug("Cache for items has been loaded successfully with %i entries.", iSize);

		return true;
	}
	else
	{
		Store_LogDebug("Refreshing cache called for items.");

		Handle hPack = CreateDataPack();
		WritePackCell(hPack, filter);
		WritePackFunction(hPack, callback);
		WritePackCell(hPack, plugin);
		WritePackCell(hPack, data);
		WritePackCell(hPack, client);

		char sQuery[MAX_QUERY_SIZE];
		Format(sQuery, sizeof(sQuery), sQuery_GetItems, STORE_DATABASE_PREFIX, sPriority);
		Store_Local_TQuery("GetItems", SQLCall_RetrieveItems, sQuery, hPack);
	}

	return true;
}

public void SQLCall_RetrieveItems(Handle owner, Handle hndl, const char[] error, any data)
{
	ResetPack(data);

	Handle filter = view_as<Handle>(ReadPackCell(data));
	Store_GetItemsCallback callback = view_as<Store_GetItemsCallback>(ReadPackFunction(data));
	Handle plugin = view_as<Handle>(ReadPackCell(data));
	int arg = ReadPackCell(data);
	int client = GetClientOfUserId(ReadPackCell(data));

	CloseHandle(data);

	if (hndl == null)
	{
		Store_LogError("SQL Error on GetItems: %s", error);
		return;
	}

	ClearArray2(hArray_Items);

	while (SQL_FetchRow(hndl))
	{
		int iID = SQL_FetchInt(hndl, 0);		//ItemId
		int iPriority = SQL_FetchInt(hndl, 1);	//ItemPriority

		char sName[STORE_MAX_NAME_LENGTH];
		SQL_FetchString(hndl, 2, sName, sizeof(sName));

		char sDisplayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		SQL_FetchString(hndl, 3, sDisplayName, sizeof(sDisplayName));

		char sDescription[STORE_MAX_DESCRIPTION_LENGTH];
		SQL_FetchString(hndl, 4, sDescription, sizeof(sDescription));

		char sItemType[STORE_MAX_TYPE_LENGTH];
		SQL_FetchString(hndl, 5, sItemType, sizeof(sItemType));

		char sLoadoutSlot[STORE_MAX_LOADOUTSLOT_LENGTH];
		SQL_FetchString(hndl, 6, sLoadoutSlot, sizeof(sLoadoutSlot));

		int iPrice = SQL_FetchInt(hndl, 7);			//ItemPrice
		int iCategoryID = SQL_FetchInt(hndl, 8);	//ItemCategoryId

		if (!SQL_IsFieldNull(hndl, 9))
		{
			int attrsLength = SQL_FetchInt(hndl, 10);

			int size = attrsLength + 1;
			char[] attrs = new char[size];
			SQL_FetchString(hndl, 9, attrs, size);

			Store_CallItemAttrsCallback(sItemType, sName, attrs);
		}

		int iIsBuyable = SQL_FetchInt(hndl, 11);	//ItemIsBuyable
		int iIsTradeable = SQL_FetchInt(hndl, 12);	//ItemIsTradeable
		int iIsRefundable = SQL_FetchInt(hndl, 13);	//ItemIsRefundable

		char sFlags[12];
		SQL_FetchString(hndl, 14, sFlags, sizeof(sFlags));

		int iServerRestrict = SQL_FetchInt(hndl, 15);	//ItemDisableServerRestriction

		Handle hArray = CreateArray(ByteCountToCells(1024));

		PushArrayCell(hArray, iID);						//ItemId
		PushArrayCell(hArray, iPriority);				//ItemPriority
		PushArrayString(hArray, sName);					//ItemName
		PushArrayString(hArray, sDisplayName);			//ItemDisplayName
		PushArrayString(hArray, sDescription);			//ItemDescription
		PushArrayString(hArray, sItemType);				//ItemType
		PushArrayString(hArray, sLoadoutSlot);			//ItemLoadoutSlot
		PushArrayCell(hArray, iPrice);					//ItemPrice
		PushArrayCell(hArray, iCategoryID);				//ItemCategoryId
		PushArrayCell(hArray, iIsBuyable);				//ItemIsBuyable
		PushArrayCell(hArray, iIsTradeable);			//ItemIsTradeable
		PushArrayCell(hArray, iIsRefundable);			//ItemIsRefundable
		PushArrayCell(hArray, ReadFlagString(sFlags));	//ItemFlags
		PushArrayCell(hArray, iServerRestrict);			//ItemDisableServerRestriction

		//Push the array into the items global array for use later.
		PushArrayCell(hArray_Items, hArray);

		PrintToServer("ID: %i, Prio: %i, Name: %s, Desc: %s, Type: %s, Loadout: %s, Price: %i", iID, iPriority, sName, sDescription, sItemType, sLoadoutSlot, iPrice);
	}

	Store_LogDebug("Items SQL has successfully loaded with %i entries!", SQL_GetRowCount(hndl));

	GetItems(client, filter, callback, plugin, true, "", arg);
}

void GetCacheStacks()
{
	if (!IsDatabaseConnected())
	{
		return;
	}

	char sQuery[MAX_QUERY_SIZE];

	Format(sQuery, sizeof(sQuery), sQuery_CacheRestrictionsCategories, STORE_DATABASE_PREFIX);
	Store_Local_TQuery("GetCategoryCacheStacks", SQLCall_GetCategoryRestrictions, sQuery);

	Format(sQuery, sizeof(sQuery), sQuery_CacheRestrictionsItems, STORE_DATABASE_PREFIX);
	Store_Local_TQuery("GetItemCacheStacks", SQLCall_GetItemRestrictions, sQuery);
}

public void SQLCall_GetCategoryRestrictions(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		Store_LogError("SQL Error on SQLCall_GetCategoryRestrictions: %s", error);
		return;
	}

	while (SQL_FetchRow(hndl) && !SQL_IsFieldNull(hndl, 0))
	{
		int array_process[2];
		array_process[0] = SQL_FetchInt(hndl, 0);
		array_process[1] = SQL_FetchInt(hndl, 1);

		PushArrayArray(hCategoriesCache, array_process);
	}
}

public void SQLCall_GetItemRestrictions(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		Store_LogError("SQL Error on SQLCall_GetItemRestrictions: %s", error);
		return;
	}

	while (SQL_FetchRow(hndl) && !SQL_IsFieldNull(hndl, 0))
	{
		int array_process[2];
		array_process[0] = SQL_FetchInt(hndl, 0);
		array_process[1] = SQL_FetchInt(hndl, 1);

		PushArrayArray(hItemsCache, array_process);
	}
}

int GetItemIndex(int id)
{
	for (int i = 0; i < GetArraySize(hArray_Items); i++)
	{
		Handle hArray = GetArrayCell(hArray_Items, i);

		if (GetArrayCell(hArray, 0) == id)
		{
			return i;
		}
	}

	return -1;
}

void GetItemAttributes(const char[] itemName, Store_ItemGetAttributesCallback callback, Handle plugin = null, any data = 0)
{
	if (!IsDatabaseConnected())
	{
		return;
	}

	Handle hPack = CreateDataPack();
	WritePackString(hPack, itemName);
	WritePackFunction(hPack, callback);
	WritePackCell(hPack, plugin);
	WritePackCell(hPack, data);

	int itemNameLength = 2 * strlen(itemName) + 1;

	char[] itemNameSafe = new char[itemNameLength];
	SQL_EscapeString(g_hSQL, itemName, itemNameSafe, itemNameLength);

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_GetItemAttributes, STORE_DATABASE_PREFIX, itemNameSafe);
	Store_Local_TQuery("GetItemAttributes", SQLCall_GetItemAttributes, sQuery, hPack);
}

public void SQLCall_GetItemAttributes(Handle owner, Handle hndl, const char[] error, any data)
{
	ResetPack(data);

	char itemName[STORE_MAX_NAME_LENGTH];
	ReadPackString(data, itemName, sizeof(itemName));

	Store_ItemGetAttributesCallback callback = view_as<Store_ItemGetAttributesCallback>(ReadPackFunction(data));
	Handle plugin = view_as<Handle>(ReadPackCell(data));
	int arg = ReadPackCell(data);

	CloseHandle(data);

	if (hndl == null)
	{
		Store_LogError("SQL Error on SQLCall_GetItemAttributes: %s", error);
		return;
	}

	if (SQL_FetchRow(hndl) && !SQL_IsFieldNull(hndl, 0))
	{
		int attrsLength = SQL_FetchInt(hndl, 1);

		char[] attrs = new char[attrsLength + 1];
		SQL_FetchString(hndl, 0, attrs, attrsLength+1);

		if (callback != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, callback);
			Call_PushString(itemName);
			Call_PushString(attrs);
			Call_PushCell(arg);
			Call_Finish();
		}
	}
}

void WriteItemAttributes(const char[] itemName, const char[] attrs, Store_BuyItemCallback callback, Handle plugin = null, any data = 0)
{
	if (!IsDatabaseConnected())
	{
		return;
	}

	Handle hPack = CreateDataPack();
	WritePackFunction(hPack, callback);
	WritePackCell(hPack, plugin);
	WritePackCell(hPack, data);

	int itemNameLength = 2 * strlen(itemName) + 1;
	char[] itemNameSafe = new char[itemNameLength];
	SQL_EscapeString(g_hSQL, itemName, itemNameSafe, itemNameLength);

	int attrsLength = 10 * 1024;
	char[] attrsSafe = new char[2 * attrsLength + 1];
	SQL_EscapeString(g_hSQL, attrs, attrsSafe, 2 * attrsLength + 1);

	char[] sQuery = new char[attrsLength + MAX_QUERY_SIZE];
	Format(sQuery, attrsLength + MAX_QUERY_SIZE, sQuery_WriteItemAttributes, STORE_DATABASE_PREFIX, attrsSafe, itemNameSafe);
	Store_Local_TQuery("WriteItemAttributes", SQLCall_WriteItemAttributes, sQuery, hPack);
}

public void SQLCall_WriteItemAttributes(Handle owner, Handle hndl, const char[] error, any data)
{
	ResetPack(data);

	Store_BuyItemCallback callback = view_as<Store_BuyItemCallback>(ReadPackFunction(data));
	Handle plugin = view_as<Handle>(ReadPackCell(data));
	int arg = ReadPackCell(data);

	CloseHandle(data);

	if (hndl == null)
	{
		Store_LogError("SQL Error on WriteItemAttributes: %s", error);
		return;
	}

	if (callback != INVALID_FUNCTION)
	{
		Call_StartFunction(plugin, callback);
		Call_PushCell(true);
		Call_PushCell(arg);
		Call_Finish();
	}
}

bool GetLoadouts(Handle filter = null, Store_GetItemsCallback callback = INVALID_FUNCTION, Handle plugin = null, bool loadFromCache = true, any data = 0)
{
	int iSize = GetArraySize(hArray_Loadouts);

	if (loadFromCache && iSize > 0)
	{
		int[] loadouts = new int[iSize];
		int count = 0;

		bool gameFilter; bool teamFilter; bool classFilter;
		char game[32]; char team[32]; char class[32];

		if (filter != null)
		{
			gameFilter = GetTrieString(filter, "game", game, sizeof(game));
			teamFilter = GetTrieString(filter, "team", team, sizeof(team));
			classFilter = GetTrieString(filter, "class", class, sizeof(class));

			CloseHandle(filter);
		}

		for (int i = 0; i < iSize; i++)
		{
			Handle hArray = GetArrayCell(hArray_Loadouts, i);

			char sGame[STORE_MAX_LOADOUTGAME_LENGTH];
			GetArrayString(hArray, 2, sGame, sizeof(sGame));

			char sClass[STORE_MAX_LOADOUTCLASS_LENGTH];
			GetArrayString(hArray, 3, sClass, sizeof(sClass));

			char sTeam[STORE_MAX_LOADOUTCLASS_LENGTH];
			GetArrayString(hArray, 4, sTeam, sizeof(sTeam));

			if ((!gameFilter || strlen(game) == 0 || strlen(sGame) == 0 || StrEqual(game, sGame)) && (!teamFilter || strlen(team) == 0 || strlen(sTeam) == 0 || StrEqual(team, sTeam)) && (!classFilter || strlen(class) == 0 || strlen(sClass) == 0 || StrEqual(class, sClass)))
			{
				loadouts[count] = GetArrayCell(hArray, 0);
				count++;
			}
		}

		if (callback != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, callback);
			Call_PushArray(loadouts, count);
			Call_PushCell(count);
			Call_PushCell(data);
			Call_Finish();
		}

		return true;
	}
	else
	{
		Handle hPack = CreateDataPack();
		WritePackCell(hPack, filter);
		WritePackFunction(hPack, callback);
		WritePackCell(hPack, plugin);
		WritePackCell(hPack, data);

		char sQuery[MAX_QUERY_SIZE];
		Format(sQuery, sizeof(sQuery), sQuery_GetLoadouts, STORE_DATABASE_PREFIX);
		Store_Local_TQuery("GetLoadouts", SQLCall_GetLoadouts, sQuery, hPack);
	}

	return true;
}

public void SQLCall_GetLoadouts(Handle owner, Handle hndl, const char[] error, any data)
{
	ResetPack(data);

	Handle filter = view_as<Handle>(ReadPackCell(data));
	Store_GetItemsCallback callback = view_as<Store_GetItemsCallback>(ReadPackFunction(data));
	Handle plugin = view_as<Handle>(ReadPackCell(data));
	int data2 = ReadPackCell(data);

	CloseHandle(data);

	if (hndl == null)
	{
		Store_LogError("SQL Error on SQLCall_GetLoadouts: %s", error);
		return;
	}

	ClearArray2(hArray_Loadouts);

	while (SQL_FetchRow(hndl))
	{
		Handle hArray = CreateArray(ByteCountToCells(1024));

		PushArrayCell(hArray, SQL_FetchInt(hndl, 0));	//LoadoutId

		char sDisplayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		SQL_FetchString(hndl, 1, sDisplayName, sizeof(sDisplayName));
		PushArrayString(hArray, sDisplayName);			//LoadoutDisplayName

		char sGame[STORE_MAX_LOADOUTGAME_LENGTH];
		SQL_FetchString(hndl, 2, sGame, sizeof(sGame));
		PushArrayString(hArray, sGame);					//LoadoutGame

		char sClass[STORE_MAX_LOADOUTCLASS_LENGTH];
		SQL_FetchString(hndl, 3, sClass, sizeof(sClass));
		PushArrayString(hArray, sClass);				//LoadoutClass

		int iLoadoutTeam = SQL_IsFieldNull(hndl, 4) ? -1 : SQL_FetchInt(hndl, 4);
		PushArrayCell(hArray, iLoadoutTeam);			//LoadoutTeam

		PushArrayCell(hArray_Loadouts, hArray);
	}

	GetLoadouts(filter, callback, plugin, true, data2);
}

int GetLoadoutIndex(int id)
{
	for (int i = 0; i < GetArraySize(hArray_Loadouts); i++)
	{
		Handle hArray = GetArrayCell(hArray_Loadouts, i);

		if (GetArrayCell(hArray, 0) == id)
		{
			return i;
		}
	}

	return -1;
}

void GetClientLoadouts(int accountId, Store_GetUserLoadoutsCallback callback, Handle plugin = null, any data = 0)
{
	if (!IsDatabaseConnected())
	{
		Store_LogError("Error getting accountId '%i' loadouts, no database connected.", accountId);
		return;
	}

	Handle hPack = CreateDataPack();
	WritePackCell(hPack, accountId);
	WritePackFunction(hPack, callback);
	WritePackCell(hPack, plugin);
	WritePackCell(hPack, data);

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_GetClientLoadouts, STORE_DATABASE_PREFIX, accountId);
	Store_Local_TQuery("GetClientLoadouts", SQLCall_GetClientLoadouts, sQuery, hPack);
}

public void SQLCall_GetClientLoadouts(Handle owner, Handle hndl, const char[] error, any data)
{
	ResetPack(data);

	int accountId = ReadPackCell(data);
	Store_GetUserLoadoutsCallback callback = view_as<Store_GetUserLoadoutsCallback>(ReadPackFunction(data));
	Handle plugin = view_as<Handle>(ReadPackCell(data));
	int arg = ReadPackCell(data);

	CloseHandle(data);

	if (hndl == null)
	{
		Store_LogError("SQL Error on SQLCall_GetClientLoadouts: %s", error);
		return;
	}

	int count = SQL_GetRowCount(hndl);

	int[] ids = new int[count];

	int index = 0;
	while (SQL_FetchRow(hndl))
	{
		ids[index] = SQL_FetchInt(hndl, 0);
		index++;
	}

	Call_StartFunction(plugin, callback);
	Call_PushCell(accountId);
	Call_PushArray(ids, count);
	Call_PushCell(count);
	Call_PushCell(arg);
	Call_Finish();
}

void QueryEquippedLoadout(int accountId, Store_GetUserEquippedLoadoutCallback callback, Handle plugin = null, any data = 0)
{
	if (!IsDatabaseConnected())
	{
		return;
	}

	Handle hPack = CreateDataPack();
	WritePackCell(hPack, accountId);
	WritePackFunction(hPack, callback);
	WritePackCell(hPack, plugin);
	WritePackCell(hPack, data);

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_QueryEquippedLoadout, STORE_DATABASE_PREFIX, accountId);
	Store_Local_TQuery("QueryEquippedLoadout", SQLCall_QueryEquippedLoadout, sQuery, hPack);
}

public void SQLCall_QueryEquippedLoadout(Handle owner, Handle hndl, const char[] error, any data)
{
	ResetPack(data);

	int accountId = ReadPackCell(data);
	Store_GetUserEquippedLoadoutCallback callback = view_as<Store_GetUserEquippedLoadoutCallback>(ReadPackFunction(data));
	Handle plugin = view_as<Handle>(ReadPackCell(data));
	int arg = ReadPackCell(data);

	CloseHandle(data);

	if (hndl == null)
	{
		Store_LogError("SQL Error on SQLCall_QueryEquippedLoadout: %s", error);
		return;
	}

	if (SQL_FetchRow(hndl))
	{
		Call_StartFunction(plugin, callback);
		Call_PushCell(accountId);
		Call_PushCell(SQL_FetchInt(hndl, 0));
		Call_PushCell(arg);
		Call_Finish();
	}
}

void SaveEquippedLoadout(int accountId, int loadoutId, Store_SaveUserEquippedLoadoutCallback callback = INVALID_FUNCTION, Handle plugin = null, any data = 0)
{
	if (!IsDatabaseConnected())
	{
		Store_LogError("Error saving equipped loadout to database for accountId %i and loadoutId %i, no database connected.", accountId, loadoutId);
		return;
	}

	Handle hPack = CreateDataPack();
	WritePackCell(hPack, accountId);
	WritePackCell(hPack, loadoutId);
	WritePackFunction(hPack, callback);
	WritePackCell(hPack, plugin);
	WritePackCell(hPack, data);

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_UpdateEquippedLoadout, STORE_DATABASE_PREFIX, loadoutId, accountId);
	Store_Local_TQuery("SaveEquippedLoadout", SQLCall_SaveEquippedLoadout, sQuery, hPack);
}

public void SQLCall_SaveEquippedLoadout(Handle owner, Handle hndl, const char[] error, any data)
{
	ResetPack(data);

	int accountId = ReadPackCell(data);
	int loadoutId = ReadPackCell(data);
	Store_SaveUserEquippedLoadoutCallback callback = view_as<Store_SaveUserEquippedLoadoutCallback>(ReadPackFunction(data));
	Handle plugin = view_as<Handle>(ReadPackCell(data));
	int arg = ReadPackCell(data);

	CloseHandle(data);

	if (hndl == null)
	{
		Store_LogError("SQL Error on SQLCall_SaveEquippedLoadout: %s", error);
		return;
	}

	if (callback != INVALID_FUNCTION)
	{
		Call_StartFunction(plugin, callback);
		Call_PushCell(accountId);
		Call_PushCell(loadoutId);
		Call_PushCell(arg);
		Call_Finish();
	}
}

void GetUserItems(Handle filter = null, int accountId, int loadoutId, Store_GetUserItemsCallback callback = INVALID_FUNCTION, Handle plugin = null, any data = 0)
{
	if (!IsDatabaseConnected())
	{
		Store_LogError("Error retrieving user items, not connected.");
		return;
	}

	PrintToServer("1: %i", data);

	if (GetArraySize(hArray_Items) < 1)
	{
		Handle hPack = CreateDataPack();
		WritePackCell(hPack, filter);
		WritePackCell(hPack, accountId);
		WritePackCell(hPack, loadoutId);
		WritePackFunction(hPack, callback);
		WritePackCell(hPack, plugin);
		WritePackCell(hPack, data);

		Store_LogError("Store_GetUserItems has been called before items have loaded.");
		GetItems(0, _, ReloadUserItems, _, true, "", hPack);

		return;
	}

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_GetUserItems, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, loadoutId, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, accountId, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX);

	int categoryId;
	if (GetTrieValue(filter, "category_id", categoryId))
	{
		Format(sQuery, sizeof(sQuery), sQuery_GetUserItems_categoryId, sQuery, STORE_DATABASE_PREFIX, categoryId);
	}

	bool isBuyable;
	if (GetTrieValue(filter, "is_buyable", isBuyable))
	{
		Format(sQuery, sizeof(sQuery), sQuery_GetUserItems_isBuyable, sQuery, STORE_DATABASE_PREFIX, isBuyable);
	}

	bool isTradeable;
	if (GetTrieValue(filter, "is_tradeable", isTradeable))
	{
		Format(sQuery, sizeof(sQuery), sQuery_GetUserItems_isTradeable, sQuery, STORE_DATABASE_PREFIX, isTradeable);
	}

	bool isRefundable;
	if (GetTrieValue(filter, "is_refundable", isRefundable))
	{
		Format(sQuery, sizeof(sQuery), sQuery_GetUserItems_isRefundable, sQuery, STORE_DATABASE_PREFIX, isRefundable);
	}

	char type[STORE_MAX_TYPE_LENGTH];
	if (GetTrieString(filter, "type", type, sizeof(type)))
	{
		int typeLength = 2 * strlen(type) + 1;

		char[] buffer = new char[typeLength];
		SQL_EscapeString(g_hSQL, type, buffer, typeLength);

		Format(sQuery, sizeof(sQuery), sQuery_GetUserItems_type, sQuery, STORE_DATABASE_PREFIX, buffer);
	}

	CloseHandle(filter);

	Handle hPack = CreateDataPack();
	WritePackCell(hPack, accountId);
	WritePackCell(hPack, loadoutId);
	WritePackFunction(hPack, callback);
	WritePackCell(hPack, plugin);
	WritePackCell(hPack, data);

	PrintToServer("2: %i", data);

	Format(sQuery, sizeof(sQuery), sQuery_GetUserItems_GroupByID, sQuery);
	Store_Local_TQuery("GetUserItems", SQLCall_GetUserItems, sQuery, hPack);
}

public void ReloadUserItems(int[] ids, int count, any hPack)
{
	ResetPack(hPack);

	Handle filter = view_as<Handle>(ReadPackCell(hPack));
	int accountId = ReadPackCell(hPack);
	int loadoutId = ReadPackCell(hPack);
	Store_GetUserItemsCallback callback = view_as<Store_GetUserItemsCallback>(ReadPackFunction(hPack));
	Handle plugin = view_as<Handle>(ReadPackCell(hPack));
	any arg = ReadPackCell(hPack);

	CloseHandle(hPack);

	GetUserItems(filter, accountId, loadoutId, callback, plugin, arg);
}

public void SQLCall_GetUserItems(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		CloseHandle(data);
		Store_LogError("SQL Error on SQLCall_GetUserItems: %s", error);
		return;
	}

	ResetPack(data);

	int accountId = ReadPackCell(data);
	int loadoutId = ReadPackCell(data);
	Store_GetUserItemsCallback callback = view_as<Store_GetUserItemsCallback>(ReadPackFunction(data));
	Handle plugin = view_as<Handle>(ReadPackCell(data));
	any arg = ReadPackCell(data);

	CloseHandle(data);

	int count = SQL_GetRowCount(hndl);

	int[] ids = new int[count];
	bool[] equipped = new bool[count];
	int[] itemCount = new int[count];

	int index = 0;
	while (SQL_FetchRow(hndl))
	{
		ids[index] = SQL_FetchInt(hndl, 0);
		equipped[index] = view_as<bool>(SQL_FetchInt(hndl, 1));
		itemCount[index] = SQL_FetchInt(hndl, 2);

		index++;
	}

	PrintToServer("3: %i", arg);

	Call_StartFunction(plugin, callback);
	Call_PushCell(accountId);
	Call_PushArray(ids, count);
	Call_PushArray(equipped, count);
	Call_PushArray(itemCount, count);
	Call_PushCell(count);
	Call_PushCell(loadoutId);
	Call_PushCell(arg);
	Call_Finish();
}

void GetUserItemsCount(int accountId, const char[] itemName, Store_GetUserItemsCountCallback callback, Handle plugin = null, any data = 0)
{
	if (!IsDatabaseConnected())
	{
		Store_LogError("Error retrieving user item count, not connected.");
		return;
	}

	Handle hPack = CreateDataPack();
	WritePackFunction(hPack, callback);
	WritePackCell(hPack, plugin);
	WritePackCell(hPack, data);

	int itemNameLength = 2 * strlen(itemName) + 1;

	char[] itemNameSafe = new char[itemNameLength];
	SQL_EscapeString(g_hSQL, itemName, itemNameSafe, itemNameLength);

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_GetUserItemsCount, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, itemNameSafe, STORE_DATABASE_PREFIX, accountId);
	Store_Local_TQuery("GetUserItemsCount", SQLCall_GetUserItemsCount, sQuery, hPack);
}

public void SQLCall_GetUserItemsCount(Handle owner, Handle hndl, const char[] error, any data)
{
	ResetPack(data);

	Store_GetUserItemsCountCallback callback = view_as<Store_GetUserItemsCountCallback>(ReadPackFunction(data));
	Handle plugin = view_as<Handle>(ReadPackCell(data));
	int arg = ReadPackCell(data);

	CloseHandle(data);

	if (hndl == null)
	{
		Store_LogError("SQL Error on SQLCall_GetUserItemsCount: %s", error);
		return;
	}

	if (SQL_FetchRow(hndl))
	{
		Call_StartFunction(plugin, callback);
		Call_PushCell(SQL_FetchInt(hndl, 0));
		Call_PushCell(arg);
		Call_Finish();
	}
}

void GetCredits(int accountId, Store_GetCreditsCallback callback, Handle plugin = null, any data = 0)
{
	if (!IsDatabaseConnected())
	{
		return;
	}

	Handle hPack = CreateDataPack();
	WritePackFunction(hPack, callback);
	WritePackCell(hPack, plugin);
	WritePackCell(hPack, data);

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_GetCredits, STORE_DATABASE_PREFIX, accountId);
	Store_Local_TQuery("GetCredits", SQLCall_GetCredits, sQuery, hPack);
}

public void SQLCall_GetCredits(Handle owner, Handle hndl, const char[] error, any data)
{
	ResetPack(data);

	Store_GetCreditsCallback callback = view_as<Store_GetCreditsCallback>(ReadPackFunction(data));
	Handle plugin = view_as<Handle>(ReadPackCell(data));
	int arg = ReadPackCell(data);

	CloseHandle(data);

	if (hndl == null)
	{
		Store_LogError("SQL Error on GetCredits: %s", error);
		return;
	}

	if (SQL_FetchRow(hndl))
	{
		Call_StartFunction(plugin, callback);
		Call_PushCell(SQL_FetchInt(hndl, 0));
		Call_PushCell(arg);
		Call_Finish();
	}
}

void BuyItem(int accountId, int itemId, Store_BuyItemCallback callback, Handle plugin = null, any data = 0)
{
	Handle hPack = CreateDataPack();
	WritePackCell(hPack, itemId);
	WritePackCell(hPack, accountId);
	WritePackFunction(hPack, callback);
	WritePackCell(hPack, plugin);
	WritePackCell(hPack, data);

	GetCredits(accountId, OnGetCreditsForItemBuy, _, hPack);
}

public void OnGetCreditsForItemBuy(int credits, any hPack)
{
	ResetPack(hPack);

	int itemId = ReadPackCell(hPack);
	int accountId = ReadPackCell(hPack);
	Store_BuyItemCallback callback = view_as<Store_BuyItemCallback>(ReadPackFunction(hPack));
	Handle plugin = view_as<Handle>(ReadPackCell(hPack));
	int arg = ReadPackCell(hPack);

	int index = GetItemIndex(itemId);
	Handle hArray = GetArrayCell(hArray_Items, index);
	int iItemPrice = GetArrayCell(hArray, 7);

	if (credits < iItemPrice)
	{
		Call_StartFunction(plugin, callback);
		Call_PushCell(0);
		Call_PushCell(arg);
		Call_Finish();

		return;
	}

	RemoveCredits(accountId, iItemPrice, OnBuyItemGiveItem, _, hPack);
}

public void OnBuyItemGiveItem(int accountId, int credits, bool bNegative, any hPack)
{
	ResetPack(hPack);

	int itemId = ReadPackCell(hPack);
	GiveItem(accountId, itemId, Store_Shop, OnGiveItemFromBuyItem, _, hPack);
}

public void OnGiveItemFromBuyItem(int accountId, any hPack)
{
	ResetPack(hPack);
	ReadPackCell(hPack);
	ReadPackCell(hPack);

	Store_BuyItemCallback callback = view_as<Store_BuyItemCallback>(ReadPackFunction(hPack));
	Handle plugin = view_as<Handle>(ReadPackCell(hPack));
	int arg = ReadPackCell(hPack);

	CloseHandle(hPack);

	Call_StartFunction(plugin, callback);
	Call_PushCell(1);
	Call_PushCell(arg);
	Call_Finish();
}

void RemoveUserItem(int accountId, int itemId, Store_UseItemCallback callback, Handle plugin = null, any data = 0)
{
	Handle hPack = CreateDataPack();
	WritePackCell(hPack, accountId);
	WritePackCell(hPack, itemId);
	WritePackFunction(hPack, callback);
	WritePackCell(hPack, plugin);
	WritePackCell(hPack, data);

	UnequipItem(accountId, itemId, -1, OnRemoveUserItem, _, hPack);
}

public void OnRemoveUserItem(int accountId, int itemId, int loadoutId, any hPack)
{
	if (!IsDatabaseConnected())
	{
		return;
	}

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_RemoveUserItem, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, itemId, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, accountId);
	Store_Local_TQuery("RemoveUserItemUnequipCallback", SQLCall_RemoveUserItem, sQuery, hPack);
}

public void SQLCall_RemoveUserItem(Handle owner, Handle hndl, const char[] error, any data)
{
	ResetPack(data);

	int accountId = ReadPackCell(data);
	int itemId = ReadPackCell(data);
	Store_UseItemCallback callback = view_as<Store_UseItemCallback>(ReadPackFunction(data));
	Handle plugin = view_as<Handle>(ReadPackCell(data));
	int arg = ReadPackCell(data);

	CloseHandle(data);

	if (hndl == null)
	{
		Store_LogError("SQL Error on SQLCall_RemoveUserItem: %s", error);
		return;
	}

	Call_StartFunction(plugin, callback);
	Call_PushCell(accountId);
	Call_PushCell(itemId);
	Call_PushCell(arg);
	Call_Finish();
}

void SetItemEquippedState(int accountId, int itemId, int loadoutId, bool isEquipped, Store_EquipItemCallback callback, Handle plugin = null, any data = 0)
{
	switch (isEquipped)
	{
		case true: EquipItem(accountId, itemId, loadoutId, callback, plugin, data);
		case false: UnequipItem(accountId, itemId, loadoutId, callback, plugin, data);
	}
}

void EquipItem(int accountId, int itemId, int loadoutId, Store_EquipItemCallback callback, Handle plugin = null, any data = 0)
{
	Handle hPack = CreateDataPack();
	WritePackCell(hPack, accountId);
	WritePackCell(hPack, itemId);
	WritePackCell(hPack, loadoutId);
	WritePackFunction(hPack, callback);
	WritePackCell(hPack, plugin);
	WritePackCell(hPack, data);

	UnequipItem(accountId, itemId, loadoutId, OnUnequipItemToEquipNewItem, _, hPack);
}

public void OnUnequipItemToEquipNewItem(int accountId, int itemId, int loadoutId, any hPack)
{
	if (!IsDatabaseConnected())
	{
		return;
	}

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_EquipUnequipItem, STORE_DATABASE_PREFIX, loadoutId, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, accountId, STORE_DATABASE_PREFIX, itemId);
	Store_Local_TQuery("EquipUnequipItemCallback", SQLCall_EquipItem, sQuery, hPack);
}

public void SQLCall_EquipItem(Handle owner, Handle hndl, const char[] error, any data)
{
	ResetPack(data);

	int accountId = ReadPackCell(data);
	int itemId = ReadPackCell(data);
	int loadoutId = ReadPackCell(data);
	Store_GiveCreditsCallback callback = view_as<Store_GiveCreditsCallback>(ReadPackFunction(data));
	Handle plugin = view_as<Handle>(ReadPackCell(data));
	int arg = ReadPackCell(data);

	CloseHandle(data);

	if (hndl == null)
	{
		Store_LogError("SQL Error on SQLCall_EquipItem: %s", error);
		return;
	}

	Call_StartFunction(plugin, callback);
	Call_PushCell(accountId);
	Call_PushCell(itemId);
	Call_PushCell(loadoutId);
	Call_PushCell(arg);
	Call_Finish();
}

void UnequipItem(int accountId, int itemId, int loadoutId, Store_EquipItemCallback callback, Handle plugin = null, any data = 0)
{
	if (!IsDatabaseConnected())
	{
		return;
	}

	Handle hPack = CreateDataPack();
	WritePackCell(hPack, accountId);
	WritePackCell(hPack, itemId);
	WritePackCell(hPack, loadoutId);
	WritePackFunction(hPack, callback);
	WritePackCell(hPack, plugin);
	WritePackCell(hPack, data);

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_UnequipItem, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, accountId, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, itemId);

	if (loadoutId != -1)
	{
		Format(sQuery, sizeof(sQuery), sQuery_UnequipItem_loadoutId, sQuery, STORE_DATABASE_PREFIX, loadoutId);
	}

	Store_Local_TQuery("UnequipItem", SQLCall_UnequipItem, sQuery, hPack);
}

public void SQLCall_UnequipItem(Handle owner, Handle hndl, const char[] error, any data)
{
	ResetPack(data);

	int accountId = ReadPackCell(data);
	int itemId = ReadPackCell(data);
	int loadoutId = ReadPackCell(data);
	Store_GiveCreditsCallback callback = view_as<Store_GiveCreditsCallback>(ReadPackFunction(data));
	Handle plugin = view_as<Handle>(ReadPackCell(data));
	int arg = ReadPackCell(data);

	CloseHandle(data);

	if (hndl == null)
	{
		Store_LogError("SQL Error on SQLCall_UnequipItem: %s", error);
		return;
	}

	Call_StartFunction(plugin, callback);
	Call_PushCell(accountId);
	Call_PushCell(itemId);
	Call_PushCell(loadoutId);
	Call_PushCell(arg);
	Call_Finish();
}

void GetEquippedItemsByType(int accountId, const char[] type, int loadoutId, Store_GetItemsCallback callback, Handle plugin = null, any data = 0)
{
	if (!IsDatabaseConnected())
	{
		return;
	}

	Handle hPack = CreateDataPack();
	WritePackFunction(hPack, callback);
	WritePackCell(hPack, plugin);
	WritePackCell(hPack, data);

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_GetEquippedItemsByType, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, accountId, STORE_DATABASE_PREFIX, type, STORE_DATABASE_PREFIX, loadoutId);
	Store_Local_TQuery("GetEquipptedItemsByType", SQLCall_GetEquippedItemsByType, sQuery, hPack);
}

public void SQLCall_GetEquippedItemsByType(Handle owner, Handle hndl, const char[] error, any data)
{
	ResetPack(data);

	Store_GetItemsCallback callback = view_as<Store_GetItemsCallback>(ReadPackFunction(data));
	Handle plugin = view_as<Handle>(ReadPackCell(data));
	int arg = ReadPackCell(data);

	CloseHandle(data);

	if (hndl == null)
	{
		Store_LogError("SQL Error on SQLCall_GetEquippedItemsByType: %s", error);
		return;
	}

	int count = SQL_GetRowCount(hndl);
	int[] ids = new int[count];

	int index = 0;
	while (SQL_FetchRow(hndl))
	{
		ids[index] = SQL_FetchInt(hndl, 0);
		index++;
	}

	Call_StartFunction(plugin, callback);
	Call_PushArray(ids, count);
	Call_PushCell(count);
	Call_PushCell(arg);
	Call_Finish();
}

void GiveCredits(int accountId, int credits, Store_GiveCreditsCallback callback, Handle plugin = null, any data = 0)
{
	if (!IsDatabaseConnected())
	{
		return;
	}

	Handle hPack = CreateDataPack();
	WritePackCell(hPack, accountId);
	WritePackCell(hPack, credits);
	WritePackFunction(hPack, callback);
	WritePackCell(hPack, plugin);
	WritePackCell(hPack, data);

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_GiveCredits, STORE_DATABASE_PREFIX, credits, accountId);
	Store_Local_TQuery("GiveCredits", SQLCall_GiveCredits, sQuery, hPack);
}

public void SQLCall_GiveCredits(Handle owner, Handle hndl, const char[] error, any data)
{
	ResetPack(data);

	int accountId = ReadPackCell(data);
	int credits = ReadPackCell(data);
	Store_GiveCreditsCallback callback = view_as<Store_GiveCreditsCallback>(ReadPackFunction(data));
	Handle plugin = view_as<Handle>(ReadPackCell(data));
	int arg = ReadPackCell(data);

	CloseHandle(data);

	if (hndl == null)
	{
		Store_LogError("SQL Error on SQLCall_GiveCredits: %s", error);
		return;
	}

	if (callback != INVALID_FUNCTION)
	{
		Call_StartFunction(plugin, callback);
		Call_PushCell(accountId);
		Call_PushCell(credits);
		Call_PushCell(arg);
		Call_Finish();
	}
}

void RemoveCredits(int accountId, int credits, Store_RemoveCreditsCallback callback, Handle plugin = null, any data = 0)
{
	if (!IsDatabaseConnected())
	{
		return;
	}

	Handle hPack = CreateDataPack();
	WritePackCell(hPack, accountId);
	WritePackCell(hPack, credits);
	WritePackFunction(hPack, callback);
	WritePackCell(hPack, plugin);
	WritePackCell(hPack, data);

	bool bIsNegative;
	if (Store_GetCreditsEx(accountId) < credits)
	{
		bIsNegative = true;
		WritePackCell(hPack, bIsNegative);

		char sQuery[MAX_QUERY_SIZE];
		Format(sQuery, sizeof(sQuery), sQuery_RemoveCredits_Negative, STORE_DATABASE_PREFIX, accountId);
		Store_Local_TQuery("RemoveCredits", SQLCall_RemoveCredits, sQuery, hPack);

		return;
	}

	WritePackCell(hPack, bIsNegative);

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_RemoveCredits, STORE_DATABASE_PREFIX, credits, accountId);
	Store_Local_TQuery("RemoveCredits", SQLCall_RemoveCredits, sQuery, hPack);
}

public void SQLCall_RemoveCredits(Handle owner, Handle hndl, const char[] error, any data)
{
	ResetPack(data);

	int accountId = ReadPackCell(data);
	int credits = ReadPackCell(data);
	Store_RemoveCreditsCallback callback = view_as<Store_RemoveCreditsCallback>(ReadPackFunction(data));
	Handle plugin = view_as<Handle>(ReadPackCell(data));
	int arg = ReadPackCell(data);
	int bIsNegative = view_as<bool>(ReadPackCell(data));

	CloseHandle(data);

	if (hndl == null)
	{
		Store_LogError("SQL Error on SQLCall_RemoveCredits: %s", error);
		return;
	}

	if (callback != INVALID_FUNCTION)
	{
		Call_StartFunction(plugin, callback);
		Call_PushCell(accountId);
		Call_PushCell(credits);
		Call_PushCell(bIsNegative);
		Call_PushCell(arg);
		Call_Finish();
	}
}

void GiveItem(int accountId, int itemId, Store_AcquireMethod acquireMethod = Store_Unknown, Store_AccountCallback callback, Handle plugin = null, any data = 0)
{
	if (!IsDatabaseConnected())
	{
		return;
	}

	Handle hPack = CreateDataPack();
	WritePackCell(hPack, accountId);
	WritePackFunction(hPack, callback);
	WritePackCell(hPack, plugin);
	WritePackCell(hPack, data);

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_GiveItem, STORE_DATABASE_PREFIX, STORE_DATABASE_PREFIX, itemId);

	switch (acquireMethod)
	{
		case Store_Shop: Format(sQuery, sizeof(sQuery), sQuery_GiveItem_Shop, sQuery);
		case Store_Trade: Format(sQuery, sizeof(sQuery), sQuery_GiveItem_Trade, sQuery);
		case Store_Gift: Format(sQuery, sizeof(sQuery), sQuery_GiveItem_Gift, sQuery);
		case Store_Admin: Format(sQuery, sizeof(sQuery), sQuery_GiveItem_Admin, sQuery);
		case Store_Web: Format(sQuery, sizeof(sQuery), sQuery_GiveItem_Web, sQuery);
		case Store_Unknown: Format(sQuery, sizeof(sQuery), sQuery_GiveItem_Unknown, sQuery);
	}

	Format(sQuery, sizeof(sQuery), sQuery_GiveItem_End, sQuery, STORE_DATABASE_PREFIX, accountId);
	Store_Local_TQuery("GiveItem", SQLCall_GiveItem, sQuery, hPack);
}

public void SQLCall_GiveItem(Handle owner, Handle hndl, const char[] error, any data)
{
	ResetPack(data);

	int accountId = ReadPackCell(data);
	Store_AccountCallback callback = view_as<Store_AccountCallback>(ReadPackFunction(data));
	Handle plugin = view_as<Handle>(ReadPackCell(data));
	int arg = ReadPackCell(data);

	CloseHandle(data);

	if (hndl == null)
	{
		Store_LogError("SQL Error on SQLCall_GiveItem: %s", error);
		return;
	}

	if (callback != INVALID_FUNCTION)
	{
		Call_StartFunction(plugin, callback);
		Call_PushCell(accountId);
		Call_PushCell(arg);
		Call_Finish();
	}
}

void GiveCreditsToUsers(int[] accountIds, int accountIdsLength, int credits)
{
	if (!IsDatabaseConnected())
	{
		return;
	}

	if (accountIdsLength == 0)
	{
		return;
	}

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_GiveCreditsToUsers, STORE_DATABASE_PREFIX, credits);

	for (int i = 0; i < accountIdsLength; i++)
	{
		Format(sQuery, sizeof(sQuery), "%s%d", sQuery, accountIds[i]);

		if (i < accountIdsLength - 1)
		{
			Format(sQuery, sizeof(sQuery), "%s, ", sQuery);
		}
	}

	Format(sQuery, sizeof(sQuery), sQuery_GiveCreditsToUsers_End, sQuery);
	Store_Local_TQuery("GiveCreditsToUsers", SQLCall_GiveCreditsToUsers, sQuery);
}

public void SQLCall_GiveCreditsToUsers(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		Store_LogError("SQL Error on SQLCall_GiveCreditsToUsers: %s", error);
		return;
	}
}

void RemoveCreditsFromUsers(int[] accountIds, int accountIdsLength, int credits)
{
	if (!IsDatabaseConnected())
	{
		return;
	}

	if (accountIdsLength == 0)
	{
		return;
	}

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_RemoveCreditsFromUsers, STORE_DATABASE_PREFIX, credits);

	for (int i = 0; i < accountIdsLength; i++)
	{
		Format(sQuery, sizeof(sQuery), "%s%d", sQuery, accountIds[i]);

		if (i < accountIdsLength - 1)
		{
			Format(sQuery, sizeof(sQuery), "%s, ", sQuery);
		}
	}

	Format(sQuery, sizeof(sQuery), sQuery_RemoveCreditsFromUsers_End, sQuery);
	Store_Local_TQuery("RemoveCreditsFromUsers", SQLCall_RemoveCreditsFromUsers, sQuery);
}

public void SQLCall_RemoveCreditsFromUsers(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		Store_LogError("SQL Error on RemoveCreditsFromUsers: %s", error);
		return;
	}
}

void GiveDifferentCreditsToUsers(int[] accountIds, int accountIdsLength, int[] credits)
{
	if (!IsDatabaseConnected())
	{
		return;
	}

	if (accountIdsLength == 0)
	{
		return;
	}

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_GiveDifferentCreditsToUsers, STORE_DATABASE_PREFIX);

	for (int i = 0; i < accountIdsLength; i++)
	{
		Format(sQuery, sizeof(sQuery), sQuery_RemoveDifferentCreditsFromUsers_accountIdsLength, sQuery, accountIds[i], credits[i]);
	}

	Format(sQuery, sizeof(sQuery), sQuery_GiveDifferentCreditsToUsers_End, sQuery);

	for (int i = 0; i < accountIdsLength; i++)
	{
		Format(sQuery, sizeof(sQuery), "%s%d", sQuery, accountIds[i]);

		if (i < accountIdsLength - 1)
		{
			Format(sQuery, sizeof(sQuery), "%s, ", sQuery);
		}
	}

	Format(sQuery, sizeof(sQuery), "%s)", sQuery);
	Store_Local_TQuery("GiveDifferentCreditsToUsers", SQLCall_GiveDifferentCreditsToUsers, sQuery);
}

public void SQLCall_GiveDifferentCreditsToUsers(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		Store_LogError("SQL Error on GiveDifferentCreditsToUsers: %s", error);
		return;
	}
}

void RemoveDifferentCreditsFromUsers(int[] accountIds, int accountIdsLength, int[] credits)
{
	if (!IsDatabaseConnected())
	{
		return;
	}

	if (accountIdsLength == 0)
	{
		return;
	}

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_RemoveDifferentCreditsFromUsers, STORE_DATABASE_PREFIX);

	for (int i = 0; i < accountIdsLength; i++)
	{
		Format(sQuery, sizeof(sQuery), sQuery_GiveDifferentCreditsToUsers_accountIdsLength, sQuery, accountIds[i], credits[i]);
	}

	Format(sQuery, sizeof(sQuery), sQuery_RemoveDifferentCreditsFromUsers_End, sQuery);

	for (int i = 0; i < accountIdsLength; i++)
	{
		Format(sQuery, sizeof(sQuery), "%s%d", sQuery, accountIds[i]);

		if (i < accountIdsLength - 1)
		{
			Format(sQuery, sizeof(sQuery), "%s, ", sQuery);
		}
	}

	Format(sQuery, sizeof(sQuery), "%s)", sQuery);
	Store_Local_TQuery("RemoveDifferentCreditsFromUsers", SQLCall_RemoveDifferentCreditsFromUsers, sQuery);
}

public void SQLCall_RemoveDifferentCreditsFromUsers(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		Store_LogError("SQL Error on SQLCall_RemoveDifferentCreditsFromUsers: %s", error);
		return;
	}
}

bool ReloadCacheStacks(int client = 0)
{
	if (!IsDatabaseConnected())
	{
		return false;
	}

	if (GetCategories(client, INVALID_FUNCTION, null, false, "", 0))
	{
		CPrintToChatAll("%t%t", "Store Tag Colored", "Reloaded categories");
	}

	if (GetItems(client, null, INVALID_FUNCTION, null, false, "", 0))
	{
		CPrintToChatAll("%t%t", "Store Tag Colored", "Reloaded items");
	}

	GetCacheStacks();
	return true;
}

void ConnectSQL()
{
	if (g_hSQL != null)
	{
		CloseHandle(g_hSQL);
		g_hSQL = null;
	}

	char sBuffer[64];
	Store_GetSQLEntry(sBuffer, sizeof(sBuffer));

	if (SQL_CheckConfig(sBuffer))
	{
		SQL_TConnect(SQLCall_ConnectToDatabase, sBuffer);
	}
	else
	{
		SetFailState("No config entry found for '%s' in databases.cfg.", sBuffer);
	}
}

public void SQLCall_ConnectToDatabase(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		Store_LogError("Connection to SQL database has failed! Error: %s", error);
		return;
	}

	g_hSQL = hndl;
	SQL_SetCharset(g_hSQL, "utf8");

	if (g_hSQL == null)
	{
		Store_LogError("Error connecting to database, contact a developer as this is a plugin issue.");
		return;
	}

	Transaction trans = SQL_CreateTransaction();

	char sQuery[MAX_QUERY_SIZE];

	Format(sQuery, sizeof(sQuery), sQuery_CreateTable_Categories, STORE_DATABASE_PREFIX);
	SQL_AddQuery(trans, sQuery);

	Format(sQuery, sizeof(sQuery), sQuery_CreateTable_Items, STORE_DATABASE_PREFIX);
	SQL_AddQuery(trans, sQuery);

	Format(sQuery, sizeof(sQuery), sQuery_CreateTable_Loadouts, STORE_DATABASE_PREFIX);
	SQL_AddQuery(trans, sQuery);

	Format(sQuery, sizeof(sQuery), sQuery_CreateTable_Users, STORE_DATABASE_PREFIX, MAX_TOKEN_SIZE);
	SQL_AddQuery(trans, sQuery);

	Format(sQuery, sizeof(sQuery), sQuery_CreateTable_Users_Items, STORE_DATABASE_PREFIX);
	SQL_AddQuery(trans, sQuery);

	Format(sQuery, sizeof(sQuery), sQuery_CreateTable_Users_Items_Loadouts, STORE_DATABASE_PREFIX);
	SQL_AddQuery(trans, sQuery);

	Format(sQuery, sizeof(sQuery), sQuery_CreateTable_Versions, STORE_DATABASE_PREFIX);
	SQL_AddQuery(trans, sQuery);

	Format(sQuery, sizeof(sQuery), sQuery_CreateTable_Servers_Categories, STORE_DATABASE_PREFIX);
	SQL_AddQuery(trans, sQuery);

	Format(sQuery, sizeof(sQuery), sQuery_CreateTable_Servers_Items, STORE_DATABASE_PREFIX);
	SQL_AddQuery(trans, sQuery);

	Store_SQL_ExecuteTransaction(trans);

	Store_RegisterPluginModule(PLUGIN_NAME, PLUGIN_DESCRIPTION, PLUGIN_VERSION_CONVAR, STORE_VERSION);

	Call_StartForward(g_dbInitializedForward);
	Call_PushCell(g_hSQL);
	Call_Finish();

	ReloadCacheStacks();
}

public void TQuery_CreateTable(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		Store_LogError("Error while creating a new table: %s", error);
		return;
	}
}

void Store_Local_TQuery(const char[] sQueryName, SQLTCallback callback, const char[] sQuery, any data = 0)
{
	SQL_TQuery(g_hSQL, callback, sQuery, data, g_queryPriority);
	//LogMessage("sQueryName: %s", sQueryName);

	if (g_printSQLQueries && strlen(sQueryName) != 0 && strlen(sQuery) != 0)
	{
		Store_LogDebug("SQL Query: [%s] [%s]", sQueryName, sQuery);
	}
}

bool IsDatabaseConnected()
{
	return g_hSQL != null;
}

////////////////////
//Natives
public int Native_ReloadCacheStacks(Handle plugin, int numParams)
{
	ReloadCacheStacks();
}

public int Native_RegisterPluginModule(Handle plugin, int numParams)
{
	if (!IsDatabaseConnected())
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Error registering plugin to database, not connected.");
		return;
	}

	int ServerID = Store_GetServerID();

	int length;
	GetNativeStringLength(1, length);

	char[] sName = new char[length + 1];
	GetNativeString(1, sName, length + 1);

	int length2;
	GetNativeStringLength(2, length2);

	char[] sDescription = new char[length2 + 1];
	GetNativeString(2, sDescription, length2 + 1);

	int length3;
	GetNativeStringLength(3, length3);

	char[] sVersion_ConVar = new char[length3 + 1];
	GetNativeString(3, sVersion_ConVar, length3 + 1);

	int length4;
	GetNativeStringLength(4, length4);

	char[] sVersion = new char[length4 + 1];
	GetNativeString(4, sVersion, length4 + 1);

	if (ServerID <= 0)
	{
		Store_LogError("Error registering module '%s - %s' due to ServerID being 0 or below, please fix this issue.", sName, sVersion);
		return;
	}

	int time = GetTime();

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_RegisterPluginModule, STORE_DATABASE_PREFIX, sName, sDescription, sVersion_ConVar, sVersion, ServerID, time, time, time);
	Store_Local_TQuery("RegisterPluginModule", SQLCall_RegisterPluginModule, sQuery);
}

public int Native_GetStoreBaseURL(Handle plugin, int numParams)
{
	SetNativeString(1, g_baseURL, GetNativeCell(2));
}

public int Native_OpenMOTDWindow(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!client || !IsClientInGame(client))
	{
		return false;
	}

	int size;

	GetNativeStringLength(2, size);

	char[] sTitle = new char[size + 1];
	GetNativeString(2, sTitle, size + 1);

	GetNativeStringLength(3, size);

	char[] sURL = new char[size + 1];
	GetNativeString(3, sURL, size + 1);

	char sSound[PLATFORM_MAX_PATH];
	GetNativeString(4, sSound, sizeof(sSound));

	switch (GetEngineVersion())
	{
		case Engine_CSGO:
		{
			ShowMOTDPanel(client, sTitle, sURL, MOTDPANEL_TYPE_URL);
		}

		default:
		{
			Handle Radio = CreateKeyValues("motd");
			KvSetString(Radio, "title", sTitle);
			KvSetString(Radio, "type", "2");
			KvSetString(Radio, "msg", sURL);
			KvSetNum(Radio, "cmd", 5);
			KvSetNum(Radio, "customsvr", g_motdFullscreen ? 1 : 0);
			ShowVGUIPanel(client, "info", Radio, true);
			CloseHandle(Radio);
		}
	}

	if (g_motdSound && strlen(sSound) != 0)
	{
		EmitSoundToClient(client, sSound);
	}

	return true;
}

public int Native_OpenMainMenu(Handle plugin, int params)
{
	OpenMainMenu(GetNativeCell(1));
}

public int Native_AddMainMenuItem(Handle plugin, int params)
{
	char displayName[32];
	GetNativeString(1, displayName, sizeof(displayName));

	char description[128];
	GetNativeString(2, description, sizeof(description));

	char value[64];
	GetNativeString(3, value, sizeof(value));

	AddMainMenuItem(true, displayName, description, value, plugin, view_as<Store_MenuItemClickCallback>(GetNativeFunction(4)), GetNativeCell(5));
}

public int Native_AddMainMenuItemEx(Handle plugin, int params)
{
	char displayName[32];
	GetNativeString(1, displayName, sizeof(displayName));

	char description[128];
	GetNativeString(2, description, sizeof(description));

	char value[64];
	GetNativeString(3, value, sizeof(value));

	AddMainMenuItem(false, displayName, description, value, plugin, view_as<Store_MenuItemClickCallback>(GetNativeFunction(4)), GetNativeCell(5));
}

public int Native_GetCurrencyName(Handle plugin, int params)
{
	SetNativeString(1, g_currencyName, GetNativeCell(2));
}

public int Native_GetSQLEntry(Handle plugin, int params)
{
	SetNativeString(1, g_sqlconfigentry, GetNativeCell(2));
}

public int Native_RegisterChatCommands(Handle plugin, int params)
{
	char command[32];
	GetNativeString(1, command, sizeof(command));

	return RegisterCommands(plugin, command, view_as<Store_ChatCommandCallback>(GetNativeFunction(2)));
}

public int Native_GetServerID(Handle plugin, int params)
{
	if (g_serverID < 0)
	{
		char sPluginName[128];
		GetPluginInfo(plugin, PlInfo_Name, sPluginName, sizeof(sPluginName));

		Store_LogError("Plugin Module '%s' attempted to get the serverID when It's currently set to a number below 0.", sPluginName);
		ThrowNativeError(SP_ERROR_NATIVE, "Error retrieving ServerID, less than zero.");

		return g_serverID;
	}

	return g_serverID;
}

public int Native_ClientIsDeveloper(Handle plugin, int params)
{
	return bDeveloperMode[GetNativeCell(1)];
}

public int Native_GetClientToken(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (strlen(sClientToken[client]) == 0)
	{
		char sToken[MAX_TOKEN_SIZE];
		GenerateRandomToken(sToken);
		strcopy(sClientToken[client], MAX_TOKEN_SIZE, sToken);
	}

	SetNativeString(2, sClientToken[client], GetNativeCell(3));
}

public int Native_GenerateNewToken(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	char sToken[MAX_TOKEN_SIZE];
	GenerateRandomToken(sToken);
	strcopy(sClientToken[client], MAX_TOKEN_SIZE, sToken);

	Store_SaveClientToken(client, sToken);
}

/////
//User Natives
public int Native_Register(Handle plugin, int numParams)
{
	char name[MAX_NAME_LENGTH];
	GetNativeString(2, name, sizeof(name));

	Register(GetNativeCell(1), name, GetNativeCell(3));
}

public int Native_RegisterClient(Handle plugin, int numParams)
{
	RegisterClient(GetNativeCell(1), GetNativeCell(2));
}

public int Native_GetClientAccountID(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int AccountID = GetSteamAccountID(client);

	if (AccountID == 0)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Error retrieving client Steam Account ID %L.", client);
		return -1;
	}

	return AccountID;
}

public int Native_GetClientUserID(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int user_id = -1;

	if (!IsDatabaseConnected())
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Error retrieving client '%L' database userid, not connected.", client);
		return user_id;
	}

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_GetClientUserID, STORE_DATABASE_PREFIX, GetSteamAccountID(client));
	Handle hQuery = SQL_Query(g_hSQL, sQuery);

	if (hQuery == null)
	{
		char sError[512];
		SQL_GetError(g_hSQL, sError, sizeof(sError));
		Store_LogError("SQL Error on Native_GetClientUserID: %s", sError);
		return user_id;
	}

	if (SQL_FetchRow(hQuery))
	{
		user_id = SQL_FetchInt(hQuery, 0);
	}

	CloseHandle(hQuery);

	return user_id;
}

public int Native_SaveClientToken(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!IsDatabaseConnected())
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Error saving client '%L' token to database, not connected.", client);
		return;
	}

	char sToken[MAX_TOKEN_SIZE];
	GetNativeString(2, sToken, sizeof(sToken));

	bool bVerbose = view_as<bool>(GetNativeCell(3));

	Handle hPack = CreateDataPack();
	WritePackCell(hPack, GetClientUserId(client));
	WritePackString(hPack, sToken);
	WritePackCell(hPack, bVerbose);

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_GenerateNewToken, STORE_DATABASE_PREFIX, sToken, GetSteamAccountID(client));
	Store_Local_TQuery("GenerateNewToken", SQLCall_GenerateNewToken, sQuery, hPack);
}

public int Native_GetUserItems(Handle plugin, int numParams)
{
	GetUserItems(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3), view_as<Store_GetUserItemsCallback>(GetNativeFunction(4)), plugin, view_as<any>(GetNativeCell(5)));
}

public int Native_GetUserItemsCount(Handle plugin, int numParams)
{
	char itemName[STORE_MAX_NAME_LENGTH];
	GetNativeString(2, itemName, sizeof(itemName));

	GetUserItemsCount(GetNativeCell(1), itemName, view_as<Store_GetUserItemsCountCallback>(GetNativeFunction(3)), plugin, view_as<any>(GetNativeCell(4)));
}

public int Native_GetCredits(Handle plugin, int numParams)
{
	GetCredits(GetNativeCell(1), view_as<Store_GetCreditsCallback>(GetNativeFunction(2)), plugin, view_as<any>(GetNativeCell(3)));
}

public int Native_GetCreditsEx(Handle plugin, int numParams)
{
	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_GetCreditsEx, STORE_DATABASE_PREFIX, GetNativeCell(1));
	Handle hQuery = SQL_Query(g_hSQL, sQuery);

	int credits = -1;

	if (hQuery == null)
	{
		char sError[512];
		SQL_GetError(g_hSQL, sError, sizeof(sError));
		Store_LogError("SQL Error on GetCreditsEx: %s", sError);
		return credits;
	}

	if (SQL_FetchRow(hQuery))
	{
		credits = SQL_FetchInt(hQuery, 0);
	}

	CloseHandle(hQuery);

	return credits;
}

public int Native_GiveCredits(Handle plugin, int numParams)
{
	GiveCredits(GetNativeCell(1), GetNativeCell(2), view_as<Store_GiveCreditsCallback>(GetNativeFunction(3)), plugin, view_as<any>(GetNativeCell(4)));
}

public int Native_GiveCreditsToUsers(Handle plugin, int numParams)
{
	int length = GetNativeCell(2);

	int[] accountIds = new int[length];
	GetNativeArray(1, accountIds, length);

	GiveCreditsToUsers(accountIds, length, GetNativeCell(3));
}

public int Native_GiveDifferentCreditsToUsers(Handle plugin, int params)
{
	int length = GetNativeCell(2);

	int[] accountIds = new int[length];
	GetNativeArray(1, accountIds, length);

	int[] credits = new int[length];
	GetNativeArray(3, credits, length);

	GiveDifferentCreditsToUsers(accountIds, length, credits);
}

public int Native_GiveItem(Handle plugin, int numParams)
{
	GiveItem(GetNativeCell(1), GetNativeCell(2), view_as<Store_AcquireMethod>(GetNativeCell(3)), view_as<Store_AccountCallback>(GetNativeFunction(4)), plugin, view_as<any>(GetNativeCell(5)));
}

public int Native_RemoveCredits(Handle plugin, int numParams)
{
	RemoveCredits(GetNativeCell(1), GetNativeCell(2), view_as<Store_RemoveCreditsCallback>(GetNativeFunction(3)), plugin, view_as<any>(GetNativeCell(4)));
}

public int Native_RemoveCreditsFromUsers(Handle plugin, int numParams)
{
	int length = GetNativeCell(2);

	int[] accountIds = new int[length];
	GetNativeArray(1, accountIds, length);

	RemoveCreditsFromUsers(accountIds, length, GetNativeCell(3));
}

public int Native_RemoveDifferentCreditsFromUsers(Handle plugin, int numParams)
{
	int length = GetNativeCell(2);

	int[] accountIds = new int[length];
	GetNativeArray(1, accountIds, length);

	int[] credits = new int[length];
	GetNativeArray(3, credits, length);

	RemoveDifferentCreditsFromUsers(accountIds, length, credits);
}

public int Native_BuyItem(Handle plugin, int numParams)
{
	BuyItem(GetNativeCell(1), GetNativeCell(2), view_as<Store_BuyItemCallback>(GetNativeFunction(3)), plugin, view_as<any>(GetNativeCell(4)));
}

public int Native_RemoveUserItem(Handle plugin, int numParams)
{
	RemoveUserItem(GetNativeCell(1), GetNativeCell(2), view_as<Store_UseItemCallback>(GetNativeFunction(3)), plugin, view_as<any>(GetNativeCell(4)));
}

public int Native_SetItemEquippedState(Handle plugin, int numParams)
{
	SetItemEquippedState(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3), GetNativeCell(4), view_as<Store_EquipItemCallback>(GetNativeFunction(5)), plugin, view_as<any>(GetNativeCell(6)));
}

public int Native_GetEquippedItemsByType(Handle plugin, int numParams)
{
	char type[32];
	GetNativeString(2, type, sizeof(type));

	GetEquippedItemsByType(GetNativeCell(1), type, GetNativeCell(3), view_as<Store_GetItemsCallback>(GetNativeFunction(4)), plugin, view_as<any>(GetNativeCell(5)));
}

/////
//Categories Natives
public int Native_GetCategories(Handle plugin, int numParams)
{
	int length;
	GetNativeStringLength(3, length);

	char[] sString = new char[length + 1];
	GetNativeString(3, sString, length + 1);

	GetCategories(0, view_as<Store_GetItemsCallback>(GetNativeFunction(1)), plugin, GetNativeCell(2), sString, view_as<any>(GetNativeCell(4)));
}

public int Native_GetCategoryPriority(Handle plugin, int numParams)
{
	int index = GetCategoryIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Categories, index);

	return GetArrayCell(hArray, 1);
}

public int Native_GetCategoryDisplayName(Handle plugin, int numParams)
{
	int index = GetCategoryIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Categories, index);

	char sDisplayName[STORE_MAX_DISPLAY_NAME_LENGTH];
	GetArrayString(hArray, 2, sDisplayName, sizeof(sDisplayName));

	SetNativeString(2, sDisplayName, GetNativeCell(3));
}

public int Native_GetCategoryDescription(Handle plugin, int numParams)
{
	int index = GetCategoryIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Categories, index);

	char sDescription[STORE_MAX_DESCRIPTION_LENGTH];
	GetArrayString(hArray, 3, sDescription, sizeof(sDescription));

	SetNativeString(2, sDescription, GetNativeCell(3));
}

public int Native_GetCategoryPluginRequired(Handle plugin, int numParams)
{
	int index = GetCategoryIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Categories, index);

	char sRequiredPlugin[STORE_MAX_REQUIREPLUGIN_LENGTH];
	GetArrayString(hArray, 4, sRequiredPlugin, sizeof(sRequiredPlugin));

	SetNativeString(2, sRequiredPlugin, GetNativeCell(3));
}

public int Native_GetCategoryServerRestriction(Handle plugin, int numParams)
{
	int index = GetCategoryIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Categories, index);

	return GetArrayCell(hArray, 5);
}

public int Native_ProcessCategory(Handle plugin, int numParams)
{
	int ServerID = GetNativeCell(1);
	int CategoryID = GetNativeCell(2);

	if (ServerID <= 0)
	{
		return true;
	}

	for (int i = 0; i < GetArraySize(hCategoriesCache); i++)
	{
		int array_process[2];
		GetArrayArray(hCategoriesCache, i, array_process);

		if (array_process[0] == CategoryID && array_process[1] == ServerID)
		{
			return true;
		}
	}

	return true;
}

/////
//Item Natives
public int Native_GetItems(Handle plugin, int numParams)
{
	int length;
	GetNativeStringLength(4, length);

	char[] sString = new char[length + 1];
	GetNativeString(4, sString, length + 1);

	GetItems(0, GetNativeCell(1), view_as<Store_GetItemsCallback>(GetNativeFunction(2)), plugin, GetNativeCell(3), sString, view_as<any>(GetNativeCell(5)));
}

public int Native_GetItemPriority(Handle plugin, int numParams)
{
	int index = GetItemIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Items, index);

	return GetArrayCell(hArray, 1);
}

public int Native_GetItemName(Handle plugin, int numParams)
{
	int index = GetItemIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Items, index);

	char sName[STORE_MAX_NAME_LENGTH];
	GetArrayString(hArray, 2, sName, sizeof(sName));

	SetNativeString(2, sName, GetNativeCell(3));
}

public int Native_GetItemDisplayName(Handle plugin, int numParams)
{
	int index = GetItemIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Items, index);

	char sDisplayName[STORE_MAX_DISPLAY_NAME_LENGTH];
	GetArrayString(hArray, 3, sDisplayName, sizeof(sDisplayName));

	SetNativeString(2, sDisplayName, GetNativeCell(3));
}

public int Native_GetItemDescription(Handle plugin, int numParams)
{
	int index = GetItemIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Items, index);

	char sDescription[STORE_MAX_DESCRIPTION_LENGTH];
	GetArrayString(hArray, 4, sDescription, sizeof(sDescription));

	SetNativeString(2, sDescription, GetNativeCell(3));
}

public int Native_GetItemType(Handle plugin, int numParams)
{
	int index = GetItemIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Items, index);

	char sItemType[STORE_MAX_TYPE_LENGTH];
	GetArrayString(hArray, 5, sItemType, sizeof(sItemType));

	SetNativeString(2, sItemType, GetNativeCell(3));
}

public int Native_GetItemLoadoutSlot(Handle plugin, int numParams)
{
	int index = GetItemIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Items, index);

	char sLoadoutSlot[STORE_MAX_LOADOUTSLOT_LENGTH];
	GetArrayString(hArray, 6, sLoadoutSlot, sizeof(sLoadoutSlot));

	SetNativeString(2, sLoadoutSlot, GetNativeCell(3));
}

public int Native_GetItemPrice(Handle plugin, int numParams)
{
	int index = GetItemIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Items, index);

	return GetArrayCell(hArray, 7);
}

public int Native_GetItemCategory(Handle plugin, int numParams)
{
	int index = GetItemIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Items, index);

	return GetArrayCell(hArray, 8);
}

public int Native_IsItemBuyable(Handle plugin, int numParams)
{
	int index = GetItemIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Items, index);

	return GetArrayCell(hArray, 9);
}

public int Native_IsItemTradeable(Handle plugin, int numParams)
{
	int index = GetItemIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Items, index);

	return GetArrayCell(hArray, 10);
}

public int Native_IsItemRefundable(Handle plugin, int numParams)
{
	int index = GetItemIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Items, index);

	return GetArrayCell(hArray, 11);
}

public int Native_GetItemServerRestriction(Handle plugin, int numParams)
{
	int index = GetItemIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Items, index);

	return GetArrayCell(hArray, 13);
}

public int Native_GetItemAttributes(Handle plugin, int numParams)
{
	char sItemName[STORE_MAX_NAME_LENGTH];
	GetNativeString(1, sItemName, sizeof(sItemName));

	GetItemAttributes(sItemName, view_as<Store_ItemGetAttributesCallback>(GetNativeFunction(2)), plugin, view_as<any>(GetNativeCell(3)));
}

public int Native_WriteItemAttributes(Handle plugin, int numParams)
{
	char sItemName[STORE_MAX_NAME_LENGTH];
	GetNativeString(1, sItemName, sizeof(sItemName));

	int attrsLength = 10 * 1024;
	GetNativeStringLength(2, attrsLength);

	char[] attrs = new char[attrsLength + 1];
	GetNativeString(2, attrs, attrsLength + 1);

	WriteItemAttributes(sItemName, attrs, view_as<Store_BuyItemCallback>(GetNativeFunction(3)), plugin, view_as<any>(GetNativeCell(4)));
}

public int Native_ProcessItem(Handle plugin, int numParams)
{
	int ServerID = GetNativeCell(1);
	int ItemID = GetNativeCell(2);

	if (ServerID <= 0)
	{
		return true;
	}

	for (int i = 0; i < GetArraySize(hItemsCache); i++)
	{
		int array_process[2];
		GetArrayArray(hItemsCache, i, array_process);

		if (array_process[0] == ItemID && array_process[1] == ServerID)
		{
			return true;
		}
	}

	return false;
}

/////
//Loadout Natives
public int Native_GetLoadouts(Handle plugin, int numParams)
{
	GetLoadouts(GetNativeCell(1), view_as<Store_GetItemsCallback>(GetNativeFunction(2)), plugin, GetNativeCell(3), view_as<any>(GetNativeCell(4)));
}

public int Native_GetLoadoutDisplayName(Handle plugin, int numParams)
{
	int index = GetLoadoutIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Loadouts, index);

	char sDisplayName[STORE_MAX_DISPLAY_NAME_LENGTH];
	GetArrayString(hArray, 1, sDisplayName, sizeof(sDisplayName));

	SetNativeString(2, sDisplayName, GetNativeCell(3));
}

public int Native_GetLoadoutGame(Handle plugin, int numParams)
{
	int index = GetLoadoutIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Loadouts, index);

	char sGame[STORE_MAX_LOADOUTGAME_LENGTH];
	GetArrayString(hArray, 2, sGame, sizeof(sGame));

	SetNativeString(2, sGame, GetNativeCell(3));
}

public int Native_GetLoadoutClass(Handle plugin, int numParams)
{
	int index = GetLoadoutIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Loadouts, index);

	char sClass[STORE_MAX_LOADOUTCLASS_LENGTH];
	GetArrayString(hArray, 3, sClass, sizeof(sClass));

	SetNativeString(2, sClass, GetNativeCell(3));
}

public int Native_GetLoadoutTeam(Handle plugin, int numParams)
{
	int index = GetLoadoutIndex(GetNativeCell(1));
	Handle hArray = GetArrayCell(hArray_Loadouts, index);

	return GetArrayCell(hArray, 4);
}

public int Native_GetClientLoadouts(Handle plugin, int numParams)
{
	GetClientLoadouts(GetNativeCell(1), view_as<Store_GetUserLoadoutsCallback>(GetNativeFunction(2)), plugin, view_as<any>(GetNativeCell(3)));
}

public int Native_QueryEquippedLoadout(Handle plugin, int numParams)
{
	QueryEquippedLoadout(GetNativeCell(1), view_as<Store_GetUserEquippedLoadoutCallback>(GetNativeFunction(2)), plugin, view_as<any>(GetNativeCell(3)));
}

public int Native_SaveEquippedLoadout(Handle plugin, int numParams)
{
	SaveEquippedLoadout(GetNativeCell(1), GetNativeCell(2), view_as<Store_SaveUserEquippedLoadoutCallback>(GetNativeFunction(3)), plugin, view_as<any>(GetNativeCell(4)));
}

/////
//SQL Natives
public int Native_SQLTQuery(Handle plugin, int numParams)
{
	if (!IsDatabaseConnected())
	{
		return;
	}

	SQLTCallback callback = view_as<SQLTCallback>(GetNativeFunction(1));

	int size;
	GetNativeStringLength(2, size);

	char[] sQuery = new char[size + 1];
	GetNativeString(2, sQuery, size + 1);

	int data = GetNativeCell(3);

	Handle hPack = CreateDataPack();
	WritePackCell(hPack, plugin);
	WritePackFunction(hPack, callback);
	WritePackCell(hPack, data);

	Store_Local_TQuery("Native", callback, sQuery, data);
}

public int Native_SQLEscapeString(Handle plugin, int numParams)
{
	int size;
	GetNativeStringLength(1, size);

	char[] sOrig = new char[size + 1];
	GetNativeString(1, sOrig, size + 1);

	size = 2 * size + 1;
	char[] sNew = new char[size + 1];
	SQL_EscapeString(g_hSQL, sOrig, sNew, size + 1);

	SetNativeString(2, sNew, size);
}

public int Native_SQL_ExecuteTransaction(Handle plugin, int numParams)
{
	Transaction trans = view_as<Transaction>(GetNativeCell(1));

	Store_SQL_Transaction_Success fSuccess = view_as<Store_SQL_Transaction_Success>(GetNativeFunction(2));
	Store_SQL_Transaction_Failure fFailure = view_as<Store_SQL_Transaction_Failure>(GetNativeFunction(3));

	any data = GetNativeCell(4);
	DBPriority prio = view_as<DBPriority>(GetNativeCell(5));

	DataPack hPack = CreateDataPack();
	WritePackCell(hPack, plugin);
	WritePackFunction(hPack, fSuccess);
	WritePackFunction(hPack, fFailure);
	WritePackCell(hPack, data);

	SQL_ExecuteTransaction(g_hSQL, trans, Native_SQL_Transaction_Success, Native_SQL_Transaction_Failure, hPack, prio);
}

public void Native_SQL_Transaction_Success(Handle db, DataPack data, int numQueries, Handle[] results, any[] queryData)
{
	ResetPack(data);

	Handle plugin = view_as<Handle>(ReadPackCell(data));
	Store_SQL_Transaction_Success callback = view_as<Store_SQL_Transaction_Success>(ReadPackFunction(data));
	ReadPackFunction(data);
	any pack_data = ReadPackCell(data);

	CloseHandle(data);

	if (callback != INVALID_FUNCTION)
	{
		Call_StartFunction(plugin, callback);
		Call_PushCell(pack_data);
		Call_PushCell(numQueries);
		Call_PushArray(results, numQueries);
		Call_PushArray(queryData, numQueries);
		Call_Finish();
	}
}

public void Native_SQL_Transaction_Failure(Handle db, DataPack data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	ResetPack(data);

	Handle plugin = view_as<Handle>(ReadPackCell(data));
	ReadPackFunction(data);
	Store_SQL_Transaction_Failure callback = view_as<Store_SQL_Transaction_Failure>(ReadPackFunction(data));
	any pack_data = ReadPackCell(data);

	CloseHandle(data);

	if (callback != INVALID_FUNCTION)
	{
		Call_StartFunction(plugin, callback);
		Call_PushCell(pack_data);
		Call_PushCell(numQueries);
		Call_PushString(error);
		Call_PushCell(failIndex);
		Call_PushArray(queryData, numQueries);
		Call_Finish();
	}
}

public int Native_SQLLogQuery(Handle plugin, int numParams)
{
	if (!IsDatabaseConnected())
	{
		return;
	}

	int size;

	GetNativeStringLength(1, size);

	char[] sSeverity = new char[size + 1];
	GetNativeString(1, sSeverity, size + 1);

	GetNativeStringLength(2, size);

	char[] sLocation = new char[size + 1];
	GetNativeString(2, sLocation, size + 1);

	GetNativeStringLength(3, size);

	char[] sMessage = new char[size + 1];
	GetNativeString(3, sMessage, size + 1);

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), sQuery_LogToDatabase, STORE_DATABASE_PREFIX, Store_GetServerID(), sSeverity, sLocation, sMessage);
	Store_Local_TQuery("Log", SQLCall_VoidQuery, sQuery);
}

public int Native_DisplayClientsMenu(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	MenuHandler hMenuHandler = view_as<MenuHandler>(GetNativeFunction(2));
	bool bExitBack = GetNativeCell(3);

	if (client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client) || hMenuHandler == INVALID_FUNCTION)
	{
		Store_LogWarning("Client index %i has requested a clients menu and failed.", client);
		return false;
	}

	Handle hMenu = CreateMenu(hMenuHandler);
	SetMenuTitle(hMenu, "Choose a client:");
	SetMenuExitBackButton(hMenu, bExitBack);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(client) || client == i)
		{
			continue;
		}

		char sID[12];
		IntToString(i, sID, sizeof(sID));

		char sName[MAX_NAME_LENGTH];
		GetClientName(i, sName, sizeof(sName));

		AddMenuItem(hMenu, sID, sName);
	}

	if (GetMenuItemCount(hMenu) < 1)
	{
		AddMenuItem(hMenu, "", "[None Found]", ITEMDRAW_DISABLED);
	}

	return DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public int Native_GetGlobalAccessType(Handle plugin, int numParams)
{
	return view_as<int>(g_accessTypes);
}

////////////////////
//Native Callbacks
public void SQLCall_RegisterPluginModule(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		Store_LogError("SQL Error on SQLCall_RegisterPluginModule: %s", error);
		return;
	}
}

public int SQLCall_GenerateNewToken(Handle owner, Handle hndl, const char[] error, any data)
{
	ResetPack(data);

	int client = GetClientOfUserId(ReadPackCell(data));

	char sToken[MAX_TOKEN_SIZE];
	ReadPackString(data, sToken, sizeof(sToken));

	bool bVerbose = view_as<bool>(ReadPackCell(data));

	CloseHandle(data);

	if (hndl == null)
	{
		Store_LogError("SQL Error on Generating a new token: %s", error);
		return;
	}

	if (client != 0 && bVerbose)
	{
		CPrintToChat(client, "Your new token has been set to '%s'.", sToken); //Translate
	}
}

public void Query_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	ResetPack(data);

	Handle plugin = view_as<Handle>(ReadPackCell(data));
	SQLTCallback callback = view_as<SQLTCallback>(ReadPackFunction(data));
	int hPack = ReadPackCell(data);

	CloseHandle(data);

	Call_StartFunction(plugin, callback);
	Call_PushCell(owner);
	Call_PushCell(hndl);
	Call_PushString(error);
	Call_PushCell(hPack);
	Call_Finish();
}

public void SQLCall_VoidQuery(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		Store_LogError("SQL Error on VoidQuery: %s", error);
		return;
	}
}
