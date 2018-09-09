/**
* TheXeon
* ngs_freeduels.sp
*
* Files:
* addons/sourcemod/plugins/ngs_freeduels.smx
* addons/sourcemod/translations/free_duels.phrases.txt
* addons/sourcemod/data/sqlite/duel.sq3
* cfg/sourcemod/free_duels.cfg
*
* Dependencies:
* sdkhooks.inc, tf2_stocks.inc, tf2attributes.inc, multicolors.inc,
* free_duels.inc, friendly.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <sdkhooks>
#include <tf2_stocks>
#include <tf2attributes>
#include <multicolors>
#include <free_duels>
#include <friendly>
#include <ngsutils>
#include <ngsupdater>

#define WEBSITE 			"https://www.neogenesisnetwork.net"
#define MAX_LINE_WIDTH 		60

enum DuelData
{
	Challenger,
	bool:Enabled,
	Type,
	Score,
	PlayedTime,
	kills,
	Deads,
	ClassRestrict,
	GodMod,
	bool:HeadShot,
	TimeLeft,
	CSprite,
	SpriteParent,
	bool:HideSprite,
	bool:HealingAllowed
}

int g_Duel[MAXPLAYERS+1][DuelData];

int	victories[MAXPLAYERS+1]			= {0, ...};
int death[MAXPLAYERS+1]				= {0, ...};
int	killsNbr[MAXPLAYERS+1]			= {0, ...};
int dueltotal[MAXPLAYERS+1]				= {0, ...};
float points[MAXPLAYERS+1]		= {0.0, ...};

bool Abandon[MAXPLAYERS+1]		= {false, ...};
bool Equality[MAXPLAYERS+1]		= {false, ...};
bool Winner[MAXPLAYERS+1]		= {false, ...};
bool SQLite 					= false;
bool disableDuel[MAXPLAYERS + 1] =  { false, ... };

ConVar c_EnableType[4];
ConVar cvarEnabled;
ConVar c_Tag;
ConVar c_EnableClass;
ConVar c_EnableGodMod;
ConVar c_EnableHeadShot;
ConVar c_HeadShotFlag;
ConVar c_Immunity;
ConVar c_ClassRestriction;
ConVar c_GodModFlag;

SmartDB db;

char ClientSteamID[MAXPLAYERS+1][24];
char ClientName[MAXPLAYERS+1][MAX_LINE_WIDTH];

static char DuelNames[4][16] 					= {"Disabled", "Normal", "Time left", "Amount of kills"};
static char ClassNames[TFClassType][] 		= {"ANY", "Scout", "Sniper", "Soldier", "Demoman", "Medic", "Heavy", "Pyro", "Spy", "Engineer" };
static char ClassRestricNames[TFClassType][] 	= {"", "scouts", "snipers", "soldiers", "demomen", "medics", "heavies", "pyros", "spies", "engineers" };
static char TF_ClassNames[TFClassType][] 		= {"", "scout", "sniper", "soldier", "demoman", "medic", "heavyweapons", "pyro", "spy", "engineer" };
static TimeLeftOptions[10] 			= {1, 2, 5, 10, 15, 20, 30, 45, 60, 120};
static AmountOfKillOptions[12] 		= {1, 2, 3, 4, 5, 10, 15, 20, 50, 75, 100, 150};

int LimitPerClass[4][10];
int RankTotal;
int Countdown = 600;


public Plugin myinfo = {
    name        = "[NGS] Free duels",
    author      = "Erreur 500 / TheXeon",
    description = "Challenge other players",
    version     = "1.2.4",
    url         = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	cvarEnabled 		= CreateConVar("duel_enabled", 			"1", 	"Enable or disable Free Duels ?", 0, true, 0.0, true, 1.0);
	c_Tag		 		= CreateConVar("duel_tag", 				"1", 	"Add 'duels' tags", 0, true, 0.0, true, 1.0);
	c_Immunity			= CreateConVar("duel_immunity", 		"0", 	"a or b or o or p or q or r or s or t or z for flag needed, 0 = no flag needed");
	c_ClassRestriction	= CreateConVar("duel_classrestrict", 	"0", 	"1 = classrestrict by DJ Tsunami, 2 = Max Class (Class Limit) by Nican , 0 = none");
	c_EnableClass		= CreateConVar("duel_class", 			"1", 	"0 = disable class restriction duel, 1 = enable", 0, true, 0.0, true, 1.0);
	c_EnableType[1]		= CreateConVar("duel_type1", 			"1",	"0 = disable `normal` duel, 1 = enable", 0, true, 0.0, true, 1.0);
	c_EnableType[2]		= CreateConVar("duel_type2", 			"1", 	"0 = disable `time left` duel, 1 = enable", 0, true, 0.0, true, 1.0);
	c_EnableType[3]		= CreateConVar("duel_type3", 			"1",	"0 = disable `amount of kills` duel, 1 = enable", 0, true, 0.0, true, 1.0);
	c_EnableGodMod		= CreateConVar("duel_godmod", 			"1", 	"0 = disable challenger godmod, 1 = enable", 0, true, 0.0, true, 1.0);
	c_GodModFlag		= CreateConVar("duel_godmod_flag", 		"0", 	"Flag needed to create godmod duel : a or b or o or p or q or r or s or t or z, 0 = no flag");
	c_EnableHeadShot	= CreateConVar("duel_headshot", 		"1", 	"0 = disable head shot only (sniper), 1 = enable", 0, true, 0.0, true, 1.0);
	c_HeadShotFlag		= CreateConVar("duel_headshot_flag", 	"a", 	"Flag needed to create head shot duel : a or b or o or p or q or r or s or t or z, 0 = no flag");

	if(cvarEnabled.BoolValue)
	{
		LogMessage("[0/5] Loading : Enabled");
		RegConsoleCmd("sm_duel", loadDuel, "Challenge player");
		RegConsoleCmd("sm_abort", AbortDuel, "Stop duel");
		RegConsoleCmd("sm_myduels", MyDuelStats, "Show your duels stats");
		RegConsoleCmd("sm_topduel", TopDuel, "Show top dueler");
		RegConsoleCmd("sm_noduelme", NoDuelMe, "Disables duel requests.");
		RegConsoleCmd("sm_dontduelme", NoDuelMe, "Disables duel requests.");

		LogMessage("[1/5] Loading : Initialisation");
		Initialisation();
		AutoExecConfig(true, "free_duels");
		Connect();
		TranslationFileExists("free_duels.phrases", true, true);
		LoadTranslations("common.phrases");

		HookEvent("player_spawn", EventPlayerSpawn, EventHookMode_Pre);
		HookEvent("player_death", EventPlayerDeath);
		HookEvent("player_team", EventPlayerTeam, EventHookMode_Pre);
		HookEvent("player_changeclass", EventPlayerchangeclass, EventHookMode_Pre);
		HookEvent("player_builtobject", EventBuiltObject);
		HookEvent("teamplay_round_win", EventRoundEnd, EventHookMode_PostNoCopy);
		HookEvent("teamplay_flag_event", EventFlag);
		HookEvent("controlpoint_starttouch", EventCPStartTouch);
		HookEvent("controlpoint_endtouch", EventCPEndTouch);
		HookEvent("player_sapped_object", EventSapped);
		HookEvent("post_inventory_application", EventPostInventoryApplication);
//		HookEvent("player_upgradedobject", EventUpgradedObject, EventHookMode_Pre);
//		HookEvent("object_deflected", EventAirblast);

		for (int iClient = 1; iClient <= MaxClients; iClient++)
          if (IsValidClient(iClient)) OnClientPutInServer(iClient);

		CreateTimer(1.0, Timer, INVALID_HANDLE, TIMER_REPEAT);
	}
	else
		LogMessage("Loading : Free Duels disabled by CVar");
}

public void OnPluginEnd()
{
	for(int i = 1; i <= MaxClients ; i++)
	{
		if(g_Duel[i][Enabled])
		{
			EndDuel(i, g_Duel[i][Type]);
			g_Duel[i][Enabled] = false;
			g_Duel[g_Duel[i][Challenger]][Enabled] = false;
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("IsPlayerInDuel", Native_IsPlayerInDuel);
	CreateNative("IsDuelRestrictionClass", Native_IsDuelRestrictionClass);
	CreateNative("GetDuelerID", Native_GetDuelerID);

	return APLRes_Success;
}

void Initialisation()
{
	for (int i = 0; i < MAXPLAYERS + 1; i++)
	{
		g_Duel[i][Enabled]		= false;
		g_Duel[i][SpriteParent]	= INVALID_ENT_REFERENCE;
		g_Duel[i][CSprite]		= INVALID_ENT_REFERENCE;
	}
}

public void OnClientConnected(int client)
{
	disableDuel[client] = false;
}

public void OnConfigsExecuted()
{
	LogMessage("[4/5] Loading : Configs Executed");
	if(c_Tag.IntValue)
		TagsCheck("Duels");

	LogMessage("[5/5] Loading : Finished");
}

void TagsCheck(const char[] tag)
{
	ConVar hTags = FindConVar("sv_tags");
	char tags[255];
	hTags.GetString(tags, sizeof(tags));

	if (!(StrContains(tags, tag, false) > -1))
	{
		char newTags[255];
		Format(newTags, sizeof(newTags), "%s,%s", tags, tag);
		hTags.SetString(newTags);
		hTags.GetString(tags, sizeof(tags));
	}
	delete hTags;
}

public void OnMapStart()
{
	AddFileToDownloadsTable("materials/free_duel/RED_Target.vmt");
	AddFileToDownloadsTable("materials/free_duel/RED_Target.vtf");
	AddFileToDownloadsTable("materials/free_duel/BLU_Target.vmt");
	AddFileToDownloadsTable("materials/free_duel/BLU_Target.vtf");

	PrecacheModel("models/player/medic_animations.mdl");
	PrecacheDecal("materials/free_duel/RED_Target.vmt", true);
	PrecacheDecal("materials/free_duel/BLU_Target.vmt", true);
}

void Connect()
{
	if (SQL_CheckConfig("duel"))
	{
		Database.Connect(Connected, "duel");
	}
	else if (SQL_CheckConfig("default"))
	{
		Database.Connect(Connected);
	}
	else
	{
		ConnectToSQLite();
	}
}

public void ConnectToSQLite()
{
	char error[255];
	SQLite = true;

	KeyValues kv = new KeyValues("");
	kv.SetString("driver", "sqlite");
	kv.SetString("database", "duel");
	db = view_as<SmartDB>(SQL_ConnectCustom(kv, error, sizeof(error), false));
	delete kv;

	if (db == null)
		LogMessage("Loading : Failed to connect: %s", error);
	else
	{
		LogMessage("[2/5] Loading : Connected to SQLite Database");
		CreateDbSQLite();
	}
}

public void Connected(Database hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("Failed to connect! Error: %s", error);
		LogMessage("Loading : Failed to connect! Falling back to SQLite!");
		ConnectToSQLite();
		return;
	}

	LogMessage("Loading : Connected to MySQL Database[2/5]");
	hndl.Query(SQLErrorCheckCallback, "SET NAMES 'utf8'");
	db = view_as<SmartDB>(hndl);
	SQL_CreateTables();
}

void SQL_CreateTables()
{
	int len = 0;
	char query[1000];
	len += Format(query[len], sizeof(query)-len, "CREATE TABLE IF NOT EXISTS `Duels_Stats` (");
	len += Format(query[len], sizeof(query)-len, "`Players` VARCHAR(30) NOT NULL,");
	len += Format(query[len], sizeof(query)-len, "`SteamID` VARCHAR(25) NOT NULL,");
	len += Format(query[len], sizeof(query)-len, "`Points` float(16,9) NOT NULL default '0',");
	len += Format(query[len], sizeof(query)-len, "`Victories` int(25) NOT NULL default '0',");
	len += Format(query[len], sizeof(query)-len, "`Duels` int(25) NOT NULL default '0',");
	len += Format(query[len], sizeof(query)-len, "`Kills` int(25) NOT NULL default '0',");
	len += Format(query[len], sizeof(query)-len, "`Deads` int(25) NOT NULL default '0',");
	len += Format(query[len], sizeof(query)-len, "`PlayTime` int(25) NOT NULL default '0',");
	len += Format(query[len], sizeof(query)-len, "`Abandoned` int(25) NOT NULL default '0',");
	len += Format(query[len], sizeof(query)-len, "`Equalities` int(25) NOT NULL default '0',");
	len += Format(query[len], sizeof(query)-len, "`Last_dueler` VARCHAR(30) NOT NULL,");
	len += Format(query[len], sizeof(query)-len, "`Last_dueler_SteamID` VARCHAR(25) NOT NULL,");
	len += Format(query[len], sizeof(query)-len, "`Etat` VARCHAR(25) NOT NULL,");
	len += Format(query[len], sizeof(query)-len, "PRIMARY KEY  (`SteamID`)");
	len += Format(query[len], sizeof(query)-len, ") ENGINE=MyISAM DEFAULT CHARSET=utf8;");
	db.VoidQuery(query);
	LogMessage("[?/5] Loading : Tables Created");
}

void CreateDbSQLite()
{
	int len = 0;
	char query[10000];
	len += Format(query[len], sizeof(query)-len, "CREATE TABLE IF NOT EXISTS `Duels_Stats`");
	len += Format(query[len], sizeof(query)-len, " (`Players` TEXT, `SteamID` TEXT,");
	len += Format(query[len], sizeof(query)-len, "  `Points` REAL DEFAULT 0,`Victories` INTEGER DEFAULT 0, `Duels` INTEGER DEFAULT 0,");
	len += Format(query[len], sizeof(query)-len, " `Kills` INTEGER DEFAULT 0, `Deads` INTEGER DEFAULT 0, `PlayTime` INTEGER DEFAULT 0,");
	len += Format(query[len], sizeof(query)-len, " `Abandoned` INTEGER DEFAULT 0, `Equalities` INTEGER DEFAULT 0,");
	len += Format(query[len], sizeof(query)-len, " `Last_dueler` TEXT, `Last_dueler_SteamID` TEXT, `Etat` TEXT");

	len += Format(query[len], sizeof(query)-len, ");");
	db.VoidQuery(query);
	LogMessage("[?/5] Loading : Tables Created");
}

public void SQLErrorCheckCallback(Database owner, DBResultSet hndl, const char[] error, any data)
{
	if (!StrEqual(error, ""))
	{
		LogError("Loading : SQL Error: %s", error);
		LogMessage("Loading : SQL Error: %s", error);
	}
	delete hndl;
}

public Action NoDuelMe(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	disableDuel[client] = !disableDuel[client];
	CReplyToCommand(client, "{CYAN}[Duel]{DEFAULT} You have %s duel requests.", (disableDuel[client]) ? "disabled" : "enabled");
	return Plugin_Handled;
}

public Action loadDuel(int iClient, int Args)
{
	if (!IsValidClient(iClient))
	{
		return Plugin_Handled;
	}

	if (disableDuel[iClient])
	{
		CReplyToCommand(iClient, "{CYAN}[Duel]{DEFAULT} You cannot send duel requests if you have disabled duel requests.");
		return Plugin_Handled;
	}
	char FlagNeeded[2];
	c_Immunity.GetString(FlagNeeded, sizeof(FlagNeeded));

	if(!isAdmin(iClient, FlagNeeded))
		return Plugin_Handled;

	char Argument1[256];
	GetCmdArgString(Argument1, sizeof(Argument1));

	if(StrEqual ("",Argument1)) 	// No Args
		CallPanel(iClient);
	else
	{
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;
		if((target_count = ProcessTargetString(
			Argument1,
			iClient,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
			{
				ReplyToTargetError(iClient, target_count);
				CallPanel(iClient);
				return Plugin_Handled;
			}

		for (int i = 0; i < target_count; i++)
		{
			if(isGoodSituation(iClient, target_list[i]))
			{
				if (disableDuel[target_list[i]])
				{
					CReplyToCommand(iClient, "{CYAN}[Duel]{DEFAULT} That person has disabled duel requests!");
					continue;
				}
				if(!g_Duel[iClient][Type])
				{
					LogAction(iClient, target_list[i], "%L challenged %L", iClient, target_list[i]);
					CreateDuel(iClient, target_list[i]);
				}
				else
					CPrintToChat(iClient,"%t", "WaitAnwser");
			}
		}
	}
	return Plugin_Handled;
}

public bool isAdmin(int iClient, char FlagNeeded[2])
{
	if(StrEqual(FlagNeeded, "0"))
		return true;
	else
	{
		int flags = GetUserFlagBits(iClient);
		if(flags == 0)
		{
			//PrintToChatAll("Flag : %s + %s", FlagNeeded[0], FlagNeeded[1]);
			CPrintToChat(iClient,"%t", "NoFlag");
			return false;
		}
		else if((flags & ADMFLAG_ROOT) && StrEqual(FlagNeeded, "z"))
			return true;
		else if((flags & ADMFLAG_RESERVATION) && StrEqual(FlagNeeded, "a"))
			return true;
		else if((flags & ADMFLAG_GENERIC) && StrEqual(FlagNeeded, "b"))
			return true;
		else if((flags & ADMFLAG_CUSTOM1) && StrEqual(FlagNeeded, "o"))
			return true;
		else if((flags & ADMFLAG_CUSTOM2) && StrEqual(FlagNeeded, "p"))
			return true;
		else if((flags & ADMFLAG_CUSTOM3) && StrEqual(FlagNeeded, "q"))
			return true;
		else if((flags & ADMFLAG_CUSTOM4) && StrEqual(FlagNeeded, "r"))
			return true;
		else if((flags & ADMFLAG_CUSTOM5) && StrEqual(FlagNeeded, "s"))
			return true;
		else if((flags & ADMFLAG_CUSTOM6) && StrEqual(FlagNeeded, "t"))
			return true;
		else
		{
			//PrintToChatAll("FlagNO : %s + %s", FlagNeeded[0], FlagNeeded[1]);
			CPrintToChat(iClient,"%t", "NoFlag");
			return false;
		}
	}
}

void RemovePlayerBuilding(int iClient)
{
	int ObjEnt;

	while((ObjEnt = FindEntityByClassname(ObjEnt, "obj_sentrygun")) != -1)
	{
		if(GetEntPropEnt(ObjEnt, Prop_Send, "m_hBuilder") == iClient)
		{
			SetVariantInt(1000);
			AcceptEntityInput(ObjEnt, "RemoveHealth");
		}
	}

	while((ObjEnt = FindEntityByClassname(ObjEnt, "obj_dispenser")) != -1)
	{
		if(GetEntPropEnt(ObjEnt, Prop_Send, "m_hBuilder") == iClient)
		{
			SetVariantInt(1000);
			AcceptEntityInput(ObjEnt, "RemoveHealth");
		}
	}

	while((ObjEnt = FindEntityByClassname(ObjEnt, "obj_teleporter")) != -1)
	{
		if(GetEntPropEnt(ObjEnt, Prop_Send, "m_hBuilder") == iClient)
		{
			SetVariantInt(1000);
			AcceptEntityInput(ObjEnt, "RemoveHealth");
		}
	}
}


//------------------------------------------------------------------------------------------------------------------------
//							Event Zone
//------------------------------------------------------------------------------------------------------------------------


public Action EventPlayerSpawn(Event hEvent, const char[] strName, bool bHidden)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if(g_Duel[iClient][Enabled] && g_Duel[iClient][ClassRestrict] != 0 && TF2_GetPlayerClass(iClient) != view_as<TFClassType>(g_Duel[iClient][ClassRestrict]))
	{
		TF2_SetPlayerClass(iClient, view_as<TFClassType>(g_Duel[iClient][ClassRestrict]), false);
		TF2_RespawnPlayer(iClient);
		CPrintToChat(iClient, "%t", "ChangeClass");
		CPrintToChat(iClient, "%t", "Abort");
	}

	if(g_Duel[iClient][Enabled] && g_Duel[iClient][GodMod] == 1)
	{
		SetGodModColor(iClient);
		SetEntProp(iClient, Prop_Send, "m_CollisionGroup", FindConVar("sm_friendly_noblock").IntValue);
	}
	else if (!g_Duel[iClient][GodMod] && !TF2Friendly_IsFriendly(iClient))
		SetEntProp(iClient, Prop_Send, "m_CollisionGroup", 5);
}

public void EventPlayerDeath(Event hEvent, const char[] strName, bool bHidden)
{

	int iClient 	= GetClientOfUserId(hEvent.GetInt("userid"));
	int iKiller 	= GetClientOfUserId(hEvent.GetInt("attacker"));
	int iAssister 	= GetClientOfUserId(hEvent.GetInt("assister"));

	if(hEvent.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)
        return;

	if(c_EnableHeadShot.BoolValue && g_Duel[iClient][HeadShot])
	{
		if(hEvent.GetInt("customkill") != 1)
		{
			return;
		}
	}

	if (g_Duel[iKiller][Challenger] == iClient && g_Duel[iKiller][Enabled])
	{
		g_Duel[iKiller][kills] += 1;
		g_Duel[iClient][Deads] += 1;

		if(g_Duel[iKiller][Enabled] &&  g_Duel[iKiller][Type] != 3 )
		{
			g_Duel[iKiller][Score] += 1;
			CPrintToChat(iKiller, "%t", "Score", iKiller, g_Duel[iKiller][Score], iClient, g_Duel[iClient][Score]);
			CPrintToChat(iClient, "%t", "Score", iClient, g_Duel[iClient], iKiller, g_Duel[iKiller][Score]);
		}
		else if(g_Duel[iKiller][Enabled] &&  g_Duel[iKiller][Type] == 3)
		{
			g_Duel[iKiller][Score] -= 1;
			CPrintToChat(iKiller, "%t", "Score", iKiller, g_Duel[iKiller][Score], iClient, g_Duel[iClient][Score]);
			CPrintToChat(iClient, "%t", "Score", iClient, g_Duel[iClient][Score], iKiller, g_Duel[iKiller][Score]);

			if(g_Duel[iKiller][Score] == 0) EndDuel(iKiller, g_Duel[iKiller][Type]);
		}
	}
	else if(g_Duel[iAssister][Challenger] == iClient && g_Duel[iAssister][Enabled])
	{
		g_Duel[iAssister][kills] += 1;
		g_Duel[iClient][Deads] += 1;
		if(g_Duel[iAssister][Enabled] &&  g_Duel[iAssister][Type] != 3 )
		{
			g_Duel[iAssister][Score] += 1;
			CPrintToChat(iAssister, "%t", "Score", iAssister, g_Duel[iAssister][Score], iClient, g_Duel[iClient][Score]);
			CPrintToChat(iClient, "%t", "Score", iClient, g_Duel[iClient][Score], iAssister, g_Duel[iAssister][Score]);
		}
		else if(g_Duel[iAssister][Enabled] &&  g_Duel[iAssister][Type] == 3)
		{
			g_Duel[iAssister][Score] -= 1;
			CPrintToChat(iAssister, "%t", "Score", iAssister, g_Duel[iAssister][Score], iClient, g_Duel[iClient][Score]);
			CPrintToChat(iClient, "%t", "Score", iClient, g_Duel[iClient][Score], iAssister, g_Duel[iAssister][Score]);

			if(g_Duel[iAssister][Score] == 0) EndDuel(iAssister, g_Duel[iAssister][Type]);
		}
	}
}

public Action EventPlayerTeam(Event hEvent, const char[] strName, bool bHidden)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));

	if(g_Duel[iClient][Enabled])
	{
		CPrintToChatAll("%t", "Victory", g_Duel[iClient][Challenger], iClient, "(Player changed team)");

		Abandon[g_Duel[iClient][Challenger]] 	= false;
		Abandon[iClient]						= true;
		Winner[g_Duel[iClient][Challenger]] 	= true;
		Winner[iClient] 						= false;

		if(g_Duel[iClient][Challenger] !=0)
			ClientCommand(g_Duel[iClient][Challenger], "playgamesound ui/duel_event.wav");

		if(iClient != 0)
			ClientCommand(iClient, "playgamesound ui/duel_event.wav");

		InitializeClientonDB(g_Duel[iClient][Challenger]);
		InitializeClientonDB(iClient);
	}
}

public void EventPlayerchangeclass(Event event, const char[] name, bool bHidden)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if(g_Duel[iClient][Enabled] && g_Duel[iClient][ClassRestrict] != 0 && TF2_GetPlayerClass(iClient) != view_as<TFClassType>(g_Duel[iClient][ClassRestrict]))
	{
		TF2_SetPlayerClass(iClient, view_as<TFClassType>(g_Duel[iClient][ClassRestrict]), false);
		TF2_RespawnPlayer(iClient);
		CPrintToChat(iClient, "%t", "ChangeClass");
		CPrintToChat(iClient, "%t", "Abort");
	}
}

public void EventRoundEnd(Event event, const char[] name, bool bHidden)
{
	for (int i = 1; i <= MaxClients ; i++)
	{
		if(g_Duel[i][Enabled])
		{
			EndDuel(i, g_Duel[i][Type]);
			g_Duel[i][Enabled] = false;
			g_Duel[g_Duel[i][Challenger]][Enabled] = false;
		}
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!IsValidClient(victim) || !IsValidClient(attacker)) return Plugin_Continue;
	if(c_EnableGodMod.BoolValue)
	{
		// int damageAmount = event.GetInt("damageamount");

		if(((g_Duel[victim][Challenger] != attacker) || (g_Duel[attacker][Challenger] != victim)) &&
			(victim != attacker) && ((g_Duel[victim][Enabled] && g_Duel[victim][GodMod] == 1 ) ||
			(g_Duel[attacker][Enabled] && g_Duel[attacker][GodMod] == 1)))
		{
			damage = 0.0;
			return Plugin_Changed;
			// SetEntityHealth(client, GetClientHealth(client) + damageAmount);
		}
	}
	return Plugin_Continue;
}

public void EventCPStartTouch(Event hEvent, const char[] strName, bool bHidden)
{
	int iClient = hEvent.GetInt("player");
	if(g_Duel[iClient][Enabled] && g_Duel[iClient][GodMod] == 1)
	{
		g_Duel[iClient][GodMod] = 2;	// It's not because you are on GodMod you can take CP!
		SetEntityRenderColor(iClient, 255, 255, 255, 255);
	}
}

public void EventCPEndTouch(Event hEvent, const char[] strName, bool bHidden)
{
	int iClient = hEvent.GetInt("player");
	if(!IsValidClient(iClient)) return;

	if(g_Duel[iClient][Enabled] && g_Duel[iClient][GodMod] == 2)
	{
		g_Duel[iClient][GodMod] = 1;	// You're a good guy!
		SetGodModColor(iClient);
	}
}

public void EventPostInventoryApplication(Event event, const char[] name, bool bHidden)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client))
	{
		if (g_Duel[client][Enabled] && !g_Duel[client][HealingAllowed])
		{
			TF2Attrib_SetByName(client, "health from healers reduced", 0.0);
		}
	}
}

public void EventFlag(Event hEvent, const char[] strName, bool bHidden)
{
	int iClient = hEvent.GetInt("player");
	int EventType = hEvent.GetInt("eventtype");

	if(!IsValidClient(iClient)) return;

	if(g_Duel[iClient][Enabled] && g_Duel[iClient][GodMod] == 1 && (EventType == 1 || EventType == 3) )
	{
		g_Duel[iClient][GodMod] = 2;	// It's not because you are on GodMod you can take Flag!
		SetEntityRenderColor(iClient, 255, 255, 255, 255);
	}
	else if(g_Duel[iClient][Enabled] && g_Duel[iClient][GodMod] == 2 && (EventType == 2 || EventType == 4) )
	{
		g_Duel[iClient][GodMod] = 1;	// You're a good guy!
		SetGodModColor(iClient);
	}
}

public void EventBuiltObject(Event hEvent, const char[] strName, bool bHidden)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	int ObjEnt = hEvent.GetInt("index");

	if(!IsValidClient(iClient)) return;

	SDKHook(ObjEnt, SDKHook_OnTakeDamage, BuildingTakeDamage);

	if(!g_Duel[iClient][Enabled]) return;
	if(!g_Duel[iClient][GodMod]) return;

	CPrintToChat(iClient, "%t", "Don'tBuilt");
	SetVariantInt(1000);
	AcceptEntityInput(ObjEnt, "RemoveHealth");
}

// Next few methods from ddhoward's friendly. He is a god.
public Action BuildingTakeDamage(int building, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	int engie = GetEntPropEnt(building, Prop_Send, "m_hBuilder");
	char classname[64];
	if (!GetEntityClassname(building, classname, sizeof(classname)))
	{
		return Plugin_Continue;
	}
	if (!IsValidClient(attacker) || !IsValidClient(engie)) {
		return Plugin_Continue;
	}

	if (g_Duel[attacker][Enabled] && g_Duel[attacker][GodMod] == 1 && g_Duel[attacker][Challenger] != engie)
	{
		damage = 0.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public void EventSapped(Event event, const char[] name, bool dontBroadcast)
{
	int spy = GetClientOfUserId(event.GetInt("userid"));
	int sapper = event.GetInt("sapperid");
	int engie = GetClientOfUserId(event.GetInt("ownerid"));
	if (g_Duel[spy][Enabled] && g_Duel[spy][GodMod] == 1)
	{
		if (g_Duel[spy][Challenger] != engie)
		{
			AcceptEntityInput(sapper, "Kill");
		}
		else
		{
			SDKHook(sapper, SDKHook_OnTakeDamage, SapperTakeDamage);
		}
	}
}

public Action SapperTakeDamage(int sapper, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	int building = GetEntPropEnt(sapper, Prop_Send, "m_hBuiltOnEntity");
	int engie = GetEntPropEnt(building, Prop_Send, "m_hBuilder");
	if (!IsValidClient(attacker))
	{
		return Plugin_Continue;
	}

	if (g_Duel[engie][Enabled] && g_Duel[engie][GodMod] == 1 && g_Duel[engie][Challenger] != attacker) // I dont know how it could be true
	{
		damage = 0.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public void OnGameFrame()
{
	float vecOrigin[3];

	for(int iClient = 1; iClient <= MaxClients; iClient++ )
		if(IsValidClient(iClient) && g_Duel[iClient][Enabled])
		{
			if(TF2_IsPlayerInCondition(iClient, TFCond_Cloaked)) // prevents showing during spells or plugin stuffs
			{
				if(!g_Duel[iClient][HideSprite])
					g_Duel[iClient][HideSprite] = true;
			}
			else
			{
				if(g_Duel[iClient][HideSprite])
					g_Duel[iClient][HideSprite] = false;
			}

			GetClientEyePosition( iClient, vecOrigin );
			vecOrigin[2] += 25.0;

			if(EntRefToEntIndex(g_Duel[iClient][SpriteParent]) != INVALID_ENT_REFERENCE)
				TeleportEntity(EntRefToEntIndex(g_Duel[iClient][SpriteParent]), vecOrigin, NULL_VECTOR, NULL_VECTOR);
		}
}


//------------------------------------------------------------------------------------------------------------------------
//							!DUEL Menu
//------------------------------------------------------------------------------------------------------------------------


public void CallPanel(int iClient)
{
	if(!g_Duel[iClient][Enabled])
	{
		if(!g_Duel[iClient][Type])
		{
			int iteam;
			int Player[40];

			if(GetClientTeam(iClient) == 2)	iteam = 3;
			else if(GetClientTeam(iClient) == 3) iteam = 2;

			if(iteam == 2 || iteam == 3)
			{
				int nbr = 0;
				for(int i = 1; i <= MaxClients ; i++)	// Create an array if valid players (players + bots)
				{
					Player[i-1] = 0;
					if(IsValidClient(i) && GetClientTeam(i) == iteam && !g_Duel[i][Enabled] && g_Duel[i][Challenger] == 0)
					{
						Player[nbr] = i;
						nbr++;
					}
				}

				if(nbr >= 1) // Player found, open menu
				{
					char Playername[MAX_LINE_WIDTH];
					char str_PlayerID[8];
					Menu menuPlayer = new Menu(DuelPanel1);
					menuPlayer.SetTitle("Who should be challenged?");

					for(int i = 0; i < nbr; i++)
					{
						GetClientName(Player[i], Playername, sizeof(Playername));
						IntToString(Player[i], str_PlayerID, sizeof(str_PlayerID));
						menuPlayer.AddItem(str_PlayerID, Playername);
					}

					menuPlayer.ExitButton = true;
					menuPlayer.Display(iClient, MENU_TIME_FOREVER);

				}
				else
					CPrintToChat(iClient,"%t", "NoFound");
			}
			else
				CPrintToChat(iClient,"%t", "Spectator");
		}
		else
			CPrintToChat(iClient,"%t", "WaitAnwser");
	}
	else
		CPrintToChat(iClient,"%t", "InDuel");
	return ;
}

public int DuelPanel1(Menu menu, MenuAction action, int iClient, int args)
{
	if (action == MenuAction_End)
		delete menu;
	else if (action == MenuAction_Select)
	{
		char str_PlayerID[8];
		GetMenuItem(menu, args, str_PlayerID, sizeof(str_PlayerID));

		CreateDuel(iClient, StringToInt(str_PlayerID));
	}
}

void CreateDuel(int Player1, int Player2)
{
	if(isGoodSituation(Player1, Player2))
	{
		g_Duel[Player1][Challenger] 	= Player2;

		GetSafeClientData(Player1);
		GetSafeClientData(Player2);

		if(StrEqual(ClientSteamID[Player1], "INVALID"))
		{
			CPrintToChat(Player1, "Your SteamID isn't valid!");
			ResetPlayer(Player1);
			ResetPlayer(Player2);
		}
		else if(StrEqual(ClientSteamID[Player2], "INVALID"))
		{
			CPrintToChat(Player1, "%N's SteamID isn't valid!", Player2);
			ResetPlayer(Player1);
			ResetPlayer(Player2);
		}
		else
		{
			g_Duel[Player1][Type] 		= 1;
			g_Duel[Player1][TimeLeft] 	= 1;
			g_Duel[Player1][Score] 		= 1;
			g_Duel[Player1][HealingAllowed] = true;

			DuelOption(Player1);
		}
	}
}

public void DuelOption(int Player1)
{
	char MenuItem[100];
	Panel menu = new Panel();

	menu.SetTitle("Duel Options:");
	Format(MenuItem, sizeof(MenuItem), "Duel                        [%s]", DuelNames[g_Duel[Player1][Type]]);
	menu.DrawItem(MenuItem);

	if(g_Duel[Player1][Type] == 2)
	{
		Format(MenuItem, sizeof(MenuItem), "Time                        [%i %s]", g_Duel[Player1][TimeLeft], g_Duel[Player1][TimeLeft] >1 ? "mins":"min");
		menu.DrawItem(MenuItem);
	}
	else if(g_Duel[Player1][Type] == 3)
	{
		Format(MenuItem, sizeof(MenuItem), "Amount                   [%i %s]", g_Duel[Player1][Score], g_Duel[Player1][Score] >1 ? "kills":"kill");
		menu.DrawItem(MenuItem);
	}
	else
		menu.DrawText(" ");

	Format(MenuItem, sizeof(MenuItem), "Class restriction                [%s]", ClassNames[g_Duel[Player1][ClassRestrict]]);
	menu.DrawItem(MenuItem);
	Format(MenuItem, sizeof(MenuItem), "Challenger protection       [%s]", g_Duel[Player1][GodMod] ? "ON":"OFF");
	menu.DrawItem(MenuItem);
	Format(MenuItem, sizeof(MenuItem), "Head shot only                  [%s]", g_Duel[Player1][HeadShot] ? "ON":"OFF");
	menu.DrawItem(MenuItem);
	Format(MenuItem, sizeof(MenuItem), "Healing allowed                 [%s]", g_Duel[Player1][HealingAllowed] ? "ON":"OFF");
	menu.DrawItem(MenuItem);
	menu.DrawText(" ");
	menu.DrawItem("Rules");
	menu.DrawItem("Send duel");
	menu.DrawItem("Exit");


	menu.Send(Player1, DuelOptionAnswer, MENU_TIME_FOREVER);
}

public int DuelOptionAnswer(Menu menu, MenuAction action, int Player1, int args)
{
	if (action == MenuAction_Cancel)
	{
		ResetPlayer(g_Duel[Player1][Challenger]);
		ResetPlayer(Player1);
	}
	else if (action == MenuAction_End)
		delete menu;
	else if (action == MenuAction_Select)
	{
		bool AvailableClass[10] = {true,...};

		// IF Class restriction Enable
		if(c_ClassRestriction.IntValue > 0)
		{
			int PlayerPerClass[2][10];
			char CVARClassRed[35];
			char CVARClassBlue[35];

			// Get Plugin restriction limit
			if(c_ClassRestriction.IntValue == 2)		//MaxClass Plugin
			{
				if(!StartReadingFromTable()) //error while reding file
				{
					c_ClassRestriction.IntValue = 0;
					LogMessage("[Duel] Error while reading MaxClass config file. Now duel_classrestrict = 0 ");
				}
			}
			else
			{
				for(int i=1;i<=9;i++)
				{
					if(c_ClassRestriction.IntValue == 1)	//Class Restrict Plugin
					{
						Format(CVARClassRed, sizeof(CVARClassRed), "sm_classrestrict_red_%s", ClassRestricNames[i]);
						Format(CVARClassBlue, sizeof(CVARClassBlue), "sm_classrestrict_blu_%s", ClassRestricNames[i]);
						LimitPerClass[2][i] = FindConVar(CVARClassRed).IntValue;
						LimitPerClass[3][i] = FindConVar(CVARClassBlue).IntValue;
					}
					else 											//Error in Cvar
					{
						LimitPerClass[2][i] = -1;
						LimitPerClass[3][i] = -1;
					}
				}
			}

			// Get current players class
			for(int i=1;i<=9;i++)
			{
				PlayerPerClass[0][i] = 0;
				PlayerPerClass[1][i] = 0;
			}
			for(int i = 1; i <= MaxClients; i++)
				if(IsClientInGame(i))
					PlayerPerClass[GetClientTeam(i)%2][TF2_GetPlayerClass(i)] ++;

			if(IsClientInGame(Player1))
				PlayerPerClass[GetClientTeam(Player1)%2][TF2_GetPlayerClass(Player1)] --;
			if(IsClientInGame(g_Duel[Player1][Challenger]))
				PlayerPerClass[GetClientTeam(g_Duel[Player1][Challenger])%2][TF2_GetPlayerClass(g_Duel[Player1][Challenger])] --;

			// Check Class full and available
			for( int i=1;i<=9;i++)
			{
				if( (LimitPerClass[2][i] < 0 && LimitPerClass[3][i] < 0) || (LimitPerClass[2][i] > PlayerPerClass[0][i] && LimitPerClass[3][i] > PlayerPerClass[1][i]) )
					AvailableClass[i] = true;
				else
					AvailableClass[i] = false;
			}
		}


		// Process the information

		char FlagNeeded1[2];
		char FlagNeeded2[2];
		c_GodModFlag.GetString(FlagNeeded1, sizeof(FlagNeeded1));
		c_HeadShotFlag.GetString(FlagNeeded2, sizeof(FlagNeeded2));



		if(args == 1)		// Duel type
		{
			g_Duel[Player1][Type]++;

			if(g_Duel[Player1][Type] > 3)
				g_Duel[Player1][Type] = 1;
		}
		else if(args == 2 && g_Duel[Player1][Type] == 2)		// Time
		{
			int i;
			while(TimeLeftOptions[i] != g_Duel[Player1][TimeLeft] && i < 10) i++;

			if(i == 9) i = 0;
			else i++;

			g_Duel[Player1][TimeLeft] = TimeLeftOptions[i];
		}
		else if(args == 2 && g_Duel[Player1][Type] == 3)		// Amount
		{
			int i;
			while(AmountOfKillOptions[i] != g_Duel[Player1][Score] && i < 12) i++;

			if(i == 11) i = 0;
			else i++;

			g_Duel[Player1][Score] = AmountOfKillOptions[i];
		}
		else if(args >= 2  && args < 9)
		{
			if(g_Duel[Player1][Type] == 1)
				args++;

			if(args == 3)		// Class Restriction
			{
				if(c_EnableClass.BoolValue)
				{
					do
					{
						if(g_Duel[Player1][ClassRestrict] == 2)	// Only for sniper
							g_Duel[Player1][HeadShot] = false;

						g_Duel[Player1][ClassRestrict] ++;

						if(g_Duel[Player1][ClassRestrict] >= 10)	// Modulo 10 classes
							g_Duel[Player1][ClassRestrict] = 0;

					}
					while(!AvailableClass[g_Duel[Player1][ClassRestrict]]);
				}
				else
					g_Duel[Player1][ClassRestrict] = 0;
			}
			else if(args == 4)		// Challenger protection
			{
				if(c_EnableGodMod.BoolValue && isAdmin(Player1, FlagNeeded1))
				{
					g_Duel[Player1][GodMod] = g_Duel[Player1][GodMod] ? 0 : 1;
					g_Duel[Player1][HealingAllowed] = false;
				}
				else
				{
					g_Duel[Player1][GodMod] = 0;
				}
			}
			else if(args == 5) // Head shot only
			{
				if(c_EnableHeadShot.BoolValue && g_Duel[Player1][ClassRestrict] == 2 && isAdmin(Player1, FlagNeeded2))
					g_Duel[Player1][HeadShot] = g_Duel[Player1][HeadShot] ? false : true;
				else
					g_Duel[Player1][HeadShot] = false;
			}
			else if(args == 6)  // Disallow healing
			{
				g_Duel[Player1][HealingAllowed] = !g_Duel[Player1][HealingAllowed];
			}
			else if(args == 7)	// Click on rules
			{
				ShowMOTDPanel(Player1, "Free-Duels rules", WEBSITE, MOTDPANEL_TYPE_URL );
			}
			else if(args == 8)	// Click on send duel
			{
				if(!isGoodSituation(Player1, g_Duel[Player1][Challenger]))
					return;

				if(IsClientInGame(g_Duel[Player1][Challenger]))
				{
					g_Duel[g_Duel[Player1][Challenger]][Challenger] 	= Player1;
					g_Duel[g_Duel[Player1][Challenger]][Type]			= g_Duel[Player1][Type];
					g_Duel[g_Duel[Player1][Challenger]][Score]			= g_Duel[Player1][Score] = g_Duel[Player1][Type] < 3 ? 0:g_Duel[Player1][Score];
					g_Duel[g_Duel[Player1][Challenger]][ClassRestrict]	= g_Duel[Player1][ClassRestrict];
					g_Duel[g_Duel[Player1][Challenger]][HealingAllowed]	= g_Duel[Player1][HealingAllowed];
					g_Duel[g_Duel[Player1][Challenger]][GodMod]			= g_Duel[Player1][GodMod];
					g_Duel[g_Duel[Player1][Challenger]][HeadShot]		= g_Duel[Player1][HeadShot];
					g_Duel[g_Duel[Player1][Challenger]][TimeLeft]		= g_Duel[Player1][TimeLeft] *= 60;


					if(IsFakeClient(g_Duel[Player1][Challenger])) // Against BOT
						LoadDuel(g_Duel[Player1][Challenger]);
					else
						ChallengerMenu(Player1, g_Duel[Player1][Challenger]); // Against Player
				}
				else
				{
					ResetPlayer(g_Duel[Player1][Challenger]);
					ResetPlayer(Player1);
					CPrintToChat(Player1, "%t", "NotInGame");
				}
				return;
			}
			else if(args == 9)	// Click on exit
			{
				ResetPlayer(g_Duel[Player1][Challenger]);
				ResetPlayer(Player1);
				return;
			}
		}

		if(IsValidClient(Player1))
			DuelOption(Player1);
	}
}

bool StartReadingFromTable()
{
	char file[PLATFORM_MAX_PATH];
	char config[PLATFORM_MAX_PATH];
	char mapname[32];
	int MaxClass[MAXPLAYERS][TFTeam + view_as<TFTeam>(1)][TFClassType + view_as<TFClassType>(1)];

	FindConVar("sm_maxclass_config").GetString(config, sizeof(config));
	BuildPath(Path_SM, file, sizeof(file),"configs/%s", config);

	if (!FileExists(file))
	  BuildPath(Path_SM, file, sizeof(file),"configs/%s", "MaxClass.txt");

	if (!FileExists(file))
		return false;

	KeyValues kv = new KeyValues("MaxClassPlayers");
	kv.ImportFromFile(file);

	//Get in the first sub-key, first look for the map, then look for default
	GetCurrentMap(mapname, sizeof(mapname));
	if (!kv.JumpToKey(mapname))
	{
		// Check for map type!
		SplitString(mapname, "_", mapname, sizeof(mapname));

		if (!kv.JumpToKey(mapname))
		{
			if (!kv.JumpToKey("default"))
			{
				delete kv;
				return false;
			}
		}
	}

	int MaxPlayers[TFClassType + view_as<TFClassType>(1)], breakpoint, iStart, iEnd, i;
	TFTeam a;
	char buffer[64], start[32], end[32];
	int redblue[TFTeam];

	//Reset all numbers to -1
	for (i=0; i<10; i++)
		MaxPlayers[i] = -1;

	for (i=0; i<= MaxClients; i++)
		for (a=TFTeam_Unassigned; a <= TFTeam_Blue; a++)
			MaxClass[i][a] = MaxPlayers;

	if (!kv.GotoFirstSubKey())
	{
		delete kv;
		return false;
	}

	do
	{
		kv.GetSectionName(buffer, sizeof(buffer));

		//Collect all data
		MaxPlayers[TFClass_Scout] =	kv.GetNum(TF_ClassNames[TFClass_Scout], -1);
		MaxPlayers[TFClass_Sniper] =   kv.GetNum(TF_ClassNames[TFClass_Sniper], -1);
		MaxPlayers[TFClass_Soldier] =  kv.GetNum(TF_ClassNames[TFClass_Soldier], -1);
		MaxPlayers[TFClass_DemoMan] =  kv.GetNum(TF_ClassNames[TFClass_DemoMan], -1);
		MaxPlayers[TFClass_Medic] =	kv.GetNum(TF_ClassNames[TFClass_Medic], -1);
		MaxPlayers[TFClass_Heavy] =	kv.GetNum(TF_ClassNames[TFClass_Heavy], -1);
		MaxPlayers[TFClass_Pyro] =	 kv.GetNum(TF_ClassNames[TFClass_Pyro], -1);
		MaxPlayers[TFClass_Spy] =	  kv.GetNum(TF_ClassNames[TFClass_Spy], -1);
		MaxPlayers[TFClass_Engineer] = kv.GetNum(TF_ClassNames[TFClass_Engineer], -1);

		if (MaxPlayers[TFClass_Engineer] == -1)
			MaxPlayers[TFClass_Engineer] = kv.GetNum("engenner", -1);

		redblue[TFTeam_Red] =  kv.GetNum("team2", 1);
		redblue[TFTeam_Blue] =  kv.GetNum("team3", 1);

		if (redblue[TFTeam_Red] == 1)
			redblue[TFTeam_Red] =  kv.GetNum("red", 1);

		if (redblue[TFTeam_Blue] == 1)
			redblue[TFTeam_Blue] =  kv.GetNum("blue", 1);

		if ((redblue[TFTeam_Red] + redblue[TFTeam_Blue]) == 0)
			continue;

		//Just 1 number
		if (StrContains(buffer,"-") == -1)
		{
			iStart = CheckBoundries(StringToInt(buffer));

			for (a=TFTeam_Unassigned; a<= TFTeam_Blue; a++)
			{
				if (redblue[a] == 1)
					MaxClass[iStart][a] = MaxPlayers;
			}
			//A range, like 1-5
		}
		else
		{
			//Break the "1-5" into "1" and "5"
			breakpoint = SplitString(buffer,"-",start,sizeof(buffer));
			strcopy(end,sizeof(end),buffer[breakpoint]);
			TrimString(start);
			TrimString(end);

			//make "1" and "5" into integers
			//Check boundries, see if does not go out of the array limits
			iStart = CheckBoundries(StringToInt(start));
			iEnd = CheckBoundries(StringToInt(end));

			//Copy data to the global array for each one in the range
			for (i= iStart; i<= iEnd;i++)
			{
				for (a=TFTeam_Unassigned; a<= TFTeam_Blue; a++)
				{
					if (redblue[a] == 1)
						MaxClass[i][a] = MaxPlayers;
				}
			}
		}
		for(i = 1; i<10; i++)
		{
			LimitPerClass[2][i] = MaxClass[GetClientCount(true)][2][i];
			LimitPerClass[3][i] = MaxClass[GetClientCount(true)][1][i];
		}
	} while (kv.GotoNextKey());


	delete kv;
	return true;
}

int CheckBoundries(int i)
{
	if (i < 0)
		return 0;
	else if (i > MAXPLAYERS)
		return MAXPLAYERS;
	else
		return i;
}


//------------------------------------------------------------------------------------------------------------------------
//							Challenger Menu Answer
//------------------------------------------------------------------------------------------------------------------------


public void ChallengerMenu(int Player1, int Player2)
{
	if(g_Duel[Player1][Type] == 1)
	{
		ClientCommand(Player1, "playgamesound ui/duel_challenge.wav");
		ClientCommand(g_Duel[Player1][Challenger], "playgamesound ui/duel_challenge.wav");

	}
	else if(g_Duel[Player1][Type] == 2 || g_Duel[Player1][Type] == 3)
	{
		ClientCommand(Player1, "playgamesound ui/duel_challenge_with_restriction.wav");
		ClientCommand(g_Duel[Player1][Challenger], "playgamesound ui/duel_challenge_with_restriction.wav");
	}
	else
	{
		ResetPlayer(Player1);
		ResetPlayer(Player2);
		return;
	}

	for(int i = 1; i<= MaxClients; i++)
		if(IsValidClient(i) && i != g_Duel[Player1][Challenger])
			CPrintToChat(i, "%t", "Challenged", Player1, g_Duel[Player1][Challenger]);

	CPrintToChat(Player2, "%t", "You!", Player1, g_Duel[Player1][Type]);


	char MenuItem[100];
	char MenuTitle[100];
	Panel menu = new Panel();

	Format(MenuTitle, sizeof(MenuTitle), "%N challenged you!", Player1);
	menu.SetTitle(MenuTitle);
	if(g_Duel[Player1][Type] == 1)
		Format(MenuItem, sizeof(MenuItem), "Type: Normal");
	else if(g_Duel[Player1][Type] == 2)
		Format(MenuItem, sizeof(MenuItem), "Type: Time left         [%i %s]", g_Duel[Player1][TimeLeft], g_Duel[Player1][TimeLeft] >1 ? "mins":"min");
	else if(g_Duel[Player1][Type] == 3)
		Format(MenuItem, sizeof(MenuItem), "Type: Amount of kills   [%i %s]", g_Duel[Player1][Score], g_Duel[Player1][Score] >1 ? "kills":"kill");
	menu.DrawText(MenuItem);
	menu.DrawText(" ");
	Format(MenuItem, sizeof(MenuItem), "Class restriction                [%s]", ClassNames[g_Duel[Player1][ClassRestrict]]);
	menu.DrawText(MenuItem);
	Format(MenuItem, sizeof(MenuItem), "Challenger protection       [%s]", g_Duel[Player1][GodMod] ? "ON":"OFF");
	menu.DrawText(MenuItem);
	Format(MenuItem, sizeof(MenuItem), "Head shot only                  [%s]", g_Duel[Player1][HeadShot] ? "ON":"OFF");
	menu.DrawText(MenuItem);
	Format(MenuItem, sizeof(MenuItem), "Healing allowed       [%s]", g_Duel[Player1][HealingAllowed] ? "ON":"OFF");
	menu.DrawText(MenuItem);
	Format(MenuItem, sizeof(MenuItem), "                                ");
	menu.DrawText(MenuItem);

	menu.DrawItem("Yes, I challenge");
	menu.DrawItem("No, I refuse");


	menu.Send(Player2, ChallengerMenuAnswer, 20);
}

public int ChallengerMenuAnswer(Menu menu, MenuAction action, int Player2, int args)
{
	if (action == MenuAction_Cancel)
	{
		CPrintToChatAll("%t", "TooAfraid", Player2, g_Duel[Player2][Challenger]);
		ResetPlayer(g_Duel[Player2][Challenger]);
		ResetPlayer(Player2);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Select)
	{
		if(args == 1)	// ACCEPT THE DUEL
		{
			if(!isGoodSituation(Player2, g_Duel[Player2][Challenger]))
				return;

			LoadDuel(Player2); // Load Duel

		}
		else if(args == 2)	// REFUSE THE DUEL
		{
			int Player1 = g_Duel[Player2][Challenger];
			int D_Type	= g_Duel[Player2][Type];

			ResetPlayer(Player1);
			ResetPlayer(Player2);

			CPrintToChatAll("%t", "Refused", Player2, Player1);

			if(D_Type == 1)
			{
				ClientCommand(Player2, "playgamesound ui/duel_challenge_rejected.wav");
				ClientCommand(Player1, "playgamesound ui/duel_challenge_rejected.wav");
			}
			else if(D_Type == 2 || D_Type == 3)
			{
				ClientCommand(Player2, "playgamesound ui/duel_challenge_rejected_with_restriction.wav");
				ClientCommand(Player1, "playgamesound ui/duel_challenge_rejected_with_restriction.wav");
			}
		}
	}
}


void LoadDuel(int Player2)
{
	if(!isGoodSituation(g_Duel[Player2][Challenger], Player2)) return;

	g_Duel[Player2][Enabled] = true;
	g_Duel[g_Duel[Player2][Challenger]][Enabled] = true;

	if(g_Duel[Player2][ClassRestrict] != 0) // Load Classrestriction
	{
		if(view_as<TFClassType>(g_Duel[Player2][ClassRestrict]) != view_as<TFClassType>(TF2_GetPlayerClass(Player2))) // Player2
		{
			TF2_SetPlayerClass(Player2, view_as<TFClassType>(g_Duel[Player2][ClassRestrict]), false);
			TF2_RespawnPlayer(Player2);
		}

		if(view_as<TFClassType>(g_Duel[Player2][ClassRestrict]) != view_as<TFClassType>(TF2_GetPlayerClass(g_Duel[Player2][Challenger]))) // Player1
		{
			TF2_SetPlayerClass(g_Duel[Player2][Challenger], view_as<TFClassType>(g_Duel[Player2][ClassRestrict]), false);
			TF2_RespawnPlayer(g_Duel[Player2][Challenger]);
		}
	}
	
	if (!g_Duel[Player2][HealingAllowed])
	{
		TF2Attrib_SetByName(Player2, "health from healers reduced", 0.0);
	}

	if(g_Duel[Player2][GodMod])	// Load Godmode
	{
		if(TF2_GetPlayerClass(Player2) == TFClass_Engineer)
			RemovePlayerBuilding(Player2);
		if(TF2_GetPlayerClass(g_Duel[Player2][Challenger]) == TFClass_Engineer)
			RemovePlayerBuilding(g_Duel[Player2][Challenger]);

		SetGodModColor(Player2);
		SetGodModColor(g_Duel[Player2][Challenger]);
		TF2_RespawnPlayer(Player2);
		TF2_RespawnPlayer(g_Duel[Player2][Challenger]);
	}

	CreateChallengerParticle(Player2);
	CreateChallengerParticle(g_Duel[Player2][Challenger]);

	if(g_Duel[Player2][Type] == 1) // Play Sound
	{
		ClientCommand(Player2, "playgamesound ui/duel_challenge_accepted.wav");
		ClientCommand(g_Duel[Player2][Challenger], "playgamesound ui/duel_challenge_accepted.wav");
	}
	else if(g_Duel[Player2][Type] == 2 || g_Duel[Player2][Type] == 3)
	{
		ClientCommand(Player2, "playgamesound ui/duel_challenge_accepted_with_restriction.wav");
		ClientCommand(g_Duel[Player2][Challenger], "playgamesound ui/duel_challenge_accepted_with_restriction.wav");
	}

	CPrintToChatAll("%t", "Accepts", Player2, g_Duel[Player2][Challenger]);
	CPrintToChat(Player2,"%t", "Abort");
	CPrintToChat(g_Duel[Player2][Challenger],"%t", "Abort");
}


//------------------------------------------------------------------------------------------------------------------------
//							Option Functions
//------------------------------------------------------------------------------------------------------------------------


void SetGodModColor(int client)
{
	int userid = GetClientUserId(client);
	if (CommandExists("sm_colorize"))
	{
	    ServerCommand("sm_colorize #%d normal", userid);
	}
	else SetEntityRenderColor(client, 255, 255, 255, 255);

	CreateTimer(0.4, OnSetGodModeColor, userid);
}

public Action OnSetGodModeColor(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsValidClient(client) || !IsPlayerAlive(client) || !g_Duel[client][Enabled]) return Plugin_Stop;
	if (TF2_GetClientTeam(client) == TFTeam_Red)
		SetEntityRenderColor(client, 200, 0, 0, 255);
	else
		SetEntityRenderColor(client, 0, 0, 200, 255);
	return Plugin_Continue;
}


void CreateChallengerParticle(int iClient)
{
	float vOrigin[3];
	GetClientAbsOrigin(iClient, vOrigin);
	vOrigin[2] += 25;

	int parent = CreateEntityByName("prop_dynamic");
	char strParent[64];
	Format(strParent, sizeof(strParent), "prop%i", parent);
	DispatchKeyValue(parent, "targetname", strParent);
	DispatchKeyValue(parent, "renderfx","0");
	DispatchKeyValue(parent, "damagetoenablemotion","0");
	DispatchKeyValue(parent, "forcetoenablemotion","0");
	DispatchKeyValue(parent, "Damagetype","0");
	DispatchKeyValue(parent, "disablereceiveshadows","1");
	DispatchKeyValue(parent, "massScale","0");
	DispatchKeyValue(parent, "nodamageforces","0");
	DispatchKeyValue(parent, "shadowcastdist","0");
	DispatchKeyValue(parent, "disableshadows","1");
	DispatchKeyValue(parent, "spawnflags","1670");
	DispatchKeyValue(parent, "model","models/player/medic_animations.mdl");
	DispatchKeyValue(parent, "PerformanceMode","1");
	DispatchKeyValue(parent, "rendermode","10");
	DispatchKeyValue(parent, "physdamagescale","0");
	DispatchKeyValue(parent, "physicsmode","2");

	DispatchSpawn(parent);
	TeleportEntity(parent, vOrigin, NULL_VECTOR, NULL_VECTOR);

	int ent = CreateEntityByName("env_sprite");
	if(ent)
	{
		char StrEntityName[64];
		Format(StrEntityName, sizeof(StrEntityName), "ent_sprite_oriented_%i", ent);

		if(GetClientTeam(iClient) == 2)
			DispatchKeyValue(ent, "model", "free_duel/RED_Target.vmt");
		else
			DispatchKeyValue(ent, "model", "free_duel/BLU_Target.vmt");
		DispatchKeyValue(ent, "classname", "env_sprite");
		DispatchKeyValue(ent, "spawnflags", "1");
		DispatchKeyValue(ent, "scale", "0.1");
		DispatchKeyValue(ent, "rendermode", "1");
		DispatchKeyValue(ent, "rendercolor", "255 255 255");
		//DispatchKeyValue(ent, "targetname", StrEntityName);
		DispatchKeyValue(ent, "parentname", strParent);

		DispatchSpawn(ent);
		TeleportEntity(ent, vOrigin, NULL_VECTOR, NULL_VECTOR);

		SetVariantString(strParent);
		AcceptEntityInput(ent, "SetParent");

		g_Duel[iClient][CSprite] = EntIndexToEntRef(ent);
		g_Duel[iClient][SpriteParent] = EntIndexToEntRef(parent);
		SDKHook(ent, SDKHook_SetTransmit, Hook_SetTransmit);
	}
}

public Action Hook_SetTransmit(int entity, int iClient)
{
	if(EntRefToEntIndex(g_Duel[iClient][CSprite]) == entity && !g_Duel[iClient][HideSprite])	// Can see
		return Plugin_Continue;

	if(EntRefToEntIndex(g_Duel[g_Duel[iClient][Challenger]][CSprite]) == entity && !g_Duel[g_Duel[iClient][Challenger]][HideSprite]) // Can see
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action Timer(Handle timer)
{
	char FlagNeeded[2];
	c_Immunity.GetString(FlagNeeded, sizeof(FlagNeeded));
	Countdown--;
	for(int t=1; t <= MaxClients; t++)
	{
		if(IsValidClient(t) && g_Duel[t][Enabled])
		{
			HudMessageTime(t);

			g_Duel[t][PlayedTime] += 1;

			if(g_Duel[t][Type] == 2)
			{
				g_Duel[t][TimeLeft] -= 1;
				if(g_Duel[t][TimeLeft] <= 0)
				{
					g_Duel[g_Duel[t][Challenger]][Enabled] = false;
					EndDuel(t, g_Duel[t][Type]);
				}
			}

			if(Countdown <= 0 && isAdmin(t, FlagNeeded))
				CPrintToChat(t, "%t","!myduels");
			else if(Countdown == 450 && isAdmin(t, FlagNeeded))
				CPrintToChat(t, "%t","!topduel");
		}
	}
	if(Countdown <= 0)
		Countdown = 900;
}

void HudMessageTime(int iClient)
{
	SetHudTextParams(0.85, 0.0, 1.0, 39, 148, 0, 255, 1, 0.0, 0.0, 0.0);

	if(g_Duel[iClient][Type] == 1 || g_Duel[iClient][Type] == 3)	ShowHudText(iClient, -1, "You : %i - Him: %i", g_Duel[iClient][Score], g_Duel[g_Duel[iClient][Challenger]][Score]);
	else if(g_Duel[iClient][Type] == 2)	ShowHudText(iClient, -1, "Time left : %i | You : %i - Him: %i", g_Duel[iClient][TimeLeft], g_Duel[iClient][Score], g_Duel[g_Duel[iClient][Challenger]][Score]);
}

public void OnClientDisconnect(int iClient)
{
	if(!IsValidClient(iClient)) return;

	if(g_Duel[iClient][Enabled])
	{
		CPrintToChatAll("%t","Victory", g_Duel[iClient][Challenger], iClient, "(Player disconnected)");

		if(IsValidClient(g_Duel[iClient][Challenger]))
			ClientCommand(g_Duel[iClient][Challenger], "playgamesound ui/duel_event.wav");

		Winner[g_Duel[iClient][Challenger]]		= true;
		Winner[iClient]				= false;
		Abandon[iClient] 			= true;
		Abandon[g_Duel[iClient][Challenger]] 		= false;

		InitializeClientonDB(g_Duel[iClient][Challenger]);
		InitializeClientonDB(iClient);
	}
}

public Action AbortDuel(int iClient, int Args)
{
	if(!IsValidClient(iClient)) return;

	if(g_Duel[iClient][Enabled])
	{
		char reason[64];
		Format(reason, sizeof(reason), "(%N aborted)", iClient);
		CPrintToChatAll("%t","Victory", g_Duel[iClient][Challenger], iClient, reason);

		Winner[g_Duel[iClient][Challenger]]		= true;
		Winner[iClient]				= false;
		Abandon[iClient] 			= true;
		Abandon[g_Duel[iClient][Challenger]] 		= false;

		InitializeClientonDB(g_Duel[iClient][Challenger]);
		InitializeClientonDB(iClient);

		if(g_Duel[iClient][Challenger] != 0)
		{
			ClientCommand(g_Duel[iClient][Challenger], "playgamesound ui/duel_event.wav");
			TF2_RespawnPlayer(g_Duel[iClient][Challenger]);
		}
		if(iClient != 0)
		{
			ClientCommand(iClient, "playgamesound ui/duel_event.wav");
			TF2_RespawnPlayer(iClient);
		}
	}
	else
		CPrintToChat(iClient,"%t", "NotInDuel");
}


//------------------------------------------------------------------------------------------------------------------------
//							Security functions
//------------------------------------------------------------------------------------------------------------------------

public bool isGoodSituation(int iClient, int Player2)
{
	if(!IsValidClient(iClient) || !IsValidClient(Player2))
	{
		ResetPlayer(Player2);
		ResetPlayer(iClient);
		return false;
	}

	if(g_Duel[Player2][Enabled])  		// too late ! iClient Player2 already in duel ...
	{
		CPrintToChat(iClient,"%t", "IsInDuel", Player2);
		ResetPlayer(iClient);
		return false;
	}
	else if(g_Duel[iClient][Enabled])  			// you are already in duel ...
	{
		CPrintToChat(iClient,"%t", "InDuel");
		ResetPlayer(iClient);
		return false;
	}
	else if(GetClientTeam(iClient) != 2 && GetClientTeam(iClient) != 3)
	{
		CPrintToChat(iClient,"%t", "TeamError");
		ResetPlayer(iClient);
		return false;
	}
	else if(GetClientTeam(Player2) != 2 && GetClientTeam(Player2) != 3)
	{
		CPrintToChat(iClient,"%t", "TeamError");
		ResetPlayer(Player2);
		return false;
	}
	else if(GetClientTeam(iClient) == GetClientTeam(Player2))
	{
		CPrintToChat(iClient,"%t", "TeamError");
		ResetPlayer(iClient);
		ResetPlayer(Player2);
		return false;
	}
	else
		return true;
}

void GetSafeClientData(int iClient)
{
	char PlayerInfo[MAX_LINE_WIDTH];

	//Client Name
	GetClientName(iClient, PlayerInfo, sizeof(PlayerInfo));

	ReplaceString(PlayerInfo, sizeof(PlayerInfo), "<?PHP", "", false); // Secure player name for DB;
	ReplaceString(PlayerInfo, sizeof(PlayerInfo), "<?", "");
	ReplaceString(PlayerInfo, sizeof(PlayerInfo), "?>", "");
	ReplaceString(PlayerInfo, sizeof(PlayerInfo), "<", "[");
	ReplaceString(PlayerInfo, sizeof(PlayerInfo), ">", "]");
	ReplaceString(PlayerInfo, sizeof(PlayerInfo), ",", ".");

	db.Escape(PlayerInfo, ClientName[iClient], MAX_LINE_WIDTH);

	//Client SteamID
	if(IsFakeClient(iClient))
		strcopy(PlayerInfo, MAX_LINE_WIDTH, "BOT");
	else
	{
		if (!GetClientAuthId(iClient, AuthId_Steam3, PlayerInfo, sizeof(PlayerInfo)))
		{
			strcopy(PlayerInfo, MAX_LINE_WIDTH, "INVALID");
		}
	}
	strcopy(ClientSteamID[iClient], 24, PlayerInfo);
}


//------------------------------------------------------------------------------------------------------------------------
//							Duel Stats
//------------------------------------------------------------------------------------------------------------------------


public Action MyDuelStats(int iClient, int Args)
{
	if (!IsValidClient(iClient))
	{
		return Plugin_Handled;
	}

	char buffer[255];

	Format(buffer, sizeof(buffer), "SELECT COUNT(*) FROM `Duels_Stats`");
	db.Query(T_Rank1, buffer, GetClientUserId(iClient));
	return Plugin_Handled;
}

public void T_Rank1(Database dummy, DBResultSet hndl, const char[] error, any userid)
{
	if (hndl == null)
		LogError("Query failed! %s", error);
	else
	{
		int iClient = GetClientOfUserId(userid);
		if(!IsValidClient(iClient))	return;
		char buffer[255];

		while (hndl.FetchRow())
		{
			RankTotal = hndl.FetchInt(0);
			Format(buffer, sizeof(buffer), "SELECT `Points`, `Victories`, `Duels`, `Kills`, `Deads` FROM `Duels_Stats` WHERE SteamID = '%s'", ClientSteamID[iClient]);
			db.Query(T_Rank2, buffer, userid);
		}
	}
}

public void T_Rank2(Database dummy, DBResultSet hndl, const char[] error, any userid)
{
	if (hndl == null)
		LogError("Query failed! %s", error);
	else
	{
		int iClient = GetClientOfUserId(userid);
		if (!IsValidClient(iClient)) return;
		char buffer[255];
		while (hndl.FetchRow())
		{
			points[iClient]	 	= hndl.FetchFloat(0);
			victories[iClient]	= hndl.FetchInt(1);
			dueltotal[iClient]		= hndl.FetchInt(2);
			killsNbr[iClient]		= hndl.FetchInt(3);
			death[iClient]		= hndl.FetchInt(4);

			Format(buffer, sizeof(buffer), "SELECT COUNT(*) FROM `Duels_Stats` WHERE `Points` > %i", victories);
			db.Query(T_Rank3, buffer, userid);
		}
	}
}

public void T_Rank3(Database dummy, DBResultSet hndl, const char[] error, any userid)
{
	if (hndl == null)
		LogError("Query failed! %s", error);
	else
	{
		int iClient = GetClientOfUserId(userid);
		if (!IsValidClient(iClient)) return;
		while (hndl.FetchRow())
			RankPanel(iClient, hndl.FetchInt(0));
	}
}

void RankPanel(int iClient, int Rank)
{
	char value[MAX_LINE_WIDTH];
	char ClientID[MAX_LINE_WIDTH];
	Panel rnkpanel = new Panel();

	GetClientName(iClient, ClientID, sizeof(ClientID) );
	rnkpanel.SetTitle("Your duels' stats:");
	Format(value, sizeof(value), "Name: %s", ClientID);
	rnkpanel.DrawText(value);
	Format(value, sizeof(value), "Rank: %i out of %i", Rank , RankTotal);
	rnkpanel.DrawText(value);
	Format(value, sizeof(value), "Points: %f" , points[iClient]);
	rnkpanel.DrawText(value);
	Format(value, sizeof(value), "Victories: %i" , victories[iClient]);
	rnkpanel.DrawText(value);
	Format(value, sizeof(value), "Duels total: %i" , dueltotal[iClient]);
	rnkpanel.DrawText(value);
	Format(value, sizeof(value), "Kills: %i" , killsNbr[iClient]);
	rnkpanel.DrawText(value);
	Format(value, sizeof(value), "Deaths: %i" , death[iClient]);
	rnkpanel.DrawText(value);
	rnkpanel.DrawItem("Close");
	rnkpanel.Send(iClient, RankPanelHandler, 15);
}

public int RankPanelHandler(Menu menu, MenuAction action, int param1, int param2)
{
}

public Action TopDuel(int iClient, int Args)
{
	char buffer[255];
	Format(buffer, sizeof(buffer), "SELECT `Players`, `Points` FROM `Duels_Stats` ORDER BY `Points` DESC LIMIT 0,100");
	db.Query(T_ShowTopDuel, buffer, GetClientUserId(iClient));
	return Plugin_Handled;
}

public void T_ShowTopDuel(Database dummy, DBResultSet hndl, const char[] error, any userid)
{
	if (hndl == null)
		LogError("Query failed! %s", error);
	else
	{
		int iClient = GetClientOfUserId(userid);
		if (!IsValidClient(iClient)) return;

		Menu menu = new Menu(TopDuelPanel);
		menu.SetTitle("Top Duel Menu:");

		int i = 1;
		while (hndl.FetchRow())
		{
			char PlayerName[MAX_LINE_WIDTH];
			char line[MAX_LINE_WIDTH];
			hndl.FetchString(0, PlayerName , MAX_LINE_WIDTH);

			Format(line, sizeof(line), "%i : %s %f points", i, PlayerName, SQL_FetchFloat(hndl,1));
			menu.AddItem("i" , line);
			i++;
		}
		menu.ExitButton = true;
		menu.Display(iClient, MENU_TIME_FOREVER);
	}
	return;
}

public int TopDuelPanel(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
		delete menu;
}


//------------------------------------------------------------------------------------------------------------------------
//							When duel end
//------------------------------------------------------------------------------------------------------------------------


bool EndDuel(int iClient, int DuelType)
{
	if(DuelType != 0)
	{
		if(DuelType == 1 || DuelType == 2)
		{
			if(g_Duel[iClient][Score] > g_Duel[g_Duel[iClient][Challenger]][Score])
			{
				CPrintToChatAll("%t", "Victory", iClient, g_Duel[iClient][Challenger],"");
				Winner[iClient] 		= true;
				Winner[g_Duel[iClient][Challenger]] 	= false;
			}
			else if (g_Duel[iClient][Score] < g_Duel[g_Duel[iClient][Challenger]][Score])
			{
				CPrintToChatAll("%t", "Victory", g_Duel[iClient][Challenger], iClient,"");
				Winner[iClient] 		= false;
				Winner[g_Duel[iClient][Challenger]] 	= true;
			}
			else
			{
				CPrintToChatAll("%t", "Equality", g_Duel[iClient][Challenger], iClient);
				Equality[iClient] 		= true;
				Winner[iClient] 		= true;
				Equality[g_Duel[iClient][Challenger]] = true;
				Winner[g_Duel[iClient][Challenger]] 	= true;
			}
		}
		else if(DuelType == 3)
		{
			if(g_Duel[iClient][Score] > g_Duel[g_Duel[iClient][Challenger]][Score])
			{
				CPrintToChatAll("%t", "Victory", g_Duel[iClient][Challenger], iClient,"");
				Winner[iClient] 		= false;
				Winner[g_Duel[iClient][Challenger]] 	= true;
			}
			else if (g_Duel[iClient][Score] < g_Duel[g_Duel[iClient][Challenger]][Score])
			{
				CPrintToChatAll("%t", "Victory", iClient, g_Duel[iClient][Challenger],"");
				Winner[iClient] 		= true;
				Winner[g_Duel[iClient][Challenger]] 	= false;
			}
			else
			{
				CPrintToChatAll("%t", "Equality", g_Duel[iClient][Challenger], iClient);
				Equality[iClient] 		= true;
				Winner[iClient] 		= true;
				Equality[g_Duel[iClient][Challenger]] = true;
				Winner[g_Duel[iClient][Challenger]] 	= true;
			}
		}

		if(IsValidClient(g_Duel[iClient][Challenger]))
			ClientCommand(g_Duel[iClient][Challenger], "playgamesound ui/duel_event.wav");

		if(IsValidClient(iClient))
			ClientCommand(iClient, "playgamesound ui/duel_event.wav");

		InitializeClientonDB(g_Duel[iClient][Challenger]);
		InitializeClientonDB(iClient);

		return true;
	}
	return false;
}


public void InitializeClientonDB(int iClient)
{
	if(iClient == 0)
	{
		ResetPlayer(iClient);
		return;
	}
	char buffer[255];

	Format(buffer, sizeof(buffer), "SELECT `Victories`,`Duels` FROM Duels_Stats WHERE STEAMID = '%s'", ClientSteamID[iClient]);
	db.Query(T_UpdateClient, buffer, iClient);
}

public void T_UpdateClient(Database dummy, DBResultSet hndl, const char[] error, any iClient)
{
	char etat[512];
	int CltPoint;
	int Victory;
	int Equal;
	int Kill = g_Duel[iClient][kills];
	int Dead = g_Duel[iClient][Deads];
	int Abort = Abandon[iClient];
	int Tmer = g_Duel[iClient][PlayedTime];
	int Dueller = g_Duel[iClient][Challenger];

	if(Equality[iClient])
	{
		Format(etat, sizeof(etat), "Equality");
		CltPoint 	= 1;
		Victory 	= 1;
		Equal		= 1;
	}
	else if(Winner[iClient])
	{
		Format(etat, sizeof(etat), "Winner");
		CltPoint 	= 2;
		Victory 	= 1;
		Equal		= 0;
	}
	else
	{
		Format(etat, sizeof(etat), "Loser");
		CltPoint 	= 0;
		Victory 	= 0;
		Equal		= 0;
	}


	ResetPlayer(iClient);

	if (!hndl.RowCount)
	{
		char buffer[1500];
		if(!SQLite)
		{
			Format(buffer, sizeof(buffer), "INSERT INTO Duels_Stats (`Players`,`SteamID`,`Points`,`Victories`,`Duels`,`Kills`,`Deads`,`PlayTime`,`Abandoned`,`Equalities`,`Last_dueler`,`Last_dueler_SteamID`,`Etat`) VALUES ('%s','%s','%i','%i','1','%i','%i','%i','%i','%i','%s','%s','%s')", ClientName[iClient], ClientSteamID[iClient], CltPoint, Victory, Kill, Dead, Tmer, Abort, Equal, ClientName[Dueller], ClientSteamID[Dueller], etat);
			db.Query(SQLErrorCheckCallback, buffer);
			LogMessage("MySQL => %s First victory, and add on database.", ClientName[iClient]);
		}
		else
		{
			Format(buffer, sizeof(buffer), "INSERT INTO Duels_Stats VALUES('%s','%s','%i','%i','1','%i','%i','%i','%i','%i','%s','%s','%s');", ClientName[iClient], ClientSteamID[iClient], CltPoint, Victory, Kill, Dead, Tmer, Abort, Equal, ClientName[Dueller], ClientSteamID[Dueller], etat );
			db.Query(SQLErrorCheckCallback, buffer);
			LogMessage("SQLite => %s First victory, and add on database.", ClientName[iClient]);
		}
		CPrintToChatAll("%t", Victory >1 ? "Victories" : "VictoryNbr", ClientName[iClient], Victory);
	}
	else
	{
		char buffer[1500];

		while (hndl.FetchRow())
		{
			int clientvictories 	= hndl.FetchInt(0);
			int clientduels			= hndl.FetchInt(1);
			if(Victory == 1)
				clientvictories += 1;
			float clientpoints 	= ((clientvictories*1.0)/(clientduels+1)) + clientvictories;

			Format(buffer, sizeof(buffer), "UPDATE Duels_Stats SET Players = '%s', Points = %f, Victories = Victories +%i, Duels = Duels +1, Kills = Kills +%i, Deads = Deads +%i, PlayTime = PlayTime +%i, Abandoned = Abandoned +%i, Equalities = Equalities +%i, Last_dueler = '%s', Last_dueler_SteamID = '%s', Etat = '%s' WHERE SteamID = '%s'",ClientName[iClient], clientpoints, Victory, Kill, Dead, Tmer, Abort, Equal, ClientName[Dueller], ClientSteamID[Dueller], etat, ClientSteamID[iClient]);
			db.Query(SQLErrorCheckCallback, buffer);

			CPrintToChatAll("%t", clientvictories >1 ? "Victories" : "VictoryNbr", ClientName[iClient], clientvictories);
			LogMessage("MySQL => %s %d victories, and updated on database.", ClientName[iClient], clientvictories);
		}
	}
}

void ResetPlayer(int iClient)
{
	if(IsValidClient(iClient))
	{
		if (g_Duel[iClient][GodMod])
		{
			if(CommandExists("sm_colorize"))
			{
			    ServerCommand("sm_colorize #%d normal", GetClientUserId(iClient));
			}
			else
			{
				SetEntityRenderColor(iClient, 255, 255, 255, 255);
			}
		}
		
		if (!g_Duel[iClient][HealingAllowed])
		{
			TF2Attrib_RemoveByName(iClient, "health from healers reduced");
		}
	}
	g_Duel[iClient][Enabled] 		= false;
	g_Duel[iClient][HeadShot]		= false;
	g_Duel[iClient][HealingAllowed]		= true;
	g_Duel[iClient][ClassRestrict] 	= 0;
	g_Duel[iClient][kills]			= 0;
	g_Duel[iClient][Deads]			= 0;
	g_Duel[iClient][TimeLeft]		= 0;
	g_Duel[iClient][Score]			= 0;
	g_Duel[iClient][Challenger] 	= 0;
	g_Duel[iClient][PlayedTime]		= 0;
	g_Duel[iClient][GodMod]			= 0;
	g_Duel[iClient][Type]			= 0;

	Winner[iClient]				= false;
	Abandon[iClient]			= false;
	Equality[iClient]			= false;

	if(IsValidEdict(EntRefToEntIndex(g_Duel[iClient][SpriteParent])))
	{
		RemoveEdict(EntRefToEntIndex(g_Duel[iClient][SpriteParent]));
		g_Duel[iClient][SpriteParent] = INVALID_ENT_REFERENCE;
	}

	if(IsValidEdict(EntRefToEntIndex(g_Duel[iClient][CSprite])))
	{
		RemoveEdict(EntRefToEntIndex(g_Duel[iClient][CSprite]));
		g_Duel[iClient][CSprite] = INVALID_ENT_REFERENCE;
	}
}


//------------------------------------------------------------------------------------------------------------------------
//							Native Functions
//------------------------------------------------------------------------------------------------------------------------


public int Native_IsPlayerInDuel(Handle plugin, int numParams)
{
	int iClient = GetNativeCell(1);

	if(!IsValidClient(iClient)) return false;

	if(g_Duel[iClient][Enabled])
		return true;
	else
		return false;
}

public int Native_IsDuelRestrictionClass(Handle plugin, int numParams)
{
	int iClient = GetNativeCell(1);

	if(!IsValidClient(iClient)) return false;

	if(g_Duel[iClient][ClassRestrict] != 0)
		return true;
	else
		return false;
}

public int Native_GetDuelerID(Handle plugin, int numParams)
{
	if(!IsValidClient(GetNativeCell(1))) return -1;
	return g_Duel[GetNativeCell(1)][Challenger];
}
