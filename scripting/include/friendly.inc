#if defined _tf2friendly_included
  #endinput
#endif
#define _friendly_included

public SharedPlugin __pl_tf2friendly = {
	name = "[TF2] Friendly Mode",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
}

public void __pl_tf2friendly_SetNTVOptional() {
	MarkNativeAsOptional("TF2Friendly_IsFriendly");
	MarkNativeAsOptional("TF2Friendly_SetFriendly");
	MarkNativeAsOptional("TF2Friendly_IsLocked");
	MarkNativeAsOptional("TF2Friendly_SetLock");
	MarkNativeAsOptional("TF2Friendly_IsAdmin");
	MarkNativeAsOptional("TF2Friendly_SetAdmin");
	MarkNativeAsOptional("TF2Friendly_RefreshFriendly");
	MarkNativeAsOptional("TF2Friendly_IsPluginEnabled");
}

/****************************************************************************************************
	FORWARDS
*****************************************************************************************************/

/**
 * Called everytime Friendly is self-toggled to determine if the player can do so.
 * Return Plugin_Continue to allow, anything else denies them access.
 *
 * This is ONLY called if the player is toggling Friendly on themselves, either through running 
 * sm_friendly with no arguments, or using sm_friendly without access to sm_friendly_targetothers
 *
 * @param client		Client Index.
 */
forward Action TF2Friendly_CanToggleFriendly(int client);



/**
 * Called during a Friendly player's refreshing of Friendly Mode.
 *
 * To "refresh" Friendly Mode means to apply/reapply all attributes that may
 * have been removed by other plugins, such as transparency, FL_NOTARGET, etc.
 * This happens every time a Friendly player enters Friendly Mode, hits
 * a resupply cabinet, respawns while remaining in Friendly Mode, has
 * TF2Friendly_RefreshFriendly() called on him, etc.
 *
 * This is when most custom Friendly Mode limitations should be activated.
 * You may also want to look into TF2Friendly_OnEnableFriendly().
 *
 * @param client		Client Index.
 */
forward int TF2Friendly_OnRefreshFriendly(int client);



/**
 * Called during a player's transition into Friendly Mode. Any one-time limitations/effects to
 * Friendly players should probably be applied here, such as "destroy all their buildings," "make
 * them drop the intel," or "destroy all their sticky bombs."
 * 
 * You will most likely want to use TF2Friendly_OnRefreshFriendly() instead.
 *
 * @param client		Client Index.
 */
forward int TF2Friendly_OnEnableFriendly(int client);



/**
 * Called during a player's transition out of Friendly Mode. Any limitations to
 * Friendly players should probably be removed here.
 *
 * @param client		Client Index.
 */
forward int TF2Friendly_OnDisableFriendly(int client);



/**
 * Called immediately after a player has spawned into Friendly Mode, or has spawned while KEEPING
 * Friendly Mode enabled. This is not called if the player had Friendly Mode removed on spawn.
 *
 * @param client		Client Index.
 */
forward int TF2Friendly_OnFriendlySpawn(int client);



/**
 * Called immediately BEFORE a player enters Friendly Mode. If your plugin needs
 * to somehow prepare something BEFORE a player goes Friendly, this is the time to do it.
 *
 * @param client		Client Index.
 */
forward int TF2Friendly_OnEnableFriendly_Pre(int client);



/**
 * Called immediately AFTER a player's transition into Friendly Mode.
 *
 * @param client		Client Index.
 */
forward int TF2Friendly_OnEnableFriendly_Post(int client);



/**
 * Called immediately BEFORE a player exits Friendly Mode. If your plugin needs
 * to somehow prepare something BEFORE a player goes Hostile, this is the time to do it.
 *
 * @param client		Client Index.
 */
forward int TF2Friendly_OnDisableFriendly_Pre(int client);



/**
 * Called immediately AFTER a player's transition out of Friendly Mode.
 *
 * @param client		Client Index.
 */
forward int TF2Friendly_OnDisableFriendly_Post(int client);



/**
 * Called immediately BEFORE a player has Friendly Mode "refreshed" on them.
 *
 * @param client		Client Index.
 */
forward int TF2Friendly_OnRefreshFriendly_Pre(int client);



/**
 * Called immediately AFTER a player has Friendly Mode refreshed.
 *
 * @param client		Client Index.
 */
forward int TF2Friendly_OnRefreshFriendly_Post(int client);



