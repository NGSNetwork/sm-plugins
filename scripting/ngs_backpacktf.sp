/****************************************************************
*																*
*	Make sure to use cfg/sourcemod/plugin.ngs_backpacktf.cfg	*
*																*
****************************************************************/

// TODO: Convert to Backpack.tf v4 API

#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <steamtools>
//#include <webfix>
#include <advanced_motd>

#define PLUGIN_VERSION		"2.11.2"
#define BACKPACK_TF_URL		"http://backpack.tf/api/IGetPrices/v3/"
#define ITEM_EARBUDS		143
#define ITEM_REFINED		5002
#define ITEM_KEY			5021
#define ITEM_CRATE			5022
#define ITEM_SALVAGED_CRATE	5068
#define ITEM_HAUNTED_SCRAP	267
#define ITEM_HEADTAKER		266
#define QUALITY_UNIQUE		"6"
#define QUALITY_UNUSUAL		"5"
#define NOTIFICATION_SOUND	"replay/downloadcomplete.wav"

public Plugin myinfo = {
	name        = "[NGS] backpack.tf Price Check",
	author      = "Dr. McKay / TheXeon",
	description = "Provides a price check command for use with backpack.tf",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
}

int lastCacheTime;
int cacheTime;
Handle backpackTFPricelist;

Handle qualityNameTrie;
Handle unusualNameTrie;

ConVar cvarBPCommand;
ConVar cvarDisplayUpdateNotification;
ConVar cvarDisplayChangedPrices;
ConVar cvarHudXPos;
ConVar cvarHudYPos;
ConVar cvarHudRed;
ConVar cvarHudGreen;
ConVar cvarHudBlue;
ConVar cvarHudHoldTime;
ConVar cvarMenuHoldTime;
ConVar cvarAPIKey;
ConVar cvarTag;

Handle hudText;
Handle sv_tags;

float budsToKeys;
float keysToRef;
float refToUsd;

