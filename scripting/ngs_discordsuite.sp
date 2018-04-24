/**
* TheXeon
* ngs_discordsuite.sp
*
* Files:
* addons/sourcemod/plugins/ngs_discordsuite.smx
*
* Dependencies:
* discord.inc, multicolors.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define LIBRARY_ADDED_FUNC OnLibAdded
#define LIBRARY_REMOVED_FUNC OnLibRemoved
#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <discord>
#include <multicolors>
#include <ngsutils>
#include <ngsupdater>

#undef REQUIRE_PLUGIN
#include <basecomm>
#include <sourcecomms>
#define REQUIRE_PLUGIN

#define OUT_MESSAGE "{\"username\":\"{BOTNAME}\",\"content\":\"**{USER}** <{AUTH}>: *{MESSAGE}*\"}"
//#define DEBUG

char g_sServerName[256];

ConVar g_cBotName;
ConVar g_cRemove;
ConVar g_cFeedbackWebhook;

bool basecommExists, sourcecommsExists;

public Plugin myinfo =
{
	name = "[NGS] Discord: Suite (based on calladmin)",
	author = ".#Zipcore / TheXeon",
	description = "Provide a host of commands that link to our discord!",
	version = "1.0.0",
	url = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	g_cBotName = CreateConVar("ngs_discordsuite_botname", "", "Report botname, leave this blank to use the server name.");
	g_cRemove = CreateConVar("ngs_discordsuite_remove", " | NGS Network", "Remove these parts from servername before sending the message.");
	g_cFeedbackWebhook = CreateConVar("ngs_feedback_webhook", "ngs_feedback", "Config key from configs/discord.cfg.");

	FindConVar("hostname").AddChangeHook(OnHostChanged);
	g_cRemove.AddChangeHook(OnHostChanged);

	RegConsoleCmd("sm_suggest", CommandFeedback, "Leave feedback to improve your server!");
	RegConsoleCmd("sm_suggestion", CommandFeedback, "Leave feedback to improve your server!");
	RegConsoleCmd("sm_feedback", CommandFeedback, "Leave feedback to improve your server!");

	AutoExecConfig(true, "ngs_discordsuite");
}

public void OnHostChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	OnConfigsExecuted();
}

public void OnConfigsExecuted()
{
	char sRemove[32][512], removeStrs[512];
	FindConVar("hostname").GetString(g_sServerName, sizeof(g_sServerName));
	g_cRemove.GetString(removeStrs, sizeof(removeStrs));
	int numStrings = ExplodeString(removeStrs, ",", sRemove, sizeof(sRemove), sizeof(sRemove[]));
	for (int i = 0; i < numStrings; i++)
	{
		#if defined DEBUG
		PrintToServer("Removing %s from %s!", sRemove[i], g_sServerName);
		#endif
		ReplaceString(g_sServerName, sizeof(g_sServerName), sRemove[i], "", false);
	}
	Format(g_sServerName, sizeof(g_sServerName), "Feedback from %s", g_sServerName);
	Discord_EscapeString(g_sServerName, sizeof(g_sServerName));
}

public void OnLibAdded(const char[] name)
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

public void OnLibRemoved(const char[] name)
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

public Action CommandFeedback(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;

	if ((basecommExists && BaseComm_IsClientGagged(client)) || (sourcecommsExists && SourceComms_GetClientGagType(client) != bNot))
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Sorry, but you have been muted from sending feedback!");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_feedback [message]");
		return Plugin_Handled;
	}

	char arg[1024], name[128], sBot[512], auth[24], output[1024] = OUT_MESSAGE;

	GetCmdArgString(arg, sizeof(arg));
	TrimString(arg);

	GetClientName(client, name, sizeof(name));

	g_cBotName.GetString(sBot, sizeof(sBot));

	#if defined DEBUG
	PrintToServer("Length of botname string is %d, first character's code is %d!", strlen(sBot), sBot[0]);
	#endif

	ReplaceString(output, sizeof(output), "{BOTNAME}", (!sBot[0]) ? g_sServerName : sBot);

	if (!GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth)))
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Sorry! Your client has not been authenticated!");
		return Plugin_Handled;
	}

	Discord_EscapeString(arg, sizeof(arg));
	Discord_EscapeString(name, sizeof(name));
	ReplaceString(output, sizeof(output), "{USER}", name);
	ReplaceString(output, sizeof(output), "{MESSAGE}", arg);
	ReplaceString(output, sizeof(output), "{AUTH}", auth);
	SendMessage(output, g_cFeedbackWebhook);
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Thank you so much for helping your community! Your feedback has been sent to our Discord (check it out with !discord)!");
	return Plugin_Handled;
}

void SendMessage(char[] sMessage, ConVar cvar)
{
	char sWebhook[32];
	cvar.GetString(sWebhook, sizeof(sWebhook));
	Discord_SendMessage(sWebhook, sMessage);
}
