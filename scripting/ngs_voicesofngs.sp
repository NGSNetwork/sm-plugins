#include <sourcemod>
#include <tf2>
#include <sdktools>

#define PLUGIN_VERSION "1.0.0"

bool firstRespawn[MAXPLAYERS + 1];
char welcomeVoicelines[][] =  { "mad_welcome.wav", "hajun_welcome.wav", "aidsmirable_welcome.wav" };
// char tradeVoicelines[][] =  {  };

public Plugin myinfo = {
    name        = "[NGS] Voices of NGS",
    author      = "TheXeon",
    description = "Custom messages from our community <3",
    version     = PLUGIN_VERSION,
    url         = "https://neogenesisnetwork.net/"
}

public void OnPluginStart()
{
	HookEvent("post_inventory_application", OnPlayerInventory);
	// HookEvent("item_found", OnPlayerItemFound);
}

public void OnMapStart()
{
	PrecacheVoices();
}

public void PrecacheVoices()
{
	for (int i = 0; i < sizeof(welcomeVoicelines); i++)
	{
		char buffer[1024];
		Format(buffer, sizeof(buffer), "ngs/voicesofngs/%s", welcomeVoicelines[i]);
		PrecacheSound(buffer);
		Format(buffer, sizeof(buffer), "sound/%s", buffer);
		AddFileToDownloadsTable(buffer);
	}	
}

public void OnClientDisconnect(int client)
{
	firstRespawn[client] = false;
}
/*
public void OnPlayerItemFound(Event event, const char[] name, bool dontBroadcast)
{
	if(event.GetInt("method") == 4)
	{
		char playerName[MAX_NAME_LENGTH];
		GetClientName(event.GetInt("player"), playerName, sizeof(playerName));
		AnnounceUnbox(playerName);
	}
}
*/
public void OnPlayerInventory(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!firstRespawn[client])
	{
		firstRespawn[client] = true;
		if (GetRandomFloat() >= 0.5)
		{
			char buffer[1024];
			Format(buffer, sizeof(buffer), "ngs/voicesofngs/%s", welcomeVoicelines[GetRandomInt(0, sizeof(welcomeVoicelines) - 1)]);
			PrintToChat(client, "Playing sound %s.", buffer);
			EmitSoundToClient(client, buffer, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 5.0);
		}
	}
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