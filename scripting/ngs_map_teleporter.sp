#pragma newdecls required
#pragma semicolon 1

#include <sdktools>
#include <sourcemod>
#include <morecolors>
#include <tf2_stocks>

#define PLUGIN_VERSION "1.1"

//-------------------------------------------------------------------------------------------------

Handle teleportTimersSkybox[MAXPLAYERS + 1];

float skyboxredorigin[3];
float skyboxbluorigin[3];

float adminroomorigin[3];

ConVar cvarSkyboxTagEnabled;
ConVar cvarSkyboxTag;
ConVar cvarSkyboxTagCaseSensitive;

public Plugin myinfo = {
	name = "[NGS] Per Map Teleport",
	author = "TheXeon",
	description = "A quick way to teleport players to map areas.",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.net"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_skybox", CommandSkybox, "Teleports you to the skybox!");
	RegAdminCmd("sm_adminroom", CommandAdminRoom, ADMFLAG_GENERIC, "Teleports you to the admin room!");
	
	cvarSkyboxTagEnabled = CreateConVar("sm_skybox_tag_enabled", "1", "If allowing tag to skybox.");
	cvarSkyboxTag = CreateConVar("sm_skybox_tag", "NGS | ", "Tag to use if tag to skybox is enabled.");
	cvarSkyboxTagCaseSensitive = CreateConVar("sm_skybox_tag_case_sensitive", "1", "If tag to skybox is case sensitive.");
	
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath);
}

public void OnMapStart()
{
	char mapName[MAX_BUFFER_LENGTH];
	GetCurrentMap(mapName, sizeof(mapName));
	if (StrContains(mapName, "trade_rawr_club_day_v3", false) != -1)
	{
		skyboxredorigin[0] = -984.273560;
		skyboxredorigin[1] = 26.774399;
		skyboxredorigin[2] = 2971.031250;
		skyboxbluorigin[0] = 64.983459;
		skyboxbluorigin[1] = 1319.008545;
		skyboxbluorigin[2] = 3020.925537;
		adminroomorigin[0] = -756.318359;
		adminroomorigin[1] = -3720.868408;
		adminroomorigin[2] = 5419.031250;
	}
	else if (StrContains(mapName, "trade_ngs_evening", false) != -1)
	{
		skyboxredorigin[0] = 6940.978516;
		skyboxredorigin[1] = -261.385651;
		skyboxredorigin[2] = 1855.671631;
		skyboxbluorigin[0] = 9880.611328;
		skyboxbluorigin[1] = 1609.373901;
		skyboxbluorigin[2] = 1832.255493;
		adminroomorigin[0] = 596.420349;
		adminroomorigin[1] = 93.558075;
		adminroomorigin[2] = -36.611389;
	}
	else
	{
		char filename[256];
		GetPluginFilename(INVALID_HANDLE, filename, sizeof(filename));
		ServerCommand("sm plugins unload %s", filename);
	}
}

public Action CommandSkybox(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	
	if (!IsPlayerAlive(client))
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Skybox: Sorry! You can only do this while you are alive!");
		return Plugin_Handled;
	}
	if (teleportTimersSkybox[client] != null)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You have already requested a teleport!");
		return Plugin_Handled;
	}
	if (cvarSkyboxTagEnabled.BoolValue)
	{
		char clientName[MAX_NAME_LENGTH];
		char tag[MAX_BUFFER_LENGTH];
		GetClientName(client, clientName, sizeof(clientName));
		cvarSkyboxTag.GetString(tag, sizeof(tag));
		if (StrContains(clientName, tag, cvarSkyboxTagCaseSensitive.BoolValue) != -1 || CheckCommandAccess(client, "sm_skybox_override", ADMFLAG_RESERVATION))
		{
			teleportTimersSkybox[client] = CreateTimer(7.0, TeleportPlayerSkybox, client);
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Teleporting to the skybox in {PURPLE}7{DEFAULT} seconds!");
			return Plugin_Handled;
		}
		else
		{
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Go ahead and add \"%s\" to your name to access this.", tag);
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Here\'s our best guess for something you can paste in: %s %N", tag, client);
			return Plugin_Handled;
		}
	}
	else
	{
		if (CheckCommandAccess(client, "sm_skybox_override", ADMFLAG_RESERVATION))
		{
			teleportTimersSkybox[client] = CreateTimer(7.0, TeleportPlayerSkybox, client);
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Teleporting to the skybox in {PURPLE}7{DEFAULT} seconds!");
			return Plugin_Handled;
		}
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Sorry, you don't have access to this command!");
		return Plugin_Handled;
	}
}

public Action TeleportPlayerSkybox(Handle timer, any client)
{
	TFTeam clientTeam = view_as<TFTeam>(GetClientTeam(client));
	if (clientTeam == TFTeam_Red) TeleportEntity(client, skyboxredorigin, NULL_VECTOR, NULL_VECTOR);
	else TeleportEntity(client, skyboxbluorigin, NULL_VECTOR, NULL_VECTOR);
	LogAction(client, -1, "Tele: %L teleported to the skybox!", client);
	teleportTimersSkybox[client] = null;
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
 	if (teleportTimersSkybox[client] != null)
	{
		KillTimer(teleportTimersSkybox[client]);
		teleportTimersSkybox[client] = null;
		CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Your teleportation to the skybox has been interrupted!");
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
 	if (teleportTimersSkybox[client] != null)
	{
		KillTimer(teleportTimersSkybox[client]);
		teleportTimersSkybox[client] = null;
		CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Your teleportation to the skybox has been interrupted!");
	}
}

public void OnClientDisconnect(int client)
{
	if (teleportTimersSkybox[client] != null)
	{
		KillTimer(teleportTimersSkybox[client]);
		teleportTimersSkybox[client] = null;
	}
}

public Action CommandAdminRoom(int client, int args)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client))
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Admin Room: Sorry! You can only do this while you are alive!");
		return Plugin_Handled;
	}
	
	int playerUserID = GetClientUserId(client);
	ServerCommand("sm_god #%d 1", playerUserID);
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Teleported to admin room!");
	
	TeleportEntity(client, adminroomorigin, NULL_VECTOR, NULL_VECTOR);
	
	LogAction(client, client, "Tele: %L teleported to the admin room!", client);

	return Plugin_Handled;
}

public bool IsValidClient(int client)
{
	if(client > 4096) client = EntRefToEntIndex(client);
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsFakeClient(client)) return false;
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}