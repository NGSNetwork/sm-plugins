#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#tryinclude <steamtools>
#include <advanced_motd>
#include <morecolors>

#define PLUGIN_VERSION "1.2"

public Plugin myinfo = {
    name 		=		"[NGS] Web Shortcuts",				/* https://www.youtube.com/watch?v=h6k5jwllFfA&hd=1 */
    author		=		"Kyle Sanderson, Nicholas Hastings / TheXeon",
    description	=		"Redux of Web Shortcuts with Large/Small MOTD Support",
    version		=		PLUGIN_VERSION,
    url			=		"http://SourceMod.net"
}

enum States {
	game_TF2 = (1<<0),
	game_L4D = (1<<1),
	big_MOTD = (1<<8)
};

States g_iGameMode;

enum FieldCheckFlags
{
	flag_Dummy_Zero			=	0,
	flag_Steam_ID			=	(1<<0),
	flag_User_ID			=	(1<<1),
	flag_Friend_ID			=	(1<<2),
	flag_Name				=	(1<<3),
	flag_IP					=	(1<<4),
	flag_Language			=	(1<<5),
	flag_Rate				=	(1<<6),
	flag_Server_IP			=	(1<<7),
	flag_Server_Port		=	(1<<8),
	flag_Server_Name		=	(1<<9),
	flag_Server_Custom		=	(1<<10),
	flag_L4D_GameMode		=	(1<<11),
	flag_Current_Map		=	(1<<12),
	flag_Next_Map			=	(1<<13),
	flag_GameDir			=	(1<<14),
	flag_CurPlayers			=	(1<<15),
	#if defined _steamtools_included
	flag_MaxPlayers			=	(1<<16),
	flag_VACStatus			=	(1<<17),
	flag_Server_Pub_IP		=	(1<<18),
	flag_Steam_ConnStatus	=	(1<<19)
	#else
	flag_MaxPlayers			=	(1<<16)
	#endif  /* _steamtools_included	 */
}; 

stock bool isTeamFortress2() {return view_as<bool>(g_iGameMode & game_TF2);}
stock bool isLeftForDead() {return view_as<bool>(g_iGameMode & game_L4D);}
stock bool goLargeOrGoHome() {return (isTeamFortress2() && view_as<bool>(g_iGameMode & big_MOTD));}

/*#include "Duck"*/

ArrayList g_hIndexArray;
StringMap g_hFastLookupTrie;

StringMap g_hCurrentTrie;
char g_sCurrentSection[128];

public void OnPluginStart()
{
	g_hIndexArray = new ArrayList(); /* We'll only use this for cleanup to prevent handle leaks and what not.
									  Our friend below doesn't have iteration, so we have to do this... */
	g_hFastLookupTrie = new StringMap();
	
	AddCommandListener(Client_Say, "say");
	AddCommandListener(Client_Say, "say_team");
	
	/* From Psychonic */
	Duck_OnPluginStart();
	
	ConVar cvarVersion = CreateConVar("webshortcutsredux_version", PLUGIN_VERSION, "Redux of Web Shortcuts with Large/Small MOTD Support", FCVAR_NOTIFY);
	
	/* On a reload, this will be set to the old version. Let's update it. */
	cvarVersion.SetString(PLUGIN_VERSION);
}

public Action Client_Say(int iClient, char[] sCommand, int argc)
{
	if (argc < 1 || !IsValidClient(iClient))
	{
		return Plugin_Continue; /* Well. While we can probably have blank hooks, I doubt anyone wants this. Lets not waste cycles. Let the game deal with this. */
	}
	
	char sFirstArg[128]; /* If this is too small, let someone know. */
	GetCmdArg(1, sFirstArg, sizeof(sFirstArg));
	TrimString(sFirstArg);
	
	StringMap hStoredTrie;
	if (!g_hFastLookupTrie.GetValue(sFirstArg, hStoredTrie) || hStoredTrie == null) /* L -> R. Strings are R -> L, but that can change. */
	{
		return Plugin_Continue; /* Didn't find anything. Bug out! */
	}
	
	if (DealWithOurTrie(iClient, sFirstArg, hStoredTrie))
	{
		if (sFirstArg[0] == '/') // Detect if using the default silent character
			return Plugin_Continue;
		return Plugin_Handled; /* We want other hooks to be called, I guess. We just don't want it to go to the game. */
	}
	
	return Plugin_Continue; /* Well this is embarasing. We didn't actually hook this. Or atleast didn't intend to. */
}

