#if defined _mckay_updater_included
 #endinput
#endif
#define _mckay_updater_included

#if defined REQUIRE_PLUGIN
 #undef REQUIRE_PLUGIN
#endif
#include <updater>
#define REQUIRE_PLUGIN

#define UPDATER_BASE_URL "http://hg.doctormckay.com/public-plugins/raw/default"

ConVar cvarEnableUpdater;
ConVar cvarPluginVersion;

public void OnAllPluginsLoaded()
{
	char cvarName[64];
	Format(cvarName, sizeof(cvarName), "%s_auto_update", CONVAR_PREFIX);
	cvarEnableUpdater = CreateConVar(cvarName, "1", "Enables automatic updating (has no effect if Updater is not installed)");
	
	Format(cvarName, sizeof(cvarName), "%s_version", CONVAR_PREFIX);
	cvarPluginVersion = CreateConVar(cvarName, PLUGIN_VERSION, "Plugin Version", FCVAR_DONTRECORD|FCVAR_CHEAT|FCVAR_NOTIFY);
	
	HookConVarChange(cvarEnableUpdater, CheckUpdaterStatus);
	HookConVarChange(cvarPluginVersion, CheckUpdaterStatus);
	CheckUpdaterStatus(INVALID_HANDLE, "", "");
	
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
	if (cvarPluginVersion == null)
	{
		return; // Version cvar not created yet
	}
	
	if (LibraryExists("updater") && cvarEnableUpdater.BoolValue)
	{
		char url[512], version[12];
		Format(url, sizeof(url), "%s/%s", UPDATER_BASE_URL, UPDATE_FILE);
		Updater_AddPlugin(url); // Has no effect if we're already in Updater's pool
		
		Format(version, sizeof(version), "%sA", PLUGIN_VERSION);
		cvarPluginVersion.SetString(version);
	}
	else
	{
		cvarPluginVersion.SetString(PLUGIN_VERSION);
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