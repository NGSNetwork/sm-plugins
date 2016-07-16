#if defined _free_duels_included_
  #endinput
#endif
#define _free_duels_included_


/**
 * Is player is in duel ?
 *
 * @param client	Client Index.
 * @return			True or false, whether player is in duel.
 */
native bool IsPlayerInDuel(int client);


/**
 * Is player is in duel with class restriction ?
 *
 * @param client	Client Index.
 * @return			True or false, whether player is in duel with class restriction.
 */
native bool IsDuelRestrictionClass(int client);


/**
 * Get player Index who play duel with "client"  ?
 *
 * @param client	Client Index.
 * @return			Player (dueler) Index.
 */
native int GetDuelerID(int client);