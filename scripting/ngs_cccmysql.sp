/**
* TheXeon
* ngs_cccmysql.sp
*
* Files:
* addons/sourcemod/plugins/ngs_cccmysql.smx
*
* Dependencies:
* sourcemod.inc, ccc.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <sourcemod>
#include <ccc>
#include <ngsutils>
#include <ngsupdater>

public Plugin myinfo = {
	name        = "[Source 2009] Custom Chat Colors MySQL Module",
	author      = "Dr. McKay / TheXeon",
	description = "Allows for Custom Chat Colors to be configured via MySQL",
	version     = "1.2.0",
	url         = "http://www.doctormckay.com"
}

KeyValues kv;

public void OnPluginStart()
{
	RegAdminCmd("sm_ccc_mysql_dump", Command_DumpData, ADMFLAG_ROOT, "DEBUG: Dumps cached data");
	CCC_OnConfigReloaded();
}

public void CCC_OnConfigReloaded()
{
	if(SQL_CheckConfig("custom-chatcolors"))
	{
		Database.Connect(OnDatabaseConnected, "custom-chatcolors");
	}
	else if(SQL_CheckConfig("default"))
	{
		Database.Connect(OnDatabaseConnected, "default");
	}
	else
	{
		SetFailState("No database configuration \"custom-chatcolors\" or \"default\" found.");
	}
}

public void OnDatabaseConnected(Database db, const char[] error, any data) {
	if(db == null)
	{
		if(kv == null)
		{
			SetFailState("Unable to connect to database. %s", error);
		}
		else
		{
			LogError("Unable to connect to database. Falling back to saved values. %s", error);
			return;
		}
	}
	if(kv == null)
	{
		db.Query(OnTableCreated, "CREATE TABLE IF NOT EXISTS `custom_chatcolors` (`index` int(11) NOT NULL, `identity` varchar(32) NOT NULL, `override` varchar(32) DEFAULT NULL, `flag` char(1) DEFAULT NULL, `tag` varchar(32) DEFAULT NULL, `tagcolor` varchar(8) DEFAULT NULL, `namecolor` varchar(8) DEFAULT NULL, `textcolor` varchar(8) DEFAULT NULL, PRIMARY KEY (`index`), UNIQUE KEY `identity` (`identity`)) ENGINE=MyISAM DEFAULT CHARSET=latin1");
	}
	else
	{
		db.Query(OnDataReceived, "SELECT * FROM `custom_chatcolors` ORDER BY `index` ASC");
	}
}

public void OnTableCreated(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		if (db != null) delete db;
		SetFailState("Error creating database table. %s", error);
	}
	db.Query(OnDataReceived, "SELECT * FROM `custom_chatcolors` ORDER BY `index` ASC");
}

public void OnDataReceived(Database db, DBResultSet results, const char[] error, any data) {
	if(results == null) {
		delete db;
		if(kv == null) {
			SetFailState("Unable to query database. %s", error);
		} else {
			LogError("Unable to query database. Falling back to saved values. %s", error);
			return;
		}
	}
	delete kv;
	kv = new KeyValues("admin_colors");
	char identity[33], override[33], flag[2], tag[33], tagcolor[12], namecolor[12], textcolor[12];
	while(results.FetchRow()) {
		// index	identity	override	flag	tag		tagcolor	namecolor	textcolor
		// 0		1			2			3		4		5			6			7
		results.FetchString(1, identity, sizeof(identity));
		results.FetchString(2, override, sizeof(override));
		results.FetchString(3, flag, sizeof(flag));
		results.FetchString(4, tag, sizeof(tag));
		results.FetchString(5, tagcolor, sizeof(tagcolor));
		results.FetchString(6, namecolor, sizeof(namecolor));
		results.FetchString(7, textcolor, sizeof(textcolor));
		kv.JumpToKey(identity, true);
		if(StrContains(identity, "STEAM_") != 0 && StrContains(identity, "[U:1:") != 0) {
			if (strlen(override) > 0)
				kv.SetString("override", override);
			if (strlen(flag) > 0)
				kv.SetString("flag", flag);
		}
		if(strlen(tag) > 0) {
			kv.SetString("tag", tag);
		}
		if(strlen(tagcolor) == 6 || strlen(tagcolor) == 8 || StrEqual(tagcolor, "O", false) || StrEqual(tagcolor, "G", false) || StrEqual(tagcolor, "T", false)) {
			if(strlen(tagcolor) > 1) {
				Format(tagcolor, sizeof(tagcolor), "#%s", tagcolor);
			}
			kv.SetString("tagcolor", tagcolor);
		}
		if(strlen(namecolor) == 6 || strlen(namecolor) == 8 || StrEqual(namecolor, "O", false) || StrEqual(namecolor, "G", false) || StrEqual(namecolor, "T", false)) {
			if(strlen(namecolor) > 1) {
				Format(namecolor, sizeof(namecolor), "#%s", namecolor);
			}
			kv.SetString("namecolor", namecolor);
		}
		if(strlen(textcolor) == 6 || strlen(textcolor) == 8 || StrEqual(textcolor, "O", false) || StrEqual(textcolor, "G", false) || StrEqual(textcolor, "T", false)) {
			if(strlen(textcolor) > 1) {
				Format(textcolor, sizeof(textcolor), "#%s", textcolor);
			}
			kv.SetString("textcolor", textcolor);
		}
		kv.Rewind();
	}
	delete db; // Close database connection
}

public Action Command_DumpData(int client, int args) {
	if(kv == null) {
		ReplyToCommand(client, "\x04[CCC] \x01No data is currently loaded.");
		return Plugin_Handled;
	}
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "data/custom-chatcolors-mysql-dump.txt");
	kv.ExportToFile(path);
	ReplyToCommand(client, "\x04[CCC] \x01Loaded data has been dumped to %s", path);
	return Plugin_Handled;
}

public void CCC_OnUserConfigLoaded(int client) {
	if(kv == null) {
		// Database not ready yet, let's wait till it is
		CreateTimer(5.0, Timer_CheckDatabase, GetClientUserId(client), TIMER_REPEAT);
		return;
	}
	char auth[32];
	if (!GetClientAuthId(client, AuthId_Engine, auth, sizeof(auth)))
	{
		LogError("Couldn\'t get %N\'s steamID!, returned %s", auth);
		return;
	}
	kv.Rewind();
	if(!kv.JumpToKey(auth)) {
		kv.Rewind();
		kv.GotoFirstSubKey();
		AdminId admin = GetUserAdmin(client);
		AdminFlag flag;
		char configFlag[2];
		char section[32];
		char override[32];
		bool found = false;
		do {
			kv.GetSectionName(section, sizeof(section));
			kv.GetString("flag", configFlag, sizeof(configFlag));
			kv.GetString("override", override, sizeof(override));
			if(StrEqual(configFlag, "") && StrEqual(override, "") && StrContains(section, "STEAM_", false) == -1 && StrContains(section, "[U:1:", false) == -1) {
				found = true;
				break;
			}
			if (strlen(override) > 0 && CheckAccess(admin, override, ADMFLAG_ROOT))
			{
				found = true;
				break;
			}
			if(!StrEqual(configFlag, "")) {
				if (!FindFlagByChar(configFlag[0], flag))
				{
					LogError("Invalid flag given for section \"%s\", skipping", section);
					continue;
				}
				if(GetAdminFlag(admin, flag)) {
					found = true;
					break;
				}
			}
		} while(kv.GotoNextKey());
		if(!found) {
			return;
		}
	}
	char clientTag[32];
	char clientTagColor[12];
	char clientNameColor[12];
	char clientChatColor[12];
	kv.GetString("tag", clientTag, sizeof(clientTag));
	kv.GetString("tagcolor", clientTagColor, sizeof(clientTagColor));
	kv.GetString("namecolor", clientNameColor, sizeof(clientNameColor));
	kv.GetString("textcolor", clientChatColor, sizeof(clientChatColor));
	ReplaceString(clientTagColor, sizeof(clientTagColor), "#", "");
	ReplaceString(clientNameColor, sizeof(clientNameColor), "#", "");
	ReplaceString(clientChatColor, sizeof(clientChatColor), "#", "");
	int tagLen = strlen(clientTagColor);
	int nameLen = strlen(clientNameColor);
	int chatLen = strlen(clientChatColor);
	int color;
	if(strlen(clientTag) > 0) {
		CCC_SetTag(client, clientTag);
	}
	if(tagLen == 6 || tagLen == 8 || StrEqual(clientTagColor, "T", false) || StrEqual(clientTagColor, "G", false) || StrEqual(clientTagColor, "O", false)) {
		if(StrEqual(clientTagColor, "T", false)) {
			color = COLOR_TEAM;
		} else if(StrEqual(clientTagColor, "G", false)) {
			color = COLOR_GREEN;
		} else if(StrEqual(clientTagColor, "O", false)) {
			color = COLOR_OLIVE;
		} else {
			color = StringToInt(clientTagColor, 16);
		}
		CCC_SetColor(client, CCC_TagColor, color, tagLen == 8); // tagLen == 8 evaluates to true if alpha is specified
	}
	if(nameLen == 6 || nameLen == 8 || StrEqual(clientNameColor, "G", false) || StrEqual(clientNameColor, "O", false)) {
		if(StrEqual(clientNameColor, "G", false)) {
			color = COLOR_GREEN;
		} else if(StrEqual(clientNameColor, "O", false)) {
			color = COLOR_OLIVE;
		} else {
			color = StringToInt(clientNameColor, 16);
		}
		CCC_SetColor(client, CCC_NameColor, color, nameLen == 8);
	}
	if(chatLen == 6 || chatLen == 8 || StrEqual(clientChatColor, "T", false) || StrEqual(clientChatColor, "G", false) || StrEqual(clientChatColor, "O", false)) {
		if(StrEqual(clientChatColor, "T", false)) {
			color = COLOR_TEAM;
		} else if(StrEqual(clientChatColor, "G", false)) {
			color = COLOR_GREEN;
		} else if(StrEqual(clientChatColor, "O", false)) {
			color = COLOR_OLIVE;
		} else {
			color = StringToInt(clientChatColor, 16);
		}
		CCC_SetColor(client, CCC_ChatColor, color, chatLen == 8);
	}
}

public Action Timer_CheckDatabase(Handle timer, any userid) {
	int client = GetClientOfUserId(userid);
	if(client == 0) {
		return Plugin_Stop;
	}
	if(kv == null) {
		return Plugin_Continue;
	}
	CCC_OnUserConfigLoaded(client);
	return Plugin_Stop;
}