public void OnPluginStart() {
	cvarBPCommand = CreateConVar("backpack_tf_bp_command", "1", "Enables the !bp command for use with backpack.tf");
	cvarDisplayUpdateNotification = CreateConVar("backpack_tf_display_update_notification", "1", "Display a notification to clients when the cached price list has been updated?");
	cvarDisplayChangedPrices = CreateConVar("backpack_tf_display_changed_prices", "1", "If backpack_tf_display_update_notification is set to 1, display all prices that changed since the last update?");
	cvarHudXPos = CreateConVar("backpack_tf_update_notification_x_pos", "-1.0", "X position for HUD text from 0.0 to 1.0, -1.0 = center", _, true, -1.0, true, 1.0);
	cvarHudYPos = CreateConVar("backpack_tf_update_notification_y_pos", "0.1", "Y position for HUD text from 0.0 to 1.0, -1.0 = center", _, true, -1.0, true, 1.0);
	cvarHudRed = CreateConVar("backpack_tf_update_notification_red", "0", "Red value of HUD text", _, true, 0.0, true, 255.0);
	cvarHudGreen = CreateConVar("backpack_tf_update_notification_green", "255", "Green value of HUD text", _, true, 0.0, true, 255.0);
	cvarHudBlue = CreateConVar("backpack_tf_update_notification_blue", "0", "Blue value of HUD text", _, true, 0.0, true, 255.0);
	cvarHudHoldTime = CreateConVar("backpack_tf_update_notification_message_time", "5", "Seconds to keep each message in the update ticker on the screen", _, true, 0.0);
	cvarMenuHoldTime = CreateConVar("backpack_tf_menu_open_time", "0", "Time to keep the price panel open for, 0 = forever");
	cvarAPIKey = CreateConVar("backpack_tf_api_key", "", "API key obtained at http://backpack.tf/api/register/", FCVAR_PROTECTED);
	cvarTag = CreateConVar("backpack_tf_add_tag", "1", "If 1, adds the backpack.tf tag to your server's sv_tags, which is required to be listed on http://backpack.tf/servers", _, true, 0.0, true, 1.0);
	AutoExecConfig();
	
	LoadTranslations("backpack-tf.phrases");
	
	sv_tags = FindConVar("sv_tags");
	
	RegConsoleCmd("sm_bp", Command_Backpack, "Usage: sm_bp <player>");
	RegConsoleCmd("sm_backpack", Command_Backpack, "Usage: sm_backpack <player>");
	
	RegConsoleCmd("sm_pc", Command_PriceCheck, "Usage: sm_pc <item>");
	RegConsoleCmd("sm_pricecheck", Command_PriceCheck, "Usage: sm_pricecheck <item>");
	
	RegAdminCmd("sm_updateprices", Command_UpdatePrices, ADMFLAG_ROOT, "Updates backpack.tf prices");
	
	qualityNameTrie = CreateTrie();
	SetTrieString(qualityNameTrie, "0", "Normal");
	SetTrieString(qualityNameTrie, "1", "Genuine");
	SetTrieString(qualityNameTrie, "2", "rarity2");
	SetTrieString(qualityNameTrie, "3", "Vintage");
	SetTrieString(qualityNameTrie, "4", "rarity3");
	SetTrieString(qualityNameTrie, "5", "Unusual");
	SetTrieString(qualityNameTrie, "6", "Unique");
	SetTrieString(qualityNameTrie, "7", "Community");
	SetTrieString(qualityNameTrie, "8", "Valve");
	SetTrieString(qualityNameTrie, "9", "Self-Made");
	SetTrieString(qualityNameTrie, "10", "Customized");
	SetTrieString(qualityNameTrie, "11", "Strange");
	SetTrieString(qualityNameTrie, "12", "Completed");
	SetTrieString(qualityNameTrie, "13", "Haunted");
	SetTrieString(qualityNameTrie, "14", "Collector's");
	SetTrieString(qualityNameTrie, "300", "Uncraftable Vintage"); // custom for backpack.tf
	SetTrieString(qualityNameTrie, "600", "Uncraftable"); // custom for backpack.tf
	SetTrieString(qualityNameTrie, "1100", "Uncraftable Strange"); // custom for backpack.tf
	SetTrieString(qualityNameTrie, "1300", "Uncraftable Haunted"); // custom for backpack.tf
	
	unusualNameTrie = CreateTrie();
	// Original effects
	SetTrieString(unusualNameTrie, "6", "Green Confetti");
	SetTrieString(unusualNameTrie, "7", "Purple Confetti");
	SetTrieString(unusualNameTrie, "8", "Haunted Ghosts");
	SetTrieString(unusualNameTrie, "9", "Green Energy");
	SetTrieString(unusualNameTrie, "10", "Purple Energy");
	SetTrieString(unusualNameTrie, "11", "Circling TF Logo");
	SetTrieString(unusualNameTrie, "12", "Massed Flies");
	SetTrieString(unusualNameTrie, "13", "Burning Flames");
	SetTrieString(unusualNameTrie, "14", "Scorching Flames");
	SetTrieString(unusualNameTrie, "15", "Searing Plasma");
	SetTrieString(unusualNameTrie, "16", "Vivid Plasma");
	SetTrieString(unusualNameTrie, "17", "Sunbeams");
	SetTrieString(unusualNameTrie, "18", "Circling Peace Sign");
	SetTrieString(unusualNameTrie, "19", "Circling Heart");
	// Batch 2
	SetTrieString(unusualNameTrie, "29", "Stormy Storm");
	SetTrieString(unusualNameTrie, "30", "Blizzardy Storm");
	SetTrieString(unusualNameTrie, "31", "Nuts n' Bolts");
	SetTrieString(unusualNameTrie, "32", "Orbiting Planets");
	SetTrieString(unusualNameTrie, "33", "Orbiting Fire");
	SetTrieString(unusualNameTrie, "34", "Bubbling");
	SetTrieString(unusualNameTrie, "35", "Smoking");
	SetTrieString(unusualNameTrie, "36", "Steaming");
	// Halloween
	SetTrieString(unusualNameTrie, "37", "Flaming Lantern");
	SetTrieString(unusualNameTrie, "38", "Cloudy Moon");
	SetTrieString(unusualNameTrie, "39", "Cauldron Bubbles");
	SetTrieString(unusualNameTrie, "40", "Eerie Orbiting Fire");
	SetTrieString(unusualNameTrie, "43", "Knifestorm");
	SetTrieString(unusualNameTrie, "44", "Misty Skull");
	SetTrieString(unusualNameTrie, "45", "Harvest Moon");
	SetTrieString(unusualNameTrie, "46", "It's A Secret To Everybody");
	SetTrieString(unusualNameTrie, "47", "Stormy 13th Hour");
	// Batch 3
	SetTrieString(unusualNameTrie, "56", "Kill-a-Watt");
	SetTrieString(unusualNameTrie, "57", "Terror-Watt");
	SetTrieString(unusualNameTrie, "58", "Cloud 9");
	SetTrieString(unusualNameTrie, "59", "Aces High");
	SetTrieString(unusualNameTrie, "60", "Dead Presidents");
	SetTrieString(unusualNameTrie, "61", "Miami Nights");
	SetTrieString(unusualNameTrie, "62", "Disco Beat Down");
	// Robo-effects
	SetTrieString(unusualNameTrie, "63", "Phosphorous");
	SetTrieString(unusualNameTrie, "64", "Sulphurous");
	SetTrieString(unusualNameTrie, "65", "Memory Leak");
	SetTrieString(unusualNameTrie, "66", "Overclocked");
	SetTrieString(unusualNameTrie, "67", "Electrostatic");
	SetTrieString(unusualNameTrie, "68", "Power Surge");
	SetTrieString(unusualNameTrie, "69", "Anti-Freeze");
	SetTrieString(unusualNameTrie, "70", "Time Warp");
	SetTrieString(unusualNameTrie, "71", "Green Black Hole");
	SetTrieString(unusualNameTrie, "72", "Roboactive");
	// Halloween 2013
	SetTrieString(unusualNameTrie, "73", "Arcana");
	SetTrieString(unusualNameTrie, "74", "Spellbound");
	SetTrieString(unusualNameTrie, "75", "Chiroptera Venenata");
	SetTrieString(unusualNameTrie, "76", "Poisoned Shadows");
	SetTrieString(unusualNameTrie, "77", "Something Burning This Way Comes");
	SetTrieString(unusualNameTrie, "78", "Hellfire");
	SetTrieString(unusualNameTrie, "79", "Darkblaze");
	SetTrieString(unusualNameTrie, "80", "Demonflame");
	// Halloween 2014
	SetTrieString(unusualNameTrie, "81", "Bonzo The All-Gnawing");
	SetTrieString(unusualNameTrie, "82", "Amaranthine");
	SetTrieString(unusualNameTrie, "83", "Stare From Beyond");
	SetTrieString(unusualNameTrie, "84", "The Ooze");
	SetTrieString(unusualNameTrie, "85", "Ghastly Ghosts Jr");
	SetTrieString(unusualNameTrie, "86", "Haunted Phantasm Jr");
	// EOTL
	SetTrieString(unusualNameTrie, "87", "Frostbite");
	SetTrieString(unusualNameTrie, "88", "Molten Mallard");
	SetTrieString(unusualNameTrie, "89", "Morning Glory");
	SetTrieString(unusualNameTrie, "90", "Death at Dusk");
	// Invasion effects
	SetTrieString(unusualNameTrie, "91", "Abduction");
	SetTrieString(unusualNameTrie, "92", "Atomic");
	SetTrieString(unusualNameTrie, "93", "Subatomic");
	SetTrieString(unusualNameTrie, "94", "Electric Hat Protector");
	SetTrieString(unusualNameTrie, "95", "Magnetic Hat Protector");
	SetTrieString(unusualNameTrie, "96", "Voltaic Hat Protector");
	SetTrieString(unusualNameTrie, "97", "Galactic Codex");
	SetTrieString(unusualNameTrie, "98", "Ancient Codex");
	SetTrieString(unusualNameTrie, "99", "Nebula");
	// Halloween 2015
	SetTrieString(unusualNameTrie, "100", "Death by Disco");
	SetTrieString(unusualNameTrie, "101", "It's a mystery to everyone");
	SetTrieString(unusualNameTrie, "102", "It's a puzzle to me");
	SetTrieString(unusualNameTrie, "103", "Ether Trail");
	SetTrieString(unusualNameTrie, "104", "Nether Trail");
	SetTrieString(unusualNameTrie, "105", "Ancient Eldritch");
	SetTrieString(unusualNameTrie, "106", "Eldritch Flame");
	// Halloween 2016
	SetTrieString(unusualNameTrie, "107", "Neutron Star");
	SetTrieString(unusualNameTrie, "108", "Tesla Coil");
	SetTrieString(unusualNameTrie, "109", "Sandstorm Insomnia");
	SetTrieString(unusualNameTrie, "110", "Sandstorm Slumber");
	// Taunt effects
	SetTrieString(unusualNameTrie, "3001", "Showstopper");
	SetTrieString(unusualNameTrie, "3002", "Showstopper");
	SetTrieString(unusualNameTrie, "3003", "Holy Grail");
	SetTrieString(unusualNameTrie, "3004", "'72");
	SetTrieString(unusualNameTrie, "3005", "Fountain of Delight");
	SetTrieString(unusualNameTrie, "3006", "Screaming Tiger");
	SetTrieString(unusualNameTrie, "3007", "Skill Gotten Gains");
	SetTrieString(unusualNameTrie, "3008", "Midnight Whirlwind");
	SetTrieString(unusualNameTrie, "3009", "Silver Cyclone");
	SetTrieString(unusualNameTrie, "3010", "Mega Strike");
	// Halloween 2014 taunt effects
	SetTrieString(unusualNameTrie, "3011", "Haunted Phantasm");
	SetTrieString(unusualNameTrie, "3012", "Ghastly Ghosts");
	// Halloween 2016 taunt effects
	SetTrieString(unusualNameTrie, "3013", "Hellish Inferno");
	SetTrieString(unusualNameTrie, "3014", "Spectral Swirl");
	SetTrieString(unusualNameTrie, "3015", "Infernal Flames");
	SetTrieString(unusualNameTrie, "3016", "Infernal Smoke");
	
	hudText = CreateHudSynchronizer();
}

