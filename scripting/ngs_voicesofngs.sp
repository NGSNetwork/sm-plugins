#include <sourcemod>
#include <tf2>
#include <sdktools>
#include <clientprefs>
#include <multicolors>

#define PLUGIN_VERSION "1.0.0"

Handle voicesEnabledCookie;
bool firstRespawn[MAXPLAYERS + 1];
char welcomeVoicelines[][] =  { "mad_welcome.wav", "hajun_welcome.wav", "aidsmirable_welcome.wav", "hughmungus_welcome.wav" };
char tradeVoicelines[][] =  { "mad_trade.wav", "hughmungus_trade.wav", "hajun_trade.wav", "aidsmirable_trade.wav" };

public Plugin myinfo = {
    name        = "[NGS] Voices of NGS",
    author      = "TheXeon",
    description = "Custom messages from our community <3",
    version     = PLUGIN_VERSION,
    url         = "https://www.neogenesisnetwork.net/"
}

public void OnPluginStart()
{
	HookEvent("post_inventory_application", OnPlayerInventory);
	voicesEnabledCookie = RegClientCookie("voicesofngsenabled", "Are Voices of NGS Enabled?", CookieAccess_Public);
}

public void OnMapStart()
{
	PrecacheVoices();
}

public void PrecacheVoices()
{
	for (int i = 0; i < sizeof(welcomeVoicelines); i++)
	{
		char buffer[MAX_BUFFER_LENGTH], path[MAX_BUFFER_LENGTH];
		Format(buffer, sizeof(buffer), "ngs/voicesofngs/%s", welcomeVoicelines[i]);
		PrecacheSound(buffer);
		Format(path, sizeof(path), "sound/%s", buffer);
		AddFileToDownloadsTable(path);
	}
	for (int i = 0; i < sizeof(tradeVoicelines); i++)
	{
		char buffer[MAX_BUFFER_LENGTH], path[MAX_BUFFER_LENGTH];
		Format(buffer, sizeof(buffer), "ngs/voicesofngs/%s", tradeVoicelines[i]);
		PrecacheSound(buffer);
		Format(path, sizeof(path), "sound/%s", buffer);
		AddFileToDownloadsTable(path);
	}	
}

public void OnClientDisconnect(int client)
{
	firstRespawn[client] = false;
}

public void OnPlayerItemFound(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (event.GetInt("method") == 2 && GetRandomFloat() >= 0.5)
	{
		char buffer[1024];
		Format(buffer, sizeof(buffer), "ngs/voicesofngs/%s", tradeVoicelines[GetRandomInt(0, sizeof(tradeVoicelines) - 1)]);
		CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Playing sound %s.", buffer);
		EmitSoundToClient(client, buffer, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 5.0);
	}
}

public void OnPlayerInventory(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!firstRespawn[client])
	{
		firstRespawn[client] = true;
		//if (GetRandomFloat() >= 0.5)
		//{
			char buffer[1024];
			Format(buffer, sizeof(buffer), "ngs/voicesofngs/%s", welcomeVoicelines[GetRandomInt(0, sizeof(welcomeVoicelines) - 1)]);
			CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Playing sound %s.", buffer);
			EmitSoundToClient(client, buffer);
			EmitSoundToClient(client, buffer);
			EmitSoundToClient(client, buffer);
		//}
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