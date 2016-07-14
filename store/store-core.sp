#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <store>

//New Syntax
#pragma newdecls required

#define PLUGIN_NAME "[Store] Core Module"
#define PLUGIN_DESCRIPTION "Core module for the Sourcemod Store."
#define PLUGIN_VERSION_CONVAR "store_core_version"

#define MAX_MENU_ITEMS 32
#define MAX_CHAT_COMMANDS 100

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

//Chat Commands Data
enum ChatCommand
{
	String:ChatCommandName[32],
	/*Handle */ChatCommandPlugin,
	Store_ChatCommandCallback:ChatCommandCallback,
}

int g_chatCommands[MAX_CHAT_COMMANDS + 1][ChatCommand];
int g_chatCommandCount;

//Config Globals
char g_currencyName[64];
char g_sqlconfigentry[64];
char g_updaterURL[2048];
bool g_hideChatCommands;
int g_firstConnectionCredits;
int g_serverID;
bool g_hideMenuItemDescriptions;
bool g_allPluginsLoaded;

//Forwards
Handle g_hOnChatCommandForward;
Handle g_hOnChatCommandPostForward;
Handle g_hOnCoreLoaded;

//Late Loads/Updater
bool bLateLoad;
bool bUpdater;

//Client Globals
bool bDeveloperMode[MAXPLAYERS + 1];

//Plugin Info
public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = STORE_AUTHORS,
	description = PLUGIN_DESCRIPTION,
	version = STORE_VERSION,
	url = STORE_URL
};

//Ask Plugin Load 2
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	//Natives
	CreateNative("Store_OpenMainMenu", Native_OpenMainMenu);
	CreateNative("Store_AddMainMenuItem", Native_AddMainMenuItem);
	CreateNative("Store_AddMainMenuItemEx", Native_AddMainMenuItemEx);
	CreateNative("Store_GetCurrencyName", Native_GetCurrencyName);
	CreateNative("Store_GetSQLEntry", Native_GetSQLEntry);
	CreateNative("Store_RegisterChatCommands", Native_RegisterChatCommands);
	CreateNative("Store_GetServerID", Native_GetServerID);
	CreateNative("Store_ClientIsDeveloper", Native_ClientIsDeveloper);
	
	//Forwards
	g_hOnChatCommandForward = CreateGlobalForward("Store_OnChatCommand", ET_Event, Param_Cell, Param_String, Param_String);
	g_hOnChatCommandPostForward = CreateGlobalForward("Store_OnChatCommand_Post", ET_Ignore, Param_Cell, Param_String, Param_String);
	g_hOnCoreLoaded = CreateGlobalForward("Store_OnCoreLoaded", ET_Ignore);

	RegPluginLibrary("store");
	bLateLoad = late;
	return APLRes_Success;
}

//On Plugin Start
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("store.phrases");
	
	//Keep the original version just to keep OCD people happy.
	CreateConVar("store_version", STORE_VERSION, "Store Version", FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_SPONLY|FCVAR_DONTRECORD);
	
	CreateConVar(PLUGIN_VERSION_CONVAR, STORE_VERSION, PLUGIN_NAME, FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_SPONLY|FCVAR_DONTRECORD);
	
	RegAdminCmd("sm_devmode", Command_DeveloperMode, ADMFLAG_ROOT, "Toggles developer mode on the client.");
	RegAdminCmd("sm_givecredits", Command_GiveCredits, ADMFLAG_ROOT, "Gives credits to a player.");
	RegAdminCmd("sm_removecredits", Command_RemoveCredits, ADMFLAG_ROOT, "Remove credits from a player.");

	g_allPluginsLoaded = false;
	
	bUpdater = LibraryExists("updater");
	
	LoadConfig();
}

public void OnConfigsExecuted()
{
	if (bLateLoad)
	{
		Call_StartForward(g_hOnCoreLoaded);
		Call_Finish();
		
		bLateLoad = false;
	}
}

public void OnAllPluginsLoaded()
{
	SortMainMenuItems();
	g_allPluginsLoaded = true;
	
	if (g_serverID > 0)
	{
		PrintToServer("%t This plugin has been assigned the ID '%i'.", "Store Tag", g_serverID);
	}
	else if (g_serverID < 0)
	{
		g_serverID = 0;
		Store_LogError("ServerID cannot be under 0, please fix this issue.");
	}
	
	char sName[32];
	if (bUpdater && GetPluginInfo(INVALID_HANDLE, PlInfo_Name, sName, sizeof(sName)))
	{
		char sURL[2048];
		Format(sURL, sizeof(sURL), "%s/%s", g_updaterURL, sName);
		Updater_AddPlugin(sURL);
	}
}

public void Store_OnDatabaseInitialized()
{
	Store_RegisterPluginModule(PLUGIN_NAME, PLUGIN_DESCRIPTION, PLUGIN_VERSION_CONVAR, STORE_VERSION);
}

public void OnLibraryAdded(const char[] name)
{
	char sName[32];
	if (StrEqual(name, "updater") && GetPluginInfo(INVALID_HANDLE, PlInfo_Name, sName, sizeof(sName)))
	{
		char sURL[2048];
		Format(sURL, sizeof(sURL), "%s/%s", g_updaterURL, sName);
		Updater_AddPlugin(sURL);
	}
}