public void OnConfigsExecuted() {
	CreateTimer(2.0, Timer_AddTag); // Let everything load first
}

public Action Timer_AddTag(Handle timer) {
	if(!GetConVarBool(cvarTag)) {
		return;
	}
	char value[512];
	GetConVarString(sv_tags, value, sizeof(value));
	TrimString(value);
	if(strlen(value) == 0) {
		SetConVarString(sv_tags, "backpack.tf");
		return;
	}
	char tags[64][64];
	int total = ExplodeString(value, ",", tags, sizeof(tags), sizeof(tags[]));
	for(int i = 0; i < total; i++) {
		if(StrEqual(tags[i], "backpack.tf")) {
			return; // Tag found, nothing to do here
		}
	}
	StrCat(value, sizeof(value), ",backpack.tf");
	SetConVarString(sv_tags, value);
}

public void OnMapStart() {
	PrecacheSound(NOTIFICATION_SOUND);
}

public void Steam_FullyLoaded() {
	CreateTimer(1.0, Timer_Update); // In case of late-loads
}

int GetCachedPricesAge() {
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "data/backpack-tf.txt");
	if(!FileExists(path)) {
		return -1;
	}
	Handle kv = CreateKeyValues("Response");
	if(!FileToKeyValues(kv, path)) {
		CloseHandle(kv);
		return -1;
	}
	int offset = KvGetNum(kv, "time_offset", 1337); // The actual offset can be positive, negative, or zero, so we'll just use 1337 as a default since that's unlikely
	int time = KvGetNum(kv, "current_time");
	CloseHandle(kv);
	if(offset == 1337 || time == 0) {
		return -1;
	}
	return GetTime() - time;
}

public Action Timer_Update(Handle timer) {
	int age = GetCachedPricesAge();
	if(age != -1 && age < 900) { // 15 minutes
		LogMessage("Locally saved pricing data is %d minutes old, bypassing backpack.tf query", age / 60);
		if(backpackTFPricelist != INVALID_HANDLE) {
			CloseHandle(backpackTFPricelist);
		}
		char path[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, path, sizeof(path), "data/backpack-tf.txt");
		backpackTFPricelist = CreateKeyValues("Response");
		FileToKeyValues(backpackTFPricelist, path);
		
		budsToKeys = GetConversion(ITEM_EARBUDS);
		keysToRef = GetConversion(ITEM_KEY);
		KvRewind(backpackTFPricelist);
		refToUsd = KvGetFloat(backpackTFPricelist, "refined_usd_value");
		
		CreateTimer(float(3600 - age), Timer_Update);
		return;
	}
	
	char key[32];
	GetConVarString(cvarAPIKey, key, sizeof(key));
	if(strlen(key) == 0) {
		LogError("No API key set. Fill in your API key and reload the plugin.");
		return;
	}
	HTTPRequestHandle request = Steam_CreateHTTPRequest(HTTPMethod_GET, BACKPACK_TF_URL);
	Steam_SetHTTPRequestGetOrPostParameter(request, "key", key);
	Steam_SetHTTPRequestGetOrPostParameter(request, "format", "vdf");
	Steam_SetHTTPRequestGetOrPostParameter(request, "names", "1");
	Steam_SendHTTPRequest(request, OnBackpackTFComplete);
}

