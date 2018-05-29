#if defined _store_core_included
#endinput
#endif
#define _store_core_included

//Prototypes
typeset Store_MenuItemClickCallback
{
	function void(int client, const char[] value);
}

typeset Store_ChatCommandCallback
{
	function void(int client);
	function void(int client, const char[] command);
	function void(int client, const char[] command, const char[] args);
}

//Forwards
forward Action Store_OnChatCommand(int client, const char[] command, const char[] args);
forward void Store_OnChatCommand_Post(int client, const char[] command, const char[] args);
forward void Store_OnCoreLoaded();

/**
 * Opens the main menu for a player.
 *
 * @param client		Client Index
 *
 * @noreturn
 */
native void Store_OpenMainMenu(int client);

/**
 * Adds an item to the main menu.
 *
 * @param displayName		The text of the item, as it is shown to the player.
 * @param description		A short description of the item.
 * @param value				Item information string that will be sent to the callback.
 * @param callback			Callback to the item click event.
 * @param order				Preferred position of the item in the menu.
 * @param bIsDisabled		True if item is disabled, false otherwise.
 *
 * @noreturn
 */
native void Store_AddMainMenuItem(const char[] displayName, const char[] description = "", const char[] value = "", Store_MenuItemClickCallback callback, int order = 32, bool bIsDisabled = false);

/**
 * Adds an item to the main menu. (Difference between the versions is this one doesn't use translations)
 *
 * @param displayName		The text of the item, as it is shown to the player.
 * @param description		A short description of the item.
 * @param value				Item information string that will be sent to the callback.
 * @param callback			Callback to the item click event.
 * @param order				Preferred position of the item in the menu.
 * @param bIsDisabled		True if item is disabled, false otherwise.
 *
 * @noreturn
 */
native void Store_AddMainMenuItemEx(const char[] displayName, const char[] description = "", const char[] value = "", Store_MenuItemClickCallback callback, int order = 32, bool bIsDisabled = false);

/**
 * Retrieve currency name as it is defined in the core config file.
 *
 * @param currencyName		Buffer to store the currency name in.
 * @param maxLength			Maximum length of string buffer.
 *
 * @noreturn
 */
native void Store_GetCurrencyName(char[] currencyName, int maxLength);

/**
* Retrieve sql config entry as it is defined in the core config file.
*
* @param sqlEntryName		Buffer to store the sql entry name in.
* @param maxLength			Maximum length of string buffer.
*
* @noreturn
*/
native void Store_GetSQLEntry(char[] sqlEntryName, int maxLength);

/**
 * Registers commands with the store plugin.
 *
 * @param commands		Space seperated list of commands to register, eg "!credits /credits"
 * @param callback		Callback for the command
 *
 * @return Returns false if a duplicate command or number of commands > MAX_CHAT_COMMANDS, otherwise true.
 */
native bool Store_RegisterChatCommands(const char[] commands, Store_ChatCommandCallback callback);

/**
 * Retrieve the server's assigned ID, this is used mostly for web panel functionality.
 *
 * @return Returns ServerID if set, 0 for all other returns.
 */
native int Store_GetServerID();

/**
 * Retrieves if the client is in developer mode or not for the store system.
 *
 * @param client		Client index.
 *
 * @return True if developer is enabled, false otherwise.
 */
native bool Store_ClientIsDeveloper(int client);

public SharedPlugin __pl_store =
{
	name = "store",
	file = "store-core.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_store_SetNTVOptional()
{
	MarkNativeAsOptional("Store_OpenMainMenu");
	MarkNativeAsOptional("Store_AddMainMenuItem");
	MarkNativeAsOptional("Store_AddMainMenuItemEx");
	MarkNativeAsOptional("Store_GetCurrencyName");
	MarkNativeAsOptional("Store_GetSQLEntry");
	MarkNativeAsOptional("Store_RegisterChatCommands");
	MarkNativeAsOptional("Store_GetServerID");
	MarkNativeAsOptional("Store_ClientIsDeveloper");
}
#endif