public bool DealWithOurTrie(int iClient, char[] sHookedString, StringMap hStoredTrie)
{
	char sUrl[256];
	if (!hStoredTrie.GetString("Url", sUrl, sizeof(sUrl)))
	{
		LogError("Unable to find a Url for: \"%s\".", sHookedString);
		return false;
	}
	
	FieldCheckFlags iUrlBits;
	
	if (!hStoredTrie.GetValue("UrlBits", iUrlBits))
	{
		iUrlBits = flag_Dummy_Zero; /* That's fine, there are no replacements! Less work for us. */
	}
	
	char sTitle[256];
	FieldCheckFlags iTitleBits;
	if (!hStoredTrie.GetString("Title", sTitle, sizeof(sTitle)))
	{
		sTitle[0] = '\0'; /* We don't really need a title. Don't worry, it's cool. */
		iTitleBits = flag_Dummy_Zero;
	}
	else
	{
		if (!hStoredTrie.GetValue("TitleBits", iTitleBits))
		{
			iTitleBits = flag_Dummy_Zero; /* That's fine, there are no replacements! Less work for us. */
		}
	}
	
	Duck_DoReplacements(iClient, sUrl, iUrlBits, sTitle, iTitleBits); /* Arrays are passed by reference. Variables are copied. */
	
	bool bBig;
	bool bNotSilent = true;
	
	hStoredTrie.GetValue("Silent", bNotSilent);
	if (goLargeOrGoHome())
	{
		hStoredTrie.GetValue("Big", bBig);
	}

	char sMessage[256];
	if (hStoredTrie.GetString("Msg", sMessage, sizeof(sMessage)))
	{
		FieldCheckFlags iMsgBits;
		hStoredTrie.GetValue("MsgBits", iMsgBits);
		
		if (iMsgBits != flag_Dummy_Zero)
		{
			Duck_DoReplacements(iClient, sMessage, iMsgBits, sMessage, flag_Dummy_Zero); /* Lame Hack for now */
		}
		
		CPrintToChatAll("%s", sMessage);
	}
	AdvMOTD_ShowMOTDPanel(iClient, sTitle, sUrl, MOTDPANEL_TYPE_URL, true, true, true, OnMOTDFailure);
	return true;
}

public void OnMOTDFailure(int client, MOTDFailureReason reason)
{
	switch(reason)
	{
		case MOTDFailure_Disabled: CPrintToChat(client, "{GREEN}[SM]{DEFAULT} You cannot view websites with HTML MOTDs disabled.");
		case MOTDFailure_Matchmaking: CPrintToChat(client, "{GREEN}[SM]{DEFAULT} You cannot view websites after joining via Quickplay.");
		case MOTDFailure_QueryFailed: CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Unable to open website.");
	}
}

public void ClearExistingData()
{
	Handle hHandle = null;
	for (int i = (g_hIndexArray.Length - 1); i >= 0; i--)
	{
		hHandle = g_hIndexArray.Get(i);
		
		if (hHandle == null)
		{
			continue;
		}
		
		delete hHandle;
	}
	
	g_hIndexArray.Clear();
	g_hFastLookupTrie.Clear();
}

public void OnConfigsExecuted()
{
	ClearExistingData();
	
	char sPath[256];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/Webshortcuts.txt");
	if (!FileExists(sPath))
	{
		return;
	}
	
	ProcessFile(sPath);
}

public void ProcessFile(char[] sPathToFile)
{
	SMCParser hSMC = new SMCParser();
	hSMC.OnEnterSection = SMC_NewSection;
	hSMC.OnKeyValue = SMC_KeyValue;
	hSMC.OnLeaveSection = SMC_EndSection;
	
	int iLine;
	SMCError ReturnedError = hSMC.ParseFile(sPathToFile, iLine); /* Calls the below functions, then execution continues. */
	
	if (ReturnedError != SMCError_Okay)
	{
		char sError[256];
		hSMC.GetErrorString(ReturnedError, sError, sizeof(sError));
		if (iLine > 0)
		{
			LogError("Could not parse file (Line: %d, File \"%s\"): %s.", iLine, sPathToFile, sError);
			delete hSMC; /* Sneaky Handles. */
			return;
		}
		
		LogError("Parser encountered error (File: \"%s\"): %s.", sPathToFile, sError);
	}

	delete hSMC;
}

