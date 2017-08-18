/****************************************************************************************************
[ANY] Name Sleuth
*****************************************************************************************************/
/* 	
	Description:
				NameSleuth is an extremely accurate and powerful plugin which bans people who use name stealer / faker cheats.
				It works by verifying the clients name with steam servers and then using a convar query to determine if the client is using a hack.
				
				It is fully compatible with sm_rename and no false positives are triggered because sourcemod does not modify the client name variable.
				
				As clients names are set from Steam and then synced to the game, it is impossible for the client to change the "name" variable client side
				without using a cheat or modification to the games files. 
				
				This is a sufficient replacement to plugins such as Name Change Punisher because it accurately determines a real hacker vs somebody changing names too many times on steam, 
				but it is only currently compatible with games that support SteamWorks.
			
				Additionally, It has been tested with a cheat to confirm that everything works as it should.
				
	Requirements:
				SteamWorks: https://forums.alliedmods.net/showthread.php?t=229556
				Steam API Key: https://steamcommunity.com/dev/apikey (Set using ns_api_key "")
	
	ChangeLog:
				0.1	- First public release.
				0.2	- 
					- Properly done web request now.
					- Removed Janson and using VDF / KeyValues now.
					- General code cleanup.
					- Woops, protected the API Key cvar!
				0.3 - 
					- Revived plugin.
				0.4 - 
					- Fixed cache causing false bans (Thanks Techno, Kinsi, DeathKnife for help over Discord).
*/

#include <autoexecconfig>
#include <SteamWorks>

#undef REQUIRE_PLUGIN
#tryinclude <sourcebans>

/****************************************************************************************************
DEFINES
*****************************************************************************************************/
#define PLUGIN_NAME "[ANY] Name Sleuth"
#define PLUGIN_URL "https://www.fragdeluxe.com"
#define PLUGIN_DESC "Anti name faking done right"
#define PLUGIN_VERSION "0.4"
#define PLUGIN_AUTHOR "SM9(); (xCoderx)"

#define STEAM_API_URL "http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/"

#define LoopConnectedClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsValidClient(%1, false))

/****************************************************************************************************
ETIQUETTE.
*****************************************************************************************************/
#pragma newdecls required
#pragma semicolon 1

/****************************************************************************************************
BOOLS.
*****************************************************************************************************/
bool g_bClientBanned[MAXPLAYERS + 1] = false;
bool g_bSourceBans = false;

/****************************************************************************************************
INTS.
*****************************************************************************************************/
int g_iFailures[MAXPLAYERS + 1];

/****************************************************************************************************
STRINGS.
*****************************************************************************************************/
char g_szSteamId64[MAXPLAYERS + 1][64];
char g_szApiKey[128];
char g_szLog[PLATFORM_MAX_PATH];

/****************************************************************************************************
CONVARS.
*****************************************************************************************************/
ConVar g_cApiKey;

public Plugin myinfo = 
{
	name = PLUGIN_NAME, 
	author = PLUGIN_AUTHOR, 
	description = PLUGIN_DESC, 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
}

public void OnPluginStart()
{
	if (!HookEventEx("player_changename", Event_PlayerNameChange)) {
		SetFailState("Unable to hook player_changename event");
	}
	
	AutoExecConfig_SetFile("plugin.namesleuth");
	
	g_cApiKey = AutoExecConfig_CreateConVar("namesleuth_api_key", "", "Obtain from: https://steamcommunity.com/dev/apikey", FCVAR_PROTECTED);
	g_cApiKey.AddChangeHook(OnCvarChanged);
	
	CreateConVar("namesleuth_version", PLUGIN_VERSION, "NameSleuth Version");
	
	LoopConnectedClients(iClient) {
		if (GetClientAuthId(iClient, AuthId_SteamID64, g_szSteamId64[iClient], sizeof(g_szSteamId64))) {
			RequestNameFromSteamAPI(iClient, g_szSteamId64[iClient]);
		}
	}
	
	AutoExecConfig_CleanFile(); AutoExecConfig_ExecuteFile();
	
	BuildPath(Path_SM, g_szLog, sizeof(g_szLog), "logs/NameSleuth.log");
	
	if (LibraryExists("sourcebans")) {
		g_bSourceBans = GetFeatureStatus(FeatureType_Native, "SourceBans_BanPlayer") == FeatureStatus_Available;
	}
}

