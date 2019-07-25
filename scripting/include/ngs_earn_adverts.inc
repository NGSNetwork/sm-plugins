#if defined _ngs_earn_adverts_included_
#endinput
#endif
#define _ngs_earn_adverts_included_

/**
 * Plays an advert to the client.
 * if the client has had an advert less than 3 mins ago it will wait before playing this one.
 *
 * @return		True if successful. False otherwise.
 */
native bool NGS_PlayAdvert(int iClient);

/**
 * Returns if an advert is currently playing to the client.
 *
 * @return		True if an advert is playing. False otherwise.
 */
native bool NGS_IsAdvertPlaying(int iClient);


public SharedPlugin __pl_vpp_adverts = {
	name = "[NGS] Adverts",
	#if defined REQUIRE_PLUGIN
	required = 1, 
	#else
	required = 0, 
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_vpp_adverts_SetNTVOptional() {
	MarkNativeAsOptional("NGS_PlayAdvert");
	MarkNativeAsOptional("NGS_IsAdvertPlaying");
}
#endif