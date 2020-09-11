#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1
#define ALL_PLUGINS_LOADED_FUNC AllPluginsLoaded

#include <afk_manager>
#include <calladmin>
#undef REQUIRE_PLUGIN
#include <smac>
#define REQUIRE_PLUGIN
#include <discord>
#include <ngsutils>
#include <ngsupdater>

#define REPORT_MSG "{\"username\":\"{BOTNAME}\",\"content\":\"{MENTION} A new report has come in, handle it with `/calladmin_handle {REPORT_ID}`.\",\"attachments\":[{\"color\":\"{COLOR}\",\"title\":\"{HOSTNAME} (steam://connect/{SERVER_IP}:{SERVER_PORT}){REFER_ID}\",\"fields\":[{\"title\":\"Reason\",\"value\":\"{REASON}\",\"short\":true},{\"title\":\"Reporter\",\"value\":\"{REPORTER_NAME}\",\"short\":true},{\"title\":\"Reporter User ID\",\"value\":\"#{REPORTER_USERID}\",\"short\":true},{\"title\":\"Reporter Steam ID\",\"value\":\"{REPORTER_ID}\",\"short\":true},{\"title\":\"Target\",\"value\":\"{TARGET_NAME}\",\"short\":true},{\"title\":\"Target User ID\",\"value\":\"#{TARGET_USERID}\",\"short\":true},{\"title\":\"Target Steam ID\",\"value\":\"{TARGET_ID}\",\"short\":true},{\"title\":\"Report ID\",\"value\":\"{REPORT_ID}\",\"short\":true},{\"title\":\"Sourcebans Bans\",\"value\":\"{SB_BANS}\"},{\"title\":\"Sourcebans Comms\",\"value\":\"{SB_COMMS}\"},{\"title\":\"Administration Online\",\"value\":\"{ADMINS_ONLINE}\"}]}]}"
#define CLAIM_MSG "{\"username\":\"{BOTNAME}\", \"content\":\"{MSG}\",\"attachments\": [{\"color\": \"{COLOR}\",\"title\": \"{HOSTNAME} (steam://connect/{SERVER_IP}:{SERVER_PORT})\",\"fields\": [{\"title\": \"Admin\",\"value\": \"{ADMIN}\",\"short\": false}]}]}"
#define HANDLED_MSG "{\"username\":\"{BOTNAME}\",\"content\":\"{MSG}\",\"attachments\":[{\"color\":\"{COLOR}\",\"title\":\"{HOSTNAME} (steam://connect/{SERVER_IP}:{SERVER_PORT})\",\"fields\":[{\"title\":\"Admin\",\"value\": \"{ADMIN}\",\"short\":true},{\"title\":\"Report ID\",\"value\":\"{REPORT_ID}\",\"short\":true}]}]}"
#define SMAC_MSG "{\"username\":\"{BOTNAME}\",\"content\":\"{MSG}\",\"attachments\":[{\"color\":\"{COLOR}\",\"title\":\"{HOSTNAME} (steam://connect/{SERVER_IP}:{SERVER_PORT})\",\"fields\":[{\"title\":\"Admin\",\"value\": \"{ADMIN}\",\"short\":true},{\"title\":\"Report ID\",\"value\":\"{REPORT_ID}\",\"short\":true}]}]}"

char sSymbols[25][1] = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"};

char g_sHostPort[6];
char g_sServerName[256];
char g_sHostIP[16];

ConVar g_cBotName = null;
ConVar g_cClaimMsg = null;
ConVar g_cColor = null;
ConVar g_cColor2 = null;
ConVar g_cColor3 = null;
ConVar g_cMention = null;
ConVar g_cRemove = null;
ConVar g_cRemove2 = null;
ConVar g_cWebhook = null;
ConVar g_cSourceBansUrl = null;

public Plugin myinfo =
{
	name = "[NGS] Discord: Admin Connection Module",
	author = ".#Zipcore / TheXeon",
	description = "",
	version = "1.2",
	url = "www.zipcore.net"
}

