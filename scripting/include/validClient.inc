#if defined _validClient_included
 #endinput
#endif
#define _validClient_included

#define _validClient_version "15.0726"

enum f_vclient {
	VCLIENT_INDEX, 			// must be > 0 && <= MaxClients
	VCLIENT_CONNECTED, 		// must pass IsClientConnected
	VCLIENT_INGAME, 		// must pass IsClientInGame
	VCLIENT_ONATEAM, 		// must be assigned to a team
	VCLIENT_NOSPEC, 		// cannot be spectating
	VCLIENT_ALIVE, 			// must be alive
};

/**
* Checks if the specified index is a valid client. Supports entity references.
*
* @param index				A client index.
* @param threshold			Defines what a "valid client" is.
* @param bots				If true, bots will always return FALSE.
* @param replay				If true, Replay and SourceTV will always return FALSE.
* @param convert			If true, client indexes below -1 will be run through EntRefToEntIndex();
* @param logerror			If true, an explanation of the failure will be printed to the error logs.
* @return					TRUE or FALSE.
*/
stock bool IsValidClient(int client, f_vclient threshold=VCLIENT_INGAME, bool nobots = false,
	bool noreplay = true, bool convert = true, bool logerror = false) {

	static bool vcListenerCreated;
	if (!vcListenerCreated) {
		AddCommandListener(print_validClient_include_version, "validClient_include_versions");
		vcListenerCreated = true;
	}

	
	if (convert && (client < INVALID_ENT_REFERENCE)) {
		client = EntRefToEntIndex(client);
		if (client == INVALID_ENT_REFERENCE) {
			if (logerror) { LogError("[VCLIENT] Reference is no longer valid!"); }
			return false;
		}
	}
	if (threshold >= VCLIENT_INDEX && (client < 1 || client > MaxClients)) {
		if (logerror) { LogError("[VCLIENT] Index %i is not between 1 and MaxClients!", client); }
		return false;
	}
	if (threshold >= VCLIENT_CONNECTED && !IsClientConnected(client)) {
		if (logerror) { LogError("[VCLIENT] Index %i is not connected!", client); }
		return false;
	}
	if (threshold >= VCLIENT_INGAME && !IsClientInGame(client)) {
		if (logerror) { LogError("[VCLIENT] %N is still connecting!", client); }
		return false;
	}
	if (nobots && IsFakeClient(client)) {
		if (logerror) { LogError("[VCLIENT] %N is a bot!", client); }
		return false;
	}
	if (noreplay && (IsClientSourceTV(client) || IsClientReplay(client))) {
		if (logerror) { LogError("[VCLIENT] Client is Replay or SourceTV!"); }
		return false;
	}
	if (threshold >= VCLIENT_ONATEAM && GetClientTeam(client) == 0) {
		if (logerror) { LogError("[VCLIENT] %N is not on any team!", client); }
		return false;
	}
	if (threshold >= VCLIENT_NOSPEC && GetClientTeam(client) == 1) {
		if (logerror) { LogError("[VCLIENT] %N is spectating!", client); }
		return false;
	}
	if (threshold >= VCLIENT_ALIVE && !IsPlayerAlive(client)) {
		if (logerror) { LogError("[VCLIENT] %N is not alive!", client); }
		return false;
	}
	return true;
}

public Action print_validClient_include_version(int client, const char[] cmdname, int iArgs)
{
	if (CheckCommandAccess(client, "validClient_include_versions", ADMFLAG_ROOT, true)) {
		char pluginFileName[PLATFORM_MAX_PATH];
		GetPluginFilename(INVALID_HANDLE, pluginFileName, sizeof(pluginFileName));

		char pluginName[64];
		if (GetPluginInfo(INVALID_HANDLE, PlInfo_Name, pluginName, sizeof(pluginName))) {
			Format(pluginName, sizeof(pluginName), "%s%s", pluginName, " - ");
		} else pluginName[0] = '\0';

		char pluginVersion[24];
		if (GetPluginInfo(INVALID_HANDLE, PlInfo_Version, pluginVersion, sizeof(pluginVersion))) {
			Format(pluginVersion, sizeof(pluginVersion), "%s%s", " ", pluginVersion);
		} else pluginVersion[0] = '\0';

		PrintToConsole(client, "%s - %s%s%s", _validClient_version, pluginName, pluginFileName, pluginVersion);
	}
	return Plugin_Continue;
}