#pragma newdecls required
#pragma semicolon 1

#include <sdktools>
#include <sourcemod>
#include <morecolors>

#define PLUGIN_VERSION "1.1"

float skyboxorigin[3] = {-622.707153, 1183.728271, 2972.568115};

//-------------------------------------------------------------------------------------------------
public Plugin myinfo = {
	name = "[NGS] Trade Rawr Club Day Teleport",
	author = "TheXeon",
	description = "A quick way to teleport players to the trade_rawr_club_day_v3 areas.",
	version = PLUGIN_VERSION,
	url = "matespastdates.servegame.com"
}

public void OnPluginStart()
{
	RegAdminCmd("sm_skybox", CommandSkybox, ADMFLAG_GENERIC, "Teleports you to the skybox!");
	RegAdminCmd("sm_adminroom", CommandAdminRoom, ADMFLAG_GENERIC, "Teleports you to the admin room!");
}

public Action CommandSkybox(int client, int args)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client))
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Skybox: Sorry! You can only do this while you are alive!");
		return Plugin_Handled;
	}
	
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Teleported to skybox!");
	
	TeleportEntity(client, skyboxorigin, NULL_VECTOR, NULL_VECTOR);
	
	LogAction(client, client, "Tele: %L teleported to the skybox!", client);

	return Plugin_Handled;
}

public Action CommandAdminRoom(int client, int args)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client))
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Admin Room: Sorry! You can only do this while you are alive!");
		return Plugin_Handled;
	}
	
	float adminroomorigin[3];
	adminroomorigin[0] = -756.318359;
	adminroomorigin[1] = -3720.868408;
	adminroomorigin[2] = 5419.031250;
	
	int playerUserID = GetClientUserId(client);
	ServerCommand("sm_god #%d", playerUserID);
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