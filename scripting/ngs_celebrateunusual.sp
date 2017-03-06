#pragma newdecls required
#pragma semicolon 1

#include <sdktools>
#include <sourcemod>
#include <morecolors>

#define PLUGIN_VERSION "1.1"

Handle hHudText;

//-------------------------------------------------------------------------------------------------
public Plugin myinfo = {
	name = "[NGS] Celebrate Unusual",
	author = "TheXeon",
	description = "A bombastic celebration of achieving an unusual!",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.net"
}

public void OnPluginStart()
{
	HookEvent("item_found", OnItemFound);
	LoadTranslations("common.phrases");
	PrecacheSound("ngs/unusualcelebration/sf13_bcon_misc17.wav");
	AddFileToDownloadsTable("sound/ngs/unusualcelebration/sf13_bcon_misc17.wav");
}

public void OnMapStart()
{
	PrecacheSound("ngs/unusualcelebration/sf13_bcon_misc17.wav");
}

public Action OnItemFound(Handle event, const char[] name, bool dontBroadcast)
{
    if(GetEventInt(event, "quality") == 5 && GetEventInt(event, "method") == 4)
    {
		char playerName[MAX_NAME_LENGTH];
		GetClientName(GetEventInt(event, "player"), playerName, sizeof(playerName));
		AnnounceUnbox(playerName);
		return;
	}
    return;
}

public void AnnounceUnbox(char[] player)
{
	hHudText = CreateHudSynchronizer();
	SetHudTextParams(-1.0, 0.1, 7.0, 255, 0, 0, 255, 1, 1.0, 1.0, 1.0);
    
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			ShowSyncHudText(i, hHudText, "%s just unboxed an Unusual!", player);
		}
	}
	CloseHandle(hHudText);
	EmitSoundToAll("ngs/unusualcelebration/sf13_bcon_misc17.wav");
	return;
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