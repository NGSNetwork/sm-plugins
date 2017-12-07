/**
 * Retrieves the slot number of a client's partner.
 *
 * @param plugin			Plugin handle.
 * @param numParams			Number of parameters.
 * @return					The slot number of the partner, -2 if the client is not married, -1 if the partner is not connected.
 */
public int Native_GetPartnerSlot(Handle plugin, int numParams) {
	return marriage_slots[GetNativeCell(1)];
}


/**
 * Retrieves the name of a client's partner.
 *
 * @param plugin			Plugin handle.
 * @param numParams			Number of parameters.
 * @noreturn
 */
public int Native_GetPartnerName(Handle plugin, int numParams) {
	if(SetNativeString(2, marriage_names[GetNativeCell(1)], GetNativeCell(3)) != SP_ERROR_NONE) {
		ThrowNativeError(SP_ERROR_NATIVE, "Error setting parameter in native GetPartnerName.");
	}
}


/**
 * Retrieves the steam ID of a client's partner.
 *
 * @param plugin			Plugin handle.
 * @param numParams			Number of parameters.
 * @noreturn
 */
public int Native_GetPartnerID(Handle plugin, int numParams)
{
	if(SetNativeString(2, marriage_ids[GetNativeCell(1)], GetNativeCell(3)) != SP_ERROR_NONE) {
		ThrowNativeError(SP_ERROR_NATIVE, "Error setting parameter in native GetPartnerID.");
	}
}


/**
 * Retrieves the marriage score of a client.
 *
 * @param plugin			Plugin handle.
 * @param numParams			Number of parameters.
 * @return					The marriage score, -1 if the client is not married.
 */
public int Native_GetMarriageScore(Handle plugin, int numParams) {
	return marriage_scores[GetNativeCell(1)];
}


/**
 * Retrieves the timestamp of a client's wedding.
 *
 * @param plugin			Plugin handle.
 * @param numParams			Number of parameters.
 * @return					The timestamp of the wedding, -1 if the client is not married.
 */
public int Native_GetWeddingTime(Handle plugin, int numParams) {
	return marriage_times[GetNativeCell(1)];	
}


/**
 * Fills an array with the proposals of all connected clients.
 * Given a client with slot number x, array[x] = -2 means the client has not proposed to anyone,
 * array[x] = -1 means the client has proposed but the target is not connected.
 * Any other number indicates the slot number of the target, except for the zero-slot which is not used.
 * This array will NOT be updated! To update the array call GetProposals again.
 *
 * @param plugin			Plugin handle.
 * @param numParams			Number of parameters.
 * @noreturn
 */
public int Native_GetProposals(Handle plugin, int numParams) {	
	int array[MAXPLAYERS + 1];
	int maxLen = GetNativeCell(2);
	
	for(int i = 1; i < maxLen; i++) {
		array[i] = proposal_slots[i];
	}
	if(SetNativeArray(1, array, maxLen) != SP_ERROR_NONE) {
		ThrowNativeError(SP_ERROR_NATIVE, "Error setting parameter in native GetProposals.");
	}
}


/**
 * Fills an array with the marital statuses of all connected clients.
 * Given a client with slot number x: array[x] = -2 means the client is not married,
 * array[x] = -1 means the client is married but the partner is not connected.
 * Any other number indicates the slot number of the partner, except for the zero-slot which is not used.
 * This array will NOT be updated! To update the array call GetMarriages again.
 *
 * @param plugin			Plugin handle.
 * @param numParams			Number of parameters.
 * @noreturn
 */
public int Native_GetMarriages(Handle plugin, int numParams) {	
	int array[MAXPLAYERS + 1];
	int maxLen = GetNativeCell(2);
	
	for(int i = 1; i < maxLen; i++) {
		array[i] = marriage_slots[i];
	}
	if(SetNativeArray(1, array, maxLen) != SP_ERROR_NONE) {
		ThrowNativeError(SP_ERROR_NATIVE, "Error setting parameter in native GetMarriages.");
	}
}