public APLRes AskPluginLoad2(Handle hNyself, bool bLate, char[] chError, int iErrMax)
{
	RegPluginLibrary("NameSleuth");
	MarkNativeAsOptional("SourceBans_BanPlayer");
	
	return APLRes_Success;
}

public void OnLibraryAdded(const char[] szName) {
	if (StrEqual(szName, "sourcebans")) {
		g_bSourceBans = GetFeatureStatus(FeatureType_Native, "SourceBans_BanPlayer") == FeatureStatus_Available;
	}
}

public void OnLibraryRemoved(const char[] szName) {
	if (StrEqual(szName, "sourcebans")) {
		g_bSourceBans = false;
	}
}

public void OnConfigsExecuted() {
	g_cApiKey.GetString(g_szApiKey, sizeof(g_szApiKey));
}

public void OnCvarChanged(ConVar cConVar, const char[] szOldValue, const char[] szNewValue)
{
	if (cConVar == g_cApiKey) {
		strcopy(g_szApiKey, sizeof(g_szApiKey), szNewValue);
	}
}

public void OnClientPostAdminCheck(int iClient)
{
	if (IsFakeClient(iClient)) {
		return;
	}
	
	if (!GetClientAuthId(iClient, AuthId_SteamID64, g_szSteamId64[iClient], sizeof(g_szSteamId64))) {
		KickClient(iClient, "Unable to retrieve AuthId\nPlease rejoin or restart your game if this persists");
		return;
	}
	
	RequestFrame(Frame_NameChanged, GetClientUserId(iClient));
}

public Action Event_PlayerNameChange(Event eEvent, const char[] szName, bool bDontBroadcast) {
	RequestFrame(Frame_NameChanged, eEvent.GetInt("userid"));
}

public void Frame_NameChanged(int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	
	if (!IsValidClient(iClient, false)) {
		return;
	}
	
	RequestNameFromSteamAPI(iClient, g_szSteamId64[iClient]);
}

public void RequestNameFromSteamAPI(int iClient, const char[] szSteam64)
{
	if (g_bClientBanned[iClient]) {
		return;
	}
	
	if (StrEqual(g_szApiKey, "", false)) {
		LogError("You must set an API key using ns_api_key, you can your API key from: https://steamcommunity.com/dev/apikey");
		return;
	}
	
	int iTime = GetTime(); char szTime[20]; IntToString(iTime, szTime, sizeof(szTime));
	
	char szApiUrl[128]; Format(szApiUrl, sizeof(szApiUrl), "%s?t=%d", STEAM_API_URL, iTime);
	if (CheckCommandAccess(iClient, "sm_admin", ADMFLAG_GENERIC))
		PrintToChat(iClient, "[SM] Admin-only: API url = %s", szApiUrl);
	
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, szApiUrl);
	
	if(hRequest == null) {
		return;
	}
	
	SteamWorks_SetHTTPRequestHeaderValue(hRequest, "Pragma", "no-cache");
	SteamWorks_SetHTTPRequestHeaderValue(hRequest, "Cache-Control", "no-cache");
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "t", szTime);
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "key", g_szApiKey);
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "steamids", g_szSteamId64[iClient]);

	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "format", "vdf");
	SteamWorks_SetHTTPRequestNetworkActivityTimeout(hRequest, 10);
	SteamWorks_SetHTTPCallbacks(hRequest, HTTP_RequestComplete);
	
	SteamWorks_SetHTTPRequestContextValue(hRequest, GetClientUserId(iClient));
	SteamWorks_SendHTTPRequest(hRequest);
}

