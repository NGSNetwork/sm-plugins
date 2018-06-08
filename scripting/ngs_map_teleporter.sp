/**
* TheXeon
* ngs_map_teleporter.sp
*
* Files:
* addons/sourcemod/plugins/ngs_map_teleporter.smx
*
* Dependencies:
* multicolors.inc, tf2_stocks.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <multicolors>
#include <tf2_stocks>
#include <autoexecconfig>
#include <ngsutils>
#include <ngsupdater>

//-------------------------------------------------------------------------------------------------

SMTimer teleportTimersSkybox[MAXPLAYERS + 1];

float skyboxredorigin[3];
float skyboxbluorigin[3];
float adminroomorigin[3];

ConVar cvarSkyboxTagEnabled;
ConVar cvarSkyboxTag;
ConVar cvarSkyboxTagCaseSensitive;
ConVar cvarMapNameContains;

KeyValues mapLocations;

public Plugin myinfo = {
	name = "[NGS] Per Map Teleport",
	author = "TheXeon",
	description = "A quick way to teleport players to map areas.",
	version = "1.2.0",
	url = "https://neogenesisnetwork.net"
}

public void OnPluginStart()
{
	RegAdminCmd("sm_reloadteleportlocs", CommandReloadTeleConfig, ADMFLAG_GENERIC, "Reloads the map config file.");
	RegConsoleCmd("sm_skybox", CommandSkybox, "Teleports you to the skybox!");
	RegAdminCmd("sm_adminroom", CommandAdminRoom, ADMFLAG_GENERIC, "Teleports you to the admin room!");

	AutoExecConfig_SetCreateDirectory(true);
	AutoExecConfig_SetCreateFile(true);
	bool appended;
	cvarSkyboxTag = AutoExecConfig_CreateConVarCheckAppend(appended, "skybox_tag", "NGS | ", "Tag to use if tag to skybox is enabled.");
	cvarSkyboxTagEnabled = AutoExecConfig_CreateConVarCheckAppend(appended, "skybox_tag_enabled", "1", "If allowing tag to skybox.");
	cvarSkyboxTagCaseSensitive = AutoExecConfig_CreateConVarCheckAppend(appended, "skybox_tag_case_sensitive", "1", "If tag to skybox is case sensitive.");
	cvarMapNameContains = AutoExecConfig_CreateConVarCheckAppend(appended, "maptele_config_contains", "1", "Whether map names in config will be checked partially or fully.");
	AutoExecConfig_ExecAndClean(appended);

	LoadConfig();

	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath);
}

public void LoadConfig()
{
	char configFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, configFile, sizeof(configFile), "configs/teleportlocations.cfg");
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
}

void FindMapCoords(char[] mapName)
{
	skyboxredorigin = NULL_VECTOR;
	skyboxbluorigin = NULL_VECTOR;
	adminroomorigin = NULL_VECTOR;
	char buffer[MAX_BUFFER_LENGTH];
	mapLocations.Rewind();
	if (!mapLocations.JumpToKey(mapName))
	{
		if (cvarMapNameContains.BoolValue)
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
	char skyboxbluBuffer[MAX_BUFFER_LENGTH], skyboxredBuffer[MAX_BUFFER_LENGTH],
		skyboxbluVector[3][MAX_BUFFER_LENGTH], skyboxredVector[3][MAX_BUFFER_LENGTH],
		adminroomBuffer[MAX_BUFFER_LENGTH], adminroomVector[3][MAX_BUFFER_LENGTH];
	mapLocations.GetString("skyboxblu", skyboxbluBuffer, sizeof(skyboxbluBuffer), "INV");
	mapLocations.GetString("skyboxred", skyboxredBuffer, sizeof(skyboxredBuffer), "INV");
	mapLocations.GetString("adminroom", adminroomBuffer, sizeof(adminroomBuffer), "INV");
	if (skyboxbluBuffer[0] != 'I' || skyboxredBuffer[0] != 'I' || adminroomBuffer[0] != 'I')
	{
		if (skyboxbluBuffer[0] != 'I')
		{
			ExplodeString(skyboxbluBuffer, ",", skyboxbluVector, sizeof(skyboxbluVector), sizeof(skyboxbluVector[]));
			for (int i = 0; i < 3; i++)
			{
				skyboxbluorigin[i] = StringToFloat(skyboxbluVector[i]);
			}
		}
		if (skyboxredBuffer[0] != 'I')
		{
			ExplodeString(skyboxredBuffer, ",", skyboxredVector, sizeof(skyboxredVector), sizeof(skyboxredVector[]));
			for (int i = 0; i < 3; i++)
			{
				skyboxredorigin[i] = StringToFloat(skyboxredVector[i]);
			}
		}
		if (adminroomBuffer[0] != 'I')
		{
			ExplodeString(adminroomBuffer, ",", adminroomVector, sizeof(adminroomVector), sizeof(adminroomVector[]));
			for (int i = 0; i < 3; i++)
			{
				adminroomorigin[i] = StringToFloat(adminroomVector[i]);
			}
		}
	}
	else
	{
		LogError("Invalidly formatted or missing location string in config file around Section \'%s\'. Make sure it is a comma separated 3d vector!", sectionName);
	}
}

public Action CommandSkybox(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;

	bool redIsValid = skyboxredorigin[0] != NULL_VECTOR[0], bluIsValid = skyboxbluorigin[0] != NULL_VECTOR[0];
	if (!redIsValid && !bluIsValid)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Skybox: Sorry! This plugin has not been configured on this map!");
		return Plugin_Handled;
	}
	else if (redIsValid ^ bluIsValid)
	{
		if (redIsValid && TF2_GetClientTeam(client) != TFTeam_Red)
		{
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Sorry! Please change team to {RED}RED{DEFAULT} to use this command!");
			return Plugin_Handled;
		}
		else if (/*bluIsValid && */TF2_GetClientTeam(client) != TFTeam_Blue)
		{
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Sorry! Please change team to {BLUE}BLUE{DEFAULT} to use this command!");
			return Plugin_Handled;
		}
	}
	if (!IsPlayerAlive(client))
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Sorry! You can only do this while you are alive!");
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
			teleportTimersSkybox[client] = new SMTimer(7.0, TeleportPlayerSkybox, GetClientUserId(client));
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Teleporting to the skybox in {PURPLE}7{DEFAULT} seconds!");
		}
		else
		{
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Go ahead and add \"%s\" to your name to access this.", tag);
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Here\'s our best guess for something you can paste in: %s %N", tag, client);
			if (CommandExists("sm_autotag"))
			{
				CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} The command {LIGHTGREEN}!autotag{DEFAULT} is enabled. You can use it to add the tag without affecting your Steam name!");
			}
		}
	}
	else
	{
		if (CheckCommandAccess(client, "sm_skybox_override", ADMFLAG_RESERVATION))
		{
			teleportTimersSkybox[client] = new SMTimer(7.0, TeleportPlayerSkybox, GetClientUserId(client));
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Teleporting to the skybox in {PURPLE}7{DEFAULT} seconds!");
		}
		else
		{
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Sorry, you don't have access to this command!");
		}
	}
	return Plugin_Handled;
}

