#pragma semicolon 1

#include <sourcemod>
#include <multicolors>

//Store Includes
#include <store/store-core>
#include <store/store-logging>

#pragma newdecls required

#define PLUGIN_NAME "[Store] Distributor Module"
#define PLUGIN_DESCRIPTION "Distributor module for the Sourcemod Store."
#define PLUGIN_VERSION_CONVAR "store_distributor_version"

#define MAX_FILTERS 128

enum Filter
{
	String:FilterMap[128],
	FilterPlayerCount,
	FilterFlags,
	Float:FilterMultiplier,
	Float:FilterMinimumMultiplier,
	Float:FilterMaximumMultiplier,
	FilterAddend,
	FilterMinimumAddend,
	FilterMaximumAddend,
	FilterTeam
}

int g_filters[MAX_FILTERS][Filter];
int g_filterCount;

float g_timeInSeconds;
bool g_enableMessagePerTick;
int g_baseMinimum;
int g_baseMaximum;

char g_currencyName[64];

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = STORE_AUTHORS,
	description = PLUGIN_DESCRIPTION,
	version = STORE_VERSION,
	url = STORE_URL
};

public void OnPluginStart()
{
	LoadTranslations("store.phrases");

	CreateConVar(PLUGIN_VERSION_CONVAR, STORE_VERSION, PLUGIN_NAME, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);

	LoadConfig("Distributor", "configs/store/distributor.cfg");
}

public void OnConfigsExecuted()
{
	Store_GetCurrencyName(g_currencyName, sizeof(g_currencyName));
}

public void Store_OnDatabaseInitialized(Handle hDatabase)
{
	Store_RegisterPluginModule(PLUGIN_NAME, PLUGIN_DESCRIPTION, PLUGIN_VERSION_CONVAR, STORE_VERSION);
}

void LoadConfig(const char[] sName, const char[] sFile)
{
	Handle hKV = CreateKeyValues(sName);

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), sFile);

	if (!FileToKeyValues(hKV, sPath))
	{
		CloseHandle(hKV);
		SetFailState("Can't read config file %s", sPath);
	}

	g_timeInSeconds = KvGetFloat(hKV, "time_per_distribute", 180.0);
	g_enableMessagePerTick = view_as<bool>(KvGetNum(hKV, "enable_message_per_distribute", 1));

	if (KvJumpToKey(hKV, "distribution"))
	{
		g_baseMinimum = KvGetNum(hKV, "base_minimum", 1);
		g_baseMaximum = KvGetNum(hKV, "base_maximum", 3);

		if (KvJumpToKey(hKV, "filters"))
		{
			g_filterCount = 0;

			if (KvGotoFirstSubKey(hKV))
			{
				do
				{
					g_filters[g_filterCount][FilterMultiplier] = KvGetFloat(hKV, "multiplier", 1.0);
					g_filters[g_filterCount][FilterMinimumMultiplier] = KvGetFloat(hKV, "min_multiplier", 1.0);
					g_filters[g_filterCount][FilterMaximumMultiplier] = KvGetFloat(hKV, "max_multiplier", 1.0);

					g_filters[g_filterCount][FilterAddend] = KvGetNum(hKV, "addend");
					g_filters[g_filterCount][FilterMinimumAddend] = KvGetNum(hKV, "min_addend");
					g_filters[g_filterCount][FilterMaximumAddend] = KvGetNum(hKV, "max_addend");

					g_filters[g_filterCount][FilterPlayerCount] = KvGetNum(hKV, "player_count", 0);
					g_filters[g_filterCount][FilterTeam] = KvGetNum(hKV, "team", -1);

					char flags[32];
					KvGetString(hKV, "flags", flags, sizeof(flags));

					if (strlen(flags) != 0)
					{
						g_filters[g_filterCount][FilterFlags] = ReadFlagString(flags);
					}

					KvGetString(hKV, "map", g_filters[g_filterCount][FilterMap], 32);

					g_filterCount++;
				} while (KvGotoNextKey(hKV));
			}
		}
	}

	CloseHandle(hKV);

	CreateTimer(g_timeInSeconds, ForgivePoints, _, TIMER_REPEAT);

	Store_LogInformational("Store Config '%s' Loaded: %s", sName, sFile);
}

public Action ForgivePoints(Handle timer)
{
	char map[128];
	GetCurrentMap(map, sizeof(map));

	int clientCount = GetClientCount();

	int[] accountIds = new int[MaxClients];
	int[] credits = new int[MaxClients];

	int count;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || IsClientObserver(i))
		{
			continue;
		}

		accountIds[count] = GetSteamAccountID(i);
		credits[count] = Calculate(i, map, clientCount);

		if (g_enableMessagePerTick)
		{
			CPrintToChat(i, "%t%t", "Store Tag Colored", "Received Credits", credits[count], g_currencyName);
		}

		count++;
	}

	Store_GiveDifferentCreditsToUsers(accountIds, count, credits);
}

int Calculate(int client, const char[] map, int clientCount)
{
	int min = g_baseMinimum;
	int max = g_baseMaximum;

	for (int i = 0; i < g_filterCount; i++)
	{
		if ((g_filters[i][FilterPlayerCount] == 0 || clientCount >= g_filters[i][FilterPlayerCount]) && (StrEqual(g_filters[i][FilterMap], "") || StrEqual(g_filters[i][FilterMap], map)) && (g_filters[i][FilterFlags] == 0 || HasPermission(client, g_filters[i][FilterFlags])) && (g_filters[i][FilterTeam] == -1 || g_filters[i][FilterTeam] == GetClientTeam(client)))
		{
			min = RoundToZero(min * g_filters[i][FilterMultiplier] * g_filters[i][FilterMinimumMultiplier]) + g_filters[i][FilterAddend] + g_filters[i][FilterMinimumAddend];
			max = RoundToZero(max * g_filters[i][FilterMultiplier] * g_filters[i][FilterMaximumMultiplier]) + g_filters[i][FilterAddend] + g_filters[i][FilterMaximumAddend];
		}
	}

	return GetRandomInt(min, max);
}

bool HasPermission(int client, int flags)
{
	AdminId admin = GetUserAdmin(client);

	if (admin == INVALID_ADMIN_ID)
	{
		return false;
	}

	int count; int found;
	for (int i = 0; i <= 20; i++)
	{
		if (flags & (1 << i))
		{
			count++;

			if (GetAdminFlag(admin, view_as<AdminFlag>(i)))
			{
				found++;
			}
		}
	}

	if (count == found)
	{
		return true;
	}

	return false;
}
