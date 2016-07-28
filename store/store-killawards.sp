#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <store>
#include <morecolors>

#define MAX_FILTERS 128
#define MAX_FILTER_KVLEN 255

enum Filter
{
	String:FilterKey[MAX_FILTER_KVLEN],
	String:FilterValue[MAX_FILTER_KVLEN],
	String:FilterType[10],
	FilterAddend,
	Float:FilterMultiplier
}

char g_currencyName[64];
char g_nameTag[MAX_BUFFER_LENGTH];

int g_filters[MAX_FILTERS][Filter];
int g_filterCount;

int g_points_kill;
int g_points_teamkill;
int g_ignore_bots;
bool g_enable_message_per_kill;
bool g_enable_only_name_tag;
bool g_enable_case_sensitive_tag;

public Plugin myinfo = {
	name        = "[Store] Kill Awards",
	author      = "eXemplar / TheXeon",
	description = "Award kills component for [Store]",
	version     = STORE_VERSION,
	url         = "https://github.com/eggsampler/store-killawards"
}

/**
 * Plugin is loading.
 */
public void OnPluginStart() 
{
	LoadConfig();
	LoadTranslations("store.killawards");
	LoadTranslations("store.phrases");

	HookEvent("player_death", Event_PlayerDeath);
}

/**
 * Configs just finished getting executed.
 */
public void OnAllPluginsLoaded()
{
	Store_GetCurrencyName(g_currencyName, sizeof(g_currencyName));
}

/**
 * Load plugin config.
 */
void LoadConfig() 
{
	Handle kv = CreateKeyValues("root");
	
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/store/killawards.cfg");
	
	if (!FileToKeyValues(kv, path)) 
	{
		CloseHandle(kv);
		SetFailState("Can't read config file %s", path);
	}

	g_points_kill = KvGetNum(kv, "points_kill", 2);
	g_points_teamkill = KvGetNum(kv, "points_teamkill", -1);
	g_ignore_bots = KvGetNum(kv, "ignore_bots", 1);
	g_enable_message_per_kill = view_as<bool>(KvGetNum(kv, "enable_message_per_kill", 0));
	g_enable_only_name_tag = view_as<bool>(KvGetNum(kv, "enable_only_name_tag", 0));
	KvGetString(kv, "name_tag", g_nameTag, sizeof(g_nameTag), "ngs");
	g_enable_case_sensitive_tag = view_as<bool>(KvGetNum(kv, "enable_case_sensitive_tag", 0));

	if (KvJumpToKey(kv, "filters"))
	{
		g_filterCount = 0;

		if (KvGotoFirstSubKey(kv))
		{
			do
			{
				char key_name[MAX_FILTER_KVLEN];
				KvGetSectionName(kv, key_name, sizeof(key_name));

				char type[10];
				KvGetString(kv, "type", type, 10);

				if (KvGotoFirstSubKey(kv))
				{
					do
					{
						strcopy(g_filters[g_filterCount][FilterKey], MAX_FILTER_KVLEN, key_name);
						KvGetSectionName(kv, g_filters[g_filterCount][FilterValue], MAX_FILTER_KVLEN);
						strcopy(g_filters[g_filterCount][FilterType], 10, type);
						g_filters[g_filterCount][FilterAddend] = KvGetNum(kv, "addend", 0);
						g_filters[g_filterCount][FilterMultiplier] = KvGetFloat(kv, "multiplier", 1.0);
						g_filterCount++;
					} while (KvGotoNextKey(kv));

					KvGoBack(kv);
				}

			} while (KvGotoNextKey(kv));
		}
	}

	CloseHandle(kv);
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int client_died = GetClientOfUserId(GetEventInt(event, "userid"));
	int client_killer = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	// ignore suicides
	if (client_killer == client_died)
	{
		return Plugin_Continue;
	}
	
	// ignore invalid clients or fake clients (bots)
	if (client_killer <= 0 || IsFakeClient(client_killer))
	{
		return Plugin_Continue;
	}
	// dont award points for bot kills
	if (g_ignore_bots == 1 && IsFakeClient(client_died))
	{
		return Plugin_Continue;
	}
	
	if (g_enable_only_name_tag)
	{
		char killerName[MAX_NAME_LENGTH];
		GetClientName(client_killer, killerName, sizeof(killerName));
		if (StrContains(killerName, g_nameTag, g_enable_case_sensitive_tag) != -1)
		{
			// teamkill
			if (GetClientTeam(client_killer) == GetClientTeam(client_died))
			{
				int points = Calculate(event, g_points_teamkill);
				if (points != 0)
				{
					Store_GiveCredits(GetSteamAccountID(client_killer), points);
					if (g_enable_message_per_kill)
					{
						CPrintToChat(client_killer, "%t%t", "Store Tag Colored", "Received Credits TeamKill", points, g_currencyName, client_died);
					}
				}
				return Plugin_Continue;
			}
		
			// all else
			int points = Calculate(event, g_points_kill);
			if (points != 0)
			{
				Store_GiveCredits(GetSteamAccountID(client_killer), points);
				if (g_enable_message_per_kill)
				{
					CPrintToChat(client_killer, "%t%t", "Store Tag Colored", "Received Credits Kill", points, g_currencyName, client_died);
				}
			}
			
			return Plugin_Continue;
		}
		return Plugin_Continue;
	}
	
	else
	{	
		// teamkill
		if (GetClientTeam(client_killer) == GetClientTeam(client_died))
		{
			int points = Calculate(event, g_points_teamkill);
			if (points != 0)
			{
				Store_GiveCredits(GetSteamAccountID(client_killer), points);
				if (g_enable_message_per_kill)
				{
					CPrintToChat(client_killer, "%t%t", "Store Tag Colored", "Received Credits TeamKill", points, g_currencyName, client_died);
				}
			}
			return Plugin_Continue;
		}
		
		// all else
		int points = Calculate(event, g_points_kill);
		if (points != 0)
		{
			Store_GiveCredits(GetSteamAccountID(client_killer), points);
			if (g_enable_message_per_kill)
			{
				CPrintToChat(client_killer, "%t%t", "Store Tag Colored", "Received Credits Kill", points, g_currencyName, client_died);
			}
		}
		
		return Plugin_Continue;
	}
}