public int OnBackpackTFComplete(HTTPRequestHandle request, bool successful, HTTPStatusCode status) {
	if(status != HTTPStatusCode_OK || !successful) {
		if(status == HTTPStatusCode_BadRequest) {
			LogError("backpack.tf API failed: You have not set an API key");
			Steam_ReleaseHTTPRequest(request);
			CreateTimer(600.0, Timer_Update); // Set this for 10 minutes instead of 1 minute
			return;
		} else if(status == HTTPStatusCode_Forbidden) {
			LogError("backpack.tf API failed: Your API key is invalid");
			Steam_ReleaseHTTPRequest(request);
			CreateTimer(600.0, Timer_Update); // Set this for 10 minutes instead of 1 minute
			return;
		} else if(status == HTTPStatusCode_PreconditionFailed) {
			char retry[16];
			Steam_GetHTTPResponseHeaderValue(request, "Retry-After", retry, sizeof(retry));
			LogError("backpack.tf API failed: We are being rate-limited by backpack.tf, next request allowed in %s seconds", retry);
		} else if(status >= HTTPStatusCode_InternalServerError) {
			LogError("backpack.tf API failed: An internal server error occurred");
		} else if(status == HTTPStatusCode_OK && !successful) {
			LogError("backpack.tf API failed: backpack.tf returned an OK response but no data");
		} else if(status != HTTPStatusCode_Invalid) {
			LogError("backpack.tf API failed: Unknown error (status code %d)", view_as<int>(status));
		} else {
			LogError("backpack.tf API failed: Unable to connect to server or server returned no data");
		}
		Steam_ReleaseHTTPRequest(request);
		CreateTimer(60.0, Timer_Update); // try again!
		return;
	}
	char path[256];
	BuildPath(Path_SM, path, sizeof(path), "data/backpack-tf.txt");
	
	Steam_WriteHTTPResponseBody(request, path);
	Steam_ReleaseHTTPRequest(request);
	LogMessage("backpack.tf price list successfully downloaded!");
	
	CreateTimer(3600.0, Timer_Update);
	
	if(backpackTFPricelist != INVALID_HANDLE) {
		CloseHandle(backpackTFPricelist);
	}
	backpackTFPricelist = CreateKeyValues("Response");
	FileToKeyValues(backpackTFPricelist, path);
	lastCacheTime = cacheTime;
	cacheTime = KvGetNum(backpackTFPricelist, "current_time");
	
	int offset = GetTime() - cacheTime;
	KvSetNum(backpackTFPricelist, "time_offset", offset);
	KeyValuesToFile(backpackTFPricelist, path);
	
	budsToKeys = GetConversion(ITEM_EARBUDS);
	keysToRef = GetConversion(ITEM_KEY);
	KvRewind(backpackTFPricelist);
	refToUsd = KvGetFloat(backpackTFPricelist, "refined_usd_value");
	
	if(!GetConVarBool(cvarDisplayUpdateNotification)) {
		return;
	}
	
	if(lastCacheTime == 0) { // first download
		Handle array = CreateArray(128);
		PushArrayString(array, "#Type_command");
		SetHudTextParams(GetConVarFloat(cvarHudXPos), GetConVarFloat(cvarHudYPos), GetConVarFloat(cvarHudHoldTime), GetConVarInt(cvarHudRed), GetConVarInt(cvarHudGreen), GetConVarInt(cvarHudBlue), 255);
		for(int i = 1; i <= MaxClients; i++) {
			if(!IsClientInGame(i)) {
				continue;
			}
			ShowSyncHudText(i, hudText, "%t", "Price list updated");
			EmitSoundToClient(i, NOTIFICATION_SOUND);
		}
		CreateTimer(GetConVarFloat(cvarHudHoldTime), Timer_DisplayHudText, array, TIMER_REPEAT);
		return;
	}
	
	PrepPriceKv();
	KvGotoFirstSubKey(backpackTFPricelist);
	bool isNegative = false;
	int lastUpdate; 
	float valueOld, valueOldHigh, value, valueHigh, difference;
	char defindex[16], qualityIndex[32], quality[32], name[64], message[128], currency[32], currencyOld[32], oldPrice[64], newPrice[64];
	Handle array = CreateArray(128);
	PushArrayString(array, "#Type_command");
	if(GetConVarBool(cvarDisplayChangedPrices)) {
		do {
			// loop through items
			KvGetSectionName(backpackTFPricelist, defindex, sizeof(defindex));
			if(StringToInt(defindex) == ITEM_REFINED) {
				continue; // Skip over refined price changes
			}
			KvGotoFirstSubKey(backpackTFPricelist);
			do {
				// loop through qualities
				KvGetSectionName(backpackTFPricelist, qualityIndex, sizeof(qualityIndex));
				if(StrEqual(qualityIndex, "item_info"))  {
					KvGetString(backpackTFPricelist, "item_name", name, sizeof(name));
					continue;
				}
				KvGotoFirstSubKey(backpackTFPricelist);
				do {
					// loop through instances (series #s, effects)
					lastUpdate = KvGetNum(backpackTFPricelist, "last_change");
					if(lastUpdate == 0 || lastUpdate < lastCacheTime) {
						continue; // hasn't updated
					}
					valueOld = KvGetFloat(backpackTFPricelist, "value_old");
					valueOldHigh = KvGetFloat(backpackTFPricelist, "value_high_old");
					value = KvGetFloat(backpackTFPricelist, "value");
					valueHigh = KvGetFloat(backpackTFPricelist, "value_high");
					
					KvGetString(backpackTFPricelist, "currency", currency, sizeof(currency));
					KvGetString(backpackTFPricelist, "currency_old", currencyOld, sizeof(currencyOld));
					
					if(strlen(currency) == 0 || strlen(currencyOld) == 0) {
						continue;
					}
					
					FormatPriceRange(valueOld, valueOldHigh, currency, oldPrice, sizeof(oldPrice), StrEqual(qualityIndex, QUALITY_UNUSUAL));
					FormatPriceRange(value, valueHigh, currency, newPrice, sizeof(newPrice), StrEqual(qualityIndex, QUALITY_UNUSUAL));
					
					// Get an average so we can determine if it went up or down
					if(valueOldHigh != 0.0) {
						valueOld = FloatDiv(FloatAdd(valueOld, valueOldHigh), 2.0);
					}
					
					if(valueHigh != 0.0) {
						value = FloatDiv(FloatAdd(value, valueHigh), 2.0);
					}
					
					// Get prices in terms of refined now so we can determine if it went up or down
					if(StrEqual(currencyOld, "earbuds")) {
						valueOld = FloatMul(FloatMul(valueOld, budsToKeys), keysToRef);
					} else if(StrEqual(currencyOld, "keys")) {
						valueOld = FloatMul(valueOld, keysToRef);
					}
					
					if(StrEqual(currency, "earbuds")) {
						value = FloatMul(FloatMul(value, budsToKeys), keysToRef);
					} else if(StrEqual(currency, "keys")) {
						value = FloatMul(value, keysToRef);
					}
					
					difference = FloatSub(value, valueOld);
					if(difference < 0.0) {
						isNegative = true;
						difference = FloatMul(difference, -1.0);
					} else {
						isNegative = false;
					}
					
					// Format a quality name
					if(StrEqual(qualityIndex, QUALITY_UNIQUE)) {
						Format(quality, sizeof(quality), ""); // if quality is unique, don't display a quality
					} else if(StrEqual(qualityIndex, QUALITY_UNUSUAL) && (StringToInt(defindex) != ITEM_HAUNTED_SCRAP && StringToInt(defindex) != ITEM_HEADTAKER)) {
						char effect[16];
						KvGetSectionName(backpackTFPricelist, effect, sizeof(effect));
						if(!GetTrieString(unusualNameTrie, effect, quality, sizeof(quality))) {
							LogError("Unknown unusual effect: %s in OnBackpackTFComplete. Please report this!", effect);
							char kvPath[PLATFORM_MAX_PATH];
							BuildPath(Path_SM, kvPath, sizeof(kvPath), "data/backpack-tf.%d.txt", GetTime());
							if(!FileExists(kvPath)) {
								KeyValuesToFile(backpackTFPricelist, kvPath);
							}
							continue;
						}
					} else {
						if(!GetTrieString(qualityNameTrie, qualityIndex, quality, sizeof(quality))) {
							LogError("Unknown quality index: %s. Please report this!", qualityIndex);
							continue;
						}
					}
					
					Format(message, sizeof(message), "%s%s%s: %s #From %s #To %s", quality, StrEqual(quality, "") ? "" : " ", name, isNegative ? "#Down" : "#Up", oldPrice, newPrice);
					PushArrayString(array, message);
					
				} while(KvGotoNextKey(backpackTFPricelist)); // end: instances
				KvGoBack(backpackTFPricelist);
				
			} while(KvGotoNextKey(backpackTFPricelist)); // end: qualities
			KvGoBack(backpackTFPricelist);
			
		} while(KvGotoNextKey(backpackTFPricelist)); // end: items
	}
	
	SetHudTextParams(GetConVarFloat(cvarHudXPos), GetConVarFloat(cvarHudYPos), GetConVarFloat(cvarHudHoldTime), GetConVarInt(cvarHudRed), GetConVarInt(cvarHudGreen), GetConVarInt(cvarHudBlue), 255);
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i)) {
			continue;
		}
		ShowSyncHudText(i, hudText, "%t", "Price list updated");
		EmitSoundToClient(i, NOTIFICATION_SOUND);
	}
	CreateTimer(GetConVarFloat(cvarHudHoldTime), Timer_DisplayHudText, array, TIMER_REPEAT);
}

