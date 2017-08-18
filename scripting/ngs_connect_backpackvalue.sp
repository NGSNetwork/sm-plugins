#include <sourcemod>
#include <async>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "1.0.0"
#define BPVALUEURL "https://ngsnetwork.000webhostapp.com/?profile=" 

ConVar cvarKickEnabled;
ConVar cvarScoreboardEnabled;
ConVar cvarKickAmount;

int playerBpValue[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[NGS] BackpackValue - Async",
	author = "TheXeon",
	description = "Plugin to get bp value using Async.",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.net/"
}

public void OnPluginStart()
{
	ConVar cvarVer = CreateConVar("sm_bpa_version", PLUGIN_VERSION, "Filter by backpack using Async - version cvar", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	cvarKickEnabled = CreateConVar("sm_bpa_kick_enabled", "1", "Enable kicking people if their bp doesn\'t meet the required amount.", FCVAR_NONE, true, 1.0, true, 3.0);
	cvarScoreboardEnabled = CreateConVar("sm_bpa_scoreboard_enabled", "1", "Enable changing of scoreboard points to bp money value.", FCVAR_NONE);
	cvarKickAmount = CreateConVar("sm_bpa_kick_amount", "25", "Amount in USD that a player\'s bp should be to connect.", FCVAR_NONE);
	
	cvarVer.SetString(PLUGIN_VERSION);	
	AutoExecConfig(true, "ngs-connect-backpackvalue");
}

public void OnClientConnected(int client)
{
	char url[MAX_BUFFER_LENGTH], auth[24];
	GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
	Format(url, sizeof(url), "%s%s", BPVALUEURL, auth);
	CurlHandle h = Async_CurlNew(client);
	Async_CurlGet(h, url, OnRequestDone);
}

public void OnRequestDone(CurlHandle request, int curlcode, int httpcode, int size, any client)
{
	char buffer = new char[size+1];
	if(curlcode == 0 && httpcode == 200)
	{
		Async_CurlGetData(request, buffer, size + 1);
		if (StrContains(buffer, "invalid", false) != -1)
		{
			playerBpValue[client] = StringToInt(buffer);
			if (cvarKickEnabled.BoolValue && playerBpValue < cvarKickAmount.IntValue)
			{
				KickClient(client, "Kicked for not meeting bp value requirements.");
			}
			if (cvarScoreboardEnabled.BoolValue)
			{
				Se
			}
		}
	}
	Async_Close(request);
}