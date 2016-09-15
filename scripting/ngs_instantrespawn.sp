#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <clientprefs>
#include <morecolors>

#define PLUGIN_VERSION "1.4"

bool ToggleTags = true;
bool bEnabled = false;
bool bPlayerEnabled = false;
bool bClientEnabled[MAXPLAYERS + 1];

Handle g_hInstantRespawnEnabled;

ConVar cv_version;
ConVar cv_enabled;
ConVar cv_playerenabled;

public Plugin myinfo = {
	name = "[NGS] Instant Respawn",
	author = "ChauffeR / TheXeon",
	version = PLUGIN_VERSION,
	url = "http://hop.tf"
}

public void OnPluginStart()
{
	cv_version = CreateConVar("tf_instantrespawn_version", PLUGIN_VERSION, "Plugin Version of [TF2] Instant Respawn", FCVAR_SPONLY | FCVAR_NOTIFY | FCVAR_REPLICATED | FCVAR_DONTRECORD);
	cv_enabled = CreateConVar("tf_instantrespawn_enabled", "0", "If TF2 Instant Respawn for all is enabled.", FCVAR_SPONLY | FCVAR_NOTIFY | FCVAR_REPLICATED | FCVAR_DONTRECORD);
	cv_playerenabled = CreateConVar("tf_instantrespawn_player_enabled", "0", "If TF2 Instant Respawn for individual people is enabled.", FCVAR_SPONLY | FCVAR_NOTIFY | FCVAR_REPLICATED | FCVAR_DONTRECORD);
	
	RegConsoleCmd("sm_instantrespawn", CommandInstantRespawn, "Enables opt-in instant respawn.");
	
	HookEvent("player_death", OnPlayerDeath);
	
	if(TagsContain("norespawntime"))
	{
		ToggleTags = false;
	}
	TagsCheck("norespawntime");
	
	SetConVarString(cv_version, PLUGIN_VERSION);
	HookConVarChange(cv_version, cvhook_version);
	HookConVarChange(cv_enabled, cvhook_enabled);
	HookConVarChange(cv_playerenabled, cvhook_playerenabled);
	
	AutoExecConfig(true, "instantrespawn");
	
	g_hInstantRespawnEnabled = RegClientCookie("instantrespawnenabled", "If instantrespawn is enabled or not.", CookieAccess_Private);
	
	for (int i = 1; i <= MaxClients; i++)
    {
        if (!AreClientCookiesCached(i))
        {
            continue;
        }
        
        OnClientCookiesCached(i);
    }
}

public void OnClientCookiesCached(int client)
{
	char sInstantRespawnValue[8];
	
	GetClientCookie(client, g_hInstantRespawnEnabled, sInstantRespawnValue, sizeof(sInstantRespawnValue));
	
	if (StringToInt(sInstantRespawnValue) == 1) bClientEnabled[client] = true;
}

public Action CommandInstantRespawn(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	if (!bPlayerEnabled)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Sorry, but player instant respawn is not currently enabled!");
		return Plugin_Handled;
	}
	if (AreClientCookiesCached(client))
	{
		char cClientCookie[MAX_BUFFER_LENGTH];
		GetClientCookie(client, g_hInstantRespawnEnabled, cClientCookie, sizeof(cClientCookie));
		if(StrEqual(cClientCookie, "1", false)) SetClientCookie(client, g_hInstantRespawnEnabled, "0");
		else SetClientCookie(client, g_hInstantRespawnEnabled, "1");
		bClientEnabled[client] = !view_as<bool>(StringToInt(cClientCookie));
	}
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You have opted %s instant respawn.", bClientEnabled[client] ? "into" : "out of");
	return Plugin_Handled;
}

public void OnPluginEnd()
{
	if(ToggleTags == true)
	{
		TagsCheck("norespawntime", true);
	}
}

public void cvhook_version(Handle cvar, const char[] oldVal, const char[] newVal)
{
	if (strcmp(newVal, PLUGIN_VERSION, false) != 0)
		SetConVarString(cvar, PLUGIN_VERSION);
}
public void cvhook_enabled(Handle cvar, const char[] oldVal, const char[] newVal) { bEnabled = GetConVarBool(cvar); }
public void cvhook_playerenabled(Handle cvar, const char[] oldVal, const char[] newVal) { bPlayerEnabled = GetConVarBool(cvar); }

public Action OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	RequestFrame(Respawn, GetClientSerial(client));
}

public void Respawn(any serial)
{
	int client = GetClientFromSerial(serial);
	if(IsValidClient(client) && (bEnabled || bClientEnabled[client]))
	{
		int team = GetClientTeam(client);
		if(!IsPlayerAlive(client) && team != 1)
		{
			TF2_RespawnPlayer(client);
		}
	}
}

public bool TagsContain(const char[] tag)
{
	Handle hTags = FindConVar("sv_tags");
	char tags[255];
	GetConVarString(hTags, tags, sizeof(tags));
	if(StrContains(tags, tag) > -1)
	{
		return true;
	}
	else
	{
		return false;
	}
}

/*
Stock from WoZeR's code
*/

stock void TagsCheck(const char[] tag, bool remove = false)
{
	Handle hTags = FindConVar("sv_tags");
	char tags[255];
	GetConVarString(hTags, tags, sizeof(tags));

	if (StrContains(tags, tag, false) == -1 && !remove)
	{
		char newTags[255];
		Format(newTags, sizeof(newTags), "%s,%s", tags, tag);
		ReplaceString(newTags, sizeof(newTags), ",,", ",", false);
		SetConVarString(hTags, newTags);
		GetConVarString(hTags, tags, sizeof(tags));
	}
	else if (StrContains(tags, tag, false) > -1 && remove)
	{
		ReplaceString(tags, sizeof(tags), tag, "", false);
		ReplaceString(tags, sizeof(tags), ",,", ",", false);
		SetConVarString(hTags, tags);
	}
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