float GetConversion(int defindex) {
	char buffer[32];
	PrepPriceKv();
	IntToString(defindex, buffer, sizeof(buffer));
	KvJumpToKey(backpackTFPricelist, buffer);
	KvJumpToKey(backpackTFPricelist, "6");
	KvJumpToKey(backpackTFPricelist, "0");
	float value = KvGetFloat(backpackTFPricelist, "value");
	float valueHigh = KvGetFloat(backpackTFPricelist, "value_high");
	if(valueHigh == 0.0) {
		return value;
	}
	return FloatDiv(FloatAdd(value, valueHigh), 2.0);
}

void FormatPrice(float price, const char[] currency, char[] output, int maxlen, bool includeCurrency = true, bool forceBuds = false) {
	char outputCurrency[32];
	if(StrEqual(currency, "metal")) {
		Format(outputCurrency, sizeof(outputCurrency), "refined");
	} else if(StrEqual(currency, "keys")) {
		Format(outputCurrency, sizeof(outputCurrency), "key");
	} else if(StrEqual(currency, "earbuds")) {
		Format(outputCurrency, sizeof(outputCurrency), "bud");
	} else if(StrEqual(currency, "usd")) {
		if(forceBuds) {
			Format(outputCurrency, sizeof(outputCurrency), "earbuds"); // This allows us to force unusual price ranges to display buds only
		}
		ConvertUSD(price, outputCurrency, sizeof(outputCurrency));
	} else {
		ThrowError("Unknown currency: %s", currency);
	}
	
	if(FloatIsInt(price)) {
		Format(output, maxlen, "%d", RoundToFloor(price));
	} else {
		Format(output, maxlen, "%.2f", price);
	}
	
	if(!includeCurrency) {
		return;
	}
	
	if(StrEqual(output, "1") || StrEqual(currency, "metal")) {
		Format(output, maxlen, "%s %s", output, outputCurrency);
	} else {
		Format(output, maxlen, "%s %ss", output, outputCurrency);
	}
}

