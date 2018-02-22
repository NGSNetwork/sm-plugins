#if defined _unusual_included_
  #endinput
#endif
#define _unusual_included_


/**
 * Remove a weapon unusual effect.
 *
 * @param SteamID	Client SteamID.
 * @param WeaponID	Weapon Index.
 */
native bool UE_RemoveEffect(char[] SteamID, int WeaponID);


/**
 * Remove all client unusual effects.
 *
 * @param SteamID	Client SteamID.
 */
native bool UE_RemovePlayerEffects(char[] SteamID);


/**
 * Get flag unusual effect number limit.
 *
 * @param flag		FlagBit (ex : ADMINFLAG_ROOT), -1 = without flag.
 * @return 			Unusual effect flag number limit, -1 = no limit, -2 if invalid FlagBit
 */
native int UE_GetUnusualEffectPermission(int flag);


/**
 * Set flag unusual effect number limit.
 *
 * @param flag		FlagBit (ex : ADMINFLAG_ROOT), -1 = without flag.
 * @param limit		limit.
 * @return 			false if invalid FlagBit, true on success.
 */
native bool UE_SetUnusualEffectPermission(int flag, int limit);



public SharedPlugin __pl_unusual =
{
	name = "unusual",
	file = "ngs_unusualweapons.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