public void OnPluginStart()
{
	AutoExecConfig_SetCreateDirectory(true);
	AutoExecConfig_SetFile("autorestart");
	AutoExecConfig_SetCreateFile(true);
	bool appended;
	Timber.plantToFile(appended);

	g_cBotName = AutoExecConfig_CreateConVarCheckAppend(appended, "discord_calladmin_botname", "", "Report botname, leave this blank to use the webhook default name.");
	g_cClaimMsg = AutoExecConfig_CreateConVarCheckAppend(appended, "discord_calladmin_claimmsg", "An admin is claiming reports on this server.", "Message to send when admin uses the claim command.");
	g_cColor = AutoExecConfig_CreateConVarCheckAppend(appended, "discord_calladmin_color", "#ff2222", "Discord/Slack attachment color used for reports.");
	g_cColor2 = AutoExecConfig_CreateConVarCheckAppend(appended, "discord_calladmin_color2", "#22ff22", "Discord/Slack attachment color used for admin claims.");
	g_cColor3 = AutoExecConfig_CreateConVarCheckAppend(appended, "discord_calladmin_color3", "#ff9911", "Discord/Slack attachment color used for admin reports.");
	g_cMention = AutoExecConfig_CreateConVarCheckAppend(appended, "discord_calladmin_mention", "@here", "This allows you to mention reports, leave blank to disable.");
	g_cRemove = AutoExecConfig_CreateConVarCheckAppend(appended, "discord_calladmin_remove", " | By PulseServers.com", "Remove this part from servername before sending the report.");
	g_cRemove2 = AutoExecConfig_CreateConVarCheckAppend(appended, "discord_calladmin_remove2", "3kliksphilip.com | ", "Remove this part from servername before sending the report.");
	g_cWebhook = AutoExecConfig_CreateConVarCheckAppend(appended, "discord_calladmin_webhook", "calladmin", "Config key from configs/discord.cfg.");
	g_cSourceBansUrl = AutoExecConfig_CreateConVarCheckAppend(appended, "discord_calladmin_sbpp_url", "https://www.neogenesisnetwork.net/sourcebans/index.php", "Index.php page of sourcebans-pp");
	AutoExecConfig_ExecAndClean(appended);
}

