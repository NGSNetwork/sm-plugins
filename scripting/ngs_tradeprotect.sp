/**
* TheXeon
* ngs_tradeprotect.sp
*
* Files:
* addons/sourcemod/plugins/ngs_tradeprotect.smx
* cfg/sourcemod/plugin.ngs_tradeprotect.cfg
*
* Dependencies:
* autoexecconfig.inc, sdktools.inc, SteamWorks.inc, multicolors.inc,
* json.inc, ccc.inc, scp.inc, sourcebans.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma dynamic 131072
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <autoexecconfig>
#include <sdktools>
#include <SteamWorks>
#include <multicolors>
#include <json>

#undef REQUIRE_PLUGIN
#include <ccc>
#include <scp>
#include <sourcebanspp>
#define REQUIRE_PLUGIN

#include <ngsutils>
#include <ngsupdater>

#define BACKPACKTF_URL		"https://backpack.tf/api/IGetUsers/v3"
#define STEAMREP_URL		"http://steamrep.com/id2rep.php"

enum TagType {
	TagType_None = 0,
	TagType_Scammer,
	TagType_TradeBanned,
	TagType_TradeProbation,
	TagType_BackpackTFBanned
}

public Plugin myinfo = {
	name        = "[NGS] Trade Protect",
	author      = "Dr. McKay / TheXeon",
	description = "Checks a user's Rep/Trade status upon connection. Plugin based on steamrep checker redux.",
	version     = "1.0.3",
	url         = "https://www.neogenesisnetwork.net"
}

ConVar cvarDealMethod;
ConVar cvarSteamIDBanLength;
ConVar cvarIPBanLength;
ConVar cvarKickTaggedScammers;
ConVar cvarTradeBanDealMethod;
ConVar cvarTradeCautionDealMethod;
ConVar cvarBackpackBannedDealMethod;
ConVar cvarExcludedTags;
ConVar cvarEnableExclusion;
ConVar cvarTagChangeDealMethod;
ConVar cvarSpawnMessage;
ConVar cvarSendSteamRepIP;

TagType clientTag[MAXPLAYERS + 1];
bool messageDisplayed[MAXPLAYERS + 1];

public void OnPluginStart() {
	AutoExecConfig_SetCreateDirectory(true);
	AutoExecConfig_SetCreateFile(true);

	bool appended;
	Timber.plantToFile(appended);
	cvarDealMethod = AutoExecConfig_CreateConVarCheckAppend(appended, "trade_protect_deal_method", "5", "How to deal with reported scammers.\n0 = Disabled\n1 = Prefix chat with [SCAMMER] tag and warn users in chat (requires Custom Chat Colors)\n2 = Kick\n3 = Ban Steam ID\n4 = Ban IP\n5 = Ban Steam ID + IP", _, true, 0.0, true, 5.0);
	cvarSteamIDBanLength = AutoExecConfig_CreateConVarCheckAppend(appended, "trade_protect_steamid_ban_length", "0", "Duration in minutes to ban Steam IDs for if trade_protect_deal_method = 3 or 5 (0 = permanent)", _, true, 0.0);
	cvarIPBanLength = AutoExecConfig_CreateConVarCheckAppend(appended, "trade_protect_ip_ban_length", "0", "Duration in minutes to ban IP addresses for if trade_protect_deal_method = 4 or 5 (0 = permanent)");
	cvarKickTaggedScammers = AutoExecConfig_CreateConVarCheckAppend(appended, "trade_protect_kick_tagged_scammers", "1", "Kick chat-tagged scammers if the server gets full?", _, true, 0.0, true, 1.0);
	cvarTradeBanDealMethod = AutoExecConfig_CreateConVarCheckAppend(appended, "trade_protect_valve_ban_deal_method", "2", "How to deal with Valve trade-banned players\n0 = Disabled\n1 = Prefix chat with [TRADE BANNED] tag and warn users in chat (requires Custom Chat Colors)\n2 = Kick\n3 = Ban Steam ID\n4 = Ban IP\n5 = Ban Steam ID + IP", _, true, 0.0, true, 5.0);
	cvarTradeCautionDealMethod = AutoExecConfig_CreateConVarCheckAppend(appended, "trade_protect_valve_probation_deal_method", "1", "How to deal with Valve trade-probation players (requires API key to be set, not implemented)\n0 = Disabled\n1 = Prefix chat with [TRADE PROBATION] tag and warn users in chat (requires Custom Chat Colors)\n2 = Kick\n3 = Ban Steam ID\n4 = Ban IP\n5 = Ban Steam ID + IP", _, true, 0.0, true, 5.0);
	cvarTagChangeDealMethod = AutoExecConfig_CreateConVarCheckAppend(appended, "trade_protect_tag_change_deal_method", "1", "How to deal with name changes on tagged players (thanks 404UNF for idea)\n0 = Do nothing\n1 = Reset name to include tag\n2 = Kick client", _, true, 0.0, true, 2.0);
	cvarBackpackBannedDealMethod = AutoExecConfig_CreateConVarCheckAppend(appended, "trade_protect_bptf_banned_deal_method", "1", "How to deal with BackpackTF banned players\n0 = Disabled\n1 = Prefix chat with [BPTF BANNED] tag and warn users in chat (requires Custom Chat Colors)\n2 = Kick\n3 = Ban Steam ID\n4 = Ban IP\n5 = Ban Steam ID + IP", _, true, 0.0, true, 5.0);
	cvarEnableExclusion = AutoExecConfig_CreateConVarCheckAppend(appended, "trade_protect_exclusion", "1", "Allow exclusion via SkipSR override?", _, true, 0.0, true, 1.0);
	cvarExcludedTags = AutoExecConfig_CreateConVarCheckAppend(appended, "trade_protect_untrusted_tags", "", "Input the tags of any community whose bans you do not trust here.");
	cvarSpawnMessage = AutoExecConfig_CreateConVarCheckAppend(appended, "trade_protect_spawn_message", "1", "Display messages upon first spawn that this server is protected by SteamRep?", _, true, 0.0, true, 1.0);
	cvarSendSteamRepIP = AutoExecConfig_CreateConVarCheckAppend(appended, "trade_protect_send_sr_ip", "1", "Send connecting client's IP to SteamRep?", _, true, 0.0, true, 1.0);
	AutoExecConfig_ExecAndClean(appended);

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_changename", Event_PlayerChangeName);

	RegConsoleCmd("sm_rep", Command_Rep, "Checks a user's Rep");
	RegConsoleCmd("sm_sr", Command_SteamRep, "Checks a user's SteamRep");
}

public void OnClientConnected(int client)
{
	clientTag[client] = TagType_None;
}

public void OnClientPostAdminCheck(int client)
{
	PerformKicks();
	if(!IsValidClient(client)) {
		return;
	} else if (cvarEnableExclusion.BoolValue && (CheckCommandAccess(client, "SkipSR", ADMFLAG_ROOT) || CheckCommandAccess(client, "ngs_tradeprotect_immunity", ADMFLAG_ROOT))) {
		return;
	}
	char auth[32];
	if (GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth)))
	{
		SWHTTPRequest bpRequest = new SWHTTPRequest(k_EHTTPMethodGET, BACKPACKTF_URL);
		bpRequest.SetParam("steamid", auth);
		bpRequest.SetContextValue(GetClientUserId(client));
		bpRequest.SetHeaderValue("Accept", "application/json");
		bpRequest.SetCallbacks(OnBackpackTFChecked);
		bpRequest.Send();
		Timber.d("Sending backpack.tf HTTP request for %L", client);

		if (cvarSendSteamRepIP.BoolValue)
		{
			char clientIP[32], excludedTags[128];
			cvarExcludedTags.GetString(excludedTags, sizeof(excludedTags));
			GetClientIP(client, clientIP, sizeof(clientIP));
			SWHTTPRequest srRequest = new SWHTTPRequest(k_EHTTPMethodGET, STEAMREP_URL);
			srRequest.SetParam("steamID32", auth);
			srRequest.SetParam("IP", clientIP);
			srRequest.SetCallbacks(OnSRRequestComplete);
			srRequest.Send();
			Timber.d("Sending SteamRep HTTP request for %L", client);
		}
	}
	else
	{
		Timber.e("Could not get SteamID2 for client %L!", client);
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
		if(cvarTradeBanDealMethod.IntValue == 1) {
			for(int i = 1; i <= MaxClients; i++) {
				if(IsClientInGame(i) && clientTag[i] == TagType_TradeBanned) {
					KickClient(i, "You were kicked to free a slot because you are trade banned");
					return;
				}
			}
		}
		if(cvarTradeCautionDealMethod.IntValue == 1) {
			for(int i= 1; i <= MaxClients; i++) {
				if(IsClientInGame(i) && clientTag[i] == TagType_TradeProbation) {
					KickClient(i, "You were kicked to free a slot because you are on trade probation");
					return;
				}
			}
		}
		if (cvarBackpackBannedDealMethod.IntValue == 1) {
			for(int i= 1; i <= MaxClients; i++) {
				if(IsClientInGame(i) && clientTag[i] == TagType_BackpackTFBanned) {
					KickClient(i, "You were kicked to free a slot because you are banned on backpack.tf");
					return;
				}
			}
		}
	}
}

public void OnBackpackTFChecked(SWHTTPRequest request, bool bFailure, bool successful, EHTTPStatusCode code, any userid) {
	int client = GetClientOfUserId(userid);
	if (client == 0) {
		Timber.d("Client with User ID %d left.", userid);
		delete request;
		return;
	}
	if (!successful || code != k_EHTTPStatusCode200OK) {
		Timber.e("Error checking BackpackTF for client %L. Status code: %d, Successful: %s", client, view_as<int>(code), successful ? "true" : "false");
		delete request;
		return;
	}
	char[] data = new char[request.ResponseSize + 1];
	request.GetBodyData(data, request.ResponseSize);
	delete request;

	JSON_Object obj = new JSON_Object();
	obj.Decode(data);
	Timber.d("Received response for %L: \'%s\'", client, data);
	JSON_Object response = obj.GetObject("response");
	if (!response.HasKey("success") || response.GetInt("success") != 1) {
		Timber.d("Success for %L is not 1, returning!", client);
	} else {
		char auth[24];
		if (GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth))) {
			JSON_Object player = response.GetObject("players").GetObject(auth);
			if (player.HasKey("steamrep_scammer") && player.GetBool("steamrep_scammer")) {
				HandleScammer(client, auth);
			} else if (player.HasKey("ban_economy") && player.GetBool("ban_economy")) {
				HandleBackpackTFPlayer(client, auth, TagType_TradeBanned);
			} else if (player.HasKey("backpack_tf_banned")) {
				JSON_Object backpack_tf_banned = player.GetObject("backpack_tf_banned");
				int end = backpack_tf_banned.GetInt("end");
				if (end != -1 && end >= GetTime()) {
					HandleBackpackTFPlayer(client, auth, TagType_BackpackTFBanned);
				}
			}
		}
	}

	obj.Cleanup();
	delete obj;
}

public void OnSRRequestComplete(SWHTTPRequest request, bool bFailure, bool successful, EHTTPStatusCode code) {
	if (!successful || code != k_EHTTPStatusCode200OK) {
		Timber.e("Error sending SteamRep client's IP. Status code: %d, Successful: %b", view_as<int>(code), successful);
	}
	delete request;
}

void HandleScammer(int client, const char[] auth) {
	char clientAuth[32];
	if (!GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth)))
	{
		Timber.e("Error handling potential scammer. (Unverified) Auth is %s.", auth);
		return;
	}
	if(!StrEqual(auth, clientAuth)) {
		Timber.e("Steam ID for %L (%s) didn't match SteamRep's response (%s)", client, clientAuth, auth);
		return;
	}
	switch(cvarDealMethod.IntValue) {
		case 0: {
			// Disabled
		}
		case 1: {
			// Chat tag
			if(!LibraryExists("scp")) {
				Timber.i("Simple Chat Processor (Redux) is not loaded, so tags will not be colored in chat.", client);
				return;
			}
			Timber.i("Tagged %L as a scammer", client);
			SetClientTag(client, TagType_Scammer);
		}
		case 2: {
			// Kick
			Timber.i("Kicked %L as a scammer", client);
			KickClient(client, "You are a reported scammer. Visit http://www.steamrep.com for more information");
		}
		case 3: {
			// Ban Steam ID
			Timber.i("Banned %L by Steam ID as a scammer", client);
			if(GetFeatureStatus(FeatureType_Native, "SBPP_BanPlayer") == FeatureStatus_Available) {
				SBPP_BanPlayer(0, client, cvarSteamIDBanLength.IntValue, "Player is a reported scammer via SteamRep.com");
			} else {
				BanClient(client, cvarSteamIDBanLength.IntValue, BANFLAG_AUTHID, "Player is a reported scammer via SteamRep.com", "You are a reported scammer. Visit http://www.steamrep.com for more information", "ngs_tradeprotect");
			}
		}
		case 4: {
			// Ban IP
			Timber.i("Banned %L by IP as a scammer", client);
			if(GetFeatureStatus(FeatureType_Native, "SBPP_BanPlayer") == FeatureStatus_Available) {
				// SourceBans doesn't currently expose a native to ban an IP!
				char ip[64];
				GetClientIP(client, ip, sizeof(ip));
				ServerCommand("sm_banip \"%s\" %d A scammer has connected from this IP. Steam ID: %s", ip, cvarIPBanLength.IntValue, clientAuth);
			} else {
				char banMessage[256];
				Format(banMessage, sizeof(banMessage), "A scammer has connected from this IP. Steam ID: %s", clientAuth);
				BanClient(client, cvarIPBanLength.IntValue, BANFLAG_IP, banMessage, "You are a reported scammer. Visit http://www.steamrep.com for more information", "ngs_tradeprotect");
			}
		}
		case 5: {
			// Ban Steam ID + IP
			Timber.i("Banned %L by Steam ID and IP as a scammer", client);
			if(GetFeatureStatus(FeatureType_Native, "SBPP_BanPlayer") == FeatureStatus_Available) {
				char ip[64];
				GetClientIP(client, ip, sizeof(ip));
				SBPP_BanPlayer(0, client, cvarSteamIDBanLength.IntValue, "Player is a reported scammer via SteamRep.com");
				ServerCommand("sm_banip \"%s\" %d A scammer has connected from this IP. Steam ID: %s", ip, cvarIPBanLength.IntValue, clientAuth);
			} else {
				BanClient(client, cvarSteamIDBanLength.IntValue, BANFLAG_AUTHID, "Player is a reported scammer via SteamRep.com", "You are a reported scammer. Visit http://www.steamrep.com for more information", "ngs_tradeprotect");
				BanClient(client, cvarIPBanLength.IntValue, BANFLAG_IP, "Player is a reported scammer via SteamRep.com", "You are a reported scammer. Visit http://www.steamrep.com for more information", "ngs_tradeprotect");
			}
		}
	}
}

void HandleBackpackTFPlayer(int client, const char[] clientAuth, TagType playerTag) {
	ConVar cvarCheck;
	char playerStatus[48], playerWithStatus[48];
	switch (playerTag) {
		case TagType_None: {
			return;
		}
		case TagType_TradeBanned: {
			cvarCheck = cvarTradeBanDealMethod;
			playerStatus = "trade banned";
			playerWithStatus = "trade banned player";
		}
		case TagType_TradeProbation: {
			cvarCheck = cvarTradeCautionDealMethod;
			playerStatus = "on trade probation";
			playerWithStatus = "player on trade probation";
		}
		case TagType_BackpackTFBanned: {
			cvarCheck = cvarBackpackBannedDealMethod;
			playerStatus = "backpack.tf banned";
			playerWithStatus = "backpack.tf banned player";
		}
	}

	switch(cvarCheck.IntValue) {
		case 0: {
			// Disabled
		}
		case 1: {
			// Chat tag
			if(!LibraryExists("scp")) {
				Timber.i("Simple Chat Processor (Redux) is not loaded, so tags will not be colored in chat.", client);
				return;
			}
			Timber.i("Tagged %L as %s", client, playerStatus);
			SetClientTag(client, playerTag);
		}
		case 2: {
			// Kick
			Timber.i("Kicked %L as %s", client, playerStatus);
			KickClient(client, "You are %s", playerStatus);
		}
		case 3: {
			// Ban Steam ID
			Timber.i("Banned %L by Steam ID as %s", client, playerStatus);
			if(GetFeatureStatus(FeatureType_Native, "SBPP_BanPlayer") == FeatureStatus_Available) {
				char message[256];
				Format(message, sizeof(message), "Player is %s", playerStatus);
				SBPP_BanPlayer(0, client, cvarSteamIDBanLength.IntValue, message);
			} else {
				char message[256], kickMessage[256];
				Format(message, sizeof(message), "Player is %s", playerStatus);
				Format(kickMessage, sizeof(kickMessage), "You are %s", playerStatus);
				BanClient(client, cvarSteamIDBanLength.IntValue, BANFLAG_AUTHID, message, kickMessage, "ngs_tradeprotect");
			}
		}
		case 4: {
			// Ban IP
			Timber.i("Banned %L by IP as %s", client, playerStatus);
			if(GetFeatureStatus(FeatureType_Native, "SBPP_BanPlayer") == FeatureStatus_Available) {
				// SourceBans doesn't currently expose a native to ban an IP!
				ServerCommand("sm_banip #%d %d A %s has connected from this IP. Steam ID: %s", playerStatus, GetClientUserId(client), cvarIPBanLength.IntValue, clientAuth);
			} else {
				char message[256], kickMessage[256];
				Format(message, sizeof(message), "A %s has connected from this IP. Steam ID: %s", playerStatus, clientAuth);
				Format(kickMessage, sizeof(kickMessage), "You are %s", playerStatus);
				BanClient(client, cvarIPBanLength.IntValue, BANFLAG_IP, message, kickMessage, "ngs_tradeprotect");
			}
		}
		case 5: {
			// Ban Steam ID + IP
			Timber.i("Banned %L by Steam ID and IP as %s", client, playerStatus);
			if(GetFeatureStatus(FeatureType_Native, "SBPP_BanPlayer") == FeatureStatus_Available) {
				char message[256];
				Format(message, sizeof(message), "Player is %s", playerStatus);
				SBPP_BanPlayer(0, client, cvarSteamIDBanLength.IntValue, message);
				ServerCommand("sm_banip #%d %d A %s has connected from this IP. Steam ID: %s", playerWithStatus, GetClientUserId(client), cvarIPBanLength.IntValue, clientAuth);
			} else {
				char message[256], kickMessage[256];
				Format(message, sizeof(message), "A %s has connected from this IP. Steam ID: %s", playerWithStatus, clientAuth);
				Format(kickMessage, sizeof(kickMessage), "You are %s", playerStatus);
				BanClient(client, cvarSteamIDBanLength.IntValue, BANFLAG_AUTHID, message, kickMessage, "ngs_tradeprotect");
				BanClient(client, cvarIPBanLength.IntValue, BANFLAG_IP, message, kickMessage, "ngs_tradeprotect");
			}
		}
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
		case TagType_BackpackTFBanned: {
			PrintToChatAll("{CORAL}CAUTION: {LIGHTGREEN}%N{DEFAULT} is backpack.tf banned", client);
			Format(name, sizeof(name), "[BPTF BANNED] %N", client);
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
		case TagType_BackpackTFBanned: ReplaceString(name, MAXLENGTH_NAME, "[BPTF BANNED]", "\x07FF7F00[BPTF BANNED]\x03");
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
	CPrintToChat(client, "{GREEN}[NGS]{DEFAULT} This server is protected by {GREEN}NGS Trade Protect{DEFAULT}.");
	messageDisplayed[client] = true;
}

public void Event_PlayerChangeName(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(clientTag[client] == TagType_None) {
		return;
	}
	
	char clientName[MAX_NAME_LENGTH];
	event.GetString("newname", clientName, sizeof(clientName));

	switch (cvarTagChangeDealMethod.IntValue) {
		case 0: {
			// Do nothing
		}
		case 1: {
			if(clientTag[client] == TagType_Scammer && StrContains(clientName, "[SCAMMER]") != 0) {
				SetClientTag(client, TagType_Scammer);
			} else if(clientTag[client] == TagType_TradeBanned && StrContains(clientName, "[TRADE BANNED]") != 0) {
				SetClientTag(client, TagType_TradeBanned);
			} else if(clientTag[client] == TagType_TradeProbation && StrContains(clientName, "[TRADE PROBATION]") != 0) {
				SetClientTag(client, TagType_TradeProbation);
			} else if(clientTag[client] == TagType_BackpackTFBanned && StrContains(clientName, "[BPTF BANNED]") != 0) {
				SetClientTag(client, TagType_BackpackTFBanned);
			}
		}
		case 2: {
			if(clientTag[client] == TagType_Scammer && StrContains(clientName, "[SCAMMER]") != 0) {
				KickClient(client, "Kicked from server\n\nDo not attempt to remove the [SCAMMER] tag");
			} else if(clientTag[client] == TagType_TradeBanned && StrContains(clientName, "[TRADE BANNED]") != 0) {
				KickClient(client, "Kicked from server\n\nDo not attempt to remove the [TRADE BANNED] tag");
			} else if(clientTag[client] == TagType_TradeProbation && StrContains(clientName, "[TRADE PROBATION]") != 0) {
				KickClient(client, "Kicked from server\n\nDo not attempt to remove the [TRADE PROBATION] tag");
			} else if(clientTag[client] == TagType_BackpackTFBanned && StrContains(clientName, "[BPTF BANNED]") != 0) {
				KickClient(client, "Kicked from server\n\nDo not attempt to remove the [BPTF BANNED] tag");
			}
		}
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
		target = FindTarget(client, arg1, true, false);
		if(target == -1) {
			DisplayClientMenu(client);
			return Plugin_Handled;
		}
	}
	char steamID[64];
	if (GetClientAuthId(target, AuthId_SteamID64, steamID, sizeof(steamID)))
	{
		char url[256];
		Format(url, sizeof(url), "https://rep.tf/%s", steamID);
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
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Could not get Rep.tf profile, try again shortly!");
	}
	return Plugin_Handled;
}

public Action Command_SteamRep(int client, int args) {
	int target;
	if(args == 0) {
		target = GetClientAimTarget(client);
		if(target <= 0) {
			DisplayClientMenu(client, true);
			return Plugin_Handled;
		}
	} else {
		char arg1[MAX_NAME_LENGTH];
		GetCmdArg(1, arg1, sizeof(arg1));
		target = FindTarget(client, arg1, true, false);
		if(target == -1) {
			DisplayClientMenu(client, true);
			return Plugin_Handled;
		}
	}
	char steamID[64];
	if (GetClientAuthId(target, AuthId_SteamID64, steamID, sizeof(steamID)))
	{
		char url[256];
		Format(url, sizeof(url), "https://rep.tf/%s", steamID);
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
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Could not get Rep.tf profile, try again shortly!");
	}
	return Plugin_Handled;
}

void DisplayClientMenu(int client, bool steamrep=false) {
	Menu menu;
	if (steamrep) {
		menu = new Menu(Handler_SteamRepClientMenu);
	} else {
		menu = new Menu(Handler_RepClientMenu);
	}
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

public int Handler_SteamRepClientMenu(Menu menu, MenuAction action, int client, int param) {
	if(action == MenuAction_End) {
		delete menu;
	}
	if(action != MenuAction_Select) {
		return;
	}
	char selection[32];
	if (menu.GetItem(param, selection, sizeof(selection)) && IsValidClient(client))
	{
		FakeClientCommand(client, "sm_sr #%s", selection);
	}
}

public int Handler_RepClientMenu(Menu menu, MenuAction action, int client, int param) {
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
