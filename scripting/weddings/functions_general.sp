/**
 * Fills the !marry menu with unmarried clients.
 *
 * @param marry_menu			Handle to the menu.
 * @param client				The slot number of the caller.
 * @return						Number of clients added to the menu.
 */ 
int addTargets(Handle marry_menu, int client)
{
	int hits = 0;
	char single_id[MAX_ID_LENGTH];
	char single_name[MAX_NAME_LENGTH];
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(client != i)
		{
			if(IsClientInGame(i) && !IsFakeClient(i) && !IsClientReplay(i))
			{
				if(marriage_slots[i] == -2 && GetClientAuthId(i, AuthId_Engine, single_id, sizeof(single_id))
				&& GetClientName(i, single_name, sizeof(single_name)))
				{					
					AddMenuItem(marry_menu, single_id, single_name);
					hits++;
				}
			}
		}
	}
	return hits;
}


/**
 * Checks for existing proposals and marriages for all connected clients.
 */ 
void checkClients()
{
	char clientid[MAX_ID_LENGTH];
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && !IsClientReplay(i) && !proposal_beingChecked[i] && !marriage_beingChecked[i] 
		&& GetClientAuthId(i, AuthId_Engine, clientid, sizeof(clientid)))
		{
			proposal_beingChecked[i] = true;
			marriage_beingChecked[i] = true;
			checkProposal(clientid);
			checkMarriage(clientid);
		}
	}
}


/**
 * Computes the time a marriage has lasted.
 *
 * @param timestamp				Time of the wedding.
 * @param &time_spent			Destination cell to store the computed time.
 * @param &format				Destination cell to store the format of the computed time. 0 : days, 1 : months, 2 : years.
 * @noreturn					
 */ 
void computeTimeSpent(int timestamp, int &time_spent, int &format)
{
	int now;
	int days;
	
	now = GetTime();
	days = (now - timestamp) / 86400;
	if(days < 30) {
		time_spent = days;
		format = 0;
	} else if(days < 365) {
		time_spent = days / 30;
		format = 1;
	} else {
		time_spent = days / 365;
		format = 2;
	}
}


/**
 * Finds the slot number of a client.
 *
 * @param clientid				The steam ID of a client.
 * @return						The slot number if the client is connected, -1 otherwise.					
 */
int getClientBySteamID(char[] clientid)
{
	int client = -1;
	char temp_id[MAX_ID_LENGTH];
		
	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientConnected(i) && !IsFakeClient(i) && !IsClientReplay(i) && GetClientAuthId(i, AuthId_Engine, temp_id, sizeof(temp_id))) {			
			if(StrEqual(clientid, temp_id)) {
				client = i;
				break;
			}			
		}
	}
	return client;
}


/**
 * Stores a client who successfully used a command.
 *
 * @param clientid				The steam ID of a client.
 * @noreturn					
 */
void cacheUsage(char[] clientid)
{
	float delay;
	DataPack data = CreateDataPack();
	
	delay = GetConVarFloat(cvar_delay) * 60;
	if(delay > 0) {
		PushArrayString(usage_cache, clientid);
		WritePackString(data, clientid);
		ResetPack(data, false);
		CreateTimer(delay, Uncache, data);
	}
}


/**
 * Checks if a client is allowed to use a command.
 *
 * @param clientid				The steam ID of a client.
 * @return						True if the client is allowed to, false otherwise.					
 */
bool checkUsage(char[] clientid)
{
	bool allowed = true;
	int entries = GetArraySize(usage_cache);
	char clientid_stored[MAX_ID_LENGTH];
	
	for(int i = 0; i < entries; i++)
	{
		GetArrayString(usage_cache, i, clientid_stored, sizeof(clientid_stored));
		if(StrEqual(clientid, clientid_stored))
		{
			allowed = false;
			break;
		}
	}
	return allowed;
}


/**
 * Selects and initiates a database connection.
 *
 * @noreturn			
 */
