/**
* TheXeon
* ngs_celebrateunusual.sp
*
* Files:
* addons/sourcemod/plugins/ngs_celebrateunusual.smx
* sound/ngs/unusualcelebration/sf13_bcon_misc17.wav
*
* Dependencies:
* sourcemod.inc, ccc.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <sourcemod>
#include <sdktools>
#include <ngsutils>
#include <ngsupdater>

Handle hHudText;

public Plugin myinfo = {
	name = "[NGS] Celebrate Unusual",
	author = "TheXeon",
	description = "A bombastic celebration of achieving an unusual!",
	version = "1.1.1",
	url = "https://neogenesisnetwork.net"
}

public void OnPluginStart()
{
	HookEvent("item_found", OnItemFound);
	LoadTranslations("common.phrases");
	PrecacheSound("ngs/unusualcelebration/Sf13_bcon_misc17.wav");
	AddFileToDownloadsTable("sound/ngs/unusualcelebration/Sf13_bcon_misc17.wav");
}

public void OnMapStart()
{
	PrecacheSound("ngs/unusualcelebration/Sf13_bcon_misc17.wav");
}

public void OnItemFound(Event event, const char[] name, bool dontBroadcast)
{
	if(event.GetInt("quality") == 5 && event.GetInt("method") == 4)
	{
		AnnounceUnbox(event.GetInt("player"));
	}
}

public void AnnounceUnbox(int player)
{
	if (!IsValidClient(player)) return;
	delete hHudText;
	hHudText = CreateHudSynchronizer();
	SetHudTextParams(-1.0, 0.1, 7.0, 255, 0, 0, 255, 1, 1.0, 1.0, 1.0);
    
	for (int i = 1; i <= MaxClients; i++)
		if (IsValidClient(i))
			ShowSyncHudText(i, hHudText, "%N just unboxed an Unusual!", player);

	delete hHudText;
	EmitSoundToAll("ngs/unusualcelebration/Sf13_bcon_misc17.wav");
	EmitSoundToAll("ngs/unusualcelebration/Sf13_bcon_misc17.wav");
	EmitSoundToAll("ngs/unusualcelebration/Sf13_bcon_misc17.wav");
	return;
}