public Action SMAC_OnCheatDetected(int client, const char[] module, DetectionType type, Handle info) {
	char sColor[8];
	if(!CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC, true))
		g_cColor.GetString(sColor, sizeof(sColor));
	else
		g_cColor3.GetString(sColor, sizeof(sColor));

	char sReason[(REASON_MAX_LENGTH + 1) * 2];
	strcopy(sReason, sizeof(sReason), reason);
	Discord_EscapeString(sReason, sizeof(sReason));

	char clientAuth[21], clientUserID[21];
	char clientName[(MAX_NAME_LENGTH + 1) * 2];

	strcopy(clientName, sizeof(clientName), "Server");
	strcopy(clientUserID, sizeof(clientUserID), "CONSOLE");
	strcopy(clientAuth, sizeof(clientAuth), "CONSOLE");

	char targetAuth[21], targetUserID[21];
	char targetName[(MAX_NAME_LENGTH + 1) * 2];

	GetClientAuthId(client, AuthId_Steam2, targetAuth, sizeof(targetAuth));
	IntToString(GetClientUserId(client), targetUserID, sizeof(targetUserID));
	GetClientName(client, targetName, sizeof(targetName));
	Discord_EscapeString(targetName, sizeof(targetName));

	char explodedAdminNames[MAXPLAYERS + 1][MAX_NAME_LENGTH];
	char implodedNames[MAXPLAYERS * MAX_NAME_LENGTH + 1];

	int j = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i, _, _, _, _, true) && CheckCommandAccess(i, "sm_ngsstaff_administra_override", ADMFLAG_GENERIC) && !CheckCommandAccess(i, "sm_ngsstaff_dev_override", ADMFLAG_ROOT))
		{
			GetClientName(i, explodedAdminNames[j], sizeof(explodedAdminNames[]));
			Discord_EscapeString(explodedAdminNames[j], sizeof(explodedAdminNames[]));
			j++;
		}
	}

	if (j == 0)
	{
		explodedAdminNames[0] = "No admins online";
		j++;
	}

	ImplodeStrings(explodedAdminNames, j, ", ", implodedNames, sizeof(implodedNames));
	StrCat(implodedNames, sizeof(implodedNames), ".");

	char sRemove[32];
	g_cRemove.GetString(sRemove, sizeof(sRemove));
	if (!StrEqual(sRemove, ""))
		ReplaceString(g_sServerName, sizeof(g_sServerName), sRemove, "");

	g_cRemove2.GetString(sRemove, sizeof(sRemove));
	if (!StrEqual(sRemove, ""))
		ReplaceString(g_sServerName, sizeof(g_sServerName), sRemove, "");


	Discord_EscapeString(g_sServerName, sizeof(g_sServerName));

	char sMention[512];
	g_cMention.GetString(sMention, sizeof(sMention));

	char sBot[512];
	g_cBotName.GetString(sBot, sizeof(sBot));

	char sourceBansUrl[512];
	g_cSourceBansUrl.GetString(sourceBansUrl, sizeof(sourceBansUrl));
	
	char sBansUrl[1024], sCommsUrl[1024];
	Format(sBansUrl, sizeof(sBansUrl), "%s?p=banlist&advSearch=%s&advType=steamid", sourceBansUrl, targetAuth);
	Format(sCommsUrl, sizeof(sCommsUrl), "%s?p=commslist&advSearch=%s&advType=steamid", sourceBansUrl, targetAuth);

	char sID[16];
	IntToString(CallAdmin_GetReportID(), sID, sizeof(sID));

	char sMSG[4096] = REPORT_MSG;

	ReplaceString(sMSG, sizeof(sMSG), "{BOTNAME}", sBot);
	ReplaceString(sMSG, sizeof(sMSG), "{MENTION}", sMention);

	ReplaceString(sMSG, sizeof(sMSG), "{COLOR}", sColor);

	ReplaceString(sMSG, sizeof(sMSG), "{HOSTNAME}", g_sServerName);
	ReplaceString(sMSG, sizeof(sMSG), "{SERVER_IP}", g_sHostIP);
	ReplaceString(sMSG, sizeof(sMSG), "{SERVER_PORT}", g_sHostPort);
	ReplaceString(sMSG, sizeof(sMSG), "{REPORT_ID}", sID);

	ReplaceString(sMSG, sizeof(sMSG), "{REASON}", sReason);

	ReplaceString(sMSG, sizeof(sMSG), "{REPORTER_NAME}", clientName);
	ReplaceString(sMSG, sizeof(sMSG), "{REPORTER_USERID}", clientUserID);
	ReplaceString(sMSG, sizeof(sMSG), "{REPORTER_ID}", clientAuth);

	ReplaceString(sMSG, sizeof(sMSG), "{TARGET_NAME}", targetName);
	ReplaceString(sMSG, sizeof(sMSG), "{TARGET_USERID}", targetUserID);
	ReplaceString(sMSG, sizeof(sMSG), "{TARGET_ID}", targetAuth);

	ReplaceString(sMSG, sizeof(sMSG), "{SB_BANS}", sBansUrl);
	ReplaceString(sMSG, sizeof(sMSG), "{SB_COMMS}", sCommsUrl);

	ReplaceString(sMSG, sizeof(sMSG), "{ADMINS_ONLINE}", implodedNames);

	char sRefer[16];
	Format(sRefer, sizeof(sRefer), " # %s%s-%d%d", sSymbols[GetRandomInt(0, 25-1)], sSymbols[GetRandomInt(0, 25-1)], GetRandomInt(0, 9), GetRandomInt(0, 9));
	ReplaceString(sMSG, sizeof(sMSG), "{REFER_ID}", sRefer);

	SendMessage(sMSG);
}

public void AllPluginsLoaded()
{
	if (!LibraryExists("calladmin"))
	{
		SetFailState("CallAdmin not found");
		return;
	}

	UpdateIPPort();
	CallAdmin_GetHostName(g_sServerName, sizeof(g_sServerName));
}

void UpdateIPPort()
{
	FindConVar("hostport").GetString(g_sHostPort, sizeof(g_sHostPort));

	if(FindConVar("net_public_adr") != null)
		FindConVar("net_public_adr").GetString(g_sHostIP, sizeof(g_sHostIP));

	int hostiplen = strlen(g_sHostIP);

	if(hostiplen == 0)
	{
		if (FindConVar("ip") != null)
		{
			FindConVar("ip").GetString(g_sHostIP, sizeof(g_sHostIP));
		}
		else if (FindConVar("hostip") != null)
		{
			int ip = FindConVar("hostip").IntValue;
			FormatEx(g_sHostIP, sizeof(g_sHostIP), "%d.%d.%d.%d", (ip >> 24) & 0x000000FF, (ip >> 16) & 0x000000FF, (ip >> 8) & 0x000000FF, ip & 0x000000FF);
		}
	}
}