public SMCResult SMC_NewSection(SMCParser smc, const char[] name, bool opt_quotes)
{
	if (!opt_quotes)
	{
		LogError("Invalid Quoting used with Section: %s.", name);
	}
	
	strcopy(g_sCurrentSection, sizeof(g_sCurrentSection), name);
	
	if (g_hFastLookupTrie.GetValue(name, g_hCurrentTrie))
	{
		return SMCParse_Continue;
	}
	else /* That's cool. Sounds like an initial insertion. Just wanted to make sure! */
	{
		g_hCurrentTrie = new StringMap();
		g_hIndexArray.Push(g_hCurrentTrie); /* Don't be leakin */
		g_hFastLookupTrie.SetValue(name, g_hCurrentTrie);
		g_hCurrentTrie.SetString("Name", name);
	}
	
	return SMCParse_Continue;
}

public SMCResult SMC_KeyValue(SMCParser smc, char[] key, char[] value, bool key_quotes, bool value_quotes)
{
	if (!key_quotes)
	{
		LogError("Invalid Quoting used with Key: \"%s\".", key);
	}
	else if (!value_quotes)
	{
		LogError("Invalid Quoting used with Key: \"%s\" Value: \"%s\".", key, value);
	}
	else if (g_hCurrentTrie == null)
	{
		return SMCParse_Continue;
	}
	
	switch (key[0])
	{
		case 'p','P':
		{
			if (!StrEqual(key, "Pointer", false))
			{
				return SMCParse_Continue;
			}
			
			int iFindValue;
			iFindValue = g_hIndexArray.FindValue(g_hCurrentTrie);
			
			if (iFindValue > -1)
			{
				g_hIndexArray.Erase(iFindValue);
			}
			
			if (g_sCurrentSection[0] != '\0')
			{
				g_hFastLookupTrie.Remove(g_sCurrentSection);
			}
			
			delete g_hCurrentTrie; /* We're about to invalidate below */

			if (g_hFastLookupTrie.GetValue(value, g_hCurrentTrie))
			{
				g_hFastLookupTrie.SetValue(g_sCurrentSection, g_hCurrentTrie, true);
				return SMCParse_Continue;
			}

			g_hCurrentTrie = new StringMap(); /* Ruhro, the thing this points to doesn't actually exist. Should we error or what? Nah, lets try and recover. */
			g_hIndexArray.Push(g_hCurrentTrie); /* Don't be losin handles */
			g_hFastLookupTrie.SetValue(g_sCurrentSection, g_hCurrentTrie, true);
			g_hCurrentTrie.SetString("Name", g_sCurrentSection, true);
		}
		
		case 'u','U':
		{
			if (!StrEqual(key, "Url", false))
			{
				return SMCParse_Continue;
			}
			
			g_hCurrentTrie.SetString("Url", value, true);
			
			FieldCheckFlags iBits;
			Duck_CalcBits(value, iBits); /* Passed by Ref */
			g_hCurrentTrie.SetValue("UrlBits", iBits, true);
		}
		
		case 'T','t':
		{
			if (!StrEqual(key, "Title", false))
			{
				return SMCParse_Continue;
			}
			
			g_hCurrentTrie.SetString("Title", value, true);
			
			FieldCheckFlags iBits;
			Duck_CalcBits(value, iBits); /* Passed by Ref */
			g_hCurrentTrie.SetValue("TitleBits", iBits, true);
		}
		
		case 'b','B':
		{
			if (!goLargeOrGoHome() || !StrEqual(key, "Big", false)) /* Maybe they don't know they can't use it? Oh well. Protect the silly. */
			{
				return SMCParse_Continue;
			}
			
			g_hCurrentTrie.SetValue("Big", TranslateToBool(value), true);
		}
	
		case 'h','H':
		{
			if (!StrEqual(key, "Hook", false))
			{
				return SMCParse_Continue;
			}
			
			g_hFastLookupTrie.SetValue(value, g_hCurrentTrie, true);
		}
		
		case 's', 'S':
		{
			if (!StrEqual(key, "Silent", false))
			{
				return SMCParse_Continue;
			}
			
			g_hCurrentTrie.SetValue("Silent", !TranslateToBool(value), true);
		}
		
		case 'M', 'm':
		{
			if (!StrEqual(key, "Msg", false))
			{
				return SMCParse_Continue;
			}
			
			g_hCurrentTrie.SetString("Msg", value, true);
			
			FieldCheckFlags iBits;
			Duck_CalcBits(value, iBits); /* Passed by Ref */
			
			g_hCurrentTrie.SetValue("MsgBits", iBits, true);
		}
	}
	
	return SMCParse_Continue;
}

public SMCResult SMC_EndSection(SMCParser smc)
{
	g_hCurrentTrie = null;
	g_sCurrentSection[0] = '\0';
}

public bool TranslateToBool(char[] sSource)
{
	switch(sSource[0])
	{
		case '0', 'n', 'N', 'f', 'F':
		{
			return false;
		}
		
		case '1', 'y', 'Y', 't', 'T', 's', 'S':
		{
			return true;
		}
	}
	
	return false; /* Assume False */
}