public Action TeleportPlayerSkybox(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid); // this is probably unnecessary.
	if (!IsValidClient(client, true)) return; // this will probably never happen
	teleportTimersSkybox[client] = null;
	TFTeam clientTeam = view_as<TFTeam>(GetClientTeam(client));
	bool redIsValid = skyboxredorigin[0] != NULL_VECTOR[0], bluIsValid = skyboxbluorigin[0] != NULL_VECTOR[0];
	if (redIsValid ^ bluIsValid)
	{
		if (redIsValid)
		{
			TeleportEntity(client, skyboxredorigin, NULL_VECTOR, NULL_VECTOR);
		}
		else
		{
			TeleportEntity(client, skyboxbluorigin, NULL_VECTOR, NULL_VECTOR);
		}
	}
	else
	{
		if (clientTeam == TFTeam_Red)
		{
			TeleportEntity(client, skyboxredorigin, NULL_VECTOR, NULL_VECTOR);
		}
		else
		{
			TeleportEntity(client, skyboxbluorigin, NULL_VECTOR, NULL_VECTOR);
		}
	}
	if (CommandExists("sm_god") && CheckCommandAccess(client, "sm_adminroom", ADMFLAG_GENERIC))
	{
		ServerCommand("sm_god #%d 0", userid); // patchiest patch to ever patch
	}
	LogAction(client, -1, "Tele: %L teleported to the skybox!", client);
}

public Action CommandReloadTeleConfig(int client, int args)
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

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(client)) return;
 	if (teleportTimersSkybox[client] != null)
	{
		delete teleportTimersSkybox[client];
		CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Your teleportation to the skybox has been interrupted!");
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(client)) return;
 	if (teleportTimersSkybox[client] != null)
	{
		delete teleportTimersSkybox[client];
		CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Your teleportation to the skybox has been interrupted!");
	}
}

public void OnClientDisconnect(int client)
{
	delete teleportTimersSkybox[client];
}

public Action CommandAdminRoom(int client, int args)
{
	if(!IsValidClient(client, true))
	{
		return Plugin_Handled;
	}

	if (adminroomorigin[0] == NULL_VECTOR[0])
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Sorry! The plugin has not been configured on this map!");
		return Plugin_Handled;
	}

	if (CommandExists("sm_god"))
	{
		int playerUserID = GetClientUserId(client);
		ServerCommand("sm_god #%d 1", playerUserID);
	}
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Teleported to admin room!");

	TeleportEntity(client, adminroomorigin, NULL_VECTOR, NULL_VECTOR);

	LogAction(client, client, "Tele: %L teleported to the admin room!", client);

	return Plugin_Handled;
}
