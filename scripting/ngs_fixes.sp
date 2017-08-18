#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION "1.0.0"

ConVar cvarDisableDoveSpawn;

public Plugin myinfo = 
{
	name = "[NGS] Game Fixes",
	author = "TheXeon",
	description = "Small plugin including changes for NGS server.",
	version = PLUGIN_VERSION,
	url = "https://www.neogenesisnetwork.net/"
}

public void OnPluginStart()
{
	cvarDisableDoveSpawn = CreateConVar("sm_ngsfixes_disable_doves", "1", "Should the plugin disable dove spawning.");
	HookUserMessage(GetUserMessageId("SpawnFlyingBird"), UserMsg_SpawnBird, true);
}

public Action UserMsg_SpawnBird(UserMsg msg_id, Handle bf, const players[], int playersNum, bool reliable, bool init)
{
	if (!cvarDisableDoveSpawn.BoolValue) return Plugin_Continue;
	return Plugin_Stop;
}