static stock bool IsValidClient(int iClient)
{
	return (0 < iClient <= MaxClients && IsClientInGame(iClient));
}

/* Psychonics Realm */

#define FIELD_CHECK(%1,%2);\
if (StrContains(source, %1) != -1) { field |= %2; }

#define TOKEN_STEAM_ID         "{STEAM_ID}"
#define TOKEN_USER_ID          "{USER_ID}"
#define TOKEN_FRIEND_ID        "{FRIEND_ID}"
#define TOKEN_NAME             "{NAME}"
#define TOKEN_IP               "{IP}"
#define TOKEN_LANGUAGE         "{LANGUAGE}"
#define TOKEN_RATE             "{RATE}"
#define TOKEN_SERVER_IP        "{SERVER_IP}"
#define TOKEN_SERVER_PORT      "{SERVER_PORT}"
#define TOKEN_SERVER_NAME      "{SERVER_NAME}"
#define TOKEN_SERVER_CUSTOM    "{SERVER_CUSTOM}"
#define TOKEN_L4D_GAMEMODE     "{L4D_GAMEMODE}"
#define TOKEN_CURRENT_MAP      "{CURRENT_MAP}"
#define TOKEN_NEXT_MAP         "{NEXT_MAP}"
#define TOKEN_GAMEDIR          "{GAMEDIR}"
#define TOKEN_CURPLAYERS       "{CURPLAYERS}"
#define TOKEN_MAXPLAYERS       "{MAXPLAYERS}"

#if defined _steamtools_included
#define TOKEN_VACSTATUS		   "{VAC_STATUS}"
#define TOKEN_SERVER_PUB_IP    "{SERVER_PUB_IP}"
#define TOKEN_STEAM_CONNSTATUS "{STEAM_CONNSTATUS}"	
bool g_bSteamTools;
#endif  /* _steamtools_included */

/* Cached values */
char g_szServerIp[16];
char g_szServerPort[6];
/* These can all be larger but whole buffer holds < 128 */
char g_szServerName[128];
char g_szServerCustom[128];
char g_szL4DGameMode[128];
char g_szCurrentMap[128];
char g_szGameDir[64];



/*Handle g_hCmdQueue[MAXPLAYERS+1];*/

#if defined _steamtools_included
public void Steam_FullyLoaded()
{
	g_bSteamTools = true;
}

public void OnLibraryRemoved(const char[] sLibrary)
{
	if (!StrEqual(sLibrary, "SteamTools", false))
	{
		return;
	}
	
	g_bSteamTools = false;
}

#endif

public void Duck_OnPluginStart()
{
	char sGameDir[64];
	GetGameFolderName(sGameDir, sizeof(sGameDir));
	if (!strncmp(sGameDir, "tf", 2, false) || !strncmp(sGameDir, "tf_beta", 7, false))
	{
		g_iGameMode |= game_TF2;
		g_iGameMode |= big_MOTD;
	}
	
	/* On a reload, these will already be registered and could be set to non-default */
	
	if (isTeamFortress2())
	{
		/* AddCommandListener(Duck_TF2OnClose, "closed_htmlpage"); */
	}	
	
	LongIPToString(FindConVar("hostip").IntValue, g_szServerIp);	
	FindConVar("hostport").GetString(g_szServerPort, sizeof(g_szServerPort));
	
	ConVar hostname = FindConVar("hostname");
	char szHostname[256];
	hostname.GetString(szHostname, sizeof(szHostname));
	Duck_UrlEncodeString(g_szServerName, sizeof(g_szServerName), szHostname);
	hostname.AddChangeHook(OnCvarHostnameChange);
	
	char szCustom[256];
	ConVar hCVARCustom = CreateConVar("WebShortcuts_Custom", "", "Custom String for this server.");
	hCVARCustom.GetString(szCustom, sizeof(szCustom));
	Duck_UrlEncodeString(g_szServerCustom, sizeof(g_szServerCustom), szCustom);
	hCVARCustom.AddChangeHook(OnCvarCustomChange);
	
	/* new iSDKVersion = GuessSDKVersion(); */
	EngineVersion iSDKVersion = GetEngineVersion();
	if (iSDKVersion == Engine_Left4Dead || iSDKVersion == Engine_Left4Dead2)
	{
		g_iGameMode |= game_L4D;
		ConVar hGameMode = FindConVar("mp_gamemode");
		char szGamemode[256];
		hGameMode.GetString(szGamemode, sizeof(szGamemode));
		Duck_UrlEncodeString(g_szL4DGameMode, sizeof(g_szL4DGameMode), szGamemode);
		hGameMode.AddChangeHook(OnCvarGamemodeChange);
	}
	
	Duck_UrlEncodeString(g_szGameDir, sizeof(g_szGameDir), sGameDir);
}