public void LoadConfig()
{
	Handle kv = CreateKeyValues("root");

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/store/core.cfg");

	if (!FileToKeyValues(kv, path))
	{
		CloseHandle(kv);
		SetFailState("Can't read config file %s", path);
	}

	KvGetString(kv, "currency_name", g_currencyName, sizeof(g_currencyName), "Credits");
	KvGetString(kv, "sql_config_entry", g_sqlconfigentry, sizeof(g_sqlconfigentry), "default");

	if (KvJumpToKey(kv, "Commands"))
	{
		char buffer[256];

		KvGetString(kv, "mainmenu_commands", buffer, sizeof(buffer), "!store /store");
		Store_RegisterChatCommands(buffer, ChatCommand_OpenMainMenu);

		KvGetString(kv, "credits_commands", buffer, sizeof(buffer), "!credits /credits");
		Store_RegisterChatCommands(buffer, ChatCommand_Credits);

		KvGoBack(kv);
	}
	
	g_hideChatCommands = view_as<bool>KvGetNum(kv, "hide_chat_commands", 0);
	g_firstConnectionCredits = KvGetNum(kv, "first_connection_credits");
	g_hideMenuItemDescriptions = view_as<bool>KvGetNum(kv, "hide_menu_descriptions", 0);
	g_serverID = KvGetNum(kv, "server_id", 0);
	
	if (KvGetString(kv, "updater_url", g_updaterURL, sizeof(g_updaterURL)))
	{	
		char sName[32];
		if (bUpdater && g_allPluginsLoaded && GetPluginInfo(null, PlInfo_Name, sName, sizeof(sName)))
		{
			char sURL[2048];
			Format(sURL, sizeof(sURL), "%s/%s", g_updaterURL, sName);
			Updater_AddPlugin(sURL);
		}
	}
	
	CloseHandle(kv);
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

			if (cmds[0][0] == 0x2F || g_hideChatCommands)
			{
				return Plugin_Handled;
			}
			else
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

public Action Command_DeveloperMode(int client, int args)
{
	switch (bDeveloperMode[client])
	{
		case true: bDeveloperMode[client] = false;
		case false: bDeveloperMode[client] = true;
	}
	
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
	
	if (g_allPluginsLoaded)
	{
		SortMainMenuItems();
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
	SetMenuTitle(menu, "%T\n%T\n \n", "Store Menu Title", client, STORE_VERSION, "Store Menu Credits", client, credits, g_currencyName);

	for (int item = 0; item < g_menuItemCount; item++)
	{
		char text[MAX_MESSAGE_LENGTH];
		
		if(!g_hideMenuItemDescriptions)
		{
			if (g_menuItems[item][MenuItemTranslate])
			{
				Format(text, sizeof(text), "%T\n%T", g_menuItems[item][MenuItemDisplayName], client, g_menuItems[item][MenuItemDescription], client);
			}
			else
			{
				Format(text, sizeof(text), "%s\n%s", g_menuItems[item][MenuItemDisplayName], g_menuItems[item][MenuItemDescription]);
			}
		}
		else
		{
			if (g_menuItems[item][MenuItemTranslate])
			{
				Format(text, sizeof(text), "%T", g_menuItems[item][MenuItemDisplayName], client);
			}
			else
			{
				Format(text, sizeof(text), "%s", g_menuItems[item][MenuItemDisplayName]);
			}
		}

		AddMenuItem(menu, g_menuItems[item][MenuItemValue], text, g_menuItems[item][MenuItemDisabled] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 0);
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

	AddMainMenuItem(true, displayName, description, value, plugin, view_as<Store_MenuItemClickCallback>GetNativeFunction(4), GetNativeCell(5));
}

public int Native_AddMainMenuItemEx(Handle plugin, int params)
{
	char displayName[32];
	GetNativeString(1, displayName, sizeof(displayName));

	char description[128];
	GetNativeString(2, description, sizeof(description));

	char value[64];
	GetNativeString(3, value, sizeof(value));

	AddMainMenuItem(false, displayName, description, value, plugin, view_as<Store_MenuItemClickCallback>GetNativeFunction(4), GetNativeCell(5));
}

public int Native_GetCurrencyName(Handle plugin, int params)
{
	SetNativeString(1, g_currencyName, GetNativeCell(2));
}

public int Native_GetSQLEntry(Handle plugin, int params)
{
	SetNativeString(1, g_sqlconfigentry, GetNativeCell(2));
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

public int Native_RegisterChatCommands(Handle plugin, int params)
{
	char command[32];
	GetNativeString(1, command, sizeof(command));

	return RegisterCommands(plugin, command, view_as<Store_ChatCommandCallback>GetNativeFunction(2));
}

public int Native_GetServerID(Handle plugin, int params)
{
	if (g_serverID < 0)
	{
		char sPluginName[128];
		GetPluginInfo(plugin, PlInfo_Name, sPluginName, sizeof(sPluginName));
		
		Store_LogError("Plugin Module '%s' attempted to get the serverID when It's currently set to a number below 0.", sPluginName);
		
		return 0;
	}
	
	return g_serverID;
}

public int Native_ClientIsDeveloper(Handle plugin, int params)
{
	return bDeveloperMode[GetNativeCell(1)];
}