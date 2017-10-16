#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <updater>

#define VERSION "1.1.2"
#define UPDATE_URL "http://www.mukunda.com/plugins/bacon/bacon_updatefile.txt"
#define HOT_BACON 1 // very tasty bacon
#define DEFAULT_BACON_NOTIFY "3"
#define DEFAULT_BACON_COOLDOWN "3.0"
#define DEFAULT_BACON_TOPCOUNT "1"
#define BACON_MAX_TOPCOUNT 10

// TODO: Make any print functions utilize the proper colorvariables variant

//-------------------------------------------------------------------------------------------------
public Plugin myinfo = {
	name = "bacon",
	author = "mukunda",
	description = "A delicious system to share your bacon with other players.",
	version = VERSION,
	url = "http://bacolicio.us/http://www.sourcemod.net"
}
 


Handle bacon_db;

bool bacon_refreshing[MAXPLAYERS+1];	// bacon amount is being loaded
bool bacon_cached[MAXPLAYERS+1];		// bacon amount is loaded
int bacon_amount[MAXPLAYERS+1];				// bacon amount (see above)
float bacon_action_time[MAXPLAYERS+1];// last time a BACON query was used by a client

//-------------------------------------------------------------------------------------------------
// CVARS (see InitCVars for descriptions)

Handle sm_bacon_notify;
int c_bacon_notify;

enum {
	BACON_NOTIFY_NONE,
	BACON_NOTIFY_TARGET,
	BACON_NOTIFY_ALL,
	BACON_NOTIFY_GIFT
};



Handle sm_bacon_cooldown;// cooldown to prevent bacon from clogging the system
float c_bacon_cooldown;


Handle sm_bacon_topcount; // how many bacon masters should be shown for sm_mostbacon
int c_bacon_topcount;

char colorcode_player[16] = "\x03";
char colorcode_bacon[16] = "";

//-------------------------------------------------------------------------------------------------

int game_index;

enum {
	GAME_CSS,
	GAME_CSGO,
	GAME_TF2,
	GAME_OTHER
}

//-------------------------------------------------------------------------------------------------

int st2_source; // source for SayText2 messages

//-------------------------------------------------------------------------------------------------
void GetGameIndex()
{
	char buffer[64];
	GetGameFolderName( buffer, sizeof buffer );
	
	if( StrEqual( buffer, "csgo", false ) ) {
		game_index = GAME_CSGO;
	} else if( StrEqual( buffer, "css", false ) ) {
		game_index = GAME_CSS;
		
	} else if( StrEqual( buffer, "tf2", false ) || StrEqual( buffer, "tf", false ) ) {
		game_index = GAME_TF2;
		
	} else {
		game_index = GAME_OTHER;
	}
	
	// game related initialization...
	if( game_index == GAME_CSS || game_index == GAME_TF2 ) {
		colorcode_bacon = "\x07bf4e17";//b14216"; // a very delicious baconal colour
		colorcode_player = "\x03";
	} else if( game_index == GAME_CSGO ) {
		colorcode_bacon = "\x09";
		colorcode_player = "\x03";
	} else {
		///????
	}
}

//-------------------------------------------------------------------------------------------------
void InitBaconDatabase()
{

	// init BACON database //
	
	char error[255];
	bacon_db = SQLite_UseDatabase("sourcemod-local", error, sizeof(error));
	if( bacon_db == INVALID_HANDLE ) {
		SetFailState( "SQL ERROR: %s", error );
	}
	
	SQL_LockDatabase( bacon_db );
	
	// a table for keeping bacon 
	SQL_FastQuery( bacon_db, "CREATE TABLE IF NOT EXISTS BACON2 (source INTEGER, dest INTEGER);");
	
	// a table to keep track of names (FOR MOST BACON)
	SQL_FastQuery( bacon_db, "CREATE TABLE IF NOT EXISTS BACON_NAME_CACHE2 (source INTEGER PRIMARY KEY, name TEXT);");
	
	SQL_UnlockDatabase( bacon_db );
}

//-------------------------------------------------------------------------------------------------
public void OnConVarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (convar == sm_bacon_notify)
	{ 
		c_bacon_notify = GetConVarInt(sm_bacon_notify);
	} 
	else if (convar == sm_bacon_cooldown)
	{
		c_bacon_cooldown = GetConVarFloat(sm_bacon_cooldown);
		ResetAllBaconCooldowns();
	}
	else if (convar == sm_bacon_topcount)
	{
		c_bacon_topcount = GetConVarInt(sm_bacon_topcount);
	}
}

