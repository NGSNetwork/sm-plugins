/** Double-include prevention */
#if defined _devzones_included_
  #endinput
#endif
#define _devzones_included_


/**
 * Check if a player are there in a zone
 *
 * @param client     Player for check
 * @String zone     Zone name
 * @bool equal     Check exact zone name or parcial name
 * @bool caseSensitive     If true, comparison is case sensitive. If false, comparison is case insensitive.
 * @return true if player are there in the zone given in Zone String
 */
native bool Zone_IsClientInZone(int client, char[] zone, bool equal=true, bool caseSensitive=false);

/**
 * Check if zone exists
 *
 * @String zone     Zone name
 * @bool equal     Check exact zone name or parcial name
 * @bool caseSensitive     If true, comparison is case sensitive. If false, comparison is case insensitive.
 * @return true if zone exist
 */
native bool Zone_CheckIfZoneExists(char[] zone, bool equal=true, bool caseSensitive=false);

/**
 * Called when a player has entered in a zone.
 * @param client   client that has entered in the zone.
 * @String zone   Zone name.
 */
forward void Zone_OnClientEntry(int client, char[] zone);

/**
 * Called when a player has left a zone.
 * @param client   client that has left the zone.
 * @String zone   Zone name.
 */
forward void Zone_OnClientLeave(int client, char[] zone);

/**
 * Get a zone position
 * @String zone   Zone name to search position.
 * @bool caseSensitive     If true, comparison is case sensitive. If false, comparison is case insensitive.
 * @Float Position   Array when the zone position will be copied
 * @return true on successfully, false otherwise
 */
native void Zone_GetZonePosition(char[] zone, bool caseSensitive=false, float Position[3]);