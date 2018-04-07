/**
* TheXeon
* ngs_enabledisableplugins.sp
*
* Files:
* addons/sourcemod/plugins/ngs_enabledisableplugins.smx
*
* Dependencies:
* multicolors.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <multicolors>
#include <ngsutils>
#include <ngsupdater>

#define USE_SOURCEMOD_ADMIN_COMMAND	//comment this line out to make the plugin use rcon commands only.

bool DEBUG_PATH = false;

public Plugin myinfo = {
	name = "[NGS] Plugin Enable/Disable",
	author = "DarthNinja / TheXeon",
	description = "Allows you to enable or disable a plugin by command.",
	version = "1.1.0",
	url = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	#if defined USE_SOURCEMOD_ADMIN_COMMAND
		RegAdminCmd("sm_plugins", DisEnablePlugin, ADMFLAG_ROOT, "sm_plugins <enable/disable> <file> <force>");
	#else
		RegServerCmd("sm_plugins", DisEnablePlugin, "sm_plugins <enable/disable> <file> <force>");
	#endif
}


#if defined USE_SOURCEMOD_ADMIN_COMMAND
public Action DisEnablePlugin(int client, int args)	//dat grammar
{
#else
public Action DisEnablePlugin(int args)
{
	int client = 0;
#endif

	if (args < 2)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: plugins <enable/disable> <file>");
		return Plugin_Handled;
	}
	char command[12], plugin_file[64], disabledpath[256], enabledpath[256], forced[12];
	GetCmdArg(1, command, sizeof(command));
	GetCmdArg(2, plugin_file, sizeof(plugin_file));
	GetCmdArg(3, forced, sizeof(forced));

	if (StrContains(plugin_file, ";", false) != -1)
		return Plugin_Handled;	// prevent badmins trying to exploit ServerCommand();
	if (StrContains(plugin_file, ".smx", false) != -1)
		ReplaceString(plugin_file, sizeof(plugin_file), ".smx", "", false);	//strip out .smx since we have it formatted below.

	BuildPath(Path_SM, disabledpath, sizeof(disabledpath), "plugins/disabled/%s.smx", plugin_file);	
	BuildPath(Path_SM, enabledpath, sizeof(enabledpath), "plugins/%s.smx", plugin_file);	
	char PluginWExt[70];
	Format(PluginWExt, sizeof(PluginWExt), "%s.smx", plugin_file);

	if (DEBUG_PATH)
	{
		CReplyToCommand(client, disabledpath);
		CReplyToCommand(client, enabledpath);
	}

	if (StrContains(command, "enable", false) == 0)
	{
		if (!FileExists(disabledpath))
		{
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT}: The plugin file could not be found.");
			return Plugin_Handled;
		}
		if (FileExists(enabledpath))
		{
			if (!StrEqual(forced, "1"))
			{
				CReplyToCommand(client, "{GREEN}[SM]{DEFAULT}: An existing plugin file (%s) has been detected that conflicts with the one being moved. No action has been taken. Use an extra 1 to force it!", enabledpath);
				return Plugin_Handled;
			}
			else
			{
				CReplyToCommand(client, "{GREEN}[SM]{DEFAULT}: Move is being forced!");
				ServerCommand("sm plugins unload %s", plugin_file);
				DeleteFile(enabledpath);
			}
		}

		RenameFile(enabledpath, disabledpath);
		ServerCommand("sm plugins load %s", plugin_file);
		DataPack pack;
		SMDataTimer.Make(0.1, ReplyPluginStatus, pack);	// delay long enough for the plugin to load
		pack.WriteString(PluginWExt);
		pack.WriteCell(view_as<int>(GetCmdReplySource()));
		if (client != 0)
			pack.WriteCell(GetClientUserId(client));
		else 
			pack.WriteCell(0);
	}
	else if (StrContains(command, "disable", false) == 0)
	{
		if (!FileExists(enabledpath))
		{
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT}: The plugin file could not be found.");
			return Plugin_Handled;
		}
		if (FileExists(disabledpath))
		{
			if (!StrEqual(forced, "1"))
			{
				CReplyToCommand(client, "{GREEN}[SM]{DEFAULT}: An existing plugin file (%s) has been detected that conflicts with the one being moved.  No action has been taken. Use an extra 1 to force it!", disabledpath);
				return Plugin_Handled;
			}
			else
			{
				CReplyToCommand(client, "{GREEN}[SM]{DEFAULT}: Move is being forced!");
				DeleteFile(disabledpath);
			}
		}

		Handle Loaded = FindPluginByFile(PluginWExt);
		char PluginName[128];
		if (Loaded != null)
			GetPluginInfo(Loaded, PlInfo_Name, PluginName, sizeof(PluginName));
		else
			strcopy(PluginName, sizeof(PluginName), PluginWExt);
		ServerCommand("sm plugins unload %s", plugin_file);
		RenameFile(disabledpath, enabledpath);

		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT}: The plugin '{YELLOW}%s{DEFAULT}' has been unloaded and moved to the /disabled/ directory.", PluginName);
	}
	else
		CReplyToCommand(client, "[SM] Usage: sm_plugin <enable/disable> <file> <force>");
	return Plugin_Handled;
}

public Action ReplyPluginStatus(Handle timer, DataPack pack)
{
	pack.Reset();
	char PluginWExt[70];
	pack.ReadString(PluginWExt, sizeof(PluginWExt));
	ReplySource reply = view_as<ReplySource>(pack.ReadCell());
	SetCmdReplySource(reply);
	int client = pack.ReadCell();
	if (client != 0)
		client = GetClientOfUserId(client);
	
	Handle Loaded = FindPluginByFile(PluginWExt);
	if (Loaded != null)
	{
		char PluginName[128];
		GetPluginInfo(Loaded, PlInfo_Name, PluginName, sizeof(PluginName));
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT}: Enabled and loaded plugin '{YELLOW}%s{DEFAULT}'!", PluginName);
	}
	else
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT}: The plugin file '{YELLOW}%s{DEFAULT}' was enabled, but it was not able to be loaded.\n{LIGHTGREEN}[SM]{DEFAULT}: Use '{OLIVE}sm plugins load %s{DEFAULT}' to try to load the plugin manually.", PluginWExt, PluginWExt);
}
