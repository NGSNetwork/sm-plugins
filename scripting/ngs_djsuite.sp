/**
* TheXeon
* ngs_djsuite.sp
*
* Files:
* addons/sourcemod/plugins/ngs_djsuite.smx
* addons/sourcemod/logs/djchat.log
* cfg/sourcemod/plugin.ngs_djsuite.cfg
*
* Dependencies:
* sourcemod.inc, multicolors.inc, ngsutils.inc, ngsupdater.inc, basecomms.inc,
* sourcecomms.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define LIBRARY_ADDED_FUNC OnLibAdded
#define LIBRARY_REMOVED_FUNC OnLibRemoved
#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <sourcemod>
#include <multicolors>
#include <ngsutils>
#include <ngsupdater>

#undef REQUIRE_PLUGIN
#include <basecomm>
#include <sourcecomms>
#define REQUIRE_PLUGIN

public Plugin myinfo = {
	name = "[NGS] RDJ Suite",
	author = "Luki / TheXeon",
	description = "Adds a special chat and features for DJ's!",
	version = "1.0.5",
	url = "https://neogenesisnetwork.net"
}

bool basecommExists, sourcecommsExists;
bool djChatToggledOn[MAXPLAYERS + 1] =  { false, ... };

ConVar cvarDisableDJForNonDJs;
ConVar sv_allow_voice_from_file;

char logfile[255];

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	RegConsoleCmd("sm_djc", CommandDJChat, "Default prepend tag for RDJC chat.");
	RegConsoleCmd("sm_songrequest", CommandSongRequest, "Request songs if DJs are online!");
	RegConsoleCmd("sm_request", CommandSongRequest, "Request songs if DJs are online!");
	RegConsoleCmd("say", CommandSay, "Sends messages through DJ chat if that is toggled on.");
	RegConsoleCmd("say_team", CommandSay, "Sends messages through DJ chat if that is toggled on.");

	cvarDisableDJForNonDJs = CreateConVar("sm_djsuite_nondj_disabled", "1", "Disable the ability for nonDJS to play music.");

	cvarDisableDJForNonDJs.AddChangeHook(OnDJDisableChange);
	sv_allow_voice_from_file = FindConVar("sv_allow_voice_from_file");

	BuildPath(Path_SM, logfile, sizeof(logfile), "logs/djchat.log");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i)) OnClientPostAdminCheck(i);
	}

	AutoExecConfig(true);
}

public void OnDJDisableChange(ConVar convar, char[] oldValue, char[] newValue)
{
	int value = StringToInt(newValue);
	char cvarValue[3];
	sv_allow_voice_from_file.GetString(cvarValue, sizeof(cvarValue));
	if (!value)
	{
		for (int i = 1; i <= MaxClients; i++)
			if (IsValidClient(i)) sv_allow_voice_from_file.ReplicateToClient(i, cvarValue);
	}
	else
	{
		for (int i = 1; i <= MaxClients; i++)
			if (IsValidClient(i))
				if (!CheckCommandAccess(i, "sm_djsuite_allowaudio_override", ADMFLAG_ROOT))
					sv_allow_voice_from_file.ReplicateToClient(i, "0");
				else
					sv_allow_voice_from_file.ReplicateToClient(i, "1");
	}
}

public void OnLibAdded(const char[] name)
{
	if (StrEqual(name, "basecomm", false))
		basecommExists = true;
	else if (StrEqual(name, "sourcecomms", false))
		sourcecommsExists = true;
}

public void OnLibRemoved(const char[] name)
{
	if (StrEqual(name, "basecomm", false))
		basecommExists = false;
	else if (StrEqual(name, "sourcecomms", false))
		sourcecommsExists = false;
}

public Action CommandDJChat(int client, int args)
{
	if (!CheckCommandAccess(client, "sm_djsuite_allowaudio_override", ADMFLAG_CUSTOM2) && !CheckCommandAccess(client, "sm_djsuite_allowaudio_override", ADMFLAG_GENERIC))
	{
		CReplyToCommand(client, "{PURPLE}[RDJC]{DEFAULT} Sorry, but you may not participate in DJ Chat.");
	}

	if (args < 1)
	{
		djChatToggledOn[client] = !djChatToggledOn[client];
		CReplyToCommand(client, "{PURPLE}[RDJC]{DEFAULT} DJ chat has been %s. Toggle it back %s with /djc again.", (djChatToggledOn[client]) ? "enabled" : "disabled", (djChatToggledOn[client]) ? "off" : "on");
	}
	else
	{
		char text[512];
		GetCmdArgString(text, sizeof(text));
		DoDJChat(client, text, false);
	}
	return Plugin_Handled;
}

public Action CommandSongRequest(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{PURPLE}[RDJC]{DEFAULT} Please supply a request.");
		return Plugin_Handled;
	}
	char text[512];

	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i))
			if (CheckCommandAccess(i, "sm_djsuite_allowaudio_override", ADMFLAG_CUSTOM2))
				GetCmdArgString(text, sizeof(text));

	if (StrEqual(text, NULL_STRING, false))
	{
		CPrintToChat(client, "{PURPLE}[RDJC]{DEFAULT} Sorry, but there are no DJs on at the moment. Please wait for one to come online.");
		return Plugin_Handled;
	}
	else
	{
		CPrintToChat(client, "{PURPLE}[RDJC]{DEFAULT} Your song has been requested, please be patient and wait for the current DJ to finish.");
		DoDJChat(client, text, true);
		return Plugin_Handled;
	}
}

public Action CommandSay(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Continue;
	if (djChatToggledOn[client])
	{
		char text[512];
		GetCmdArgString(text, sizeof(text));
		StripQuotes(text);
		if (StrContains(text, "!") == 0 || StrContains(text, "/") == 0 || StrContains(text, "@") == 0) return Plugin_Continue;
		DoDJChat(client, text);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public void OnClientConnected(int client)
{
	djChatToggledOn[client] = false;
}

public void OnClientPostAdminCheck(int client)
{
	if (!cvarDisableDJForNonDJs.BoolValue) return;
	if (!CheckCommandAccess(client, "sm_djsuite_allowaudio_override", ADMFLAG_ROOT, true))
		sv_allow_voice_from_file.ReplicateToClient(client, "0");
	else
		sv_allow_voice_from_file.ReplicateToClient(client, "1");
}

void DoDJChat(int client, char[] msg, bool isRequest=false)
{
	TrimString(msg);
	if (strlen(msg) == 0) return;

	if ((basecommExists && BaseComm_IsClientGagged(client)) || (sourcecommsExists && SourceComms_GetClientGagType(client) != bNot))
	{
		CPrintToChat(client, "{PURPLE}[RDJC]{DEFAULT} Sorry, but you have been muted from DJ chat.");
		return;
	}

	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i))
			if (CheckCommandAccess(i, "sm_djsuite_allowaudio_override", ADMFLAG_ROOT))
				if (isRequest) CPrintToChat(i, "{PURPLE}[RDJC]{DEFAULT} {RED}*REQUEST*{DEFAULT} {CYAN}%N{DEFAULT}: {PINK}%s", client, msg);
				else CPrintToChat(i, "{PURPLE}[RDJC]{DEFAULT} {CYAN}%N{DEFAULT}: {PINK}%s", client, msg);

	LogToFile(logfile, "%L says \"%s\"", client, msg);
}
