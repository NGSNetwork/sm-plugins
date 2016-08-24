/****************************************
 * http://ddhoward.bitbucket.org/scripting/include/ddhoward_updater.inc
 * 
 * This file is used in Derek's plugins for Updater integration.
 * It is based off of Dr. McKay's mckayupdater.sp
 * For more info on Updater, see:
 * 		https://forums.alliedmods.net/showthread.php?t=169095
 * For Dr. McKay's original file, see:
 * 		https://bitbucket.org/Doctor_McKay/public-plugins/src/default/scripting/mckayupdater.sp
 * You may copy and use this file, but please be sure to change the URL to your own!
 * 
 * This file performs the following tasks:
 * 	- Adds the plugin to Updater's updating pool (using UPDATER_BASE_URL/UPDATE_FILE)
 * 	- Creates a _update cvar to control whether Updater is enabled
 * 		- 0 disables automatic updating entirely.
 * 		- 1 will cause Updater to check for an update and indicate that an update
 * 			was found in Updater.log
 * 		- 2 will cause Updater to download the update, which will be loaded next
 * 			map change or server reboot.
 * 		- 3 will cause the plugin's update to be loaded immediately after download.
 * 			3 will do the same as 2	if NEVER_RELOAD_ON_UPDATE is #define'd before
 * 			including this file.
 * 	- Creates a _version cvar
 * 	- Dynamically adds "-upd" to the version cvar if an update has been downloaded
 * 		but the old version is still running
 *	- Creates a new command listener for "ddhoward_updater_include_versions"
 *		All plugins running this include will respond to that command in the console,
 *		and will tell the command user what version of this include was used.
 * 		Default access is ROOT.
 *
 * 6 REQUIREMENTS:
 * 	-	Define UPDATE_FILE before including this file
 * 			(path to the update file, including extension, relative to the UPDATER_BASE_URL)
 * 			(do not include leading forward-slash)
 * 	-	Define CONVAR_PREFIX before including this file
 * 			(If you want your cvars to have sm_ in the front, you must specify the sm_ here)
 * 	-	Define DEFAULT_UPDATE_SETTING to "0" "1" "2" or "3" before including this file.
 * 	-	Define PLUGIN_VERSION before including this file
 * 	-	If including this file, you must put UPD_OnAllPluginsLoaded(); in OnAllPluginsLoaded
 * 			Example: public OnAllPluginsLoaded() { UPD_OnAllPluginsLoaded(); }
 * 			If you don't need OnAllPluginsLoaded, just #define UPD_OAPL
 * 	-	If including this file, you must put UPD_OnLibraryAdded(); in OnLibraryAdded
 * 			Example: public OnLibraryAdded(const String:name[]) { UPD_OnLibraryAdded(); }
 * 			If you don't need OnAllPluginsLoaded, just #define UPD_OLA
 * 
 * 3 SUGGESTIONS:
 * 	-	Remember to #undef REQUIRE_PLUGIN before including this file, or your plugin will
 * 			refuse to load unless Updater is also running.
 * 	-	Define NEVER_RELOAD_ON_UPDATE before including this file and the plugin 
 * 			will NEVER reload itself upon being updated.
 *			(updated plugins will instead be run on next map change or server restart)
 * 	-	Defining UPD_LIBFUNC works the same as defining both other UPD_ defines.
 * 
 */

#if defined _ddhoward_updater_version
 #endinput
#endif
#define _ddhoward_updater_version "16.0727"

#include <updater>

#define UPDATER_BASE_URL "http://ddhoward.bitbucket.org"

ConVar cvar_update;
ConVar cvar_version;

bool PLUGIN_UPDATE_PENDING;

