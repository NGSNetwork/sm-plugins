/**
* TheXeon
* ngs_steamrepchecker.sp
*
* Files:
* addons/sourcemod/plugins/ngs_steamrepchecker.smx
* cfg/sourcemod/plugin.steamrep_checker.cfg
*
* Dependencies:
* sdktools.inc, SteamWorks.inc, multicolors.inc, ngsutils.inc,
* ngsupdater.inc, ccc.inc, scp.inc, sourcebans.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <sdktools>
#include <SteamWorks>
#include <multicolors>
#include <ngsutils>
#include <ngsupdater>

#undef REQUIRE_PLUGIN
#include <ccc>
#include <scp>
#include <sourcebans>
#define REQUIRE_PLUGIN

#define STEAMREP_URL		"http://steamrep.com/id2rep.php"
#define STEAM_API_URL		"https://api.steampowered.com/ISteamUser/GetPlayerBans/v1/"

enum LogLevel {
	Log_Error = 0,
	Log_Info,
	Log_Debug
}

enum TagType {
	TagType_None = 0,
	TagType_Scammer,
	TagType_TradeBanned,
	TagType_TradeProbation
}

public Plugin myinfo = {
	name        = "[NGS] SteamRep Checker (Redux)",
	author      = "Dr. McKay / TheXeon",
	description = "Checks a user's SteamRep upon connection",
	version     = "2.2.0",
	url         = "https://www.neogenesisnetwork.net"
}

ConVar cvarDealMethod;
ConVar cvarSteamIDBanLength;
ConVar cvarIPBanLength;
ConVar cvarKickTaggedScammers;
ConVar cvarValveBanDealMethod;
ConVar cvarValveCautionDealMethod;
ConVar cvarSteamAPIKey;
ConVar cvarSendIP;
ConVar cvarExcludedTags;
ConVar cvarEnableExclusion;
ConVar cvarSpawnMessage;
ConVar cvarLogLevel;

TagType clientTag[MAXPLAYERS + 1];
bool messageDisplayed[MAXPLAYERS + 1];

public void OnPluginStart() {
	cvarDealMethod = CreateConVar("steamrep_checker_deal_method", "2", "How to deal with reported scammers.\n0 = Disabled\n1 = Prefix chat with [SCAMMER] tag and warn users in chat (requires Custom Chat Colors)\n2 = Kick\n3 = Ban Steam ID\n4 = Ban IP\n5 = Ban Steam ID + IP", _, true, 0.0, true, 5.0);
	cvarSteamIDBanLength = CreateConVar("steamrep_checker_steamid_ban_length", "0", "Duration in minutes to ban Steam IDs for if steamrep_checker_deal_method = 3 or 5 (0 = permanent)", _, true, 0.0);
	cvarIPBanLength = CreateConVar("steamrep_checker_ip_ban_length", "0", "Duration in minutes to ban IP addresses for if steamrep_checker_deal_method = 4 or 5 (0 = permanent)");
	cvarKickTaggedScammers = CreateConVar("steamrep_checker_kick_tagged_scammers", "1", "Kick chat-tagged scammers if the server gets full?", _, true, 0.0, true, 1.0);
	cvarValveBanDealMethod = CreateConVar("steamrep_checker_valve_ban_deal_method", "2", "How to deal with Valve trade-banned players (requires API key to be set)\n0 = Disabled\n1 = Prefix chat with [TRADE BANNED] tag and warn users in chat (requires Custom Chat Colors)\n2 = Kick\n3 = Ban Steam ID\n4 = Ban IP\n5 = Ban Steam ID + IP", _, true, 0.0, true, 5.0);
	cvarValveCautionDealMethod = CreateConVar("steamrep_checker_valve_probation_deal_method", "1", "How to deal with Valve trade-probation players (requires API key to be set)\n0 = Disabled\n1 = Prefix chat with [TRADE PROBATION] tag and warn users in chat (requires Custom Chat Colors)\n2 = Kick\n3 = Ban Steam ID\n4 = Ban IP\n5 = Ban Steam ID + IP", _, true, 0.0, true, 5.0);
	cvarSteamAPIKey = CreateConVar("steamrep_checker_steam_api_key", "", "API key obtained from http://steamcommunity.com/dev (only required for Valve trade-ban or trade-probation detection", FCVAR_PROTECTED);
	cvarSendIP = CreateConVar("steamrep_checker_send_ip", "0", "Send IP addresses of connecting players to SteamRep?", _, true, 0.0, true, 1.0);
	cvarEnableExclusion = CreateConVar("steamrep_checker_exclusion", "1", "Allow exclusion via SkipSR override?", _, true, 0.0, true, 1.0);
	cvarExcludedTags = CreateConVar("steamrep_checker_untrusted_tags", "", "Input the tags of any community whose bans you do not trust here.");
	cvarSpawnMessage = CreateConVar("steamrep_checker_spawn_message", "1", "Display messages upon first spawn that this server is protected by SteamRep?", _, true, 0.0, true, 1.0);
	cvarLogLevel = CreateConVar("steamrep_checker_log_level", "1", "Level of logging\n0 = Errors only\n1 = Info + errors\n2 = Info, errors, and debug", _, true, 0.0, true, 2.0);
	AutoExecConfig(true, "plugin.steamrep_checker");

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_changename", Event_PlayerChangeName);

	RegConsoleCmd("sm_rep", Command_Rep, "Checks a user's SteamRep");
	RegConsoleCmd("sm_sr", Command_Rep, "Checks a user's SteamRep");
}

public void OnClientConnected(int client)
{
	clientTag[client] = TagType_None;
}

public void OnClientPostAdminCheck(int client)
{
	PerformKicks();
	if(!IsValidClient(client) || (cvarEnableExclusion.BoolValue && CheckCommandAccess(client, "SkipSR", ADMFLAG_ROOT))) {
		return;
	}
	char auth[32];
	if (GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth)))
	{
		char excludedTags[64], ip[64];
		cvarExcludedTags.GetString(excludedTags, sizeof(excludedTags));
		if(cvarSendIP.BoolValue) {
			GetClientIP(client, ip, sizeof(ip));
		}
		SWHTTPRequest request = new SWHTTPRequest(k_EHTTPMethodGET, STEAMREP_URL);
		request.SetParam("steamID32", auth);
		request.SetParam("ignore", excludedTags);
		request.SetParam("IP", ip);
		request.SetContextValue(GetClientUserId(client));
		request.SetCallbacks(OnSteamRepChecked);
		request.Send();
		#if defined DEBUG
		LogItem(Log_Debug, "Sending HTTP request for %L", client);
		#endif
	}
	else
	{
		LogItem(Log_Error, "Could not get SteamID2 for client %L!", client);
	}
}

void PerformKicks() {
	if((GetClientCount() >= MaxClients - 1) && cvarKickTaggedScammers.BoolValue) {
		if(cvarDealMethod.IntValue == 1) {
			for(int i = 1; i <= MaxClients; i++) {
				if(IsClientInGame(i) && clientTag[i] == TagType_Scammer) {
					KickClient(i, "You were kicked to free a slot because you are a reported scammer");
					return;
				}
			}
		}
		if(cvarValveBanDealMethod.IntValue == 1) {
			for(int i = 1; i <= MaxClients; i++) {
				if(IsClientInGame(i) && clientTag[i] == TagType_TradeBanned) {
					KickClient(i, "You were kicked to free a slot because you are trade banned");
					return;
				}
			}
		}
		if(cvarValveCautionDealMethod.IntValue == 1) {
			for(int i= 1; i <= MaxClients; i++) {
				if(IsClientInGame(i) && clientTag[i] == TagType_TradeProbation) {
					KickClient(i, "You were kicked to free a slot because you are on trade probation");
					return;
				}
			}
		}
	}
}

public void OnSteamRepChecked(SWHTTPRequest request, bool bFailure, bool successful, EHTTPStatusCode code, any userid) {
	int client = GetClientOfUserId(userid);
	if(client == 0) {
		LogItem(Log_Debug, "Client with User ID %d left.", userid);
		delete request;
		return;
	}
	if(!successful || code != k_EHTTPStatusCode200OK) {
		LogItem(Log_Error, "Error checking SteamRep for client %L. Status code: %d, Successful: %s", client, view_as<int>(code), successful ? "true" : "false");
		delete request;
		return;
	}
	char data[4096];
	request.GetBodyData(data, sizeof(data));
	delete request;
	LogItem(Log_Debug, "Received rep for %L: '%s'", client, data);
	char exploded[3][35];
	ExplodeString(data, "&", exploded, sizeof(exploded), sizeof(exploded[]));
	if(StrContains(exploded[1], "SCAMMER", false) != -1) {
		LogItem(Log_Debug, "%L is a scammer, handling", client);
		HandleScammer(client, exploded[2]);
	} else {
		char apiKey[64];
		cvarSteamAPIKey.GetString(apiKey, sizeof(apiKey));
		if(apiKey[0] != '\0') {
			LogItem(Log_Debug, "%L is not a SR scammer, checking Steam...", client);
			char steamid[64];
			if (GetClientAuthId(client, AuthId_SteamID64, steamid, sizeof(steamid)))
			{
				request = new SWHTTPRequest(k_EHTTPMethodGET, STEAM_API_URL);
				request.SetCallbacks(OnSteamAPI);
				request.SetParam("key", apiKey);
				request.SetParam("steamids", steamid);
				request.SetParam("format", "vdf");
				request.SetContextValue(userid);
				request.Send();
			}
			else
			{
				LogItem(Log_Error, "Could not get SteamID64 for client %L!", client);
			}
		}
	}
}

void HandleScammer(int client, const char[] auth) {
	char clientAuth[32];
	if (!GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth)))
	{
		LogItem(Log_Error, "Error handling potential scammer. (Unverified) Auth is %s.", auth);
		return;
	}
	if(!StrEqual(auth, clientAuth)) {
		LogItem(Log_Error, "Steam ID for %L (%s) didn't match SteamRep's response (%s)", client, clientAuth, auth);
		return;
	}
	switch(cvarDealMethod.IntValue) {
		case 0: {
			// Disabled
		}
		case 1: {
			// Chat tag
			if(!LibraryExists("scp")) {
				LogItem(Log_Info, "Simple Chat Processor (Redux) is not loaded, so tags will not be colored in chat.", client);
				return;
			}
			LogItem(Log_Info, "Tagged %L as a scammer", client);
			SetClientTag(client, TagType_Scammer);
		}
		case 2: {
			// Kick
			LogItem(Log_Info, "Kicked %L as a scammer", client);
			KickClient(client, "You are a reported scammer. Visit http://www.steamrep.com for more information");
		}
		case 3: {
			// Ban Steam ID
			LogItem(Log_Info, "Banned %L by Steam ID as a scammer", client);
			if(GetFeatureStatus(FeatureType_Native, "SourceBans_BanPlayer") == FeatureStatus_Available) {
				SourceBans_BanPlayer(0, client, cvarSteamIDBanLength.IntValue, "Player is a reported scammer via SteamRep.com");
			} else {
				BanClient(client, cvarSteamIDBanLength.IntValue, BANFLAG_AUTHID, "Player is a reported scammer via SteamRep.com", "You are a reported scammer. Visit http://www.steamrep.com for more information", "steamrep_checker");
			}
		}
		case 4: {
			// Ban IP
			LogItem(Log_Info, "Banned %L by IP as a scammer", client);
			if(GetFeatureStatus(FeatureType_Native, "SourceBans_BanPlayer") == FeatureStatus_Available) {
				// SourceBans doesn't currently expose a native to ban an IP!
				char ip[64];
				GetClientIP(client, ip, sizeof(ip));
				ServerCommand("sm_banip \"%s\" %d A scammer has connected from this IP. Steam ID: %s", ip, cvarIPBanLength.IntValue, clientAuth);
			} else {
				char banMessage[256];
				Format(banMessage, sizeof(banMessage), "A scammer has connected from this IP. Steam ID: %s", clientAuth);
				BanClient(client, cvarIPBanLength.IntValue, BANFLAG_IP, banMessage, "You are a reported scammer. Visit http://www.steamrep.com for more information", "steamrep_checker");
			}
		}
		case 5: {
			// Ban Steam ID + IP
			LogItem(Log_Info, "Banned %L by Steam ID and IP as a scammer", client);
			if(GetFeatureStatus(FeatureType_Native, "SourceBans_BanPlayer") == FeatureStatus_Available) {
				char ip[64];
				GetClientIP(client, ip, sizeof(ip));
				SourceBans_BanPlayer(0, client, cvarSteamIDBanLength.IntValue, "Player is a reported scammer via SteamRep.com");
				ServerCommand("sm_banip \"%s\" %d A scammer has connected from this IP. Steam ID: %s", ip, cvarIPBanLength.IntValue, clientAuth);
			} else {
				BanClient(client, cvarSteamIDBanLength.IntValue, BANFLAG_AUTHID, "Player is a reported scammer via SteamRep.com", "You are a reported scammer. Visit http://www.steamrep.com for more information", "steamrep_checker");
				BanClient(client, cvarIPBanLength.IntValue, BANFLAG_IP, "Player is a reported scammer via SteamRep.com", "You are a reported scammer. Visit http://www.steamrep.com for more information", "steamrep_checker");
			}
		}
	}
}

public void OnSteamAPI(SWHTTPRequest request, bool bFailure, bool successful, EHTTPStatusCode code, any userid) {
	int client = GetClientOfUserId(userid);
	char getResponse[4096];
	if(client == 0) {
		LogItem(Log_Debug, "Client with User ID %d left when checking Valve status.", userid);
		delete request;
		return;
	}
	if(!successful || code != k_EHTTPStatusCode200OK) {
		LogItem(Log_Error, "Error checking Steam for client %L. Status code: %d, Successful: %s", client, view_as<int>(code), successful ? "true" : "false");
		delete request;
		return;
	}
	request.GetBodyData(getResponse, request.ResponseSize);
	delete request;
	KeyValues kv = new KeyValues("response");
	#if defined DEBUG
	PrintToServer(getResponse);
	#endif
	if(!kv.ImportFromString(getResponse)) {
		LogItem(Log_Error, "Steam returned invalid KeyValues for %L, returned %s.", client, getResponse);
		delete kv;
		return;
	}
	kv.JumpToKey("players");
	kv.JumpToKey("0");
	char banStatus[64];
	kv.GetString("EconomyBan", banStatus, sizeof(banStatus));
	delete kv;
	if(StrEqual(banStatus, "banned")) {
		LogItem(Log_Debug, "%L is trade-banned, handling...", client);
		HandleValvePlayer(client, true);
	} else if(StrEqual(banStatus, "probation")) {
		LogItem(Log_Debug, "%L is on trade probation, handling...", client);
		HandleValvePlayer(client, false);
	} else {
		LogItem(Log_Debug, "Steam reports that %L is OK", client);
	}
}

void HandleValvePlayer(int client, bool banned) {
	char clientAuth[32];
	if (GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth)))
	{
		switch((banned) ? cvarValveBanDealMethod.IntValue : cvarValveCautionDealMethod.IntValue) {
			case 0: {
				// Disabled
			}
			case 1: {
				// Chat tag
				if(!LibraryExists("scp")) {
					LogItem(Log_Info, "Simple Chat Processor (Redux) is not loaded, so tags will not be colored in chat.", client);
					return;
				}
				LogItem(Log_Info, "Tagged %L as %s", client, banned ? "trade banned" : "trade probation");
				SetClientTag(client, banned ? TagType_TradeBanned : TagType_TradeProbation);
			}
			case 2: {
				// Kick
				LogItem(Log_Info, "Kicked %L as %s", client, banned ? "trade banned" : "trade probation");
				KickClient(client, "You are %s", banned ? "trade banned" : "on trade probation");
			}
			case 3: {
				// Ban Steam ID
				LogItem(Log_Info, "Banned %L by Steam ID as %s", client, banned ? "trade banned" : "trade probation");
				if(GetFeatureStatus(FeatureType_Native, "SourceBans_BanPlayer") == FeatureStatus_Available) {
					char message[256];
					Format(message, sizeof(message), "Player is %s", banned ? "trade banned" : "on trade probation");
					SourceBans_BanPlayer(0, client, cvarSteamIDBanLength.IntValue, message);
				} else {
					char message[256], kickMessage[256];
					Format(message, sizeof(message), "Player is %s", banned ? "trade banned" : "on trade probation");
					Format(kickMessage, sizeof(kickMessage), "You are %s", banned ? "trade banned" : "on trade probation");
					BanClient(client, cvarSteamIDBanLength.IntValue, BANFLAG_AUTHID, message, kickMessage, "steamrep_checker");
				}
			}
			case 4: {
				// Ban IP
				LogItem(Log_Info, "Banned %L by IP as %s", client, banned ? "trade banned" : "trade probation");
				if(GetFeatureStatus(FeatureType_Native, "SourceBans_BanPlayer") == FeatureStatus_Available) {
					// SourceBans doesn't currently expose a native to ban an IP!
					ServerCommand("sm_banip #%d %d A %s has connected from this IP. Steam ID: %s", banned ? "trade banned player" : "player on trade probation", GetClientUserId(client), cvarIPBanLength.IntValue, clientAuth);
				} else {
					char message[256], kickMessage[256];
					Format(message, sizeof(message), "A %s has connected from this IP. Steam ID: %s", banned ? "trade banned player" : "player on trade probation", clientAuth);
					Format(kickMessage, sizeof(kickMessage), "You are %s", banned ? "trade banned" : "on trade probation");
					BanClient(client, cvarIPBanLength.IntValue, BANFLAG_IP, message, kickMessage, "steamrep_checker");
				}
			}
			case 5: {
				// Ban Steam ID + IP
				LogItem(Log_Info, "Banned %L by Steam ID and IP as %s", client, banned ? "trade banned" : "trade probation");
				if(GetFeatureStatus(FeatureType_Native, "SourceBans_BanPlayer") == FeatureStatus_Available) {
					char message[256];
					Format(message, sizeof(message), "Player is %s", banned ? "trade banned" : "on trade probation");
					SourceBans_BanPlayer(0, client, cvarSteamIDBanLength.IntValue, message);
					ServerCommand("sm_banip #%d %d A %s has connected from this IP. Steam ID: %s", banned ? "trade banned player" : "player on trade probation", GetClientUserId(client), cvarIPBanLength.IntValue, clientAuth);
				} else {
					char message[256], kickMessage[256];
					Format(message, sizeof(message), "A %s has connected from this IP. Steam ID: %s", banned ? "trade banned player" : "player on trade probation", clientAuth);
					Format(kickMessage, sizeof(kickMessage), "You are %s", banned ? "trade banned" : "on trade probation");
					BanClient(client, cvarSteamIDBanLength.IntValue, BANFLAG_AUTHID, message, kickMessage, "steamrep_checker");
					BanClient(client, cvarIPBanLength.IntValue, BANFLAG_IP, message, kickMessage, "steamrep_checker");
				}
			}
		}
	}
	else
	{
		LogItem(Log_Error, "Could not get SteamID2 for client %L in HandleValvePlayer!", client);
	}
}

void SetClientTag(int client, TagType type) {
	char name[MAX_NAME_LENGTH];
	switch(type) {
		case TagType_Scammer: {
			CPrintToChatAll("{DARKORANGE}WARNING: {LIGHTGREEN}%N{DEFAULT} is a reported scammer at SteamRep.com", client);
			Format(name, sizeof(name), "[SCAMMER] %N", client);
			SetClientInfo(client, "name", name);
		}
		case TagType_TradeBanned: {
			PrintToChatAll("{DARKORANGE}WARNING: {LIGHTGREEN}%N{DEFAULT} is trade banned", client);
			Format(name, sizeof(name), "[TRADE BANNED] %N", client);
			SetClientInfo(client, "name", name);
		}
		case TagType_TradeProbation: {
			PrintToChatAll("{CORAL}CAUTION: {LIGHTGREEN}%N{DEFAULT} is on trade probation", client);
			Format(name, sizeof(name), "[TRADE PROBATION] %N", client);
			SetClientInfo(client, "name", name);
		}
	}
	clientTag[client] = type;
}

public Action OnChatMessage(int &author, Handle recipients, char[] name, char[] message) {
	switch(clientTag[author]) {
		case TagType_None: return Plugin_Continue;
		case TagType_Scammer: ReplaceString(name, MAXLENGTH_NAME, "[SCAMMER]", "\x07FF0000[SCAMMER]\x03");
		case TagType_TradeBanned: ReplaceString(name, MAXLENGTH_NAME, "[TRADE BANNED]", "\x07FF0000[TRADE BANNED]\x03");
		case TagType_TradeProbation: ReplaceString(name, MAXLENGTH_NAME, "[TRADE PROBATION]", "\x07FF7F00[TRADE PROBATION]\x03");
	}
	return Plugin_Changed;
}

public Action CCC_OnColor(int client, const char[] message, CCC_ColorType type) {
	if(type == CCC_TagColor && clientTag[client] != TagType_None) {
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	if(!cvarSpawnMessage.BoolValue) {
		return;
	}
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(GetClientTeam(client) < 2 || messageDisplayed[client]) {
		return;
	}
	CPrintToChat(client, "{GREEN}[SR]{DEFAULT} This server is protected by {GREEN}SteamRep{DEFAULT}. Visit {GREEN}SteamRep.com{DEFAULT} for more information.");
	messageDisplayed[client] = true;
}

public void Event_PlayerChangeName(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(clientTag[client] == TagType_None) {
		return;
	}
	char clientName[MAX_NAME_LENGTH];
	event.GetString("newname", clientName, sizeof(clientName));
	if(clientTag[client] == TagType_Scammer && StrContains(clientName, "[SCAMMER]") != 0) {
		KickClient(client, "Kicked from server\n\nDo not attempt to remove the [SCAMMER] tag");
	} else if(clientTag[client] == TagType_TradeBanned && StrContains(clientName, "[TRADE BANNED]") != 0) {
		KickClient(client, "Kicked from server\n\nDo not attempt to remove the [TRADE BANNED] tag");
	} else if(clientTag[client] == TagType_TradeProbation && StrContains(clientName, "[TRADE PROBATION]") != 0) {
		KickClient(client, "Kicked from server\n\nDo not attempt to remove the [TRADE PROBATION] tag");
	}
}

public Action Command_Rep(int client, int args) {
	int target;
	if(args == 0) {
		target = GetClientAimTarget(client);
		if(target <= 0) {
			DisplayClientMenu(client);
			return Plugin_Handled;
		}
	} else {
		char arg1[MAX_NAME_LENGTH];
		GetCmdArg(1, arg1, sizeof(arg1));
		target = FindTargetEx(client, arg1, true, false, false);
		if(target == -1) {
			DisplayClientMenu(client);
			return Plugin_Handled;
		}
	}
	char steamID[64];
	if (GetClientAuthId(target, AuthId_SteamID64, steamID, sizeof(steamID)))
	{
		char url[256];
		Format(url, sizeof(url), "https://steamrep.com/profiles/%s", steamID);
		KeyValues Kv = new KeyValues("data");
		Kv.SetString("title", "");
		Kv.SetString("type", "2");
		Kv.SetString("msg", url);
		Kv.SetNum("customsvr", 1);
		ShowVGUIPanel(client, "info", Kv);
		delete Kv;
	}
	else
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Could not get SteamRep profile, try again shortly!");
	}
	return Plugin_Handled;
}

void DisplayClientMenu(int client) {
	Menu menu = new Menu(Handler_ClientMenu);
	menu.SetTitle("Select Player");
	char name[MAX_NAME_LENGTH], index[8];
	for(int i= 1; i <= MaxClients; i++) {
		if(!IsValidClient(i)) {
			continue;
		}
		GetClientName(i, name, sizeof(name));
		IntToString(GetClientUserId(i), index, sizeof(index));
		menu.AddItem(index, name);
	}
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_ClientMenu(Menu menu, MenuAction action, int client, int param) {
	if(action == MenuAction_End) {
		delete menu;
	}
	if(action != MenuAction_Select) {
		return;
	}
	char selection[32];
	if (menu.GetItem(param, selection, sizeof(selection)) && IsValidClient(client))
	{
		FakeClientCommand(client, "sm_rep #%s", selection);
	}
}

int FindTargetEx(int client, const char[] target, bool nobots = false, bool immunity = true, bool replyToError = true) {
	char target_name[MAX_TARGET_LENGTH];
	int target_list[1], target_count;
	bool tn_is_ml;

	int flags = COMMAND_FILTER_NO_MULTI;
	if(nobots) {
		flags |= COMMAND_FILTER_NO_BOTS;
	}
	if(!immunity) {
		flags |= COMMAND_FILTER_NO_IMMUNITY;
	}

	if((target_count = ProcessTargetString(
			target,
			client,
			target_list,
			1,
			flags,
			target_name,
			sizeof(target_name),
			tn_is_ml)) > 0)
	{
		return target_list[0];
	} else {
		if(replyToError) {
			ReplyToTargetError(client, target_count);
		}
		return -1;
	}
}

void LogItem(LogLevel level, const char[] format, any ...)
{
	int logLevel = cvarLogLevel.IntValue;
	if(logLevel < view_as<int>(level))
	{
		return;
	}
	char logPrefixes[][] = {"[ERROR]", "[INFO]", "[DEBUG]"};
	char buffer[512], file[PLATFORM_MAX_PATH];
	VFormat(buffer, sizeof(buffer), format, 3);
	BuildPath(Path_SM, file, sizeof(file), "logs/steamrep_checker.log");
	LogToFileEx(file, "%s %s", logPrefixes[view_as<int>(level)], buffer);
}
