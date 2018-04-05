/**
* TheXeon
* ngs_voicemenuthrottler.sp
*
* Files:
* addons/sourcemod/plugins/ngs_voicemenuthrottler.smx
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

SMTimer voiceMenuTimer[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[NGS] VoiceMenu Throttler",
	author = "TheXeon",
	description = "Throttles voicemenu spam.",
	version = "1.2.0",
	url = "https://neogenesisnetwork.net"
}

public void OnPluginStart()
{
	RegConsoleCmd("voicemenu", OnPlayerVoiceMenu);
}

public Action OnPlayerVoiceMenu(int client, int args)
{
	if (voiceMenuTimer[client] != null)
	{
		return Plugin_Handled;
	}
	else
	{
		char CmdString[4];
		GetCmdArgString(CmdString, sizeof(CmdString));
		if (StrEqual(CmdString, "0 0"))
			voiceMenuTimer[client] = new SMTimer(0.5, OnVoiceMenuTimer, client);
		else
			voiceMenuTimer[client] = new SMTimer(0.1, OnVoiceMenuTimer, client);
		return Plugin_Continue;
	}
}

public Action OnVoiceMenuTimer(Handle timer, any client)
{
	voiceMenuTimer[client] = null;
}

public void OnClientDisconnect(int client)
{
	delete voiceMenuTimer[client];
}