public void OnMapStart()
{
	char sTempMap[sizeof(g_szCurrentMap)];
	GetCurrentMap(sTempMap, sizeof(sTempMap));
	
	Duck_UrlEncodeString(g_szCurrentMap, sizeof(g_szCurrentMap), sTempMap);
}

stock void Duck_DoReplacements(int iClient, char sUrl[256], FieldCheckFlags iUrlBits, char sTitle[256], FieldCheckFlags iTitleBits) /* Huge thanks to Psychonic */
{
	if (iUrlBits & flag_Steam_ID || iTitleBits & flag_Steam_ID)
	{
		char sSteamId[64];
		if (GetClientAuthId(iClient, AuthId_Steam2, sSteamId, sizeof(sSteamId), true))
		{
			ReplaceString(sSteamId, sizeof(sSteamId), ":", "%3a");
			if (iTitleBits & flag_Steam_ID)
				ReplaceString(sTitle, sizeof(sTitle), TOKEN_STEAM_ID, sSteamId);
			if (iUrlBits & flag_Steam_ID)
				ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_STEAM_ID, sSteamId);
		}
		else
		{
			if (iTitleBits & flag_Steam_ID)
				ReplaceString(sTitle,   sizeof(sTitle),   TOKEN_STEAM_ID, "");
			if (iUrlBits & flag_Steam_ID)
				ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_STEAM_ID, "");
		}
	}
	
	if (iUrlBits & flag_User_ID || iTitleBits & flag_User_ID)
	{
		char sUserId[16];
		IntToString(GetClientUserId(iClient), sUserId, sizeof(sUserId));
		if (iTitleBits & flag_User_ID)
			ReplaceString(sTitle, sizeof(sTitle), TOKEN_USER_ID, sUserId);
		if (iUrlBits & flag_User_ID)
			ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_USER_ID, sUserId);
	}
	
	if (iUrlBits & flag_Friend_ID || iTitleBits & flag_Friend_ID)
	{
		char sFriendId[64];
		if (GetClientFriendID(iClient, sFriendId, sizeof(sFriendId)))
		{
			if (iTitleBits & flag_Friend_ID)
				ReplaceString(sTitle, sizeof(sTitle), TOKEN_FRIEND_ID, sFriendId);
			if (iUrlBits & flag_Friend_ID)
				ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_FRIEND_ID, sFriendId);
		}
		else
		{
			if (iTitleBits & flag_Friend_ID)
				ReplaceString(sTitle, sizeof(sTitle), TOKEN_FRIEND_ID, "");
			if (iUrlBits & flag_Friend_ID)
				ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_FRIEND_ID, "");
		}
	}
	
	if (iUrlBits & flag_Name || iTitleBits & flag_Name)
	{
		char sName[MAX_NAME_LENGTH];
		if (GetClientName(iClient, sName, sizeof(sName)))
		{
			char sEncName[sizeof(sName)*3];
			Duck_UrlEncodeString(sEncName, sizeof(sEncName), sName);
			if (iTitleBits & flag_Name)
				ReplaceString(sTitle, sizeof(sTitle), TOKEN_NAME, sEncName);
			if (iUrlBits & flag_Name)
				ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_NAME, sEncName);
		}
		else
		{
			if (iTitleBits & flag_Name)
				ReplaceString(sTitle, sizeof(sTitle), TOKEN_NAME, "");
			if (iUrlBits & flag_Name)
				ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_NAME, "");
		}
	}
	
	if (iUrlBits & flag_IP || iTitleBits & flag_IP)
	{
		char sClientIp[32];
		if (GetClientIP(iClient, sClientIp, sizeof(sClientIp)))
		{
			if (iTitleBits & flag_IP)
				ReplaceString(sTitle, sizeof(sTitle), TOKEN_IP, sClientIp);
			if (iUrlBits & flag_IP)
				ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_IP, sClientIp);
		}
		else
		{
			if (iTitleBits & flag_IP)
				ReplaceString(sTitle, sizeof(sTitle), TOKEN_IP, "");
			if (iUrlBits & flag_IP)
				ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_IP, "");
		}
	}
	
	if (iUrlBits & flag_Language || iTitleBits & flag_Language)
	{
		char sLanguage[32];
		if (GetClientInfo(iClient, "cl_language", sLanguage, sizeof(sLanguage)))
		{
			char sEncLanguage[sizeof(sLanguage)*3];
			Duck_UrlEncodeString(sEncLanguage, sizeof(sEncLanguage), sLanguage);
			if (iTitleBits & flag_Language)
				ReplaceString(sTitle, sizeof(sTitle), TOKEN_LANGUAGE, sEncLanguage);
			if (iUrlBits & flag_Language)
				ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_LANGUAGE, sEncLanguage);
		}
		else
		{
			if (iTitleBits & flag_Language)
				ReplaceString(sTitle, sizeof(sTitle), TOKEN_LANGUAGE, "");
			if (iUrlBits & flag_Language)
				ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_LANGUAGE, "");
		}
	}
	
	if (iUrlBits & flag_Rate || iTitleBits & flag_Rate)
	{
		char sRate[16];
		if (GetClientInfo(iClient, "rate", sRate, sizeof(sRate)))
		{
			/* due to iClient's rate being silly, this won't necessarily be all digits */
			char sEncRate[sizeof(sRate)*3];
			Duck_UrlEncodeString(sEncRate, sizeof(sEncRate), sRate);
			if (iTitleBits & flag_Rate)
				ReplaceString(sTitle, sizeof(sTitle), TOKEN_RATE, sEncRate);
			if (iUrlBits & flag_Rate)
				ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_RATE, sEncRate);
		}
		else
		{
			if (iTitleBits & flag_Rate)
				ReplaceString(sTitle, sizeof(sTitle), TOKEN_RATE, "");
			if (iUrlBits & flag_Rate)
				ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_RATE, "");
		}
	}
	
	if (iTitleBits & flag_Server_IP)
		ReplaceString(sTitle, sizeof(sTitle), TOKEN_SERVER_IP, g_szServerIp);
	if (iUrlBits & flag_Server_IP)
		ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_SERVER_IP, g_szServerIp);
	
	if (iTitleBits & flag_Server_Port)
		ReplaceString(sTitle, sizeof(sTitle), TOKEN_SERVER_PORT, g_szServerPort);
	if (iUrlBits & flag_Server_Port)
		ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_SERVER_PORT, g_szServerPort);
	
	if (iTitleBits & flag_Server_Name)
		ReplaceString(sTitle, sizeof(sTitle), TOKEN_SERVER_NAME, g_szServerName);
	if (iUrlBits & flag_Server_Name)
		ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_SERVER_NAME, g_szServerName);	
	
	if (iTitleBits & flag_Server_Custom)
		ReplaceString(sTitle, sizeof(sTitle), TOKEN_SERVER_CUSTOM, g_szServerCustom);
	if (iUrlBits & flag_Server_Custom)
		ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_SERVER_CUSTOM, g_szServerCustom);
	
	if (isLeftForDead() && ((iUrlBits & flag_L4D_GameMode) || (iTitleBits & flag_L4D_GameMode)))
	{
		if (iTitleBits & flag_L4D_GameMode)
			ReplaceString(sTitle, sizeof(sTitle), TOKEN_L4D_GAMEMODE, g_szL4DGameMode);
		if (iUrlBits & flag_L4D_GameMode)
			ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_L4D_GAMEMODE, g_szL4DGameMode);
	}
	
	if (iTitleBits & flag_Current_Map)
		ReplaceString(sTitle, sizeof(sTitle), TOKEN_CURRENT_MAP, g_szCurrentMap);
	if (iUrlBits & flag_Current_Map)
		ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_CURRENT_MAP, g_szCurrentMap);
	
	if (iUrlBits & flag_Next_Map || iTitleBits & flag_Next_Map)
	{
		char szNextMap[PLATFORM_MAX_PATH];
		if (GetNextMap(szNextMap, sizeof(szNextMap)))
		{
			if (iTitleBits & flag_Next_Map)
				ReplaceString(sTitle, sizeof(sTitle), TOKEN_NEXT_MAP, szNextMap);
			if (iUrlBits & flag_Next_Map)
				ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_NEXT_MAP, szNextMap);
		}
		else
		{
			if (iTitleBits & flag_Next_Map)
				ReplaceString(sTitle, sizeof(sTitle), TOKEN_NEXT_MAP, "");
			if (iUrlBits & flag_Next_Map)
				ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_NEXT_MAP, "");
		}
	}
	
	if (iTitleBits & flag_GameDir)
		ReplaceString(sTitle, sizeof(sTitle), TOKEN_GAMEDIR, g_szGameDir);
	if (iUrlBits & flag_GameDir)
		ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_GAMEDIR, g_szGameDir);
	
	if (iUrlBits & flag_CurPlayers || iTitleBits & flag_CurPlayers)
	{
		char sCurPlayers[10];
		IntToString(GetClientCount(false), sCurPlayers, sizeof(sCurPlayers));
		if (iTitleBits & flag_CurPlayers)
			ReplaceString(sTitle, sizeof(sTitle), TOKEN_CURPLAYERS, sCurPlayers);
		if (iUrlBits & flag_CurPlayers)
			ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_CURPLAYERS, sCurPlayers);
	}
	
	if (iUrlBits & flag_MaxPlayers || iTitleBits & flag_MaxPlayers)
	{
		char maxplayers[10];
		IntToString(MaxClients, maxplayers, sizeof(maxplayers));
		if (iTitleBits & flag_MaxPlayers)
			ReplaceString(sTitle, sizeof(sTitle), TOKEN_MAXPLAYERS, maxplayers);
		if (iUrlBits & flag_MaxPlayers)
			ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_MAXPLAYERS, maxplayers);
	}
	
