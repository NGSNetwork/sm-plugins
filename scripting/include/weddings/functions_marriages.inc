/**
 * Adds a new marriage and deletes all existing proposals from and to the involved clients.
 *
 * @param source_name			The name of the proposer.
 * @param source_id				The steam ID of the proposer.
 * @param target_name 			The name of the accepter.
 * @param target_id				The steam ID of the accepter.
 * @noreturn
 */
void addMarriage(char[] source_name, char[] source_id, char[] target_name, char[] target_id) {
	if(weddings_db == INVALID_HANDLE) {
		LogError("Unable to connect to database.");
	} else {
		int date;
		char query_add[MAX_BUFFER_LENGTH];
		char query_delete4source_src[MAX_BUFFER_LENGTH];
		char query_delete4target_src[MAX_BUFFER_LENGTH];
		char query_delete4source_trg[MAX_BUFFER_LENGTH];
		char query_delete4target_trg[MAX_BUFFER_LENGTH];
		char source_name_temp[MAX_BUFFER_LENGTH];
		char source_id_temp[MAX_BUFFER_LENGTH];
		char target_name_temp[MAX_BUFFER_LENGTH];
		char target_id_temp[MAX_BUFFER_LENGTH];
	
		date = GetTime();
		SQL_EscapeString(weddings_db, source_name, source_name_temp, sizeof(source_name_temp));
		SQL_EscapeString(weddings_db, source_id, source_id_temp, sizeof(source_id_temp));
		SQL_EscapeString(weddings_db, target_name, target_name_temp, sizeof(target_name_temp));
		SQL_EscapeString(weddings_db, target_id, target_id_temp, sizeof(target_id_temp));
		Format(query_delete4source_src, sizeof(query_delete4source_src), sql_deleteProposalsSource, source_id_temp);
		Format(query_delete4target_src, sizeof(query_delete4target_src), sql_deleteProposalsSource, target_id_temp);
		Format(query_delete4source_trg, sizeof(query_delete4source_trg), sql_deleteProposalsTarget, source_id_temp);
		Format(query_delete4target_trg, sizeof(query_delete4target_trg), sql_deleteProposalsTarget, target_id_temp);
		Format(query_add, sizeof(query_add), sql_addMarriage, source_name_temp, source_id_temp, target_name_temp, target_id_temp, 0, date);
		SQL_TQuery(weddings_db, Proposal_Remove, query_delete4source_src);
		SQL_TQuery(weddings_db, Proposal_Remove, query_delete4target_src);
		SQL_TQuery(weddings_db, Proposal_Remove, query_delete4source_trg);
		SQL_TQuery(weddings_db, Proposal_Remove, query_delete4target_trg);
		SQL_TQuery(weddings_db, Marriage_Add, query_add);	
	}
}


/**
 * Checks whether a client is already married.
 *
 * @param client_id				The steam ID of the client.
 * @noreturn
 */
void checkMarriage(char[] client_id) {
	char query[MAX_BUFFER_LENGTH];
	
	if(weddings_db == null) {
		LogError("Unable to connect to database.");
	} else {
		DataPack data = CreateDataPack();
		char client_id_temp[MAX_BUFFER_LENGTH];
		
		SQL_EscapeString(weddings_db, client_id, client_id_temp, sizeof(client_id_temp));
		Format(query, sizeof(query), sql_getMarriage, client_id_temp, client_id_temp);
		WritePackString(data, client_id);
		ResetPack(data, false);
		SQL_TQuery(weddings_db, Marriage_Check, query, data);
	}
}


/**
 * Revokes a client's marriage.
 *
 * @param client_id				The steam ID of the client.
 * @noreturn
 */
void revokeMarriage(char[] client_id) {
	char query[MAX_BUFFER_LENGTH];
	
	if(weddings_db == null) {
		LogError("Unable to connect to database.");
	} else {	
		char client_id_temp[MAX_BUFFER_LENGTH];
		
		SQL_EscapeString(weddings_db, client_id, client_id_temp, sizeof(client_id_temp));
		Format(query, sizeof(query), sql_revokeMarriage, client_id_temp, client_id_temp);
		SQL_TQuery(weddings_db, Marriage_Revoke, query);		
	}
}


/**
 * Retrieves the top couples.
 *
 * @param client				The slot number of the caller.
 * @noreturn
 */