void FormatPriceRange(float low, float high, const char[] currency, char[] output, int maxlen, bool forceBuds = false) {
	if(high == 0.0) {
		FormatPrice(low, currency, output, maxlen, true, forceBuds);
		return;
	}
	char buffer[32];
	FormatPrice(low, currency, output, maxlen, false, forceBuds);
	FormatPrice(high, currency, buffer, sizeof(buffer), true, forceBuds);
	Format(output, maxlen, "%s-%s", output, buffer);
}

void ConvertUSD(float &price, char[] outputCurrency, int maxlen) {
	float budPrice = FloatMul(FloatMul(refToUsd, keysToRef), budsToKeys);
	if(price < budPrice && !StrEqual(outputCurrency, "earbuds")) {
		float keyPrice = FloatMul(refToUsd, keysToRef);
		price = FloatDiv(price, keyPrice);
		Format(outputCurrency, maxlen, "key");
	} else {
		price = FloatDiv(price, budPrice);
		Format(outputCurrency, maxlen, "bud");
	}
}

bool FloatIsInt(float input) {
	return float(RoundToFloor(input)) == input;
}

public Action Timer_DisplayHudText(Handle timer, any array) {
	if(GetArraySize(array) == 0) {
		CloseHandle(array);
		return Plugin_Stop;
	}
	char text[128], display[128];
	GetArrayString(array, 0, text, sizeof(text));
	SetHudTextParams(GetConVarFloat(cvarHudXPos), GetConVarFloat(cvarHudYPos), GetConVarFloat(cvarHudHoldTime), GetConVarInt(cvarHudRed), GetConVarInt(cvarHudGreen), GetConVarInt(cvarHudBlue), 255);
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i)) {
			continue;
		}
		PerformTranslationTokenReplacement(i, text, display, sizeof(display));
		ShowSyncHudText(i, hudText, display);
	}
	RemoveFromArray(array, 0);
	return Plugin_Continue;
}

void PerformTranslationTokenReplacement(int client, const char[] message, char[] output, int maxlen) {
	SetGlobalTransTarget(client);
	strcopy(output, maxlen, message);
	char buffer[64];
	
	Format(buffer, maxlen, "%t", "Type !pc for a price check");
	ReplaceString(output, maxlen, "#Type_command", buffer);
	
	Format(buffer, maxlen, "%t", "Up");
	ReplaceString(output, maxlen, "#Up", buffer);
	
	Format(buffer, maxlen, "%t", "Down");
	ReplaceString(output, maxlen, "#Down", buffer);
	
	Format(buffer, maxlen, "%t", "From");
	ReplaceString(output, maxlen, "#From", buffer);
	
	Format(buffer, maxlen, "%t", "To");
	ReplaceString(output, maxlen, "#To", buffer);
}

void PrepPriceKv() {
	KvRewind(backpackTFPricelist);
	KvJumpToKey(backpackTFPricelist, "prices");
}