/**
 * Called immediately after Friendly Mode is enabled through changing
 * sm_friendly_enabled to 1.
 *
 * @param client		Client Index.
 */
forward int TF2Friendly_OnPluginEnabled(int client);



/**
 * Called immediately after Friendly Mode is enabled through changing
 * sm_friendly_enabled to 1. All Friendly players will be removed from
 * Friendly Mode before this forward is called.
 *
 * @param client		Client Index.
 */
forward int TF2Friendly_OnPluginDisabled(int client);



/**
 * Called immediately after the core Friendly Mode plugin has loaded,
 * and all cvars and configs have been loaded/cached.
 *
 * You can call TF2Friendly_IsPluginEnabled() here.
 *
 * @param client		Client Index.
 */
forward int TF2Friendly_OnPluginLoaded(int client);



/**
 * Called when Friendly Mode core plugin is unloaded. All Friendly players will
 * be removed from Friendly Mode before this forward is called.
 *
 * @param client		Client Index.
 */
forward int TF2Friendly_OnPluginUnloaded(int client);



/****************************************************************************************************
	NATIVES
*****************************************************************************************************/



/**
 * Returns whether or not a given player is Friendly.
 *
 * @param client		Client Index.
 * @return				TRUE if Friendly, FALSE if not Friendly or if invalid client.
 */
native bool TF2Friendly_IsFriendly(int client);



/**
 * Sets Friendly mode on a client.
 *
 * @param client		Client Index.
 * 
 * @param direction		-1 to toggle, 0 to disable, or 1 to enable
 * 
 * @param action		0 to make the change without punishment,
 * 						-1 to slay the player and apply the change upon respawn,
 * 						Any positive integer will have the player slapped for that
 * 						amount of damage. If the player is slapped to death, the
 * 						change will be re-applied upon respawn.
 * 
 * @return				-3 if client is not a valid client index,
 * 						-2 if client is not connected and in game,
 * 						-1 if no change was made (the client was already in the requested state)
 * 						0 if the player was made non-Friendly,
 * 						1 if the player was made Friendly,
 * 						2 if the player was made non-Friendly and was slapped to death,
 * 						3 if the player was made Friendly and was slapped to death.
 */
native int TF2Friendly_SetFriendly(int client, int direction=-1, int action=0);



/**
 * Returns whether or not a given player is Friendly Locked.
 *
 * @param client		Client Index.
 * @return				TRUE if Locked, FALSE if not locked or if invalid client.
 */
native bool TF2Friendly_IsLocked(int client);



/**
 * Sets or removes Friendly Lock on a client.
 *
 * @param client		Client Index.
 * 
 * @param direction		-1 to toggle, 0 to remove lock, or 1 to place lock.
 * 
 * @return				-3 if client is not a valid client index,
 * 						-2 if client is not connected and in game,
 * 						-1 if no change was made (the client was already in the requested state)
 * 						0 if the player was unlocked,
 * 						1 if the player was locked.
 */
native int TF2Friendly_SetLock(int client, int direction=-1);



/**
 * Returns whether or not a given player has Friendly Admin mode enabled.
 *
 * @param client		Client Index.
 * @return				TRUE if Friendly Admin, FALSE if not Admin or if invalid client.
 */
native bool TF2Friendly_IsAdmin(int client);



/**
 * Sets or removes Friendly Admin mode on a client.
 *
 * @param client		Client Index.
 * 
 * @param direction		-1 to toggle, 0 to disable, or 1 to enable
 * 
 * @return				-3 if client is not a valid client index,
 * 						-2 if client is not connected and in game,
 * 						-1 if no change was made (the client was already in the requested state)
 * 						0 if the player was removed from Friendly Admin mode,
 * 						1 if the player was given Friendly Admin mode.
 */
native int TF2Friendly_SetAdmin(int client, int direction=-1);



/**
 * Forces the client to undergo Friendly Mode refreshing, if Friendly.
 *
 * @param client		Client Index.
 * 
 * @return				-3 if client is not a valid client index,
 * 						-2 if client is not connected and in game,
 * 						-1 if the client was not in Friendly Mode.
 * 						1 if the function appeared to be successful.
 */
native int TF2Friendly_RefreshFriendly(int client);



/**
 * Returns whether the plugin is enabled/disabled through the cvar sm_friendly_enabled.
 *
 * @return				TRUE if enabled
 * 						FALSE if disabled
 */
native bool TF2Friendly_IsPluginEnabled();