void findMarriages(char[] client_id) {
	char query[MAX_BUFFER_LENGTH];
	
	if(weddings_db == null) {
		LogError("Unable to connect to database.");
	} else {
		DataPack data = CreateDataPack();		
		int show_couples = cvar_couples.IntValue;
		
		WritePackString(data, client_id);
		WritePackCell(data, show_couples);		
		ResetPack(data, false);
		Format(query, sizeof(query), sql_getMarriages, show_couples);
		SQL_TQuery(weddings_db, Marriages_Find, query, data);
	}
}


/**
 * Retrieves the new name of a client.
 *
 * @param client_name			The old name of the client.
 * @param client_id				The steam ID of the client.
 * @param newName 				String to store the new name of the client.
 * @param update_db				If true, the weddings_marriages table will be updated.
 * @param who					Update mode. 0 : update source, 1 : update target.
 * @noreturn
 */
void updateMarriage(char[] client_name, char[] client_id, char[] newName, int update_db, int who)
{
	char query[MAX_BUFFER_LENGTH];
	
	int client_index = getClientBySteamID(client_id);	
	if(client_index == -1) {
		strcopy(newName, MAX_NAME_LENGTH, client_name);
	} else {		
		if(GetClientName(client_index, newName, MAX_NAME_LENGTH) && !StrEqual(newName, client_name) && update_db) {		
			if(weddings_db == null) {
				LogError("Unable to connect to database.");
			} else {
				char newName_temp[MAX_BUFFER_LENGTH];
				char client_id_temp[MAX_BUFFER_LENGTH];
				
				SQL_EscapeString(weddings_db, newName, newName_temp, sizeof(newName_temp));
				SQL_EscapeString(weddings_db, client_id, client_id_temp, sizeof(client_id_temp));
				switch(who) {
					case 0 : {
						Format(query, sizeof(query), sql_updateMarriageSource, newName_temp, client_id_temp);
					}
					case 1 :{
						Format(query, sizeof(query), sql_updateMarriageTarget, newName_temp, client_id_temp);
					}
				}				
				SQL_TQuery(weddings_db, Marriage_Update, query);			
			}
		}
	}
}


/**
 * Updates the marriage score of a client.
 *
 * @param client_id				The steam ID of the client.
 * @noreturn
 */
void updateMarriageScore(char[] client_id) {
	if(weddings_db == null) {
		LogError("Unable to connect to database.");
	} else {
		char query[MAX_BUFFER_LENGTH];
		char client_id_temp[MAX_BUFFER_LENGTH];
		
		SQL_EscapeString(weddings_db, client_id, client_id_temp, sizeof(client_id_temp));
		Format(query, sizeof(query), sql_updateMarriageScore, client_id_temp, client_id_temp);
		SQL_TQuery(weddings_db, Marriage_UpdateScore, query);
	}
}


// Callback for addMarriage.
public void Proposal_Remove(Handle owner, Handle handle, const char[] error, any data)
{
	if(handle == null) {
		LogError("Error removing proposal from database. (%s)", error);
	}
}


// Callback for addMarriage.
public void Marriage_Add(Handle owner, Handle handle, const char[] error, any data) {
	if(handle == null) {
		LogError("Error adding marriage to database. (%s)", error);
	}
}