public Action Command_PriceCheck(int client, int args) {
	if(backpackTFPricelist == INVALID_HANDLE) {
		char key[32];
		GetConVarString(cvarAPIKey, key, sizeof(key));
		if(strlen(key) == 0) {
			ReplyToCommand(client, "\x04[SM] \x01The server administrator has not filled in their API key yet. Please contact the server administrator.");
		} else {
			ReplyToCommand(client, "\x04[SM] \x01%t.", "The price list has not loaded yet");
		}
		return Plugin_Handled;
	}
	if(args == 0) {
		Handle menu = CreateMenu(Handler_ItemSelection);
		SetMenuTitle(menu, "Price Check");
		PrepPriceKv();
		KvGotoFirstSubKey(backpackTFPricelist);
		char name[128];
		do {
			if(!KvJumpToKey(backpackTFPricelist, "item_info")) {
				continue;
			}
			KvGetString(backpackTFPricelist, "item_name", name, sizeof(name));
			if(KvGetNum(backpackTFPricelist, "proper_name") == 1) {
				Format(name, sizeof(name), "The %s", name);
			}
			AddMenuItem(menu, name, name);
			KvGoBack(backpackTFPricelist);
		} while(KvGotoNextKey(backpackTFPricelist));
		DisplayMenu(menu, client, GetConVarInt(cvarMenuHoldTime));
		return Plugin_Handled;
	}
	int resultDefindex = -1;
	char defindex[8], name[128], itemName[128];
	GetCmdArgString(name, sizeof(name));
	bool exact = StripQuotes(name);
	PrepPriceKv();
	KvGotoFirstSubKey(backpackTFPricelist);
	Handle matches;
	if(!exact) {
		matches = CreateArray(128);
	}
	do {
		KvGetSectionName(backpackTFPricelist, defindex, sizeof(defindex));
		if(!KvJumpToKey(backpackTFPricelist, "item_info")) {
			continue;
		}
		KvGetString(backpackTFPricelist, "item_name", itemName, sizeof(itemName));
		if(KvGetNum(backpackTFPricelist, "proper_name") == 1) {
			Format(itemName, sizeof(itemName), "The %s", itemName);
		}
		KvGoBack(backpackTFPricelist);
		if(exact) {
			if(StrEqual(itemName, name, false)) {
				resultDefindex = StringToInt(defindex);
				break;
			}
		} else {
			if(StrContains(itemName, name, false) != -1) {
				resultDefindex = StringToInt(defindex); // In case this is the only match, we store the resulting defindex here so that we don't need to search to find it again
				PushArrayString(matches, itemName);
			}
		}
	} while(KvGotoNextKey(backpackTFPricelist));
	if(!exact && GetArraySize(matches) > 1) {
		Handle menu = CreateMenu(Handler_ItemSelection);
		SetMenuTitle(menu, "Search Results");
		int size = GetArraySize(matches);
		for(int i = 0; i < size; i++) {
			GetArrayString(matches, i, itemName, sizeof(itemName));
			AddMenuItem(menu, itemName, itemName);
		}
		DisplayMenu(menu, client, GetConVarInt(cvarMenuHoldTime));
		CloseHandle(matches);
		return Plugin_Handled;
	}
	if(!exact) {
		CloseHandle(matches);
	}
	if(resultDefindex == -1) {
		ReplyToCommand(client, "\x04[SM] \x01No matching item was found.");
		return Plugin_Handled;
	}
	// At this point, we know that we've found our item. Its defindex is stored in resultDefindex as a cell
	// defindex was used to store the defindex of every item as we searched it, so it's not reliable
	if(resultDefindex == ITEM_REFINED) {
		SetGlobalTransTarget(client);
		Handle menu = CreateMenu(Handler_PriceListMenu);
		SetMenuTitle(menu, "%t\n%t\n%t\n ", "Price check", itemName, "Prices are estimates only", "Prices courtesy of backpack.tf");
		char buffer[32];
		Format(buffer, sizeof(buffer), "Unique: $%.2f USD", refToUsd);
		AddMenuItem(menu, "", buffer);
		DisplayMenu(menu, client, GetConVarInt(cvarMenuHoldTime));
		return Plugin_Handled;
	}
	bool isCrate = (resultDefindex == ITEM_CRATE || resultDefindex == ITEM_SALVAGED_CRATE);
	bool onlyOneUnusual = (resultDefindex == ITEM_HEADTAKER || resultDefindex == ITEM_HAUNTED_SCRAP);
	PrepPriceKv();
	IntToString(resultDefindex, defindex, sizeof(defindex));
	KvJumpToKey(backpackTFPricelist, defindex);
	KvJumpToKey(backpackTFPricelist, "item_info");
	KvGetString(backpackTFPricelist, "item_name", itemName, sizeof(itemName));
	if(KvGetNum(backpackTFPricelist, "proper_name") == 1) {
		Format(itemName, sizeof(itemName), "The %s", itemName);
	}
	KvGotoNextKey(backpackTFPricelist);
	
	SetGlobalTransTarget(client);
	Handle menu = CreateMenu(Handler_PriceListMenu);
	SetMenuTitle(menu, "%t\n%t\n%t\n ", "Price check", itemName, "Prices are estimates only", "Prices courtesy of backpack.tf");
	bool unusualDisplayed = false;
	float value, valueHigh;
	char currency[32], qualityIndex[16], quality[16], series[8], price[32], buffer[64];
	do {
		KvGetSectionName(backpackTFPricelist, qualityIndex, sizeof(qualityIndex));
		if(StrEqual(qualityIndex, "item_info") || StrEqual(qualityIndex, "alt_defindex")) {
			continue;
		}
		KvGotoFirstSubKey(backpackTFPricelist);
		do {
			if(StrEqual(qualityIndex, QUALITY_UNUSUAL) && !onlyOneUnusual) {
				if(!unusualDisplayed) {
					AddMenuItem(menu, defindex, "Unusual: View Effects");
					unusualDisplayed = true;
				}
			} else {
				value = KvGetFloat(backpackTFPricelist, "value");
				valueHigh = KvGetFloat(backpackTFPricelist, "value_high");
				KvGetString(backpackTFPricelist, "currency", currency, sizeof(currency));
				FormatPriceRange(value, valueHigh, currency, price, sizeof(price));
				
				if(!GetTrieString(qualityNameTrie, qualityIndex, quality, sizeof(quality))) {
					LogError("Unknown quality index: %s. Please report this!", qualityIndex);
					continue;
				}
				if(isCrate) {
					KvGetSectionName(backpackTFPricelist, series, sizeof(series));
					if(StrEqual(series, "0")) {
						continue;
					}
					if(StrEqual(qualityIndex, QUALITY_UNIQUE)) {
						Format(buffer, sizeof(buffer), "Series %s: %s", series, price);
					} else {
						Format(buffer, sizeof(buffer), "%s: Series %s: %s", quality, series, price);
					}
				} else {
					Format(buffer, sizeof(buffer), "%s: %s", quality, price);
				}
				AddMenuItem(menu, "", buffer, ITEMDRAW_DISABLED);
			}
		} while(KvGotoNextKey(backpackTFPricelist));
		KvGoBack(backpackTFPricelist);
	} while(KvGotoNextKey(backpackTFPricelist));
	DisplayMenu(menu, client, GetConVarInt(cvarMenuHoldTime));
	return Plugin_Handled;
}

public int Handler_ItemSelection(Handle menu, MenuAction action, int client, int param) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	}
	if(action != MenuAction_Select) {
		return;
	}
	char selection[128];
	GetMenuItem(menu, param, selection, sizeof(selection));
	FakeClientCommand(client, "sm_pricecheck \"%s\"", selection);
}