public void CallAdmin_OnServerDataChanged(ConVar convar, ServerData type, const char[] oldVal, const char[] newVal)
{
	if (type == ServerData_HostName)
		CallAdmin_GetHostName(g_sServerName, sizeof(g_sServerName));
}

public void CallAdmin_OnReportHandled(int client, int id)
{
	char sName[(MAX_NAME_LENGTH + 1) * 2], sID[16];

	if (client == 0)
	{
		strcopy(sName, sizeof(sName), "CONSOLE");
	}
	else
	{
		GetClientName(client, sName, sizeof(sName));
		Discord_EscapeString(sName, sizeof(sName));
	}

	char sRemove[32];
	g_cRemove.GetString(sRemove, sizeof(sRemove));
	if (!StrEqual(sRemove, ""))
		ReplaceString(g_sServerName, sizeof(g_sServerName), sRemove, "");

	g_cRemove2.GetString(sRemove, sizeof(sRemove));
	if (!StrEqual(sRemove, ""))
		ReplaceString(g_sServerName, sizeof(g_sServerName), sRemove, "");

	Discord_EscapeString(g_sServerName, sizeof(g_sServerName));

	char sClaimMsg[512];
	g_cClaimMsg.GetString(sClaimMsg, sizeof(sClaimMsg));

	Discord_EscapeString(sClaimMsg, sizeof(sClaimMsg));

	char sBot[512];
	g_cBotName.GetString(sBot, sizeof(sBot));

	char sColor[8];
	g_cColor2.GetString(sColor, sizeof(sColor));

	IntToString(id, sID, sizeof(sID));

	char sMSG[512] = HANDLED_MSG;

	ReplaceString(sMSG, sizeof(sMSG), "{BOTNAME}", sBot);
	ReplaceString(sMSG, sizeof(sMSG), "{COLOR}", sColor);
	ReplaceString(sMSG, sizeof(sMSG), "{ADMIN}", sName);
	ReplaceString(sMSG, sizeof(sMSG), "{REPORT_ID}", sID);
	ReplaceString(sMSG, sizeof(sMSG), "{MSG}", sClaimMsg);

	ReplaceString(sMSG, sizeof(sMSG), "{HOSTNAME}", g_sServerName);
	ReplaceString(sMSG, sizeof(sMSG), "{SERVER_IP}", g_sHostIP);
	ReplaceString(sMSG, sizeof(sMSG), "{SERVER_PORT}", g_sHostPort);

	SendMessage(sMSG);

	ReplyToCommand(client, "Discord Module: Message sent.");
}

