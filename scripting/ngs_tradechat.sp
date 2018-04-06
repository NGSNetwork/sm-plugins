/**
* TheXeon
* ngs_tradechat.sp
*
* Files:
* addons/sourcemod/plugins/ngs_tradechat.smx
* addons/sourcemod/translations/tradechat.phrases.txt
* cfg/sourcemod/plugin.ngs_tradechat.cfg
*
* Dependencies:
* clientprefs.inc, morecolors.inc, ngsutils.inc, ngsupdater.inc, basecomm.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define LIBRARY_ADDED_FUNC LibraryAdded
#define LIBRARY_REMOVED_FUNC LibraryRemoved
#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <clientprefs>
#include <morecolors>
#include <ngsutils>
#include <ngsupdater>

#undef REQUIRE_PLUGIN
#include <basecomm>
#include <sourcecomms>
#define REQUIRE_PLUGIN

public Plugin myinfo = {
	name = "[NGS] Trade Chat",
	author = "Luki / TheXeon",
	description = "This plugin adds a special trade chat, players can hide it.",
	version = "1.6.2",
	url = "https://neogenesisnetwork.net/"
}

ConVar hAntiSpamDelay;
ConVar hAntiSpamMaxCount;
ConVar hAntiSpamPunish;
ConVar hAntiSpamShowInterval;
ConVar hChatCheck;
ConVar hChatTriggers;
ConVar hChatTag;

bool basecommExists, sourcecommsExists;

bool HideTradeChat[MAXPLAYERS + 1];
bool TradeChatGag[MAXPLAYERS + 1];
int LastMessageTime[MAXPLAYERS + 1];
int SpamCount[MAXPLAYERS + 1];
char logfile[PLATFORM_MAX_PATH];
int iAntiSpamDelay = 0;
int iAntiSpamMaxCount = 0;
int triggersAmount = 0;
char sChatTriggers[32][1024];
char sLastMessage[MAXPLAYERS + 1][512];
char sChatTag[32] = "Trade";

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "translations/tradechat.phrases.txt");
	if(!FileExists(path))
	{
		SetFailState("Missing translations at %s", path);
	}

	LoadTranslations("tradechat.phrases");

	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");

	RegConsoleCmd("sm_t", Command_TradeChat);
	RegConsoleCmd("sm_lt", Command_LastTradeChat);
	RegConsoleCmd("sm_mlt", Command_MyLastTrade);
	RegConsoleCmd("sm_togglechat", Command_ToggleChat);

	RegAdminCmd("sm_trade_gag", Command_TradeGag, ADMFLAG_CHAT);
	RegAdminCmd("sm_trade_ungag", Command_TradeUnGag, ADMFLAG_CHAT);

	hAntiSpamDelay = CreateConVar("sm_trade_antispam_delay", "5", "Minimum delay between messages from one client (0 = disable)", FCVAR_REPLICATED, true, 0.0, true, 60.0);
	hAntiSpamMaxCount = CreateConVar("sm_trade_antispam_max", "5", "Maximum number of messages, that player can send during block time before autogag (0 = disable)", FCVAR_REPLICATED, true, 0.0, true, 25.0);
	hAntiSpamPunish = CreateConVar("sm_trade_antispam_punish", "1", "Should the plugin reset the interval between messages every time player tries to send it again?", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	hAntiSpamShowInterval = CreateConVar("sm_trade_antispam_showinterval", "0", "Show the remaining time player has to wait before sending another offer", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	hChatCheck = CreateConVar("sm_trade_chatcheck", "1", "Check for triggers in chat.", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	hChatTag = CreateConVar("sm_trade_chattag", "Trade Chat", "Tag used to specify trade chat.", FCVAR_REPLICATED);
	hChatTriggers = CreateConVar("sm_trade_chattriggers", "trade, sell, buy, trading, S>, B>, [S], [B]", "Chat triggers that move a message to trade chat.", FCVAR_REPLICATED);


	if (hAntiSpamDelay != null)
		HookConVarChange(hAntiSpamDelay, OnAntiSpamDelayChange);

	if (hAntiSpamMaxCount != null)
		HookConVarChange(hAntiSpamMaxCount, OnAntiSpamMaxCountChange);

	if (hChatTriggers != null)
		HookConVarChange(hChatTriggers, OnChatTriggersChange);

	if (hChatTag != null)
		HookConVarChange(hChatTag, OnChatTagChange);

	BuildPath(Path_SM, logfile, sizeof(logfile), "logs/tradechat.log");

	AutoExecConfig(true);
}

public void LibraryAdded(const char[] name)
{
	if (StrEqual(name, "basecomm", false))
	{
		basecommExists = true;
	}
	else if (StrEqual(name, "sourcecomms", false))
	{
		sourcecommsExists = true;
	}
}

public void LibraryRemoved(const char[] name)
{
	if (StrEqual(name, "basecomm", false))
	{
		basecommExists = false;
	}
	else if (StrEqual(name, "sourcecomms", false))
	{
		sourcecommsExists = false;
	}
}

public void OnConfigsExecuted()
{
	iAntiSpamDelay = GetConVarInt(hAntiSpamDelay);
	iAntiSpamMaxCount = GetConVarInt(hAntiSpamMaxCount);

	char buffer[512];
	GetConVarString(hChatTriggers, buffer, sizeof(buffer));
	triggersAmount = ExplodeString(buffer, ", ", sChatTriggers, sizeof(sChatTriggers), sizeof(sChatTriggers[]), false);
}

public void OnClientConnected(int client)
{
	HideTradeChat[client] = false;
	TradeChatGag[client] = false;
	LastMessageTime[client] = 0;
	SpamCount[client] = 0;
}

public Action Command_Say(int client, const char[] command, int argc)
{
	if (!IsValidClient(client)) return Plugin_Continue;
	if (hChatCheck.IntValue < 1) return Plugin_Continue;

	char text[512];
	GetCmdArgString(text, sizeof(text));

	if (checkForTriggers(text))
	{
		StripQuotes(text);
		if (DoTradeChat(client, text, true)) return Plugin_Continue;
		else return Plugin_Handled;
	}
	return Plugin_Continue;
}

public bool checkForTriggers(char[] text)
{
	if (!(FindCharInString(text, '/') == 1 || FindCharInString(text, '!') == 1 || FindCharInString(text, '@') == 1))
	{
		for (int i = 0; i < triggersAmount; i++)
		{
			if (StrContains(text, sChatTriggers[i], false) != -1)
				return true;
		}
	}
	return false;
}

public Action Command_TradeChat(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	char text[512];
	GetCmdArgString(text, sizeof(text));

	DoTradeChat(client, text);

	return Plugin_Handled;
}

public Action Command_LastTradeChat(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	if (strlen(sLastMessage[client]) != 0)
		DoTradeChat(client, sLastMessage[client]);
	else
		CPrintToChat(client, "%t", "LastMessageIsEmpty", sChatTag);

	return Plugin_Handled;
}

public Action Command_MyLastTrade(int client, int args)
{
	if (strlen(sLastMessage[client]) != 0)
		CPrintToChat(client, "%t", "YourLastMessage", sChatTag, sLastMessage[client]);
	else
		CPrintToChat(client, "%t", "LastMessageIsEmpty", sChatTag);

	return Plugin_Handled;
}

stock bool DoTradeChat(int client, char[] msg, bool fromChatTriggers=false)
{
	TrimString(msg);
	if (strlen(msg) == 0)
		return true;

	if (TradeChatGag[client] || ((basecommExists && BaseComm_IsClientGagged(client)) || (sourcecommsExists && SourceComms_GetClientGagType(client) != bNot)))
	{
		CPrintToChat(client, "%t", "TradeBanned", sChatTag);
		return false;
	}

	if (HideTradeChat[client])
	{
		if (!fromChatTriggers)
		{
			CPrintToChat(client, "%t", "TradeDisabledForYou", sChatTag);
		}
		return true;
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));

	if (((GetTime() - LastMessageTime[client]) < iAntiSpamDelay) && (iAntiSpamDelay != 0))
	{
		SpamCount[client]++;
		if ((SpamCount[client] > iAntiSpamMaxCount) && (iAntiSpamMaxCount != 0))
		{
			TradeChatGag[client] = true;
			LogToFile(logfile, "%L was automatically banned from the trade chat", client);
			CPrintToChatAll("%t", "AntiSpamAutoGag", sChatTag, name);
			return false;
		}
		if (hAntiSpamPunish.BoolValue)
			LastMessageTime[client] = GetTime();
		LogToFile(logfile, "%L was blocked from sending an offer", client);
		if (hAntiSpamShowInterval.BoolValue)
			CPrintToChat(client, "%t", "AntiSpamBlockedInterval", sChatTag, iAntiSpamDelay - (GetTime() - LastMessageTime[client]));
		else
			CPrintToChat(client, "%t", "AntiSpamBlocked", sChatTag);
		return false;
	}

	SpamCount[client] = 0;
	LastMessageTime[client] = GetTime();
	Format(sLastMessage[client], sizeof(sLastMessage[]), "%s", msg);

	bool HintCommandAccess = CheckCommandAccess(client, "sm_trade_hudtext_override", ADMFLAG_RESERVATION);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && !HideTradeChat[i])
		{
			CPrintToChat(i, "%t", "Offer", sChatTag, name, msg);
			if (HintCommandAccess)
			{
				PrintHintText(i, "[%s] %s: %s", sChatTag, name, msg);
			}
		}
	}
	LogToFile(logfile, "%L says \"%s\"", client, msg);
	return false;
}

public Action Command_TradeGag(int client, int args)
{
	char sTarget[MAX_NAME_LENGTH];

	if (!GetCmdArg(1, sTarget, sizeof(sTarget)))
	{
		ReplyToCommand(client, "%t", "TradeGagUsage");
		return Plugin_Handled;
	}

	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	char target_name[MAX_TARGET_LENGTH];

	if ((target_count = ProcessTargetString(
			sTarget,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED | COMMAND_FILTER_NO_BOTS,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	for (int i = 0; i < target_count; i++)
	{
		char targetname[MAX_NAME_LENGTH];
		GetClientName(target_list[i], targetname, sizeof(targetname));
		TradeChatGag[target_list[i]] = true;

		CPrintToChatAll("%t", "TradeBan", sChatTag, name, targetname);
		LogToFile(logfile, "%L has disabled trade chat for %L", client, target_list[i]);
	}

	return Plugin_Handled;
}

public Action Command_TradeUnGag(int client, int args)
{
	char sTarget[MAX_NAME_LENGTH];

	if (!GetCmdArg(1, sTarget, sizeof(sTarget)))
	{
		ReplyToCommand(client, "%t", "TradeGagUsage");
		return Plugin_Handled;
	}

	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	char target_name[MAX_TARGET_LENGTH];

	if ((target_count = ProcessTargetString(
			sTarget,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED | COMMAND_FILTER_NO_BOTS,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	for (int i = 0; i < target_count; i++)
	{
		char targetname[MAX_NAME_LENGTH];
		GetClientName(target_list[i], targetname, sizeof(targetname));
		TradeChatGag[target_list[i]] = false;
		LastMessageTime[target_list[i]] = 0;
		SpamCount[target_list[i]] = 0;

		CPrintToChatAll("%t", "TradeUnBan", sChatTag, name, targetname);
		LogToFile(logfile, "%L has enabled trade chat for %L", client, target_list[i]);
	}

	return Plugin_Handled;
}

public Action Command_ToggleChat(int client, int args)
{
	if (!HideTradeChat[client])
	{
		HideTradeChat[client] = true;
		CPrintToChat(client, "%t", "HideChatOn", sChatTag);
	}
	else
	{
		HideTradeChat[client] = false;
		CPrintToChat(client, "%t", "HideChatOff", sChatTag);
	}
	return Plugin_Handled;
}

public void OnAntiSpamDelayChange(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	iAntiSpamDelay = StringToInt(newVal);
}

public void OnAntiSpamMaxCountChange(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	iAntiSpamMaxCount = StringToInt(newVal);
}

public void OnChatTriggersChange(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	char buffer[512];
	GetConVarString(hChatTriggers, buffer, sizeof(buffer));
	triggersAmount = ExplodeString(buffer, ", ", sChatTriggers, sizeof(sChatTriggers), sizeof(sChatTriggers[]), false);
}

public void OnChatTagChange(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	GetConVarString(hChatTag, sChatTag, sizeof(sChatTag));
}