public int Handler_PriceListMenu(Handle menu, MenuAction action, int client, int param) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	}
	if(action != MenuAction_Select) {
		return;
	}
	char defindex[32];
	GetMenuItem(menu, param, defindex, sizeof(defindex));
	
	char name[64];
	PrepPriceKv();
	KvJumpToKey(backpackTFPricelist, defindex);
	KvJumpToKey(backpackTFPricelist, "item_info");
	KvGetString(backpackTFPricelist, "item_name", name, sizeof(name));
	if(KvGetNum(backpackTFPricelist, "proper_name") == 1) {
		Format(name, sizeof(name), "The Unusual %s", name);
	} else {
		Format(name, sizeof(name), "Unusual %s", name);
	}
	KvGoBack(backpackTFPricelist);
	
	if(!KvJumpToKey(backpackTFPricelist, QUALITY_UNUSUAL)) {
		return;
	}
	
	KvGotoFirstSubKey(backpackTFPricelist);
	
	SetGlobalTransTarget(client);
	Handle menu2 = CreateMenu(Handler_PriceListMenu);
	SetMenuTitle(menu2, "%t\n%t\n%t\n ", "Price check", name, "Prices are estimates only", "Prices courtesy of backpack.tf");
	char effect[8], effectName[64], message[128], price[64], currency[32];
	float value, valueHigh;
	do {
		KvGetSectionName(backpackTFPricelist, effect, sizeof(effect));
		if(!GetTrieString(unusualNameTrie, effect, effectName, sizeof(effectName))) {
			LogError("Unknown unusual effect: %s in Handler_PriceListMenu. Please report this!", effect);
			char path[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, path, sizeof(path), "data/backpack-tf.%d.txt", GetTime());
			if(!FileExists(path)) {
				KeyValuesToFile(backpackTFPricelist, path);
			}
			continue;
		}
		value = KvGetFloat(backpackTFPricelist, "value");
		valueHigh = KvGetFloat(backpackTFPricelist, "value_high");
		KvGetString(backpackTFPricelist, "currency", currency, sizeof(currency));
		if(StrEqual(currency, "")) {
			continue;
		}
		FormatPriceRange(value, valueHigh, currency, price, sizeof(price), true);
		
		Format(message, sizeof(message), "%s: %s", effectName, price);
		AddMenuItem(menu2, "", message, ITEMDRAW_DISABLED);
	} while(KvGotoNextKey(backpackTFPricelist));
	DisplayMenu(menu2, client, GetConVarInt(cvarMenuHoldTime));
}

public Action Command_Backpack(int client, int args) {
	if(!GetConVarBool(cvarBPCommand)) {
		return Plugin_Continue;
	}
	int target;
	if(args == 0) {
		target = GetClientAimTarget(client);
		if(target <= 0) {
			DisplayClientMenu(client);
			return Plugin_Handled;
		}
	} else {
		char arg1[MAX_NAME_LENGTH];
		GetCmdArg(1, arg1, sizeof(arg1));
		target = FindTargetEx(client, arg1, true, false, false);
		if(target == -1) {
			DisplayClientMenu(client);
			return Plugin_Handled;
		}
	}
	char steamID[64];
	Steam_GetCSteamIDForClient(target, steamID, sizeof(steamID)); // we could use the regular Steam ID, but we already have SteamTools, so we can just bypass backpack.tf's redirect directly
	char url[256];
	Format(url, sizeof(url), "https://backpack.tf/profiles/%s", steamID);
	AdvMOTD_ShowMOTDPanel(client, "backpack.tf", url, MOTDPANEL_TYPE_URL, true, true, true, OnMOTDFailure);
//	WebFix_OpenUrl(client, "backpack.tf", url);
	return Plugin_Handled;
}

public void OnMOTDFailure(int client, MOTDFailureReason reason) {
	switch(reason) 
	{
		case MOTDFailure_Disabled: PrintToChat(client, "\x04[SM] .\x01You cannot view backpacks with HTML MOTDs disabled.");
		case MOTDFailure_Matchmaking: PrintToChat(client, "\x04[SM] \x01You cannot view backpacks after joining via Quickplay.");
		case MOTDFailure_QueryFailed: PrintToChat(client, "\x04[SM] \x01Unable to open backpack.");
	}
}

void DisplayClientMenu(int client) {
	Handle menu = CreateMenu(Handler_ClientMenu);
	SetMenuTitle(menu, "Select Player");
	char name[MAX_NAME_LENGTH], index[8];
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i) || IsFakeClient(i)) {
			continue;
		}
		GetClientName(i, name, sizeof(name));
		IntToString(GetClientUserId(i), index, sizeof(index));
		AddMenuItem(menu, index, name);
	}
	DisplayMenu(menu, client, GetConVarInt(cvarMenuHoldTime));
}

public int Handler_ClientMenu(Handle menu, MenuAction action, int client, int param) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	}
	if(action != MenuAction_Select) {
		return;
	}
	char selection[32];
	GetMenuItem(menu, param, selection, sizeof(selection));
	FakeClientCommand(client, "sm_backpack #%s", selection);
}

public Action Command_UpdatePrices(int client, int args) {
	int age = GetCachedPricesAge();
	if(age != -1 && age < 900) { // 15 minutes
		ReplyToCommand(client, "\x04[SM] \x01The price list cannot be updated more frequently than every 15 minutes. It is currently %d minutes old.", age / 60);
		return Plugin_Handled;
	}
	ReplyToCommand(client, "\x04[SM] \x01Updating backpack.tf prices...");
	Timer_Update(INVALID_HANDLE);
	return Plugin_Handled;
}

int FindTargetEx(int client, const char[] target, bool nobots = false, bool immunity = true, bool replyToError = true) {
	char target_name[MAX_TARGET_LENGTH];
	int target_list[1], target_count; 
	bool tn_is_ml;
	
	int flags = COMMAND_FILTER_NO_MULTI;
	if(nobots) {
		flags |= COMMAND_FILTER_NO_BOTS;
	}
	if(!immunity) {
		flags |= COMMAND_FILTER_NO_IMMUNITY;
	}
	
	if((target_count = ProcessTargetString(
			target,
			client, 
			target_list, 
			1, 
			flags,
			target_name,
			sizeof(target_name),
			tn_is_ml)) > 0)
	{
		return target_list[0];
	} else {
		if(replyToError) {
			ReplyToTargetError(client, target_count);
		}
		return -1;
	}
}