public void UPD_OnAllPluginsLoaded() {
	char cvarName[64];
	Format(cvarName, sizeof(cvarName), "%s_update", CONVAR_PREFIX);

	#if defined NEVER_RELOAD_ON_UPDATE
	cvar_update = CreateConVar(cvarName, DEFAULT_UPDATE_SETTING, "(0/1/2) Updater compatibility. 0 to disable, 1 to notify, 2 to download and install on map change", _, true, 0.0, true, 2.0);
	#else
	cvar_update = CreateConVar(cvarName, DEFAULT_UPDATE_SETTING, "(0/1/2/3) Updater compatibility. 0 to disable, 1 to notify, 2 to download and install next map change, 3 to auto-load new version", _, true, 0.0, true, 3.0);
	#endif
	
	Format(cvarName, sizeof(cvarName), "%s_version", CONVAR_PREFIX);
	cvar_version = CreateConVar(cvarName, PLUGIN_VERSION, "Plugin Version", FCVAR_DONTRECORD);
	
	cvar_update.AddChangeHook(UPD_CheckUpdaterStatus);
	cvar_version.AddChangeHook(UPD_CheckUpdaterStatus);
	UPD_CheckUpdaterStatus(INVALID_HANDLE, "", "");
	
	AddCommandListener(print_ddhoward_updater_include_version, "ddhoward_updater_include_versions");	
}

public void UPD_OnLibraryAdded() { UPD_CheckUpdaterStatus(INVALID_HANDLE, "", ""); }

public void UPD_CheckUpdaterStatus(Handle convar, const char[] oldValue, const char[] newValue) {
	if(cvar_version == null) return; // cvars not created yet

	if (cvar_update.IntValue > 0 && LibraryExists("updater")) {
		char url[512];
		Format(url, sizeof(url), "%s/%s", UPDATER_BASE_URL, UPDATE_FILE);
		Updater_AddPlugin(url);
	}

	if (PLUGIN_UPDATE_PENDING) {
		char version[16];
		Format(version, sizeof(version), "%s-upd", PLUGIN_VERSION);
		cvar_version.SetString(version);
		#if !defined NEVER_RELOAD_ON_UPDATE
		 if (cvar_update.IntValue >= 3) { ReloadPlugin(); }
		#endif
	}
	else { cvar_version.SetString(PLUGIN_VERSION); }
}

public Action Updater_OnPluginChecking() {
	if (cvar_update.IntValue >= 1) { return Plugin_Continue; }
	else { return Plugin_Handled; }
}

public Action Updater_OnPluginDownloading() {
	if (cvar_update.IntValue >= 2) { return Plugin_Continue; }
	else { return Plugin_Handled; }
}

public void Updater_OnPluginUpdated() {
	#if defined NEVER_RELOAD_ON_UPDATE
		PLUGIN_UPDATE_PENDING = true;
		UPD_CheckUpdaterStatus(INVALID_HANDLE, "", "");
	#else
		if (cvar_update.IntValue >= 3) {
			ReloadPlugin();
		}
		else {
			PLUGIN_UPDATE_PENDING = true;
			UPD_CheckUpdaterStatus(INVALID_HANDLE, "", "");
		}
	#endif
}

#if defined UPD_LIBFUNC || defined UPD_OAPL
	public void OnAllPluginsLoaded() { UPD_OnAllPluginsLoaded(); }
#endif
#if defined UPD_LIBFUNC || defined UPD_OLA
	public void OnLibraryAdded(const char[] name) { UPD_OnLibraryAdded(); }
#endif

public Action print_ddhoward_updater_include_version(int client, const char[] cmdname, int Args) {
	if (CheckCommandAccess(client, "ddhoward_updater_include_versions", ADMFLAG_ROOT, true)) {
		char pluginFileName[PLATFORM_MAX_PATH];
		GetPluginFilename(INVALID_HANDLE, pluginFileName, sizeof(pluginFileName));

		char pluginName[64];
		if (GetPluginInfo(INVALID_HANDLE, PlInfo_Name, pluginName, sizeof(pluginName))) {
			Format(pluginName, sizeof(pluginName), "%s%s", pluginName, " - ");
		}

		char pluginVersion[24];
		if (GetPluginInfo(INVALID_HANDLE, PlInfo_Version, pluginVersion, sizeof(pluginVersion))) {
			Format(pluginVersion, sizeof(pluginVersion), "%s%s", " ", pluginVersion);
		}
		
		ReplyToCommand(client, "%s - %s%s%s", _ddhoward_updater_version, pluginName, pluginFileName, pluginVersion);
	}
	return Plugin_Continue;
}