#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <ccc>

#define PLUGIN_VERSION		"1.0.0"

KeyValues configFile;

public Plugin myinfo = {
	name        = "[NGS] Custom Chat Colors Group Override",
	author      = "TheXeon",
	description = "Custom Chat Colors with overrides!",
	version     = PLUGIN_VERSION,
	url         = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	RegAdminCmd("sm_reloadcccgo", CommandReloadConfig, ADMFLAG_CONFIG, "Reloads Custom Chat Colors Overrides config file");
}

public void OnAllPluginsLoaded()
{
	LoadConfig();
}

void LoadConfig()
{
	if (configFile != null)
	{
		 delete configFile;
		 configFile = null;
	}
	configFile = new KeyValues("override_colors");
	char path[64];
	BuildPath(Path_SM, path, sizeof(path), "configs/ccc_overrides.cfg");
	if (!configFile.ImportFromFile(path))
	{
		SetFailState("Config file missing");
	}
	for(int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
		{
			continue;
		}
		OnClientPostAdminCheck(i);
	}
}

public Action CommandReloadConfig(int client, int args)
{
	LoadConfig();
	LogAction(client, -1, "Reloaded Custom Chat Colors Group Overrides config file");
	ReplyToCommand(client, "[CCC] Reloaded overrides config file.");
	return Plugin_Handled;
}

public void OnClientPostAdminCheck(int client)
{
	configFile.Rewind();
	configFile.GotoFirstSubKey();
	char section[32];
	char override[128];
	bool found = false;
	do
	{
		configFile.GetSectionName(section, sizeof(section));
		configFile.GetString("override", override, sizeof(override));
		if (CheckCommandAccess(client, override, ADMFLAG_ROOT))
		{
			found = true;
			break;
		}
	} 
	while (configFile.GotoNextKey());
	if (!found)
	{
		return;
	}
	char tag[24];
	char clientTagColor[12];
	char clientNameColor[12];
	char clientChatColor[12];
	configFile.GetString("tag", tag, sizeof(tag));
	configFile.GetString("tagcolor", clientTagColor, sizeof(clientTagColor));
	configFile.GetString("namecolor", clientNameColor, sizeof(clientNameColor));
	configFile.GetString("textcolor", clientChatColor, sizeof(clientChatColor));
	ReplaceString(clientTagColor, sizeof(clientTagColor), "#", "");
	ReplaceString(clientNameColor, sizeof(clientNameColor), "#", "");
	ReplaceString(clientChatColor, sizeof(clientChatColor), "#", "");
	
	if (strlen(tag) > 0) CCC_SetTag(client, tag);
	if (strlen(clientTagColor) > 0) CCC_SetColor(client, CCC_TagColor, StringToInt(clientTagColor, 16), false);
	if (strlen(clientNameColor) > 0) CCC_SetColor(client, CCC_NameColor, StringToInt(clientNameColor, 16), false);
	if (strlen(clientChatColor) > 0) CCC_SetColor(client, CCC_ChatColor, StringToInt(clientChatColor, 16), false);
}
