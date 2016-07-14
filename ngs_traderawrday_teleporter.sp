#include <sdktools>
#include <sourcemod>
#define VERSION "1.1"

//-------------------------------------------------------------------------------------------------
public Plugin myinfo = {
	name = [NGS] Trade Rawr Club Day Teleport",
	author = "TheXeon",
	description = "A quick way to teleport players to the trade_rawr_club_day_v3 areas.",
	version = VERSION,
	url = "matespastdates.servegame.com"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_skybox", CommandSkybox, "Teleports you to the skybox!");
	RegConsoleCmd("sm_adminroom", CommandAdminRoom, "Teleports you to the admin room!");
}

public Action CommandSkybox(client, args)
{
	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) <= 1 || !IsPlayerAlive(client))
	{
		ReplyToCommand(client, "[SM] Skybox: Sorry! You can only do this while you are alive!");
		return Plugin_Handled;
	}
	
	float skyboxorigin[3];
	skyboxorigin[0] = -622.707153;
	skyboxorigin[1] = 1183.728271;
	skyboxorigin[2] = 2972.568115;
	
	ReplyToCommand(client, "[SM] Teleported to skybox!");
	
	TeleportEntity(client, skyboxorigin, NULL_VECTOR, NULL_VECTOR);
	
	LogAction(client, client, "Tele: %L teleported to the skybox!", client);

	return Plugin_Handled;
}

public Action CommandAdminRoom(client, args)
{
	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) <= 1 || !IsPlayerAlive(client))
	{
		ReplyToCommand(client, "[SM] Admin Room: Sorry! You can only do this while you are alive!");
		return Plugin_Handled;
	}
	
	float adminroomorigin[3];
	adminroomorigin[0] = -756.318359;
	adminroomorigin[1] = -3720.868408;
	adminroomorigin[2] = 5419.031250;
	
	ReplyToCommand(client, "[SM] Teleported to admin room!");
	
	TeleportEntity(client, adminroomorigin, NULL_VECTOR, NULL_VECTOR);
	
	LogAction(client, client, "Tele: %L teleported to the admin room!", client);

	return Plugin_Handled;
}