/**
* TheXeon
* ngs_celebrateunusual.sp
*
* Files:
* addons/sourcemod/plugins/ngs_celebrateunusual.smx
* Optional: the sound file below
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

ConVar cvarSoundFile, cvarSoundVolume;
char soundFile[PLATFORM_MAX_PATH];

Handle hHudText;

public Plugin myinfo = {
	name = "[NGS] Celebrate Unusual",
	author = "TheXeon",
	description = "A bombastic celebration of achieving an unusual!",
	version = "1.2.0",
	url = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	cvarSoundFile = CreateConVar("sm_celebrateunusual_file", "ngs/unusualcelebration/Sf13_bcon_misc17.wav", "The sound file relative to the sound folder played when someone gets an unusual.");
	cvarSoundVolume = CreateConVar("sm_celebrateunusual_volume", "3.5", "The sound to play when someone gets an unusual.", FCVAR_NONE, true, 0.0, true, 5.0);
	cvarSoundFile.AddChangeHook(OnSoundFileChanged);

	AutoExecConfig(true, "celebrateunusual.cfg");

	HookEvent("item_found", OnItemFound);
	LoadTranslations("common.phrases");

	cvarSoundFile.GetString(soundFile, sizeof(soundFile));
	char path[PLATFORM_MAX_PATH];
	Format(path, sizeof(path), "sound/%s", soundFile);
	if (FileExists(path))
	{
		AddFileToDownloadsTable(path);
	}

	if (GetEngineVersion() != Engine_TF2)
	{
		LogError("Attempting to run plugin on unsupported game!");
	}
}

public void OnMapStart()
{
	PrecacheSound(soundFile);
}

public void OnSoundFileChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char path[PLATFORM_MAX_PATH];
	Format(path, sizeof(path), "sound/%s", newValue);
	if (FileExists(path))
	{
		AddFileToDownloadsTable(path);
	}
	PrecacheSound(newValue);
	strcopy(soundFile, sizeof(soundFile), newValue);
}

public void OnItemFound(Event event, const char[] name, bool dontBroadcast)
{
	if(!event.GetBool("isFake") && event.GetInt("quality") == 5 && event.GetInt("method") == 4)
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
    
	ShowSyncHudTextAll(hHudText, "%N just unboxed an Unusual!", player);

	delete hHudText;
	float volume = cvarSoundVolume.FloatValue;
	while (volume > 0.0)
	{
		if (volume < 1.0)
			EmitSoundToAll(soundFile, _, _, _, SND_CHANGEVOL, volume);
		else
			EmitSoundToAll(soundFile);
		volume--;
	}
}