/****************************************
 * ngsupdater.sp
 *
 * This file is an updated version of the one used in Dr. McKay's plugins for Updater integration
 * Some cool ideas from ddhoward's updater have also been added.
 * For more info on Dr. McKay's plugins, see http://www.doctormckay.com
 * For more info on Updater, see https://forums.alliedmods.net/showthread.php?t=169095
 * For more info on NGS and their plugins, see https://www.neogenesisnetwork.net
 * You may copy and use this file, but please be sure to change the URL to your own!
 *
 * This file does the following tasks:
 * 		- Adds the plugin to Updater's updating pool (using UPDATER_BASE_URL/UPDATE_FILE (UPDATE_FILE may be defined prior to including this file))
 * 		- Creates a cvar CONVAR_PREFIX_auto_update to control whether Updater is enabled (CONVAR_PREFIX may be defined prior to including this file)
 * 		- Creates a version cvar CONVAR_PREFIX_version (CONVAR_PREFIX may be defined prior to including this file)
 * 		- Dynamically adds "A" to the version cvar based on whether Updater is installed and working
 *
 * If you need to put code into OnAllPluginsLoaded, define ALL_PLUGINS_LOADED_FUNC with a function (doesn't need to be public) to be called inside of OnAllPluginsLoaded
 * 		For example, #define ALL_PLUGINS_LOADED_FUNC AllPluginsLoaded
 * 		AllPluginsLoaded() { ... }
 *
 * If you need to put code into OnLibraryAdded, define LIBRARY_ADDED_FUNC with a function (doesn't need to be public) to be called inside of OnLibraryAdded
 * 		For example, #define LIBRARY_ADDED_FUNC LibraryAdded
 * 		LibraryAdded(const char[] name) { ... }
 *
 * If you need to put code into OnLibraryRemoved, define LIBRARY_REMOVED_FUNC with a function (doesn't need to be public) to be called inside of OnLibraryRemoved
 * 		For example, #define LIBRARY_REMOVED_FUNC LibraryRemoved
 * 		LibraryRemoved(const char[] name) { ... }
 *
 * Define RELOAD_ON_UPDATE and the plugin will reload itself upon being updated
 *
 * So in all:
 * #define PLUGIN_VERSION "1.0.0" (optional if maintained in Plugin myinfo)
 * #define CONVAR_PREFIX "deadbeef" (optional)
 * #define UPDATE_FILE "foobar.txt" (optional, but use .txt)
 * #define ALL_PLUGINS_LOADED_FUNC AllPlugsLoaded (if needed)
 * #define LIBRARY_ADDED_FUNC OnLibAdded (if needed)
 * #define LIBRARY_REMOVED_FUNC OnLibRemoved (if needed)
 * #define RELOAD_ON_UPDATE (if possible)
 * include <ngsupdater>
 */

#if defined _ngs_updater_included
 #endinput
#endif
#define _ngs_updater_included
#define _ngsupdater_version "0.0.1"

#tryinclude <updater>

#if !defined UPDATER_BASE_URL
  #define UPDATER_BASE_URL "https://raw.githubusercontent.com/NGSNetwork/sm-plugins/master/updater"
#endif

ConVar cvarEnableUpdater;
ConVar cvarVersion;
char updater_plugin_version[32];

public void OnAllPluginsLoaded()
{
	char cvarName[64], cvarPrefix[128];
	#if !defined CONVAR_PREFIX
		GetPluginFilename(null, cvarPrefix, sizeof(cvarPrefix));
		ReplaceString(cvarPrefix, sizeof(cvarPrefix), ".smx", "");
	#else
		Format(cvarPrefix, sizeof(cvarPrefix), "%s", CONVAR_PREFIX);
	#endif

	Format(cvarName, sizeof(cvarName), "%s_auto_update", cvarPrefix);
	cvarEnableUpdater = CreateConVar(cvarName, "1", "Enables automatic updating (has no effect if Updater is not installed)");

	Format(cvarName, sizeof(cvarName), "%s_version", cvarPrefix);
	#if !defined PLUGIN_VERSION
		GetPluginInfo(null, PlInfo_Version, updater_plugin_version, sizeof(updater_plugin_version));
	#else
		Format(updater_plugin_version, sizeof(updater_plugin_version), "%s", PLUGIN_VERSION);
	#endif
	cvarVersion = CreateConVar(cvarName, updater_plugin_version, "Plugin Version", FCVAR_DONTRECORD|FCVAR_CHEAT|FCVAR_NOTIFY);

	cvarEnableUpdater.AddChangeHook(CheckUpdaterStatus);
	cvarVersion.AddChangeHook(CheckUpdaterStatus);
	CheckUpdaterStatus(null, "", "");
	AddCommandListener(print_ngsupdater_include_version, "dev_ngsupdater_include_versions");
#if defined ALL_PLUGINS_LOADED_FUNC
	ALL_PLUGINS_LOADED_FUNC();
#endif
}

public void OnLibraryAdded(const char[] name)
{
	CheckUpdaterStatus(null, "", "");

#if defined LIBRARY_ADDED_FUNC
	LIBRARY_ADDED_FUNC(name);
#endif
}

public void OnLibraryRemoved(const char[] name)
{
	CheckUpdaterStatus(null, "", "");

#if defined LIBRARY_REMOVED_FUNC
	LIBRARY_REMOVED_FUNC(name);
#endif
}

public void CheckUpdaterStatus(ConVar convar, const char[] name, const char[] value)
{
	if(cvarVersion == null)
	{
		return; // Version cvar not created yet
	}

	if(LibraryExists("updater") && cvarEnableUpdater.BoolValue)
	{
		char url[512], version[12];
		#if defined UPDATE_FILE
			Format(url, sizeof(url), "%s/%s", UPDATER_BASE_URL, UPDATE_FILE);
		#else
			char fileName[PLATFORM_MAX_PATH];
			GetPluginFilename(null, fileName, sizeof(fileName));
			ReplaceString(fileName, sizeof(fileName), ".smx", "");
			Format(url, sizeof(url), "%s/%s.txt", UPDATER_BASE_URL, fileName);
		#endif
		Updater_AddPlugin(url); // Has no effect if we're already in Updater's pool

		Format(version, sizeof(version), "%sA", updater_plugin_version);
		cvarVersion.SetString(version);
	}
	else
	{
		cvarVersion.SetString(updater_plugin_version);
	}
}

public Action Updater_OnPluginChecking()
{
	if(!cvarEnableUpdater.BoolValue)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

#if defined RELOAD_ON_UPDATE
public Updater_OnPluginUpdated()
{
	ReloadPlugin();
}
#endif

//command listener which prints information to the chat, ALL plugins with this include will respond
public Action print_ngsupdater_include_version(int client, const char[] cmdname, int Args)
{
	if (CheckCommandAccess(client, "dev_ngsupdater_include_versions", ADMFLAG_ROOT, true))
	{

		char pluginFilename[PLATFORM_MAX_PATH];
		GetPluginFilename(null, pluginFilename, sizeof(pluginFilename));

		char pluginName[64];
		if (GetPluginInfo(null, PlInfo_Name, pluginName, sizeof(pluginName)))
		{
			Format(pluginName, sizeof(pluginName), "%s%s", pluginName, " -");
		}

		ReplyToCommand(client, "- Plugin %s v%s (%s) is running v%s of the include.", pluginName,
			updater_plugin_version, pluginFilename, _ngsupdater_version);
	}
	return Plugin_Continue;
}
