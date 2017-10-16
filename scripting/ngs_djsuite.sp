#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <colorvariables>
// #include <morecolors>

#undef REQUIRE_PLUGIN
#include <basecomm>
#include <sourcecomms>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION "1.0.0"

public Plugin myinfo = {
	name = "[NGS] RDJ Suite",
	author = "Luki / TheXeon",
	description = "Adds a special chat and features for DJ's!",
	version = PLUGIN_VERSION,
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
	
	CreateConVar("sm_rdjsuite_version", PLUGIN_VERSION, "DJSuite version number.", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
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
			if (IsValidClient(i)) SendConVarValue(i, sv_allow_voice_from_file, cvarValue);
	}
	else
	{
		for (int i = 1; i <= MaxClients; i++)
			if (IsValidClient(i))
				if (!CheckCommandAccess(i, "sm_djsuite_allowaudio_override", ADMFLAG_ROOT))
					SendConVarValue(i, sv_allow_voice_from_file, "0");
				else
					SendConVarValue(i, sv_allow_voice_from_file, "1");
	}
}

public void OnLibraryAdded(const char[] name) 
{ 
	if (StrEqual(name, "basecomm", false)) 
		basecommExists = true;
	else if (StrEqual(name, "sourcecomms", false))
		sourcecommsExists = true;
}

public void OnLibraryRemoved(const char[] name)
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
		SendConVarValue(client, sv_allow_voice_from_file, "0");
	else
		SendConVarValue(client, sv_allow_voice_from_file, "1");
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
	
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i))
			if (CheckCommandAccess(i, "sm_djsuite_allowaudio_override", ADMFLAG_ROOT))
				if (isRequest) CPrintToChat(i, "{PURPLE}[RDJC]{DEFAULT} {RED}*REQUEST*{DEFAULT} {CYAN}%s{DEFAULT}: {PINK}%s", name, msg);
				else CPrintToChat(i, "{PURPLE}[RDJC]{DEFAULT} {CYAN}%s{DEFAULT}: {PINK}%s", name, msg);
	
	LogToFile(logfile, "%L says \"%s\"", client, msg);
}

public bool IsValidClient (int client)
{
	if(client > 4096) client = EntRefToEntIndex(client);
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsFakeClient(client)) return false;
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}