int Calculate(Handle event, int basepoints)
{
	int points = basepoints;

	for (int filter = 0; filter < g_filterCount; filter++)
	{
		bool matches = false;
		if (StrEqual(g_filters[filter][FilterType], "string"))
		{
			char value[MAX_FILTER_KVLEN];
			GetEventString(event, g_filters[filter][FilterKey], value, sizeof(value));
			if(StrEqual(value, g_filters[filter][FilterValue]))
			{
				matches = true;
			}
		}
		else if (StrEqual(g_filters[filter][FilterType], "int"))
		{
			int value = GetEventInt(event, g_filters[filter][FilterKey]);
			if (value == StringToInt(g_filters[filter][FilterValue]))
			{
				matches = true;
			}
		}
		else if (StrEqual(g_filters[filter][FilterType], "bool"))
		{
			bool value = view_as<bool>(GetEventInt(event, g_filters[filter][FilterKey]));
			if (value == view_as<bool>(StringToInt(g_filters[filter][FilterValue])))
			{
				matches = true;
			}
		}
		else if (StrEqual(g_filters[filter][FilterType], "float"))
		{
			float value = GetEventFloat(event, g_filters[filter][FilterKey]);
			if (value == StringToFloat(g_filters[filter][FilterValue]))
			{
				matches = true;
			}
		}

		if(matches == true)
		{
			points = RoundToZero(points * g_filters[filter][FilterMultiplier]);
			if (points >= 0)
			{
				points += g_filters[filter][FilterAddend];
			}
			else
			{
				points -= g_filters[filter][FilterAddend];
			}
		}
	}

	return points;
}