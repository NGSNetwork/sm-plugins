/**
* TheXeon
* ngs_storestuff.sp
*
* Files:
* addons/sourcemod/plugins/ngs_storestuff.smx
* addons/sourcemod/configs/storelocations.cfg
*
* Dependencies:
* tf2_stocks.inc, clientprefs.inc, store.inc, afk_manager.inc,
* friendly.inc, ngsutils.inc, ngsupdater.inc,
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

//#define DEBUG

#include <tf2_stocks>

#if defined DEBUG
	#undef REQUIRE_PLUGIN
#endif
#include <clientprefs>
#include <store>
#include <afk_manager>
#include <friendly>
#if defined DEBUG
	#define REQUIRE_PLUGIN
#endif

#include <ngsutils>
#include <ngsupdater>


public Plugin myinfo = {
	name = "[NGS] Store Additions",
	author = "MasterOfTheXP / WhiteThunder / TheXeon",
	description = "Additional store items!",
	version = "1.1.2",
	url = "https://neogenesisnetwork.net/"
}

ConVar cvarHealth;
ConVar cvarHealthPerPlayer;
ConVar cvarHealthPerLevel;
ConVar host_timescale;
ConVar sm_timewarp_cooldown;
ConVar mapNameContains;

Cookie dailyTradeTimeCookie;
Cookie dailyLoginTimeCookie;
SMTimer killMerasmusTimer;

KeyValues mapLocations;
float merasmusLocation[3];

int g_spawn_count;
float g_player_spawns[100][3];
float current_timescale;
float g_lastwarp;
float monoculusLocation[3];

bool time_warped = false;
bool firstLogin[MAXPLAYERS + 1];
bool loginCookiesJustMade[MAXPLAYERS + 1];
bool tradeCookiesJustMade[MAXPLAYERS + 1];

float c_timewarp_cooldown;

int SpawnCooldown;
int SpecMonoculusCooldown[2];
int uNecromashCooldown;
int jNecromashCooldown;

public void OnPluginStart()
{
	RegAdminCmd("sm_spawnmonoculuscenter", CommandSpawnMonoculusCenter, ADMFLAG_SLAY, "Spawns a monoculus in the center of the pokeball!");
	RegAdminCmd("sm_spawnmerasmuscenter", CommandSpawnMerasmusCenter, ADMFLAG_SLAY, "Spawns a merasmus in the center of the pokeball!");
	RegAdminCmd("sm_spawnspectralmonoculus", CommandTeamMonoculus, ADMFLAG_SLAY, "Spawns a spectral monoculus where the arg is looking!");
	RegAdminCmd("sm_ultimatenecromash", CommandUltimateNecromash, ADMFLAG_SLAY, "Spawns the ultimate necromash.");
	RegAdminCmd("sm_judgingnecromash", CommandJudgingNecromash, ADMFLAG_SLAY, "Judges a random person with the blessed hammer!");
	RegAdminCmd("sm_reloadstorelocs", CommandReloadStoreConfig, ADMFLAG_GENERIC, "Reloads the map config file.");
	host_timescale = FindConVar("host_timescale");
	current_timescale = 1.0;

	RegAdminCmd("sm_warptime", Command_warpTime, ADMFLAG_RCON);
	sm_timewarp_cooldown = CreateConVar("sm_timewarp_cooldown", "180", "The serverwide cooldown for the timewarp item.");
	mapNameContains = CreateConVar("storestuff_config_contains", "1", "Whether map names in config will be checked partially or fully.");

	dailyLoginTimeCookie = new Cookie("dailycreditloginreward", "Timestamp to check credit reward against.", CookieAccess_Private);
	dailyTradeTimeCookie = new Cookie("dailytradereward", "Timestamp to check trade reward against.", CookieAccess_Private);

	LoadConfig();

	sm_timewarp_cooldown.AddChangeHook(OnConVarChanged);
	LoadTranslations("store.phrases");
	PrecacheMonoculus();
	findSpawnPoints();
	HookEvent("post_inventory_application", OnPostInventoryApplication);
	HookEvent("item_found", EventItemFound);
	HookEvent("merasmus_killed", OnMerasmusKilled, EventHookMode_Pre);
	HookEvent("merasmus_escape_warning", OnMerasmusEscapeWarning);
}

// Thank you Dr.Mckay and your CCC
public void LoadConfig()
{
	char configFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, configFile, sizeof(configFile), "configs/storelocations.cfg");
	if (!FileExists(configFile))
	{
		SetFailState("Missing config file (should be at %s)! Please get it from the repo!", configFile);
	}
	delete mapLocations;
	mapLocations = new KeyValues("Locations");
	if (!mapLocations.ImportFromFile(configFile))
	{
		SetFailState("Invalid config file at %s! Please fix it!", configFile);
	}
}

public void OnMapStart()
{
	char mapName[MAX_BUFFER_LENGTH];
	GetCurrentMap(mapName, sizeof(mapName));
	FindMapCoords(mapName);

	PrecacheMonoculus();
	PrecacheMerasmus();
	findSpawnPoints();
	host_timescale.FloatValue = 1.0;
	g_lastwarp = -c_timewarp_cooldown;

	PrecacheSound("ui/halloween_loot_spawn.wav", true);
	PrecacheSound("ui/halloween_loot_found.wav", true);
}

void FindMapCoords(char[] mapName)
{
	merasmusLocation = NULL_VECTOR;
	monoculusLocation = NULL_VECTOR;
	char buffer[MAX_BUFFER_LENGTH];
	mapLocations.Rewind();
	if (!mapLocations.JumpToKey(mapName))
	{
		if (mapNameContains.BoolValue)
		{
			mapLocations.Rewind();
			mapLocations.GotoFirstSubKey();
			bool found;
			do
			{
				mapLocations.GetSectionName(buffer, sizeof(buffer));
				if (StrContains(mapName, buffer, false) != -1)
				{
					SetMapCoords(buffer);
					found = true;
					break;
				}
			}
			while (mapLocations.GotoNextKey());

			if (!found)
			{
				LogError("Map %s is not in config file!", mapName);
			}
		}
		else
		{
			LogError("Map %s is not in config file!", mapName);
		}
	}
	else
	{
		SetMapCoords(mapName);
	}
}

void SetMapCoords(char[] sectionName)
{
	char monoculusBuffer[MAX_BUFFER_LENGTH], merasmusBuffer[MAX_BUFFER_LENGTH],
		monoculusVector[3][MAX_BUFFER_LENGTH], merasmusVector[3][MAX_BUFFER_LENGTH];
	mapLocations.GetString("monoculus", monoculusBuffer, sizeof(monoculusBuffer), "INV");
	mapLocations.GetString("merasmus", merasmusBuffer, sizeof(merasmusBuffer), "INV");
	if (monoculusBuffer[0] != 'I' || merasmusBuffer[0] != 'I')
	{
		if (monoculusBuffer[0] != 'I')
		{
			ExplodeString(monoculusBuffer, ",", monoculusVector, sizeof(monoculusVector), sizeof(monoculusVector[]));
			for (int i = 0; i < 3; i++)
			{
				monoculusLocation[i] = StringToFloat(monoculusVector[i]);
			}
		}
		if (merasmusBuffer[0] != 'I')
		{
			ExplodeString(merasmusBuffer, ",", merasmusVector, sizeof(merasmusVector), sizeof(merasmusVector[]));
			for (int i = 0; i < 3; i++)
			{
				merasmusLocation[i] = StringToFloat(merasmusVector[i]);
			}
		}
	}
	else
	{
		LogError("Invalidly formatted or missing location string in config file around Section \'%s\'. Make sure it is a comma separated 3d vector!", sectionName);
	}
}

public void OnConfigsExecuted()
{
	cvarHealth = FindConVar("tf_eyeball_boss_health_base");
	cvarHealthPerPlayer = FindConVar("tf_eyeball_boss_health_per_player");
	cvarHealthPerLevel = FindConVar("tf_eyeball_boss_health_per_level");
}

public void OnConVarChanged( ConVar cvar, const char[] oldval, const char[] newval )
{
	c_timewarp_cooldown = GetConVarFloat( sm_timewarp_cooldown );
}

public void OnClientConnected(int client)
{
	firstLogin[client] = false;
}

public void OnClientDisconnect(int client)
{
	tradeCookiesJustMade[client] = false;
	loginCookiesJustMade[client] = false;
}

public void OnClientPostAdminCheck(int client)
{
	if (AreClientCookiesCached(client))
	{
		char sTradeCookieValue[MAX_BUFFER_LENGTH], sLoginCookieValue[MAX_BUFFER_LENGTH], sNewTCV[MAX_BUFFER_LENGTH], sNewLCV[MAX_BUFFER_LENGTH];
		dailyLoginTimeCookie.GetValue(client, sLoginCookieValue, sizeof(sLoginCookieValue));
		dailyTradeTimeCookie.GetValue(client, sTradeCookieValue, sizeof(sTradeCookieValue));
		if (sTradeCookieValue[0] == '\0')
		{
			IntToString(GetTime(), sNewTCV, sizeof(sNewTCV));
			dailyTradeTimeCookie.SetValue(client, sNewTCV);
			loginCookiesJustMade[client] = true;
		}
		if (sLoginCookieValue[0] == '\0')
		{
			IntToString(GetTime(), sNewLCV, sizeof(sNewLCV));
			dailyTradeTimeCookie.SetValue(client, sNewLCV);
			tradeCookiesJustMade[client] = true;
		}
	}
	else
		LogMessage("Client Cookies are not cached yet, for some reason.");
}

public void OnPostInventoryApplication(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (!firstLogin[client])
	{
		if (AreClientCookiesCached(client))
		{
			int accountID = GetSteamAccountID(client);
			char sCookieValue[64];
			dailyLoginTimeCookie.GetValue(client, sCookieValue, sizeof(sCookieValue));
			int cookieValue = StringToInt(sCookieValue);
			int currentTime = GetTime();
			char newCookieValue[MAX_BUFFER_LENGTH];
	 		if (GetFeatureStatus(FeatureType_Native, "Store_GiveCredits") == FeatureStatus_Available && (loginCookiesJustMade[client] || currentTime > (cookieValue + 86400)))
			{
				Store_GiveCredits(accountID, 200);
				CPrintToChat(client, "%tCongrats, you have been awarded {PURPLE}200{DEFAULT} credits for logging in today. We hope you enjoy the NGS family!", "Store Tag Colored");
				IntToString(currentTime, newCookieValue, sizeof(newCookieValue));
				dailyLoginTimeCookie.SetValue(client, newCookieValue);
				if (loginCookiesJustMade[client]) loginCookiesJustMade[client] = false;
			}
		}
		firstLogin[client] = true;
	}
}

public Action CommandReloadStoreConfig(int client, int args)
{
	if (mapLocations == null)
	{
		CReplyToCommand(client, "The config file does not currently exist!");
	}
	else
	{
		char mapName[MAX_BUFFER_LENGTH];
		GetCurrentMap(mapName, sizeof(mapName));
		LoadConfig();
		FindMapCoords(mapName);
		CReplyToCommand(client, "Locations have been reloaded!");
	}
	return Plugin_Handled;
}

public Action CommandSpawnMerasmusCenter(int client, int args)
{
	if (args > 0)
	{
		char arg1[32];
		GetCmdArg(1, arg1, sizeof(arg1));

		int target = FindTarget(client, arg1, false, false);
		if (target == -1) return Plugin_Handled;

		if (merasmusLocation[0] == NULL_VECTOR[0])
		{
			CPrintToChat(target, "%tThe map is not configured for this boss, notify an admin!", "Store Tag Colored");
			Store_GiveItem(GetSteamAccountID(target), 485);
			return Plugin_Handled;
		}
		else if (TF2Friendly_IsFriendly(target))
		{
			CPrintToChat(target, "%tYou may not use the item because you are friendly.", "Store Tag Colored");
			return Plugin_Handled;
		}
		int currentTime = GetTime();
		if (currentTime - SpawnCooldown < 900)
		{
			CPrintToChat(target, "%tYou must wait {PURPLE}%d{DEFAULT} seconds to spawn this.", "Store Tag Colored", 900 - (currentTime - SpawnCooldown));
			Store_GiveItem(GetSteamAccountID(target), 485);
			return Plugin_Handled;
		}

		SpawnCooldown = currentTime;
		CPrintToChatAll("%t{OLIVE}%N{DEFAULT} spawned in {GREY}MERASMUS{DEFAULT}!", "Store Tag Colored", target);
	}

	if (args == 0 && merasmusLocation[0] == NULL_VECTOR[0])
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} The map is not configured for this boss!");
		return Plugin_Handled;
	}

	int BaseHealth = GetConVarInt(cvarHealth), HealthPerPlayer = GetConVarInt(cvarHealthPerPlayer), HealthPerLevel = GetConVarInt(cvarHealthPerLevel);
	SetConVarInt(cvarHealth, 4200), SetConVarInt(cvarHealthPerPlayer, 300), SetConVarInt(cvarHealthPerLevel, 2000);
	int ent = CreateEntityByName("merasmus");
	if (!IsValidEntity(ent)) return Plugin_Handled;
	SetEntProp(ent, Prop_Send, "m_CollisionGroup", 2);
	TeleportEntity(ent, merasmusLocation, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(ent);
	SetConVarInt(cvarHealth, BaseHealth), SetConVarInt(cvarHealthPerPlayer, HealthPerPlayer), SetConVarInt(cvarHealthPerLevel, HealthPerLevel);
	return Plugin_Handled;
}

public Action CommandSpawnMonoculusCenter(int client, int args)
{
	if (args > 0)
	{
		char arg1[32];
		GetCmdArg(1, arg1, sizeof(arg1));

		int target = FindTarget(client, arg1, false, false);
		if (target == -1) return Plugin_Handled;

		if (monoculusLocation[0] == NULL_VECTOR[0])
		{
			CPrintToChat(target, "%tThe map is not configured for this plugin, notify an admin!", "Store Tag Colored");
			Store_GiveItem(GetSteamAccountID(target), 405);
			return Plugin_Handled;
		}
		else if (TF2Friendly_IsFriendly(target))
		{
			CPrintToChat(target, "%tYou may not use the item because you are friendly.", "Store Tag Colored");
			return Plugin_Handled;
		}
		int currentTime = GetTime();
		if (currentTime - SpawnCooldown < 900)
	    {
			CPrintToChat(target, "%tYou must wait {PURPLE}%d{DEFAULT} seconds to spawn this.", "Store Tag Colored", 900 - (currentTime - SpawnCooldown));
			Store_GiveItem(GetSteamAccountID(target), 405);
			return Plugin_Handled;
		}

		SpawnCooldown = currentTime;
		CPrintToChatAll("%t{OLIVE}%N{DEFAULT} spawned in {PURPLE}MONOCULUS{DEFAULT}!", "Store Tag Colored", target);
	}

	if (args == 0 && monoculusLocation[0] == NULL_VECTOR[0])
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} The map is not configured for this boss!");
		return Plugin_Handled;
	}

	int BaseHealth = GetConVarInt(cvarHealth), HealthPerPlayer = GetConVarInt(cvarHealthPerPlayer), HealthPerLevel = GetConVarInt(cvarHealthPerLevel);
	SetConVarInt(cvarHealth, 4200), SetConVarInt(cvarHealthPerPlayer, 300), SetConVarInt(cvarHealthPerLevel, 2000);
	int Ent = CreateEntityByName("eyeball_boss");
	if (!IsValidEntity(Ent)) return Plugin_Handled;
	SetEntProp(Ent, Prop_Data, "m_iTeamNum", 5);
	SetEntProp(Ent, Prop_Send, "m_CollisionGroup", 2);
	TeleportEntity(Ent, monoculusLocation, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(Ent);
	SetConVarInt(cvarHealth, BaseHealth), SetConVarInt(cvarHealthPerPlayer, HealthPerPlayer), SetConVarInt(cvarHealthPerLevel, HealthPerLevel);
	return Plugin_Handled;
}

public Action CommandTeamMonoculus(int client, int args)
{
	if (args < 1) return Plugin_Handled;

	char arg1[MAX_BUFFER_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));

	int target = FindTarget(client, arg1, false, false);
	if (target == -1) return Plugin_Handled;
	if (TF2Friendly_IsFriendly(target))
	{
		CPrintToChat(target, "%tYou may not use this item because you are friendly.", "Store Tag Colored");
		return Plugin_Handled;
	}
	int playerTeam = view_as<int>(GetClientTeam(target));
	int currentTime = GetTime();
	if (currentTime - SpecMonoculusCooldown[playerTeam - 2] < 90)
	{
		CPrintToChat(target, "%tYou must wait {PURPLE}%d{DEFAULT} seconds to spawn this.", "Store Tag Colored", 90 - (currentTime - SpecMonoculusCooldown[playerTeam - 2]));
		Store_GiveItem(GetSteamAccountID(target), 406);
		return Plugin_Handled;
	}

	int BaseHealth = cvarHealth.IntValue, HealthPerPlayer = cvarHealthPerPlayer.IntValue, HealthPerLevel = cvarHealthPerLevel.IntValue;
	cvarHealth.IntValue = 4200, cvarHealthPerPlayer.IntValue = 300, cvarHealthPerLevel.IntValue = 2000;
	int Ent = CreateEntityByName("eyeball_boss");
	if (!IsValidEntity(Ent))
	{
		CPrintToChat(target, "%Could not create the entity, please try again!", "Store Tag Colored", 90 - (currentTime - SpecMonoculusCooldown[playerTeam - 2]));
		Store_GiveItem(GetSteamAccountID(target), 406);
		return Plugin_Handled;
	}
	SpecMonoculusCooldown[playerTeam - 2] = currentTime;

	SetEntProp(Ent, Prop_Data, "m_iTeamNum", playerTeam);
	SetEntProp(Ent, Prop_Send, "m_CollisionGroup", 2);

	float start[3], angle[3], end[3];
	GetClientEyePosition(target, start);
	GetClientEyeAngles(target, angle);
	TR_TraceRayFilter(start, angle, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer, target);
	if (TR_DidHit())
	{
		TR_GetEndPosition(end);
	}
	if (NearSpawn(end))
	{
		CPrintToChat(target, "%tSorry, you can't spawn this near spawns.", "Store Tag Colored");
		Store_GiveItem(GetSteamAccountID(target), 406);
		return Plugin_Handled;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (target == i || !IsValidClient(i, true)) continue;
		float clientPos[3];
		GetEntPropVector(i, Prop_Send, "m_vecOrigin", clientPos);
		if (GetVectorDistance(clientPos, end) < 175.0)
		{
			CPrintToChat(target, "%tSorry, you can't spawn this near players.", "Store Tag Colored");
			Store_GiveItem(GetSteamAccountID(target), 406);
			return Plugin_Handled;
		}
	}

	CPrintToChatAll("%t{OLIVE}%N{DEFAULT} spawned in %sSPECTRAL MONOCULUS{DEFAULT}!", "Store Tag Colored", target, (GetClientTeam(target) == view_as<int>(TFTeam_Blue)) ? "{BLUE}" : "{RED}");

	end[2] += 50;
	TeleportEntity(Ent, end, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(Ent);
	EmitSoundToAll("ui/halloween_boss_summoned_fx.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_HOME);
	cvarHealth.IntValue = BaseHealth, cvarHealthPerPlayer.IntValue = HealthPerPlayer, cvarHealthPerLevel.IntValue = HealthPerLevel;
	return Plugin_Handled;
}

public Action CommandUltimateNecromash(int client, int args)
{
	if (!CommandExists("sm_smash")) return Plugin_Handled;
	if (args > 0)
	{
		char arg1[32];
		GetCmdArg(1, arg1, sizeof(arg1));

		int target = FindTarget(client, arg1, false, false);
		if (target == -1) return Plugin_Handled;
		if (TF2Friendly_IsFriendly(target))
		{
			CPrintToChat(target, "%tYou may not use the item because you are friendly.", "Store Tag Colored");
			return Plugin_Handled;
		}
		int currentTime = GetTime();
		if (currentTime - uNecromashCooldown < 900)
	    {
			CReplyToCommand(target, "%tYou must wait {PURPLE}%d{DEFAULT} seconds to use this.", "Store Tag Colored", 900 - (currentTime - uNecromashCooldown));
			Store_GiveItem(GetSteamAccountID(target), 365); // Gives hammer back after unsuccessful usage. So unfutureproof
			return Plugin_Handled;
		}

		uNecromashCooldown = currentTime;
		CPrintToChatAll("%t{OLIVE}%N{DEFAULT} called the power of {GREEN}THE ULTIMATE NECROMASH{DEFAULT}!", "Store Tag Colored", target);
	}
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i, true))
		{
			TF2_StunPlayer(i, 12.0, 0.95, TF_STUNFLAG_SLOWDOWN, client);
		}
	}
	PrintCenterTextAll("You slowed in fear!");
	SMTimer.Make(2.0, TimerSmashAll);
	return Plugin_Handled;
}

public Action TimerSmashAll(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i, true, _, _, _, true))
		{
			ServerCommand("sm_smash #%d", GetClientUserId(i));
		}
	}
	CPrintToChatAll("%t{RED}THE HAMMER{DEFAULT} SEES ALL!", "Store Tag Colored");
}

public Action CommandJudgingNecromash(int client, int args)
{
	if (!CommandExists("sm_smash")) return Plugin_Handled;
	if (args > 0)
	{
		char arg1[32];
		GetCmdArg(1, arg1, sizeof(arg1));

		int target = FindTarget(client, arg1, false, false);
		if (target == -1) return Plugin_Handled;
		if (TF2Friendly_IsFriendly(target))
		{
			CPrintToChat(target, "%tYou may not use the item because you are friendly.", "Store Tag Colored");
			return Plugin_Handled;
		}
		int currentTime = GetTime();
		if (currentTime - jNecromashCooldown < 60)
	    {
	   		CPrintToChat(target, "%tYou must wait {PURPLE}%d{DEFAULT} seconds to use this.", "Store Tag Colored", 60 - (currentTime - jNecromashCooldown));
	   		Store_GiveItem(GetSteamAccountID(target), 369);
	   		return Plugin_Handled;
	  	}

		jNecromashCooldown = currentTime;
		CPrintToChatAll("%t{OLIVE}%N{DEFAULT} called the power of {GREEN}THE JUDGING NECROMASH{DEFAULT}!", "Store Tag Colored", target);
	}
	SMTimer.Make(2.0, TimerRandomSmash);
	return Plugin_Handled;
}

public Action TimerRandomSmash(Handle timer)
{
	if (GetClientCount() < 1) return Plugin_Stop;
	int client;
	do
	{
		client = GetRandomInt(1, MaxClients);
	}
	while(!IsValidClient(client) || !IsPlayerAlive(client) || AFKM_IsClientAFK(client));
	int userid = GetClientUserId(client);
	ServerCommand("sm_smash #%d", userid);
	CPrintToChatAll("%t{RED}THE HAMMER{DEFAULT} HAS JUDGED! {OLIVE}%N{DEFAULT}, THE HAMMER KNOWS YOUR SINS!", "Store Tag Colored", client);
	return Plugin_Continue;
}

public void EventItemFound(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("player");
	int accountID = GetSteamAccountID(client);
	int method = event.GetInt("method");
	if (method == 2)
	{
		char sCookieValue[64];
		char newCookieValue[MAX_BUFFER_LENGTH];
		dailyTradeTimeCookie.GetValue(client, sCookieValue, sizeof(sCookieValue));
		int cookieValue = StringToInt(sCookieValue);
		int currentTime = GetTime();
 		if (GetFeatureStatus(FeatureType_Native, "Store_GiveCredits") == FeatureStatus_Available && (tradeCookiesJustMade[client] || currentTime > (cookieValue + 86400)))
		{
			Store_GiveCredits(accountID, 500);
			CPrintToChat(client, "%tCongrats, you have been awarded {PURPLE}500{DEFAULT} credits for trading an item today.", "Store Tag Colored");
			IntToString(currentTime, newCookieValue, sizeof(newCookieValue));
			dailyTradeTimeCookie.SetValue(client, newCookieValue);
			if (tradeCookiesJustMade[client]) tradeCookiesJustMade[client] = false;
		}
	}
}

public Action Command_warpTime(int client, int args)
{
	if (args < 1) return Plugin_Handled;

	char arg1[MAX_BUFFER_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));

	int target = FindTarget(client, arg1, false, false);
	if (target == -1) return Plugin_Handled;

	warpTime(target);
	return Plugin_Handled;
}

bool warpTime(int client)
{

	if( time_warped ) {
		CPrintToChat(client,"%tTime is already warped!", "Store Tag Colored");
		return false;
	}

	float time = GetGameTime();
	if( time < g_lastwarp + c_timewarp_cooldown )
	{
		CPrintToChat( client, "%tTime has recently been warped. Please try again in {PURPLE}%d{DEFAULT} seconds.", "Store Tag Colored", RoundToCeil(g_lastwarp + c_timewarp_cooldown - time) );
		return false;
	}

	g_lastwarp = time;
	EmitSoundToAll( "ui/halloween_loot_spawn.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_HOME );
	TFTeam client_team = view_as<TFTeam>(GetClientTeam(client));

	if (client_team == TFTeam_Blue) CPrintToChatAll("%t{BLUE}%N{DEFAULT} has warped time!", "Store Tag Colored", client);
	else CPrintToChatAll("%t{RED}%N{DEFAULT} has warped time!", "Store Tag Colored", client);

	time_warped = true;
	for( int i = 1; i <= MaxClients; i++ ) {
		if( IsValidClient(i) ) {
			fakeCheats( i, true );
		}
	}

	SMTimer.Make( 0.1, Timer_warpTimeInc, _, TIMER_REPEAT );
	SMTimer.Make( 15.0, Timer_unWarpTime );
	return true;
}


bool NearSpawn(float end[3])
{
	float target[3];
	target[0] = end[0];
	target[1] = end[1];
	for( int i = 0; i < g_spawn_count; i++ ) {
		target[2] = end[2] + (end[2] - g_player_spawns[i][2])*2;
		float distance = GetVectorDistance(g_player_spawns[i],target,true);
		if(distance < 562500){
			return true;
		}
	}
	return false;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask, any data)
{
	return entity > MaxClients;
}

void fakeCheats(int client, bool on_off ){
	SendConVarValue( client, FindConVar("sv_cheats"), on_off ? "1" : "0" );
}

void findSpawnPoints() {
	int ent = -1;
	g_spawn_count = 0;
	while( (ent = FindEntityByClassname(ent, "info_player_teamspawn")) != -1){
		GetEntPropVector( ent, Prop_Send, "m_vecOrigin", g_player_spawns[g_spawn_count]);
		g_spawn_count++;
	}
}

public Action Timer_warpTimeInc( Handle timer )
{
	current_timescale -= 0.03;

	SetConVarFloat(host_timescale, current_timescale);
	if( current_timescale <= 0.5 ){
		SetConVarFloat(host_timescale, 0.5);
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action Timer_unWarpTime( Handle timer ) {
	EmitSoundToAll( "ui/halloween_loot_found.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_HOME );
	CPrintToChatAll("%tThe {PURPLE}time warp{DEFAULT} has ended!", "Store Tag Colored");
	SMTimer.Make( 0.1, Timer_unWarpTimeInc, _, TIMER_REPEAT );
}

public Action OnMerasmusKilled(Event event, const char[] name, bool dontBroadcast)
{
	delete killMerasmusTimer;
	int ent = -1;
	while((ent = FindEntityByClassname(ent, "merasmus")) != -1) {
		if(!IsValidEntity(ent)) return Plugin_Continue;
		AcceptEntityInput(ent, "Kill");
	}
	return Plugin_Continue;
}

public void OnMerasmusEscapeWarning(Event event, const char[] name, bool dontBroadcast)
{
	if (killMerasmusTimer == null)
	{
		int timeremaining = event.GetInt("time_remaining");
		LogMessage("Escape warning timer is at %d.", timeremaining);
		killMerasmusTimer = new SMTimer(float(timeremaining), OnKillMerasmusTimer);
	}
}

public Action OnKillMerasmusTimer(Handle timer)
{
	killMerasmusTimer = null;
	int ent = -1;
	while((ent = FindEntityByClassname(ent, "merasmus")) != -1) {
		if(!IsValidEntity(ent)) return;
		AcceptEntityInput(ent, "Kill");
	}
}

public Action Timer_unWarpTimeInc( Handle timer ) {

	current_timescale += 0.03;
	host_timescale.FloatValue = current_timescale;

	if( current_timescale <= 1.0 )
	{
		host_timescale.FloatValue = 1.0;
		for( int i = 1; i <= MaxClients; i++ ) {
			if( IsValidClient(i) ) {
				fakeCheats(i,false);
			}
		}
		time_warped = false;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

void PrecacheMonoculus()
{
	PrecacheModel( "models/props_halloween/halloween_demoeye.mdl", true );
	PrecacheModel( "models/props_halloween/eyeball_projectile.mdl", true );

	PrecacheSound( "vo/halloween_eyeball/eyeball_biglaugh01.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_boss_pain01.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_laugh01.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_laugh02.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_laugh03.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_mad01.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_mad02.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_mad03.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_teleport01.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball01.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball02.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball03.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball04.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball05.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball06.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball07.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball08.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball09.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball10.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball11.wav", true );

	PrecacheSound( "ui/halloween_boss_summon_rumble.wav", true);
	PrecacheSound( "ui/halloween_boss_chosen_it.wav", true );
	PrecacheSound( "ui/halloween_boss_defeated_fx.wav", true );
	PrecacheSound( "ui/halloween_boss_defeated.wav", true );
	PrecacheSound( "ui/halloween_boss_player_becomes_it.wav", true );
	PrecacheSound( "ui/halloween_boss_summoned_fx.wav", true );
	PrecacheSound( "ui/halloween_boss_summoned.wav", true );
	PrecacheSound( "ui/halloween_boss_tagged_other_it.wav", true );
	PrecacheSound( "ui/halloween_boss_escape.wav", true );
	PrecacheSound( "ui/halloween_boss_escape_sixty.wav", true );
	PrecacheSound( "ui/halloween_boss_escape_ten.wav", true );
	PrecacheSound( "ui/halloween_boss_tagged_other_it.wav", true );
}

void PrecacheMerasmus()
{
	PrecacheModel("models/bots/merasmus/merasmus.mdl", true);
	PrecacheModel("models/prop_lakeside_event/bomb_temp.mdl", true);
	PrecacheModel("models/prop_lakeside_event/bomb_temp_hat.mdl", true);

	for(int i = 1; i <= 17; i++) {
		char iString[PLATFORM_MAX_PATH];
		if(i < 10) Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_appears0%d.wav", i);
		else Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_appears%d.wav", i);
		if(FileExists(iString)) {
			PrecacheSound(iString, true);
		}
	}

	for(int i = 1; i <= 11; i++) {
		char iString[PLATFORM_MAX_PATH];
		if(i < 10) Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_attacks0%d.wav", i);
		else Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_attacks%d.wav", i);
		if(FileExists(iString)) {
			PrecacheSound(iString, true);
		}
	}

	for(int i = 1; i <= 54; i++) {
		char iString[PLATFORM_MAX_PATH];
		if(i < 10) Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_bcon_headbomb0%d.wav", i);
		else Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_bcon_headbomb%d.wav", i);
		if(FileExists(iString)) {
			PrecacheSound(iString, true);
		}
	}

	for(int i = 1; i <= 33; i++) {
		char iString[PLATFORM_MAX_PATH];
		if(i < 10) Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_bcon_held_up0%d.wav", i);
		else Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_bcon_held_up%d.wav", i);
		if(FileExists(iString)) {
			PrecacheSound(iString, true);
		}
	}

	for(int i = 2; i <= 4; i++) {
		char iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_bcon_island0%d.wav", i);
		PrecacheSound(iString, true);
	}

	for(int i = 1; i <= 3; i++) {
		char iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_bcon_skullhat0%d.wav", i);
		PrecacheSound(iString, true);
	}

	for(int i = 1; i <= 2; i++) {
		char iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_combat_idle0%d.wav", i);
		PrecacheSound(iString, true);
	}

	for(int i = 1; i <= 12; i++) {
		char iString[PLATFORM_MAX_PATH];
		if(i < 10) Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_defeated0%d.wav", i);
		else Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_defeated%d.wav", i);
		if(FileExists(iString)) {
			PrecacheSound(iString, true);
		}
	}

	for(int i = 1; i <= 9; i++) {
		char iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_found0%d.wav", i);
		PrecacheSound(iString, true);
	}

	for(int i = 3; i <= 6; i++) {
		char iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_grenades0%d.wav", i);
		PrecacheSound(iString, true);
	}

	for(int i = 1; i <= 26; i++) {
		char iString[PLATFORM_MAX_PATH];
		if(i < 10) Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_headbomb_hit0%d.wav", i);
		else Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_headbomb_hit%d.wav", i);
		if(FileExists(iString)) {
			PrecacheSound(iString, true);
		}
	}

	for(int i = 1; i <= 19; i++) {
		char iString[PLATFORM_MAX_PATH];
		if(i < 10) Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_hide_heal10%d.wav", i);
		else Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_hide_heal1%d.wav", i);
		if(FileExists(iString)) {
			PrecacheSound(iString, true);
		}
	}

	for(int i = 1; i <= 49; i++) {
		char iString[PLATFORM_MAX_PATH];
		if(i < 10) Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_hide_idles0%d.wav", i);
		else Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_hide_idles%d.wav", i);
		if(FileExists(iString)) {
			PrecacheSound(iString, true);
		}
	}

	for(int i = 1; i <= 16; i++) {
		char iString[PLATFORM_MAX_PATH];
		if(i < 10) Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_leaving0%d.wav", i);
		else Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_leaving%d.wav", i);
		if(FileExists(iString)) {
			PrecacheSound(iString, true);
		}
	}

	for(int i = 1; i <= 5; i++) {
		char iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_pain0%d.wav", i);
		PrecacheSound(iString, true);
	}

	for(int i = 4; i <= 8; i++) {
		char iString[PLATFORM_MAX_PATH];
		Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_ranged_attack0%d.wav", i);
		PrecacheSound(iString, true);
	}

	for(int i = 2; i <= 13; i++) {
		char iString[PLATFORM_MAX_PATH];
		if(i < 10) Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_staff_magic0%d.wav", i);
		else Format(iString, sizeof(iString), "vo/halloween_merasmus/sf12_staff_magic%d.wav", i);
		if(FileExists(iString)) {
			PrecacheSound(iString, true);
		}
	}

	PrecacheSound("vo/halloween_merasmus/sf12_hide_idles_demo01.wav", true);
	PrecacheSound("vo/halloween_merasmus/sf12_magic_backfire06.wav", true);
	PrecacheSound("vo/halloween_merasmus/sf12_magic_backfire07.wav", true);
	PrecacheSound("vo/halloween_merasmus/sf12_magic_backfire23.wav", true);
	PrecacheSound("vo/halloween_merasmus/sf12_magic_backfire29.wav", true);
	PrecacheSound("vo/halloween_merasmus/sf12_magicwords11.wav", true);

	PrecacheSound("misc/halloween/merasmus_appear.wav", true);
	PrecacheSound("misc/halloween/merasmus_death.wav", true);
	PrecacheSound("misc/halloween/merasmus_disappear.wav", true);
	PrecacheSound("misc/halloween/merasmus_float.wav", true);
	PrecacheSound("misc/halloween/merasmus_hiding_explode.wav", true);
	PrecacheSound("misc/halloween/merasmus_spell.wav", true);
	PrecacheSound("misc/halloween/merasmus_stun.wav", true);
}