#if defined _steamtools_included	
	if (iUrlBits & flag_VACStatus || iTitleBits & flag_VACStatus)
	{
		if (g_bSteamTools && Steam_IsVACEnabled())
		{
			if (iTitleBits & flag_VACStatus)
				ReplaceString(sTitle, sizeof(sTitle), TOKEN_VACSTATUS, "1");
			if (iUrlBits & flag_VACStatus)
				ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_VACSTATUS, "1");
		}
		else
		{
			if (iTitleBits & flag_VACStatus)
				ReplaceString(sTitle, sizeof(sTitle), TOKEN_VACSTATUS, "0");
			if (iUrlBits & flag_VACStatus)
				ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_VACSTATUS, "0");
		}
	}
	
	if (iUrlBits & flag_Server_Pub_IP || iTitleBits & flag_Server_Pub_IP)
	{
		if (g_bSteamTools)
		{
			int ip[4];
			char sIPString[16];
			Steam_GetPublicIP(ip);
			FormatEx(sIPString, sizeof(sIPString), "%d.%d.%d.%d", ip[0], ip[1], ip[2], ip[3]);
			
			if (iTitleBits & flag_Server_Pub_IP)
				ReplaceString(sTitle, sizeof(sTitle), TOKEN_SERVER_PUB_IP, sIPString);
			if (iUrlBits & flag_Server_Pub_IP)
				ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_SERVER_PUB_IP, sIPString);
		}
		else
		{
			if (iTitleBits & flag_Server_Pub_IP)
				ReplaceString(sTitle, sizeof(sTitle), TOKEN_SERVER_PUB_IP, "");
			if (iUrlBits & flag_Server_Pub_IP)
				ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_SERVER_PUB_IP, "");
		}
	}
	
	if (iUrlBits & flag_Steam_ConnStatus || iTitleBits & flag_Steam_ConnStatus)
	{
		if (g_bSteamTools && Steam_IsConnected())
		{
			if (iTitleBits & flag_Steam_ConnStatus)
				ReplaceString(sTitle, sizeof(sTitle), TOKEN_STEAM_CONNSTATUS, "1");
			if (iUrlBits & flag_Steam_ConnStatus)
				ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_STEAM_CONNSTATUS, "1");
		}
		else
		{
			if (iTitleBits & flag_Steam_ConnStatus)
				ReplaceString(sTitle, sizeof(sTitle), TOKEN_STEAM_CONNSTATUS, "0");
			if (iUrlBits & flag_Steam_ConnStatus)
				ReplaceString(sUrl,   sizeof(sUrl),   TOKEN_STEAM_CONNSTATUS, "0");
		}
	}
