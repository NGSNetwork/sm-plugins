#pragma newdecls required
#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "TheXeon"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <steamworks>
#include <tf2attributes>

bool isSteamWorksLoaded;
bool isTF2AttributesLoaded;


public Plugin myinfo = {
	name = "[TF2] Project Mann",
	author = PLUGIN_AUTHOR,
	description = "The plugin to overhaul the game!",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.servegame.com/"
}

public void OnPluginStart()
{
	char gameDescription[64];
	Format(gameDescription, sizeof(gameDescription), "Project Mann V%s", PLUGIN_VERSION);
	SteamWorks_SetGameDescription(gameDescription);
	HookEvent("post_inventory_application", )
}

public void OnLibraryAdded(char[] name)
{
	if (StrEqual(name, )

}

public void OnLibraryRemoved(char[] name)
{
	if (StrEqual)

}