//-------------------------------------------------------------------------------------------------
void InitCVars() {
	sm_bacon_notify = CreateConVar("sm_bacon_notify", DEFAULT_BACON_NOTIFY, "Notify when bacon is given or taken. (0=off, 1=notify target only, 2=notify everyone, 3=gift notify)", 0, true, 0.0, true, 3.0);
	HookConVarChange(sm_bacon_notify, OnConVarChanged);
	c_bacon_notify = GetConVarInt( sm_bacon_notify );
	
	sm_bacon_cooldown = CreateConVar( "sm_bacon_cooldown",DEFAULT_BACON_COOLDOWN,
		"Time (seconds) clients must wait between bacon transactions.",
		0, true, 0.0 );
	HookConVarChange( sm_bacon_cooldown, OnConVarChanged );
	c_bacon_cooldown = GetConVarFloat( sm_bacon_cooldown );
	
	sm_bacon_topcount = CreateConVar( "sm_bacon_topcount", DEFAULT_BACON_TOPCOUNT, "How many bacon masters should be shown when sm_mostbacon is used.", 0, true, 1.0, true, float(BACON_MAX_TOPCOUNT));
	HookConVarChange(sm_bacon_topcount, OnConVarChanged);
	c_bacon_topcount = GetConVarInt( sm_bacon_topcount );
		 
	AutoExecConfig();
}

