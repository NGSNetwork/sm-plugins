#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <morecolors>

#define PLUGIN_VERSION "1.0"

Handle voiceMenuTimer[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[NGS] VoiceMenu Throttler",
	author = "TheXeon",
	description = "Throttles voicemenu spam.",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.net"
}

public void OnPluginStart()
{
	RegConsoleCmd("voicemenu", OnPlayerVoiceMenu);
}

public Action OnPlayerVoiceMenu(int client, int args)
{
	if (voiceMenuTimer[client] != null)
		return Plugin_Handled;
	else
	{
		char CmdString[4];
		GetCmdArgString(CmdString, sizeof(CmdString));
		if (StrEqual(CmdString, "0 0")) voiceMenuTimer[client] = CreateTimer(0.5, OnVoiceMenuTimer, client);
		else voiceMenuTimer[client] = CreateTimer(0.1, OnVoiceMenuTimer, client);
		return Plugin_Continue;
	}
}

public Action OnVoiceMenuTimer(Handle timer, any client)
{
	if (voiceMenuTimer[client] != null)
	{
		KillTimer(voiceMenuTimer[client]);
		voiceMenuTimer[client] = null;
	}
}