void initDatabase()
{
	int database;
	
	database = GetConVarInt(cvar_database);
	switch(database) {
		case 0 : {
			SQL_TConnect(DB_Connect, "storage-local");
		}
		case 1 : {
			if(SQL_CheckConfig("weddings")) {
				SQL_TConnect(DB_Connect, "weddings");
			} else {
				LogError("Unable to find \"weddings\" entry in \"sourcemod\\configs\\databases.cfg\".");
			}
		}
	}
}


/**
 * Creates the weddings_proposals and weddings_marriages tables.
 *
 * @noreturn			
 */
void createTables() {
	if(weddings_db == null) {
		LogError("Unable to connect to database.");
	} else {
		SQL_TQuery(weddings_db, DB_Create, sql_createProposals);
		SQL_TQuery(weddings_db, DB_Create, sql_createMarriages);
	}
}


/**
 * Deletes all data from the weddings_proposals and weddings_marriages tables.
 *
 * @param client				Slot number of the caller.
 * @noreturn			
 */
void resetTables(int client) {
	if(weddings_db == null) {
		LogError("Unable to connect to database.");
	} else {
		DataPack data_proposals = CreateDataPack();
		DataPack data_marriages = CreateDataPack();
		WritePackCell(data_proposals, 0);
		WritePackCell(data_proposals, client);
		ResetPack(data_proposals, false);
		WritePackCell(data_marriages, 1);
		WritePackCell(data_marriages, client);
		ResetPack(data_marriages, false);
		SQL_TQuery(weddings_db, DB_Reset, sql_resetProposals, data_proposals);
		SQL_TQuery(weddings_db, DB_Reset, sql_resetMarriages, data_marriages);
	}
}


// Callback for initDatabase.
public void DB_Connect(Handle owner, Handle handle, const char[] error, any data)
{
	if(handle == null)
	{
		LogError("Unable to initiate database connection. (%s)", error);
	} else {
		weddings_db = handle;
		createTables();
	}
}


// Callback for createTables.
public void DB_Create(Handle owner, Handle handle, const char[] error, any data) {
	if(handle == INVALID_HANDLE) {
		LogError("Error creating tables in database. (%s)", error);
	} else {
		checkClients();
	}
}


// Callback for resetTables.
public void DB_Reset(Handle owner, Handle handle, const char[] error, any data)
{
	if(handle == INVALID_HANDLE) {
		LogError("Error resetting tables in database. (%s)", error);
	} else {
		int type = ReadPackCell(data);
		int client = ReadPackCell(data);
		CloseHandle(data);
		if(IsClientInGame(client)) {
			switch(type) {
				case 0 : {
					PrintToChat(client, "[SM] %t", "reset proposals");
				}
				case 1 : {
					PrintToChat(client, "[SM] %t", "reset marriages");
				}
			}
		}
	}
}


/**
 * Calls the OnProposal forward.
 *
 * @param proposer			The slot number of the proposer. 
 * @param target			The slot number of the target.
 * @noreturn 					 
 */
void forwardProposal(int proposer, int target)
{
	Call_StartForward(forward_proposal);
	Call_PushCell(proposer);
	Call_PushCell(target);
	Call_Finish();
}


/**
 * Calls the OnWedding forward.
 *
 * @param proposer			The slot number of the proposer. 
 * @param accepter			The slot number of the accepter.
 * @noreturn 					 
 */
void forwardWedding(int proposer, int accepter) {
	Call_StartForward(forward_wedding);
	Call_PushCell(proposer);
	Call_PushCell(accepter);
	Call_Finish();
}


/**
 * Calls the OnDivorce forward.
 *
 * @param divorcer			The slot number of the divorcer.
 * @param partner			The slot number of the partner, -1 if the partner is not connected.
 * @noreturn 					 
 */
void forwardDivorce(int divorcer, int iPartner) {
	Call_StartForward(forward_divorce);
	Call_PushCell(divorcer);
	Call_PushCell(iPartner);
	Call_Finish();
}