public void CallAdmin_OnReportPost(int client, int target, const char[] reason)
{
	char sColor[8];
	if(!CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC, true))
		g_cColor.GetString(sColor, sizeof(sColor));
	else
		g_cColor3.GetString(sColor, sizeof(sColor));

	char sReason[(REASON_MAX_LENGTH + 1) * 2];
	strcopy(sReason, sizeof(sReason), reason);
	Discord_EscapeString(sReason, sizeof(sReason));

	char clientAuth[21], clientUserID[21];
	char clientName[(MAX_NAME_LENGTH + 1) * 2];

	if (client == REPORTER_CONSOLE)
	{
		strcopy(clientName, sizeof(clientName), "Server");
		strcopy(clientUserID, sizeof(clientUserID), "CONSOLE");
		strcopy(clientAuth, sizeof(clientAuth), "CONSOLE");
	}
	else
	{
		GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth));
		GetClientName(client, clientName, sizeof(clientName));
		IntToString(GetClientUserId(client), clientUserID, sizeof(clientUserID));
		Discord_EscapeString(clientName, sizeof(clientName));
	}

	char targetAuth[21], targetUserID[21];
	char targetName[(MAX_NAME_LENGTH + 1) * 2];

	GetClientAuthId(target, AuthId_Steam2, targetAuth, sizeof(targetAuth));
	IntToString(GetClientUserId(target), targetUserID, sizeof(targetUserID));
	GetClientName(target, targetName, sizeof(targetName));
	Discord_EscapeString(targetName, sizeof(targetName));

	char explodedAdminNames[MAXPLAYERS + 1][MAX_NAME_LENGTH];
	char implodedNames[MAXPLAYERS * MAX_NAME_LENGTH + 1];

	int j = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i, _, _, _, _, true) && CheckCommandAccess(i, "sm_ngsstaff_administra_override", ADMFLAG_GENERIC) && !CheckCommandAccess(i, "sm_ngsstaff_dev_override", ADMFLAG_ROOT))
		{
			GetClientName(i, explodedAdminNames[j], sizeof(explodedAdminNames[]));
			Discord_EscapeString(explodedAdminNames[j], sizeof(explodedAdminNames[]));
			j++;
		}
	}

	if (j == 0)
	{
		explodedAdminNames[0] = "No admins online";
		j++;
	}

	ImplodeStrings(explodedAdminNames, j, ", ", implodedNames, sizeof(implodedNames));
	StrCat(implodedNames, sizeof(implodedNames), ".");

	char sRemove[32];
	g_cRemove.GetString(sRemove, sizeof(sRemove));
	if (!StrEqual(sRemove, ""))
		ReplaceString(g_sServerName, sizeof(g_sServerName), sRemove, "");

	g_cRemove2.GetString(sRemove, sizeof(sRemove));
	if (!StrEqual(sRemove, ""))
		ReplaceString(g_sServerName, sizeof(g_sServerName), sRemove, "");


	Discord_EscapeString(g_sServerName, sizeof(g_sServerName));

	char sMention[512];
	g_cMention.GetString(sMention, sizeof(sMention));

	char sBot[512];
	g_cBotName.GetString(sBot, sizeof(sBot));

	char sourceBansUrl[512];
	g_cSourceBansUrl.GetString(sourceBansUrl, sizeof(sourceBansUrl));
	
	char sBansUrl[1024], sCommsUrl[1024];
	Format(sBansUrl, sizeof(sBansUrl), "%s?p=banlist&advSearch=%s&advType=steamid", sourceBansUrl, targetAuth);
	Format(sCommsUrl, sizeof(sCommsUrl), "%s?p=commslist&advSearch=%s&advType=steamid", sourceBansUrl, targetAuth);

	char sID[16];
	IntToString(CallAdmin_GetReportID(), sID, sizeof(sID));

	char sMSG[4096] = REPORT_MSG;

	ReplaceString(sMSG, sizeof(sMSG), "{BOTNAME}", sBot);
	ReplaceString(sMSG, sizeof(sMSG), "{MENTION}", sMention);

	ReplaceString(sMSG, sizeof(sMSG), "{COLOR}", sColor);

	ReplaceString(sMSG, sizeof(sMSG), "{HOSTNAME}", g_sServerName);
	ReplaceString(sMSG, sizeof(sMSG), "{SERVER_IP}", g_sHostIP);
	ReplaceString(sMSG, sizeof(sMSG), "{SERVER_PORT}", g_sHostPort);
	ReplaceString(sMSG, sizeof(sMSG), "{REPORT_ID}", sID);

	ReplaceString(sMSG, sizeof(sMSG), "{REASON}", sReason);

	ReplaceString(sMSG, sizeof(sMSG), "{REPORTER_NAME}", clientName);
	ReplaceString(sMSG, sizeof(sMSG), "{REPORTER_USERID}", clientUserID);
	ReplaceString(sMSG, sizeof(sMSG), "{REPORTER_ID}", clientAuth);

	ReplaceString(sMSG, sizeof(sMSG), "{TARGET_NAME}", targetName);
	ReplaceString(sMSG, sizeof(sMSG), "{TARGET_USERID}", targetUserID);
	ReplaceString(sMSG, sizeof(sMSG), "{TARGET_ID}", targetAuth);

	ReplaceString(sMSG, sizeof(sMSG), "{SB_BANS}", sBansUrl);
	ReplaceString(sMSG, sizeof(sMSG), "{SB_COMMS}", sCommsUrl);

	ReplaceString(sMSG, sizeof(sMSG), "{ADMINS_ONLINE}", implodedNames);

	char sRefer[16];
	Format(sRefer, sizeof(sRefer), " # %s%s-%d%d", sSymbols[GetRandomInt(0, 25-1)], sSymbols[GetRandomInt(0, 25-1)], GetRandomInt(0, 9), GetRandomInt(0, 9));
	ReplaceString(sMSG, sizeof(sMSG), "{REFER_ID}", sRefer);

	SendMessage(sMSG);
}

void SendMessage(char[] sMessage)
{
	char sWebhook[32];
	g_cWebhook.GetString(sWebhook, sizeof(sWebhook));
	Discord_SendMessage(sWebhook, sMessage);
}