public int HTTP_RequestComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	bool bSuccess = true;
	
	if (!IsValidClient(iClient, false)) {
		delete hRequest;
		return;
	}
	
	int iBodySize;
	
	if (SteamWorks_GetHTTPResponseBodySize(hRequest, iBodySize)) {
		if (iBodySize <= 0) {
			bSuccess = false;
		}
	} else {
		bSuccess = false;
	}
	
	KeyValues hKv = new KeyValues("response");
	
	if (bSuccess) {
		char[] szBody = new char[iBodySize + 1]; SteamWorks_GetHTTPResponseBodyData(hRequest, szBody, iBodySize);
		
		if (StrContains(szBody, "Forbidden", false) != -1) {
			bSuccess = false;
		}
		
		if (bSuccess) {
			hKv.SetEscapeSequences(true);
			
			if (!hKv.ImportFromString(szBody)) {
				delete hKv;
				bSuccess = false;
			}
			
			if (!KvJumpToKey(hKv, "players")) {
				delete hKv;
				bSuccess = false;
			}
			
			if (!KvJumpToKey(hKv, "0")) {
				delete hKv;
				bSuccess = false;
			}
		}
	}
	
	if (!bSuccess) {
		if (++g_iFailures[iClient] > 5) {
			LogError("Failed to sucessfully check player %N's name with the steam backend after 5 attempts, please confirm you API key (%s) is correct", iClient, g_szApiKey);
			g_iFailures[iClient] = 0;
		} else {
			RequestNameFromSteamAPI(iClient, g_szSteamId64[iClient]);
		}
	} else {
		QueryClientConVar(iClient, "name", Query_NameCheck, hKv);
		g_iFailures[iClient] = 0;
	}
	
	delete hRequest;
}

public void Query_NameCheck(QueryCookie qCookie, int iClient, ConVarQueryResult cqResult, const char[] chCvarName, const char[] szCvarValue, KeyValues hKv)
{
	if (cqResult != ConVarQuery_Okay) {
		KickClient(iClient, "ConVar Query timeout\nplease try rejoining or restarting your game if this persists");
		delete hKv;
		return;
	}
	
	char szGameName[MAX_NAME_LENGTH];
	
	if (!GetClientName(iClient, szGameName, sizeof(szGameName))) {
		KickClient(iClient, "Unable to retrieve Name\nPlease rejoin or restart your game if this persists");
		delete hKv;
		return;
	}
	
	char szSteamName[MAX_NAME_LENGTH]; hKv.GetString("personaname", szSteamName, sizeof(szSteamName));
	
	if (StrEqual(szGameName, szCvarValue, true) && !StrEqual(szGameName, szSteamName, true)) {
		LogToFileEx(g_szLog, "\n[Name Faker]: \nGame Name: %s\nSteam Name: %s\nConsole Name: %s\n", szGameName, szSteamName, szCvarValue);
		NS_BanClient(iClient);
	}
	
	delete hKv;
}

public void NS_BanClient(int iClient)
{
	g_bClientBanned[iClient] = true;
	
	if (g_bSourceBans) {
		SourceBans_BanPlayer(0, iClient, 0, "Cheating Violation");
	} else {
		char szResult[64]; ServerCommandEx(szResult, sizeof(szResult), "sm_ban #%d 0 \"[NameSleuth] Name stealer/faker detected\"", GetClientUserId(iClient));
		
		if (StrContains(szResult, "Unknown") != -1) {
			if (!BanClient(iClient, 0, BANFLAG_AUTO, "[NameSleuth] Name stealer/faker detected", "Cheating Violation")) {
				char szAuthId[64];
				
				if (GetClientAuthId(iClient, AuthId_Engine, szAuthId, sizeof(szAuthId))) {
					ServerCommand("banid \"0\" \"%s\"; writeid", szAuthId);
				}
				
				if (IsClientConnected(iClient)) {
					KickClient(iClient, "Cheating Violation");
				}
				
				LogToFileEx(g_szLog, "Ban for %N (%s) might of failed, please check manually.", iClient, szAuthId);
			}
		}
	}
}

public void OnClientDisconnect(int iClient) {
	g_bClientBanned[iClient] = false;
	g_iFailures[iClient] = 0;
}

stock int IsValidClient(int iClient, bool bCheckInGame)
{
	if (iClient <= 0 || iClient > MaxClients) {
		return false;
	}
	
	if (!IsClientConnected(iClient)) {
		return false;
	}
	
	if (IsFakeClient(iClient)) {
		return false;
	}
	
	if (bCheckInGame) {
		return IsClientInGame(iClient);
	}
	
	return true;
} 