#endif  /* _steamtools_included */
}

stock bool GetClientFriendID(int client, char[] sFriendID, int size) 
{
#if defined _steamtools_included
	Steam_GetCSteamIDForClient(client, sFriendID, size);
#else
	char sSteamID[64];
	if (!GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID), true))
	{
		sFriendID[0] = '\0'; /* Sanitize incase the return isn't checked. */
		return false;
	}
	
	TrimString(sSteamID); /* Just incase... */
	
	if (StrEqual(sSteamID, "STEAM_ID_LAN", false))
	{
		sFriendID[0] = '\0';
		return false;
	}
	
	char toks[3][16];
	ExplodeString(sSteamID, ":", toks, sizeof(toks), sizeof(toks));
	
	int iServer = StringToInt(toks[1]);
	int iAuthID = StringToInt(toks[2]);
	int iFriendID = (iAuthID*2) + 60265728 + iServer;
	
	if (iFriendID >= 100000000)
	{
		char temp[12];
		char carry[12];
		FormatEx(temp, sizeof(temp), "%d", iFriendID);
		FormatEx(carry, 2, "%s", temp);
		int icarry = StringToInt(carry[0]);
		int upper = 765611979 + icarry;
		
		FormatEx(temp, sizeof(temp), "%d", iFriendID);
		FormatEx(sFriendID, size, "%d%s", upper, temp[1]);
	}
	else
	{
		Format(sFriendID, size, "765611979%d", iFriendID);
	}
	#endif
	return true;
}

