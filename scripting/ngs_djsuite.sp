#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <morecolors>

#undef REQUIRE_PLUGIN
#include <basecomm>

#define PLUGIN_VERSION "1.0.0"

public Plugin myinfo = {
	name = "[NGS] RDJ Suite",
	author = "Luki / TheXeon",
	description = "Adds a special chat to RDJs",
	version = PLUGIN_VERSION,
	url = "https://matespastdates.servegame.com"
}

bool basecommExists = false;

char logfile[255];

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	RegConsoleCmd("sm_djc", CommandDJChat, "Default prepend tag for RDJC chat.");
	RegConsoleCmd("sm_songrequest", CommandSongRequest, "Request songs if DJs are online!");
	RegConsoleCmd("sm_request", CommandSongRequest, "Request songs if DJs are online!");
	
	CreateConVar("sm_rdjsuite_version", PLUGIN_VERSION, "DJSuite version number.", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	BuildPath(Path_SM, logfile, sizeof(logfile), "logs/djchat.log");
	
	AutoExecConfig(true);
}

public void OnLibraryAdded(const char[] name) { if (StrEqual(name, "basecomm")) basecommExists = true; }

public void OnLibraryRemoved(const char[] name) { if (StrEqual(name, "basecomm")) basecommExists = false; }

public Action CommandDJChat(int client, int args)
{
	if (CheckCommandAccess(client, "sm_djchat_override", ADMFLAG_CUSTOM2) || CheckCommandAccess(client, "sm_djchat_override", ADMFLAG_GENERIC))
	{
		char text[512];
		GetCmdArgString(text, sizeof(text));
		
		DoDJChat(client, text, false);
		return Plugin_Handled;
	}
	
	CPrintToChat(client, "{PURPLE}[RDJC]{DEFAULT} Sorry, but you may not participate in DJ Chat.");
	return Plugin_Handled;
}

public Action CommandSongRequest(int client, int args)
{
	if (args < 1)
	{
		CPrintToChat(client, "{PURPLE}[RDJC]{DEFAULT} Please supply a request.");
		return Plugin_Handled;
	}
	char text[512];
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i))
			if (CheckCommandAccess(i, "sm_djchat_override", ADMFLAG_CUSTOM2))
				GetCmdArgString(text, sizeof(text));
	
	if (StrEqual(text, NULL_STRING, false))
	{
		CPrintToChat(client, "{PURPLE}[RDJC]{DEFAULT} Sorry, but there are no RDJs on at the moment. Please wait for one to come online.");
		return Plugin_Handled;
	}
	else
	{
		CPrintToChat(client, "{PURPLE}[RDJC]{DEFAULT} Your song has been requested, please be patient and wait for the current RDJ to finish.");
		DoDJChat(client, text, true);
		return Plugin_Handled;
	}
}

public void DoDJChat(int client, char[] msg, bool isRequest)
{
	TrimString(msg);
	if (strlen(msg) == 0) return;
	
	if (basecommExists && BaseComm_IsClientGagged(client))
	{
		CPrintToChat(client, "{PURPLE}[RDJC]{DEFAULT} Sorry, but you have been muted from DJ chat.");
		return;
	}
	
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i))
			if (CheckCommandAccess(i, "sm_djchat_override", ADMFLAG_CUSTOM2) || CheckCommandAccess(i, "sm_djchat_override", ADMFLAG_GENERIC))
				if (isRequest) CPrintToChat(i, "{PURPLE}[RDJC]{DEFAULT} {RED}*REQUEST*{DEFAULT} {CYAN}%s{DEFAULT}: {PINK}%s", name, msg);
				else CPrintToChat(i, "{PURPLE}[RDJC]{DEFAULT} {CYAN}%s{DEFAULT}: {PINK}%s", name, msg);
	
	LogToFile(logfile, "%L says \"%s\"", client, msg);
}