#if defined _weddings_included_
	#endinput
#endif
#define _weddings_included_


/**
 * Retrieves the slot number of a client's partner. Use this function to check whether a client is married.
 *
 * @param client			The slot number of the client.
 * @return					The slot number of the partner, -2 if the client is not married, -1 if the partner is not connected.
 *							If 0 is returned, then either the client is not connected, or the marital status is still being checked.
 */
native GetPartnerSlot(client);


/**
 * Retrieves the name of a client's partner.
 *
 * @param client			The slot number of the client.
 * @param buffer			Destination buffer, will be empty if the client is not married.
 * @param maxLen			Destination buffer length.
 * @noreturn
 */
native GetPartnerName(client, String:buffer[], maxLen);


/**
 * Retrieves the steam ID of a client's partner.
 *
 * @param client			The slot number of the client.
 * @param buffer			Destination buffer, will be empty if the client is not married.
 * @param maxLen			Destination buffer length.
 * @noreturn
 */
native GetPartnerID(client, String:buffer[], maxLen);


/**
 * Retrieves the marriage score of a client.
 *
 * @param client			The slot number of the client.
 * @return					The marriage score, -1 if the client is not married.
 */
native GetMarriageScore(client);


/**
 * Retrieves the timestamp of a client's wedding.
 *
 * @param client			The slot number of the client.
 * @return					The timestamp of the wedding, -1 if the client is not married.
 */
native GetWeddingTime(client);


/**
 * Fills an array with the proposals of all connected clients.
 * Given a client with slot number x, array[x] = -2 means the client has not proposed to anyone,
 * array[x] = -1 means the client has proposed but the target is not connected.
 * array[x] = 0 means that either the client is not connected, or the marital status is still being checked.
 * Any other number indicates the slot number of the target.
 * This array will NOT be updated! To update the array call GetProposals again.
 *
 * @param array				Destination array.
 * @param maxLen			Destination array length. This should be MaxClients + 1.
 * @noreturn
 */
native GetProposals(array[], maxLen);


/**
 * Fills an array with the marital statuses of all connected clients.
 * Given a client with slot number x: array[x] = -2 means the client is not married,
 * array[x] = -1 means the client is married but the partner is not connected.
 * array[x] = 0 means that either the client is not connected, or the marital status is still being checked.
 * Any other number indicates the slot number of the partner.
 * This array will NOT be updated! To update the array call GetMarriages again.
 *
 * @param array				Destination array.
 * @param maxLen			Destination array length. This should be MaxClients + 1.
 * @noreturn
 */
native GetMarriages(array[], maxLen);


/**
 * Called when a client makes a marriage proposal.
 *
 * @param proposer			The slot number of the proposer. 
 * @param target			The slot number of the target.
 * @noreturn 					 
 */
forward OnProposal(proposer, target);


/**
 * Called when a client accepts a marriage proposal.
 *
 * @param proposer			The slot number of the proposer. 
 * @param accepter			The slot number of the accepter.
 * @noreturn 					 
 */
forward OnWedding(proposer, accepter);


/**
 * Called when a client divorces.
 *
 * @param divorcer			The slot number of the divorcer.
 * @param partner			The slot number of the partner, -1 if the partner is not connected.
 * @noreturn 					 
 */
forward OnDivorce(divorcer, partner);