void Duck_CalcBits(char[] source, FieldCheckFlags &field)
{
	field = flag_Dummy_Zero;
	
	FIELD_CHECK(TOKEN_STEAM_ID,    flag_Steam_ID);
	FIELD_CHECK(TOKEN_USER_ID,     flag_User_ID);
	FIELD_CHECK(TOKEN_FRIEND_ID,   flag_Friend_ID);
	FIELD_CHECK(TOKEN_NAME,        flag_Name);
	FIELD_CHECK(TOKEN_IP,          flag_IP);
	FIELD_CHECK(TOKEN_LANGUAGE,    flag_Language);
	FIELD_CHECK(TOKEN_RATE,        flag_Rate);
	FIELD_CHECK(TOKEN_SERVER_IP,   flag_Server_IP);
	FIELD_CHECK(TOKEN_SERVER_PORT, flag_Server_Port);
	FIELD_CHECK(TOKEN_SERVER_NAME, flag_Server_Name);
	FIELD_CHECK(TOKEN_SERVER_CUSTOM, flag_Server_Custom);
	
	if (isLeftForDead())
	{
		FIELD_CHECK(TOKEN_L4D_GAMEMODE, flag_L4D_GameMode);
	}
	
	FIELD_CHECK(TOKEN_CURRENT_MAP, flag_Current_Map);
	FIELD_CHECK(TOKEN_NEXT_MAP,    flag_Next_Map);
	FIELD_CHECK(TOKEN_GAMEDIR,     flag_GameDir);
	FIELD_CHECK(TOKEN_CURPLAYERS,  flag_CurPlayers);
	FIELD_CHECK(TOKEN_MAXPLAYERS,  flag_MaxPlayers);

#if defined _steamtools_included
	FIELD_CHECK(TOKEN_VACSTATUS,        flag_VACStatus);
	FIELD_CHECK(TOKEN_SERVER_PUB_IP,    flag_Server_Pub_IP);
	FIELD_CHECK(TOKEN_STEAM_CONNSTATUS, flag_Steam_ConnStatus);
#endif
}

/* Courtesy of Mr. Asher Baker */
stock void LongIPToString(int ip, char szBuffer[16])
{
	FormatEx(szBuffer, sizeof(szBuffer), "%i.%i.%i.%i", (((ip & 0xFF000000) >> 24) & 0xFF), (((ip & 0x00FF0000) >> 16) & 0xFF), (((ip & 0x0000FF00) >>  8) & 0xFF), (((ip & 0x000000FF) >>  0) & 0xFF));
}

/* loosely based off of PHP's urlencode */
stock void Duck_UrlEncodeString(char[] output, int size, char[] input)
{
	int icnt = 0;
	int ocnt = 0;
	
	for(;;)
	{
		if (ocnt == size)
		{
			output[ocnt-1] = '\0';
			return;
		}
		
		int c = input[icnt];
		if (c == '\0')
		{
			output[ocnt] = '\0';
			return;
		}
		
		// Use '+' instead of '%20'.
		// Still follows spec and takes up less of our limited buffer.
		if (c == ' ')
		{
			output[ocnt++] = '+';
		}
		else if ((c < '0' && c != '-' && c != '.') ||
			(c < 'A' && c > '9') ||
			(c > 'Z' && c < 'a' && c != '_') ||
			(c > 'z' && c != '~')) 
		{
			output[ocnt++] = '%';
			Format(output[ocnt], size-strlen(output[ocnt]), "%x", c);
			ocnt += 2;
		}
		else
		{
			output[ocnt++] = c;
		}
		
		icnt++;
	}
}

public void OnCvarHostnameChange(ConVar convar, char[] oldValue, char[] newValue)
{
	Duck_UrlEncodeString(g_szServerName, sizeof(g_szServerName), newValue);
}

public void OnCvarGamemodeChange(ConVar convar, char[] oldValue, char[] newValue)
{
	Duck_UrlEncodeString(g_szL4DGameMode, sizeof(g_szL4DGameMode), newValue);
}

public void OnCvarCustomChange(ConVar convar, char[] oldValue, char[] newValue)
{
	Duck_UrlEncodeString(g_szServerCustom, sizeof(g_szServerCustom), newValue);
}