// Callback for checkMarriage.
public void Marriage_Check(Handle owner, Handle handle, const char[] error, any data) {
	if(handle == null) {
		LogError("Error checking marriage in database. (%s)", error);
	} else {
		int client;
		int partner;
		char client_id[MAX_ID_LENGTH];
		char client_name[MAX_ID_LENGTH];
		char temp_name[MAX_NAME_LENGTH];
		char partner_name[MAX_NAME_LENGTH];
		char partner_id[MAX_ID_LENGTH];
				
		ReadPackString(data, client_id, sizeof(client_id));
		CloseHandle(data);
		client = getClientBySteamID(client_id);
		if(client != -1 && GetClientName(client, client_name, sizeof(client_name))) {
			if(SQL_GetRowCount(handle) == 0) {
				if(GetConVarInt(cvar_disallow) == 1) {	
					char kick_msg[MAX_MSG_LENGTH];
					GetConVarString(cvar_kick_msg, kick_msg, sizeof(kick_msg));
					KickClient(client, kick_msg);
				} else {
					marriage_slots[client] = -2;					
					marriage_names[client] = "";
					marriage_ids[client] = "";
					marriage_scores[client] = -1;
					marriage_times[client] = -1;					
				}
			} else {														
				SQL_FetchRow(handle);
				SQL_FetchString(handle, 1, partner_id, sizeof(partner_id));
				if(StrEqual(client_id, partner_id)) {
					SQL_FetchString(handle, 2, temp_name, sizeof(temp_name));
					SQL_FetchString(handle, 3, partner_id, sizeof(partner_id));
					updateMarriage(temp_name, partner_id, partner_name, true, 1);
				} else {
					SQL_FetchString(handle, 0, temp_name, sizeof(temp_name));
					updateMarriage(temp_name, partner_id, partner_name, true, 0);
				}	
				partner = getClientBySteamID(partner_id);
				if(partner != -1) {
					marriage_slots[partner] = client;
					marriage_names[partner] = client_name;
				}
				marriage_slots[client] = partner;
				marriage_names[client] = partner_name;
				marriage_ids[client] = partner_id;	
				marriage_scores[client] = SQL_FetchInt(handle, 4);			
				marriage_times[client] = SQL_FetchInt(handle, 5);
			}
			marriage_checked[client] = true;
			marriage_beingChecked[client] = false;
		}
	}
}


// Callback for revokeMarriage.
public void Marriage_Revoke(Handle owner, Handle handle, const char[] error, any data) {
	if(handle == null) {
		LogError("Error removing marriage from database. (%s)", error);
	}
}


// Callback for findMarriages.
public void Marriages_Find(Handle owner, Handle handle, const char[] error, any data) {
	if(handle == null) {
		LogError("Error finding marriages in database. (%s)", error);
	} else {		
		int client;
		int show_couples;		
		char client_id[MAX_ID_LENGTH];
		
		ReadPackString(data, client_id, sizeof(client_id));
		show_couples = ReadPackCell(data);
		CloseHandle(data);
		client = getClientBySteamID(client_id);
		if(client != -1) {
			if(SQL_GetRowCount(handle) == 0) {
				PrintToChat(client, "[SM] %t", "no couples");
			} else {
				int score;		
				int date_temp;		
				char date[MAX_DATE_LENGTH];
				char source_id[MAX_ID_LENGTH];
				char target_id[MAX_ID_LENGTH];
				char source_name[MAX_NAME_LENGTH];
				char target_name[MAX_NAME_LENGTH];
				char source_newName[MAX_NAME_LENGTH];
				char target_newName[MAX_NAME_LENGTH];
				char entry[MAX_ERROR_LENGTH];
				Menu couples_menu = new Menu(CouplesMenuHandler, MENU_ACTIONS_DEFAULT);			

				couples_menu.SetTitle("%t", "!couples menu title", show_couples);
				while(SQL_FetchRow(handle)) {
					SQL_FetchString(handle, 0, source_name, sizeof(source_name));
					SQL_FetchString(handle, 1, source_id, sizeof(source_id));
					SQL_FetchString(handle, 2, target_name, sizeof(target_name));
					SQL_FetchString(handle, 3, target_id, sizeof(target_id));
					score = SQL_FetchInt(handle, 4);
					date_temp = SQL_FetchInt(handle, 5);
					FormatTime(date, sizeof(date), DATE_FORMAT, date_temp);
					updateMarriage(source_name, source_id, source_newName, true, 0);
					updateMarriage(target_name, target_id, target_newName, true, 1);
					Format(entry, sizeof(entry), "%t", "!couples menu entry", source_newName, target_newName, date, score);
					AddMenuItem(couples_menu, "", entry);
				}
				DisplayMenu(couples_menu, client, MAX_MENU_DISPLAY_TIME);
			}
		}
	}
}


// Callback for updateMarriage.
public void Marriage_Update(Handle owner, Handle handle, const char[] error, any data) {
	if(handle == null) {
		LogError("Error updating marriage in database. (%s)", error);
	}
}


// Callback for updateMarriageScore.
public void Marriage_UpdateScore(Handle owner, Handle handle, const char[] error, any data) {
	if(handle == null) {
		LogError("Error updating marriage score in database. (%s)", error);
	}
}