//-------------------------------------------------------------------------------------------------
public void OnPluginStart() {
	
	// public cvar!
	CreateConVar("serves_bacon", "YES", "The answer to your question.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	GetGameIndex();
	
	LoadTranslations("common.phrases");
	LoadTranslations( "bacon.phrases" );
	
	InitCVars();
	InitBaconDatabase();
	
	RegConsoleCmd( "sm_bacon", Command_bacon, "Give Bacon" );
	RegConsoleCmd( "sm_nobacon", Command_nobacon, "Take Bacon" );
	RegConsoleCmd( "sm_takebacon", Command_nobacon, "Take Bacon" );
	RegConsoleCmd( "sm_mostbacon", Command_mostbacon, "Who has the most Bacon?" );
	
	RegServerCmd( "sm_bacon_drop", CommandDrop, "Eat all bacon" );
	
	// keep bacon fresh
	if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
	
}

//-------------------------------------------------------------------------------------------------
public void OnLibraryAdded(const char[] name)
{
	// nobody likes old bacon
	if(StrEqual(name, "updater")) 
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}

//-------------------------------------------------------------------------------------------------
void ResetAllBaconCooldowns() {
	for(int i = 0; i <= MaxClients; i++)
	{
		bacon_action_time[i] = -9000.0;
	}
}

//-------------------------------------------------------------------------------------------------
public void OnMapStart() {
	ResetAllBaconCooldowns();
}

//-------------------------------------------------------------------------------------------------

// easy functions to set reply source and restore within one level
ReplySource old_reply_source;
void SetReplySource(ReplySource Source)
{
	old_reply_source = GetCmdReplySource();
	SetCmdReplySource(Source);
}

//-------------------------------------------------------------------------------------------------
void RestoreReplySource() {
	SetCmdReplySource(old_reply_source);
}

//-------------------------------------------------------------------------------------------------
public void OnClientConnected(int iClient)
{
	bacon_refreshing[iClient] = false;
	bacon_cached[iClient] = false;
	bacon_amount[iClient] = 0;
	bacon_action_time[iClient] = -c_bacon_cooldown;
	// im getting a little hungry
}	

//-------------------------------------------------------------------------------------------------
bool ProcessColorCodes(char[] message, int maxlen)
{
	
	ReplaceString(message, maxlen, "{CMD}", ""); // unused color code, might change mind later

	int count = 0;
	int requires_st2 = 0;
	count += ReplaceString( message, maxlen, "{DEF}", "\x01" );
	requires_st2 = ReplaceString( message, maxlen, "{PLAYER}", colorcode_player );
	count += requires_st2;
	count += ReplaceString( message, maxlen, "{BACON}", colorcode_bacon );
	
	if( count > 0 ) {
		if( game_index == GAME_CSGO ) {
			Format( message, maxlen, "\x01\x0B\x01%s", message );
		} else {
			Format( message, maxlen, "\x01%s", message );
		}
	}
	return requires_st2 > 0;
}

//-------------------------------------------------------------------------------------------------
void RemoveColorCodes( char[] message, int maxlen ) {
	ReplaceString( message, maxlen, "{CMD}", "" ); // unused color code, might change mind later
	ReplaceString( message, maxlen, "{DEF}", "" );
	ReplaceString( message, maxlen, "{PLAYER}", "" );
	ReplaceString( message, maxlen, "{BACON}", "" );
}

void SayText2( int client, const char[] message) {
	 
	Handle hBf = StartMessageOne("SayText2", client);
	if (hBf != INVALID_HANDLE) {
		if (GetUserMessageType() == UM_Protobuf)
		{
			PbSetBool(hBf, "chat", true); // this controls the click sound when the message is sent
			PbSetInt( hBf, "ent_idx", st2_source );
			PbSetString( hBf, "msg_name", message );
			PbAddString(hBf, "params", "");
			PbAddString(hBf, "params", "");
			PbAddString(hBf, "params", "");
			PbAddString(hBf, "params", "");
		}
		else
		{
			BfWriteByte(hBf,   st2_source);
			BfWriteByte(hBf,   true); // this controls the click sound when the message is sent
			BfWriteString(hBf, message);
		}
		EndMessage();
	}
	
}

//-------------------------------------------------------------------------------------------------
void BaconPrint( int client, any ... ) {
	char message[256];
    
	if( client == 0 ) {
		SetGlobalTransTarget(LANG_SERVER);
	} else {
		SetGlobalTransTarget(client);
	}
	VFormat( message, sizeof(message), "%t", 2 );
	if( client == 0 || GetCmdReplySource() == SM_REPLY_TO_CONSOLE ) {
		RemoveColorCodes( message, sizeof(message) );
		
		ReplyToCommand( client, message );
		
	} else {
		if( ProcessColorCodes( message, sizeof(message) ) && st2_source != 0 ) {
			// need to use saytext2 to set client source
			SayText2( client, message );
			
		} else {
			// use normal printing
			PrintToChat( client, message );
		}
		
	}
	
}

//-------------------------------------------------------------------------------------------------
void BaconPrint2( int client, any ... ) {
	// bacon print variation without command context
	char message[256];
	if( client == 0 ) {
		SetGlobalTransTarget(LANG_SERVER);
		VFormat( message, sizeof(message), "%t", 2 );
		RemoveColorCodes( message, sizeof(message) );
		
		PrintToServer( message );
	} else {
		SetGlobalTransTarget(client);
		VFormat( message, sizeof(message), "%t", 2 );
		
		if( ProcessColorCodes( message, sizeof(message) ) && st2_source != 0 ) {
			// need to use saytext2 to set client source
			SayText2( client, message );
		} else {
			// use normal printing
			PrintToChat( client, message );
		}
	}
}


//-------------------------------------------------------------------------------------------------
void BaconPrintAll( any ... ) {

	// this following code is the slowest shit ever
	// ...like i give a shit
	char message[256];	
	for( int i = 0; i <= MaxClients; i++ ) {
		if( i != 0 ) if( !IsClientInGame(i) ) continue;
		
		
		SetGlobalTransTarget( i == 0 ? LANG_SERVER : i );
		VFormat( message, sizeof(message), "%t", 1 );
		
		
		if( i == 0 ) {
			RemoveColorCodes( message, sizeof(message) );
			PrintToServer( message );
		} else {
			if( ProcessColorCodes( message, sizeof(message) ) && st2_source != 0 ) {
			// need to use saytext2 to set client source
				SayText2( i, message );
			} else {
				// use normal printing (which probably does the same thing?)
				PrintToChat( i, message );
			}
		}
	}
}

//-------------------------------------------------------------------------------------------------
bool BaconFloodCheck( int client, bool print = true, bool set = true ) {
	if( (GetGameTime() - bacon_action_time[client]) < c_bacon_cooldown ) {
		if( print ) BaconPrint( client, "TOO MUCH BACON" );
		return true;
	}
	
	if( set ) {
		bacon_action_time[client] = GetGameTime();
	}
	return false;
}

//-------------------------------------------------------------------------------------------------
int GetBaconAccountID( int client ) {
	return client == 0 ? 0 : GetSteamAccountID(client);
}
/*
FormatAuthCode( client, char[] authcode[], maxlen ) {
	// for server, use 0
	if( client == 0 ) {
		Format( authcode, maxlen, "0" );
		return;
	}
	
	// translate steamid into pure bacon number string
	char steamid[64];
	GetClientAuthString( client, steamid, sizeof(steamid) );
	// STEAM_X:Y:ZZZZZZ
	// 01234567890
	Format( authcode, maxlen, "%c%s", steamid[8], steamid[10] );
}*/

//-------------------------------------------------------------------------------------------------
bool ValidateBaconTransaction( int client, int target ) {
	if( client < 0 || client > MaxClients ) return false;
	if( target < 0 || target > MaxClients ) {
		BaconPrint( client, "INVALID TRANSACTION" );
		return false;
	}
	if( client != 0 ) {
		if(!IsClientAuthorized(client) ) {
			BaconPrint( client, "INVALID TRANSACTION" );
			return false;
		}
	}
	if( target != 0 ) {
		if( !IsClientAuthorized( target ) ) {
			BaconPrint( client, "INVALID TRANSACTION" );
			return false;
		}
	}
	return true; // BACON TRANSACTION AUTHORIZED
}

//-------------------------------------------------------------------------------------------------
int GetBaconClient( int userid ) { // mmm... bacon client
	if( userid == 0 ) return 0;
	int a = GetClientOfUserId( userid );
	return a == 0 ? -1 : a;
}

//-------------------------------------------------------------------------------------------------
int GetBaconUserId( int client ) {
	if( client == 0 ) return 0;
	return GetClientUserId( client );
}

//-------------------------------------------------------------------------------------------------
void PrintBaconAmount( int client ) {
	if( bacon_amount[client] != 0 )
		BaconPrint( client, "YOU HAVE ___ BACON", bacon_amount[client] );
	else
		BaconPrint( client, "YOU HAVE NO BACON" );
	// todo: system that supports parallel universes where other numbers are singular and one may be plural
}

//-------------------------------------------------------------------------------------------------
public void ShowBaconQuery( Handle owner, Handle hndl, const char[] error, any pack ) {
	ResetPack(pack);
	int client = GetBaconClient( ReadPackCell(pack) );
	ReplySource rs =  ReadPackCell(pack);
	CloseHandle(pack);
	if( client == -1 ) return;
	
	SetReplySource( rs );
	
	bacon_refreshing[client] = false;
	
	if( !hndl ) {
		bacon_cached[client] = false;
		LogMessage( "ShowBaconQuery Database Error: %s", error );
		BaconPrint( client, "BACON DATABASE ERROR" );
		RestoreReplySource();
		return;
	}
	
	bacon_cached[client] = true;
	
	if( SQL_GetRowCount(hndl) == 0 ) {
		bacon_amount[client] = 0;
	} else {
		SQL_FetchRow(hndl);
		bacon_amount[client] = SQL_FetchInt( hndl, 0 );
	}
	
	PrintBaconAmount(client);
	
	RestoreReplySource();
}

//-------------------------------------------------------------------------------------------------
void ShowBacon( int client ) {
	if( bacon_cached[client] ) {
	
		// tell the user how much bacon he has
		PrintBaconAmount(client);
		return;
	}
	
	// catch refresh in progress
	if( bacon_refreshing[client] ) {
		BaconPrint( client, "TOO MUCH BACON" );
		return;
	}
	
	// prevent system bacon overload //
	if( BaconFloodCheck(client) ) return;
	
	// refresh bacon amount //
	bacon_refreshing[client] = true;
	char query[256];
	int authcode = GetBaconAccountID( client );
	//char authcode[64];
	//FormatAuthCode( client, authcode, sizeof(authcode) );
	Format(query, sizeof(query), "SELECT SUM(1) FROM BACON2 WHERE dest=%d", authcode );
	
	Handle pack = CreateDataPack();
	WritePackCell( pack, GetBaconUserId(client) );
	WritePackCell( pack, view_as<int>(GetCmdReplySource()) );
	SQL_TQuery( bacon_db, ShowBaconQuery, query, pack );
}

//-------------------------------------------------------------------------------------------------
public void GiveBaconInsert( Handle owner, Handle hndl, const char[] error, any pack ) {
	ResetPack(pack);
	int client = GetBaconClient(ReadPackCell(pack));
	int target = GetBaconClient(ReadPackCell(pack));
	ReplySource rs = ReadPackCell(pack);
	CloseHandle(pack);
	if( client == -1 ) return; // client disconnected
	SetReplySource(rs);
	
	// handle errors
	if( !hndl ) {
		LogMessage( "GiveBaconInsert Database Error: %s", error );
		BaconPrint( client, "BACON DATABASE ERROR" );
		RestoreReplySource();
		return;
	}
	
	char targetname[64];
	if( target != -1 ) GetClientName( target, targetname, sizeof(targetname) );
	else targetname = "???";
	char clientname[64];
	if( client != -1 ) GetClientName( client, clientname, sizeof(clientname) );
	else clientname = "???";
	
	st2_source = target;
	
	if( target == 0 ) {
		BaconPrint( client, "YOU GAVE SERVER SOME BACON" );
	} else {
		BaconPrint( client, "YOU GAVE ___ SOME BACON", targetname );
	}
	
	
	if( target >= 0 ) {
		
		if( c_bacon_notify == BACON_NOTIFY_TARGET ) {
			// notify target
			
			if( client == 0 ) {
				BaconPrint2( target, "GOT BACON FROM SERVER" );
			} else {
				BaconPrint2( target, "GOT BACON", clientname );
			}
		} else if( c_bacon_notify == BACON_NOTIFY_ALL ) {
			// notify all targets, i'm sure the server wants to know about this too

			if( target == 0 ) {
				BaconPrintAll( "SOMEONE GAVE SERVER BACON", clientname );
				
			} else if( client == 0 ) {
				BaconPrintAll( "SERVER GAVE SOMEONE BACON", targetname );
			} else {
				BaconPrintAll( "SOMEONE GAVE BACON", clientname, targetname );
			} 
		} else if( c_bacon_notify == BACON_NOTIFY_GIFT ) {
			
			if( target == 0 ) {
				BaconPrintAll( "SERVER RECEIVED BACON GIFT" );
			} else {
				BaconPrintAll( "RECEIVED BACON GIFT", targetname );
			}
		}
	}
	
	// reset bacon cache
	if( target != -1 ) {
		bacon_cached[target] = false;
	}
	
	RestoreReplySource();
}

//-------------------------------------------------------------------------------------------------
public void GiveBaconSelect( Handle owner, Handle hndl, const char[] error, any pack ) {
	ResetPack(pack);
	int client = GetBaconClient( ReadPackCell(pack) );
	int target = GetBaconClient( ReadPackCell(pack) );
	ReplySource rs = ReadPackCell(pack);
		
	SetReplySource(rs);
	
	// check if either clients disconnected
	if( target == -1 || client == -1 ) {
		CloseHandle(pack);
		if( client != -1 ) {
			BaconPrint( client, "GIVEBACON DISCONNECTED" );
		}
		RestoreReplySource();
		return;
	}
	
	// handle errors
	if( !hndl ) {
		CloseHandle(pack);
		LogMessage( "GiveBaconSelect Database Error: %s", error );
		BaconPrint( client, "BACON DATABASE ERROR" );
		RestoreReplySource();
		return;
	}
	
	st2_source = target;
	
	// if rowcount != 0, the client has already given the target bacon
	if( SQL_GetRowCount(hndl) != 0 ) {
		CloseHandle(pack);
		if( target != 0 ) {
			BaconPrint( client, "ALREADY GAVE BACON" );
		} else {
			BaconPrint( client, "ALREADY GAVE SERVER" );
		}
		RestoreReplySource();
		return;
	}
	
	// insert new (delicious) bacon into system
	char query[256];
	int source = GetBaconAccountID(client);
	int dest = GetBaconAccountID(target);
	
	Format( query, sizeof(query), "INSERT INTO BACON2 VALUES (%d,%d)", source, dest );
	SQL_TQuery( bacon_db, GiveBaconInsert, query, pack );
	
	RestoreReplySource();
}

//-------------------------------------------------------------------------------------------------
void GiveBacon( int client, int target ) {

	if( client == target ) {
		BaconPrint( client, "NO SELF BACONING" );
		return;
	}
	
	if( !ValidateBaconTransaction( client, target ) ) return;
	
	// prevent system bacon overload //
	if( BaconFloodCheck(client) ) return;
	
	// give bacon to user //
	char query[1024]; 
	
	int source = GetBaconAccountID( client );
	int dest = GetBaconAccountID( target );
	
	Format( query, sizeof(query), "SELECT * FROM BACON2 WHERE source=%d AND dest=%d", source, dest );
	
	Handle pack = CreateDataPack();
	WritePackCell( pack, GetBaconUserId(client) );
	WritePackCell( pack, GetBaconUserId(target) );
	WritePackCell( pack, view_as<int>(GetCmdReplySource()) );
	
	SQL_TQuery( bacon_db, GiveBaconSelect, query, pack );
	
	// other than server, recache client name
	if( target != 0 ) {
		char name[128];
		char escapedname[512];
		GetClientName( target, name, sizeof(name) );
		
		// bacon sql injection from a person's username, it could happen??
		SQL_EscapeString( bacon_db, name, escapedname, sizeof(escapedname) );
		
		Format( query, sizeof(query), "INSERT OR REPLACE INTO BACON_NAME_CACHE2 VALUES (%d,'%s')", dest, escapedname );
		
		SQL_TQuery( bacon_db, CacheBaconTarget, query );
	}
}

//-------------------------------------------------------------------------------------------------
public void CacheBaconTarget( Handle owner, Handle hndl, const char[] error, any data ) {
	// handle errors
	if( !hndl ) {
		LogMessage( "CacheBaconTarget Database Error: %s", error );
	}
}

//-------------------------------------------------------------------------------------------------
public void TakeBaconDelete( Handle owner, Handle hndl, const char[] error, any pack ) {
	ResetPack(pack);
	int client = GetBaconClient( ReadPackCell(pack) );
	int target = GetBaconClient( ReadPackCell(pack) );
	ReplySource rs = ReadPackCell(pack);
	CloseHandle(pack);
	if( client == -1 ) return; // client disconnected
	
	SetReplySource(rs);

	// handle errors
	if( !hndl ) {
		LogMessage( "TakeBaconDelete Database Error: %s", error );
		BaconPrint( client, "BACON DATABASE ERROR" );
		RestoreReplySource();
		return;
	}
	
	char targetname[64]; 
	if( target != -1 ) GetClientName( target, targetname, sizeof(targetname) );
	else targetname = "???";
	char clientname[64];
	if( client != -1 ) GetClientName( client, clientname, sizeof(clientname) );
	else clientname = "???";
	
	st2_source = target;
	
	if( target == 0 ) {
		BaconPrint( client, "YOU TOOK YOUR BACON AWAY FROM SERVER" );
	} else {
		BaconPrint( client, "YOU TOOK YOUR BACON AWAY FROM ___", targetname );
	}
	
	if( target >= 0 ) {
		
		if( c_bacon_notify == BACON_NOTIFY_TARGET ) {
			// notify target
			
			if( client == 0 ) {
				BaconPrint2( target, "SERVER TOOK YOUR BACON" );
			} else {
				BaconPrint2( target, "SOMEONE TOOK YOUR BACON", clientname );
			}
		} else if( c_bacon_notify == BACON_NOTIFY_ALL ) {
			// notify all targets, i'm sure the server wants to know about this too
			

			if( target == 0 ) {
				BaconPrintAll( "SOMEONE TOOK SERVER BACON", clientname );
			} else if( client == 0 ) {
				BaconPrintAll( "SERVER TOOK SOMEONES BACON", targetname );
			} else {
				BaconPrintAll( "SOMEONE TOOK BACON", clientname, targetname );
			}
		} else if( c_bacon_notify == BACON_NOTIFY_GIFT ) {
			if( target == 0 ) {
			
				BaconPrintAll( "SERVER LOST BACON" );
			} else {
			
				BaconPrintAll( "LOST BACON", targetname );
			}
		}
	}
	
	// reset bacon cache
	if( target != -1 ) {
		bacon_cached[target] = false;
	}
	RestoreReplySource();
}

//-------------------------------------------------------------------------------------------------
public void TakeBaconSelect( Handle owner, Handle hndl, const char[] error, any pack ) {
	ResetPack(pack);
	int client = GetBaconClient( ReadPackCell(pack) );
	int target = GetBaconClient( ReadPackCell(pack) );
	ReplySource rs = ReadPackCell(pack);
	
	SetReplySource(rs);
	
	// check if either clients disconnected
	if( target == -1 || client == -1 ) {
		CloseHandle(pack);
		if( client != -1 ) {
			BaconPrint( client, "TAKEBACON DISCONNECTED" );
		}
		RestoreReplySource();
		return;
	}
	
	// handle errors
	if( !hndl ) {
		CloseHandle(pack);
		LogMessage( "TakeBaconSelect Database Error: %s", error );
		BaconPrint( client, "BACON DATABASE ERROR" );
		RestoreReplySource();
		return;
	}
	
	if( SQL_GetRowCount(hndl) == 0 ) {
		CloseHandle(pack);
		if( target == 0 )
			BaconPrint( client, "NO SERVER BACON TO TAKE" );
		else
			BaconPrint( client, "NO BACON TO TAKE" );
		RestoreReplySource();
		return;
	}
	
	RestoreReplySource();
	
	char query[512]; 
	int source = GetBaconAccountID( client );
	int dest = GetBaconAccountID( target );
	
	Format( query, sizeof(query), "DELETE FROM BACON2 WHERE source=%d AND dest=%d", source, dest );
	SQL_TQuery( bacon_db, TakeBaconDelete, query, pack );
	
}

//-------------------------------------------------------------------------------------------------
void TakeBacon( int client, int target ) {
	
	if( client == target ) {
		BaconPrint( client, "NO SELF TAKING" );
		return;
	}
	
	if( !ValidateBaconTransaction( client, target ) ) return;
	
	// prevent system bacon overload //
	if( BaconFloodCheck(client) ) return;
	
	// take bacon from user
	char query[512];
	int source = GetBaconAccountID( client );
	int dest = GetBaconAccountID( target );
	Format( query, sizeof(query), "SELECT * FROM BACON2 WHERE source=%d AND dest=%d", source, dest );
	
	Handle pack = CreateDataPack();
	WritePackCell( pack, GetBaconUserId(client) );
	WritePackCell( pack, GetBaconUserId(target) );
	WritePackCell( pack, view_as<int>(GetCmdReplySource()) );
	
	SQL_TQuery( bacon_db, TakeBaconSelect, query, pack );
}

//-------------------------------------------------------------------------------------------------
public void MostBaconQueryNames( Handle owner, Handle hndl, const char[] error, any pack ) {
	ResetPack(pack);
	int client = GetBaconClient( ReadPackCell(pack) );
	ReplySource rs = ReadPackCell(pack);
	int topcount = ReadPackCell(pack);
	////////////////////CloseHandle(pack);
	
	if( client == -1 ) {
		CloseHandle(pack);
		return;
	}
	
	SetReplySource(rs);
	
	// handle errors
	if( !hndl ) {
		CloseHandle(pack);
		LogMessage( "MostBaconQueryNames Database Error: %s", error );
		BaconPrint( client, "BACON DATABASE ERROR" );
		RestoreReplySource();
		return;
	}
	 
	int accounts[BACON_MAX_TOPCOUNT];
	char names[BACON_MAX_TOPCOUNT][64];
	
	int rows = SQL_GetRowCount(hndl);
	for( int i = 0; i < rows; i++ ) {
		SQL_FetchRow(hndl);
		accounts[i] = SQL_FetchInt( hndl, 0 );
		SQL_FetchString( hndl, 1, names[i], sizeof(names[]) );
	}
	 
	st2_source = 0;
	
	for( int i = 0; i < topcount; i++ ) {
		
		char bacon_master_name[64] = "???";
		
		int id = ReadPackCell(pack);
		int count = ReadPackCell(pack);
		
		if( id != 0 ) {
			for( int j = 0; j < rows; j++ ) {
				if( id == accounts[j] ) {
					strcopy( bacon_master_name, sizeof bacon_master_name, names[j] );
					break;
				}
			}
		}
		
		if( topcount == 1 ) {
			if( id == 0 ) {
				BaconPrint( client, "SERVER MOST BACON", count );
			} else {
				BaconPrint( client, "MOST BACON", bacon_master_name, count );
			}
		} else {
			if( id == 0 ) {
				BaconPrint( client, "SERVER HAS BACON", count );
			} else {
				BaconPrint( client, "PERSON HAS BACON", bacon_master_name, count );
			}
		}
	}
	 
	CloseHandle(pack);
	RestoreReplySource();
	
	// phew, that was a lot of work!
}

//-------------------------------------------------------------------------------------------------
public void MostBaconQuery( Handle owner, Handle hndl, const char[] error, any pack ) {
	ResetPack(pack);
	int client = GetBaconClient( ReadPackCell(pack) );
	ReplySource rs = ReadPackCell(pack);
	if( client == -1 ) return;
	
	SetReplySource(rs);
	
	// handle errors
	if( !hndl ) {
		CloseHandle(pack);
		LogMessage( "MostBaconQuery Database Error: %s", error );
		BaconPrint( client, "BACON DATABASE ERROR" );
		RestoreReplySource();
		return;
	}
	
	int rows = SQL_GetRowCount(hndl);
	
	
	st2_source = 0;
	
	if( rows == 0 ) {
		CloseHandle(pack);
		BaconPrint( client, "NOBODY HAS BACON" );
		RestoreReplySource();
		return;
	}
	
	char query[1024];
	
	Format( query, sizeof(query), "SELECT source,name FROM BACON_NAME_CACHE2 WHERE " );// source=%s", sourcecode );
	
	ResetPack(pack);
	WritePackCell( pack, GetBaconUserId(client) );
	WritePackCell( pack, view_as<int>(rs) );
	WritePackCell( pack, rows );
	
	for( int i = 0; i < rows; i++ ) {
		SQL_FetchRow( hndl );
		int sourcecode = SQL_FetchInt( hndl, 0 );
		int count = SQL_FetchInt( hndl, 1 );
		
		char condition[64];
		Format( condition, sizeof condition, "%ssource=%d", i==0 ? "" : " OR ", sourcecode );
		 
		StrCat( query, sizeof(query), condition );
		
		WritePackCell( pack, sourcecode );
		WritePackCell( pack, count );
	}
	 
	RestoreReplySource();
	
	// lookup in bacon name cache the names of the bacon masters
	SQL_TQuery( bacon_db, MostBaconQueryNames, query, pack ); 
	
} 

//-------------------------------------------------------------------------------------------------
int GetBaconTarget( int client ) {
	char arg[64];
	GetCmdArg( 1, arg, sizeof(arg) );
	if( StrEqual( arg, "server", false ) ) {
		return 0;
	} else {
		return FindTarget( client, arg, true, false );
	}
}

//-------------------------------------------------------------------------------------------------
public Action Command_bacon( int client, int args ) {
	if( args == 0 ) {
		ShowBacon(client);
		return Plugin_Handled;
	}
	
	int target = GetBaconTarget( client );
	if( target == -1 ) return Plugin_Handled;
	
	GiveBacon( client, target );
	
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action Command_nobacon( int client, int args ) {
	if( args == 0 ) {
		BaconPrint( client, "NOBACON USAGE" );
		return Plugin_Handled;
	}
	
	int target = GetBaconTarget( client );
	if( target == -1 ) return Plugin_Handled;
	
	TakeBacon( client, target );
	
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action Command_mostbacon( int client, int args ) {
	
	// prevent system bacon overload //
	if( BaconFloodCheck(client) ) return Plugin_Handled;
	
	char query[256];
	Format( query, sizeof(query), "SELECT dest,SUM(1) AS count FROM BACON2 GROUP BY dest ORDER BY count DESC LIMIT %d", c_bacon_topcount );
	
	Handle pack = CreateDataPack();
	WritePackCell( pack, GetBaconUserId( client ) );
	WritePackCell( pack, view_as<int>(GetCmdReplySource()) );
	
	SQL_TQuery( bacon_db, MostBaconQuery, query, pack );
	
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action CommandDrop(int args) {
	SQL_LockDatabase( bacon_db );	
	SQL_FastQuery( bacon_db, "DROP TABLE BACON2" );
	SQL_FastQuery( bacon_db, "DROP TABLE BACON_NAME_CACHE2" );
	SQL_UnlockDatabase( bacon_db );
	CloseHandle(bacon_db);
	
	InitBaconDatabase();
	
	PrintToServer( "%T", "BACON DROPPED", LANG_SERVER  );
	
	return Plugin_Handled;
}

/* -------------------------------------------------------------------------------------------------
  
                                                 __      _.._
                      .-'__`-._.'.--.'.__.,
                     /--'  '-._.'    '-._./
                    /__.--._.--._.'``-.__/
                    '._.-'-._.-._.-''-..'  :D
               jgs

mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm */
 