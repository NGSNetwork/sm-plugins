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
#include <SteamWorks>
#include <advanced_motd>

#define PLUGIN_VERSION		"2.11.3"
#define BACKPACK_TF_URL		"https://backpack.tf/api/IGetPrices/v4"
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
KeyValues backpackTFPricelist;

StringMap qualityNameTrie;
StringMap unusualNameTrie;

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
ConVar sv_tags;

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

	qualityNameTrie = new StringMap();
	qualityNameTrie.SetString("0", "Normal");
	qualityNameTrie.SetString("1", "Genuine");
	qualityNameTrie.SetString("2", "rarity2");
	qualityNameTrie.SetString("3", "Vintage");
	qualityNameTrie.SetString("4", "rarity3");
	qualityNameTrie.SetString("5", "Unusual");
	qualityNameTrie.SetString("6", "Unique");
	qualityNameTrie.SetString("7", "Community");
	qualityNameTrie.SetString("8", "Valve");
	qualityNameTrie.SetString("9", "Self-Made");
	qualityNameTrie.SetString("10", "Customized");
	qualityNameTrie.SetString("11", "Strange");
	qualityNameTrie.SetString("12", "Completed");
	qualityNameTrie.SetString("13", "Haunted");
	qualityNameTrie.SetString("14", "Collector's");
	qualityNameTrie.SetString("300", "Uncraftable Vintage"); // custom for backpack.tf
	qualityNameTrie.SetString("600", "Uncraftable"); // custom for backpack.tf
	qualityNameTrie.SetString("1100", "Uncraftable Strange"); // custom for backpack.tf
	qualityNameTrie.SetString("1300", "Uncraftable Haunted"); // custom for backpack.tf

	unusualNameTrie = new StringMap();
	// Original effects
	unusualNameTrie.SetString("6", "Green Confetti");
	unusualNameTrie.SetString("7", "Purple Confetti");
	unusualNameTrie.SetString("8", "Haunted Ghosts");
	unusualNameTrie.SetString("9", "Green Energy");
	unusualNameTrie.SetString("10", "Purple Energy");
	unusualNameTrie.SetString("11", "Circling TF Logo");
	unusualNameTrie.SetString("12", "Massed Flies");
	unusualNameTrie.SetString("13", "Burning Flames");
	unusualNameTrie.SetString("14", "Scorching Flames");
	unusualNameTrie.SetString("15", "Searing Plasma");
	unusualNameTrie.SetString("16", "Vivid Plasma");
	unusualNameTrie.SetString("17", "Sunbeams");
	unusualNameTrie.SetString("18", "Circling Peace Sign");
	unusualNameTrie.SetString("19", "Circling Heart");
	// Batch 2
	unusualNameTrie.SetString("29", "Stormy Storm");
	unusualNameTrie.SetString("30", "Blizzardy Storm");
	unusualNameTrie.SetString("31", "Nuts n' Bolts");
	unusualNameTrie.SetString("32", "Orbiting Planets");
	unusualNameTrie.SetString("33", "Orbiting Fire");
	unusualNameTrie.SetString("34", "Bubbling");
	unusualNameTrie.SetString("35", "Smoking");
	unusualNameTrie.SetString("36", "Steaming");
	// Halloween
	unusualNameTrie.SetString("37", "Flaming Lantern");
	unusualNameTrie.SetString("38", "Cloudy Moon");
	unusualNameTrie.SetString("39", "Cauldron Bubbles");
	unusualNameTrie.SetString("40", "Eerie Orbiting Fire");
	unusualNameTrie.SetString("43", "Knifestorm");
	unusualNameTrie.SetString("44", "Misty Skull");
	unusualNameTrie.SetString("45", "Harvest Moon");
	unusualNameTrie.SetString("46", "It's A Secret To Everybody");
	unusualNameTrie.SetString("47", "Stormy 13th Hour");
	// Batch 3
	unusualNameTrie.SetString("56", "Kill-a-Watt");
	unusualNameTrie.SetString("57", "Terror-Watt");
	unusualNameTrie.SetString("58", "Cloud 9");
	unusualNameTrie.SetString("59", "Aces High");
	unusualNameTrie.SetString("60", "Dead Presidents");
	unusualNameTrie.SetString("61", "Miami Nights");
	unusualNameTrie.SetString("62", "Disco Beat Down");
	// Robo-effects
	unusualNameTrie.SetString("63", "Phosphorous");
	unusualNameTrie.SetString("64", "Sulphurous");
	unusualNameTrie.SetString("65", "Memory Leak");
	unusualNameTrie.SetString("66", "Overclocked");
	unusualNameTrie.SetString("67", "Electrostatic");
	unusualNameTrie.SetString("68", "Power Surge");
	unusualNameTrie.SetString("69", "Anti-Freeze");
	unusualNameTrie.SetString("70", "Time Warp");
	unusualNameTrie.SetString("71", "Green Black Hole");
	unusualNameTrie.SetString("72", "Roboactive");
	// Halloween 2013
	unusualNameTrie.SetString("73", "Arcana");
	unusualNameTrie.SetString("74", "Spellbound");
	unusualNameTrie.SetString("75", "Chiroptera Venenata");
	unusualNameTrie.SetString("76", "Poisoned Shadows");
	unusualNameTrie.SetString("77", "Something Burning This Way Comes");
	unusualNameTrie.SetString("78", "Hellfire");
	unusualNameTrie.SetString("79", "Darkblaze");
	unusualNameTrie.SetString("80", "Demonflame");
	// Halloween 2014
	unusualNameTrie.SetString("81", "Bonzo The All-Gnawing");
	unusualNameTrie.SetString("82", "Amaranthine");
	unusualNameTrie.SetString("83", "Stare From Beyond");
	unusualNameTrie.SetString("84", "The Ooze");
	unusualNameTrie.SetString("85", "Ghastly Ghosts Jr");
	unusualNameTrie.SetString("86", "Haunted Phantasm Jr");
	// EOTL
	unusualNameTrie.SetString("87", "Frostbite");
	unusualNameTrie.SetString("88", "Molten Mallard");
	unusualNameTrie.SetString("89", "Morning Glory");
	unusualNameTrie.SetString("90", "Death at Dusk");
	// Invasion effects
	unusualNameTrie.SetString("91", "Abduction");
	unusualNameTrie.SetString("92", "Atomic");
	unusualNameTrie.SetString("93", "Subatomic");
	unusualNameTrie.SetString("94", "Electric Hat Protector");
	unusualNameTrie.SetString("95", "Magnetic Hat Protector");
	unusualNameTrie.SetString("96", "Voltaic Hat Protector");
	unusualNameTrie.SetString("97", "Galactic Codex");
	unusualNameTrie.SetString("98", "Ancient Codex");
	unusualNameTrie.SetString("99", "Nebula");
	// Halloween 2015
	unusualNameTrie.SetString("100", "Death by Disco");
	unusualNameTrie.SetString("101", "It's a mystery to everyone");
	unusualNameTrie.SetString("102", "It's a puzzle to me");
	unusualNameTrie.SetString("103", "Ether Trail");
	unusualNameTrie.SetString("104", "Nether Trail");
	unusualNameTrie.SetString("105", "Ancient Eldritch");
	unusualNameTrie.SetString("106", "Eldritch Flame");
	// Halloween 2016
	unusualNameTrie.SetString("107", "Neutron Star");
	unusualNameTrie.SetString("108", "Tesla Coil");
	unusualNameTrie.SetString("109", "Sandstorm Insomnia");
	unusualNameTrie.SetString("110", "Sandstorm Slumber");
	// Taunt effects
	unusualNameTrie.SetString("3001", "Showstopper");
	unusualNameTrie.SetString("3002", "Showstopper");
	unusualNameTrie.SetString("3003", "Holy Grail");
	unusualNameTrie.SetString("3004", "'72");
	unusualNameTrie.SetString("3005", "Fountain of Delight");
	unusualNameTrie.SetString("3006", "Screaming Tiger");
	unusualNameTrie.SetString("3007", "Skill Gotten Gains");
	unusualNameTrie.SetString("3008", "Midnight Whirlwind");
	unusualNameTrie.SetString("3009", "Silver Cyclone");
	unusualNameTrie.SetString("3010", "Mega Strike");
	// Halloween 2014 taunt effects
	unusualNameTrie.SetString("3011", "Haunted Phantasm");
	unusualNameTrie.SetString("3012", "Ghastly Ghosts");
	// Halloween 2016 taunt effects
	unusualNameTrie.SetString("3013", "Hellish Inferno");
	unusualNameTrie.SetString("3014", "Spectral Swirl");
	unusualNameTrie.SetString("3015", "Infernal Flames");
	unusualNameTrie.SetString("3016", "Infernal Smoke");

	hudText = CreateHudSynchronizer();
}

public void OnConfigsExecuted() {
	CreateTimer(2.0, Timer_AddTag); // Let everything load first
}

public Action Timer_AddTag(Handle timer) {
	if(!cvarTag.BoolValue) {
		return;
	}
	char value[512];
	sv_tags.GetString(value, sizeof(value));
	TrimString(value);
	if(strlen(value) == 0) {
		sv_tags.SetString("backpack.tf");
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
	sv_tags.SetString(value);
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
	KeyValues kv = new KeyValues("response");
	if(!kv.ImportFromFile(path)) {
		delete kv;
		return -1;
	}
	int offset = kv.GetNum("time_offset", 1337); // The actual offset can be positive, negative, or zero, so we'll just use 1337 as a default since that's unlikely
	int time = kv.GetNum("current_time");
	delete kv;
	if(offset == 1337 || time == 0) {
		return -1;
	}
	return GetTime() - time;
}

public Action Timer_Update(Handle timer) {
	int age = GetCachedPricesAge();
	if(age != -1 && age < 900) { // 15 minutes
		LogMessage("Locally saved pricing data is %d minutes old, bypassing backpack.tf query", age / 60);
		if(backpackTFPricelist != null) {
			delete backpackTFPricelist;
		}
		char path[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, path, sizeof(path), "data/backpack-tf.txt");
		backpackTFPricelist = new KeyValues("response");
		if (backpackTFPricelist.ImportFromFile(path))
		{
			budsToKeys = GetConversion(ITEM_EARBUDS);
			keysToRef = GetConversion(ITEM_KEY);
			backpackTFPricelist.Rewind();
			refToUsd = backpackTFPricelist.GetFloat("raw_usd_value");
		}
		CreateTimer(float(3600 - age), Timer_Update);
		return;
	}

	char key[32];
	cvarAPIKey.GetString(key, sizeof(key));
	if(strlen(key) == 0) {
		LogError("No API key set. Fill in your API key and reload the plugin.");
		return;
	}
	SWHTTPRequest request = new SWHTTPRequest(k_EHTTPMethodGET, BACKPACK_TF_URL);
	request.SetParam("key", key);
	request.SetParam("format", "vdf");
	request.SetParam("names", "1");
	request.SetCallbacks(OnBackpackTFComplete);
	request.Send();
}

public int OnBackpackTFComplete(SWHTTPRequest request, bool bFailure, bool successful, EHTTPStatusCode status) {
	if(status != k_EHTTPStatusCode200OK || !successful) {
		if(status == k_EHTTPStatusCode400BadRequest) {
			LogError("backpack.tf API failed: You have not set an API key");
			delete request;
			CreateTimer(600.0, Timer_Update); // Set this for 10 minutes instead of 1 minute
			return;
		} else if(status == k_EHTTPStatusCode403Forbidden) {
			LogError("backpack.tf API failed: Your API key is invalid");
			delete request;
			CreateTimer(600.0, Timer_Update); // Set this for 10 minutes instead of 1 minute
			return;
		} else if(status == k_EHTTPStatusCode412PreconditionFailed) {
			char retry[16];
			SteamWorks_GetHTTPResponseHeaderValue(request, "Retry-After", retry, sizeof(retry));
			LogError("backpack.tf API failed: We are being rate-limited by backpack.tf, next request allowed in %s seconds", retry);
		} else if(status >= k_EHTTPStatusCode500InternalServerError) {
			LogError("backpack.tf API failed: An internal server error occurred");
		} else if(status == k_EHTTPStatusCode200OK && !successful) {
			LogError("backpack.tf API failed: backpack.tf returned an OK response but no data");
		} else if(status != k_EHTTPStatusCodeInvalid) {
			LogError("backpack.tf API failed: Unknown error (status code %d)", view_as<int>(status));
		} else {
			LogError("backpack.tf API failed: Unable to connect to server or server returned no data");
		}
		delete request;
		CreateTimer(60.0, Timer_Update); // try again!
		return;
	}
	char path[256];
	BuildPath(Path_SM, path, sizeof(path), "data/backpack-tf.txt");

	request.WriteResponseToFile(path);
	delete request;
	LogMessage("backpack.tf price list successfully downloaded!");

	CreateTimer(3600.0, Timer_Update);

	if(backpackTFPricelist != null) {
		delete backpackTFPricelist;
	}
	backpackTFPricelist = new KeyValues("response");
	if (backpackTFPricelist.ImportFromFile(path))
	{
		lastCacheTime = cacheTime;
		cacheTime = backpackTFPricelist.GetNum("current_time");

		int offset = GetTime() - cacheTime;
		backpackTFPricelist.SetNum("time_offset", offset);
		backpackTFPricelist.ExportToFile(path);

		budsToKeys = GetConversion(ITEM_EARBUDS);
		keysToRef = GetConversion(ITEM_KEY);
		backpackTFPricelist.Rewind();
		refToUsd = backpackTFPricelist.GetFloat("raw_usd_value");

		if(!cvarDisplayUpdateNotification.BoolValue) {
			return;
		}

		if(lastCacheTime == 0) { // first download
			ArrayList array = new ArrayList(128);
			array.PushString("#Type_command");
			SetHudTextParams(cvarHudXPos.FloatValue, cvarHudYPos.FloatValue, cvarHudHoldTime.FloatValue, cvarHudRed.IntValue, cvarHudGreen.IntValue, cvarHudBlue.IntValue, 255);
			for(int i = 1; i <= MaxClients; i++) {
				if(!IsClientInGame(i)) {
					continue;
				}
				ShowSyncHudText(i, hudText, "%t", "Price list updated");
				EmitSoundToClient(i, NOTIFICATION_SOUND);
			}
			CreateTimer(cvarHudHoldTime.FloatValue, Timer_DisplayHudText, array, TIMER_REPEAT);
			return;
		}

		PrepPriceKv();
		backpackTFPricelist.GotoFirstSubKey();
		bool isNegative = false;
		int lastUpdate;
		float valueOld, valueOldHigh, value, valueHigh, difference;
		char defindex[16], qualityIndex[32], quality[32], name[64], message[128], currency[32], currencyOld[32], oldPrice[64], newPrice[64];
		ArrayList array = new ArrayList(128);
		array.PushString("#Type_command");
		if(cvarDisplayChangedPrices.BoolValue) {
			do {
				// loop through items
				backpackTFPricelist.GetSectionName(defindex, sizeof(defindex));
				if(StringToInt(defindex) == ITEM_REFINED) {
					continue; // Skip over refined price changes
				}
				backpackTFPricelist.GotoFirstSubKey();
				do {
					// loop through qualities
					backpackTFPricelist.GetSectionName(qualityIndex, sizeof(qualityIndex));
					if(StrEqual(qualityIndex, "item_info"))  {
						backpackTFPricelist.GetString("item_name", name, sizeof(name));
						continue;
					}
					backpackTFPricelist.GotoFirstSubKey();
					do {
						// loop through instances (series #s, effects)
						lastUpdate = backpackTFPricelist.GetNum("last_change");
						if(lastUpdate == 0 || lastUpdate < lastCacheTime) {
							continue; // hasn't updated
						}
						valueOld = backpackTFPricelist.GetFloat("value_old");
						valueOldHigh = backpackTFPricelist.GetFloat("value_high_old");
						value = backpackTFPricelist.GetFloat("value");
						valueHigh = backpackTFPricelist.GetFloat("value_high");

						backpackTFPricelist.GetString("currency", currency, sizeof(currency));
						backpackTFPricelist.GetString("currency_old", currencyOld, sizeof(currencyOld));

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
							backpackTFPricelist.GetSectionName(effect, sizeof(effect));
							if(!unusualNameTrie.GetString(effect, quality, sizeof(quality))) {
								LogError("Unknown unusual effect: %s in OnBackpackTFComplete. Please report this!", effect);
								char kvPath[PLATFORM_MAX_PATH];
								BuildPath(Path_SM, kvPath, sizeof(kvPath), "data/backpack-tf.%d.txt", GetTime());
								if(!FileExists(kvPath)) {
									backpackTFPricelist.ExportToFile(kvPath);
								}
								continue;
							}
						} else {
							if(!qualityNameTrie.GetString(qualityIndex, quality, sizeof(quality))) {
								LogError("Unknown quality index: %s. Please report this!", qualityIndex);
								continue;
							}
						}

						Format(message, sizeof(message), "%s%s%s: %s #From %s #To %s", quality, StrEqual(quality, "") ? "" : " ", name, isNegative ? "#Down" : "#Up", oldPrice, newPrice);
						array.PushString(message);

					} while(backpackTFPricelist.GotoNextKey()); // end: instances
					backpackTFPricelist.GoBack();

				} while(backpackTFPricelist.GotoNextKey()); // end: qualities
				backpackTFPricelist.GoBack();

			} while(backpackTFPricelist.GotoNextKey()); // end: items
		}

		SetHudTextParams(cvarHudXPos.FloatValue, cvarHudYPos.FloatValue, cvarHudHoldTime.FloatValue, cvarHudRed.IntValue, cvarHudGreen.IntValue, cvarHudBlue.IntValue, 255);
		for(int i = 1; i <= MaxClients; i++) {
			if(!IsClientInGame(i)) {
				continue;
			}
			ShowSyncHudText(i, hudText, "%t", "Price list updated");
			EmitSoundToClient(i, NOTIFICATION_SOUND);
		}
		CreateTimer(cvarHudHoldTime.FloatValue, Timer_DisplayHudText, array, TIMER_REPEAT);
	}
}

float GetConversion(int defindex) {
	char buffer[32];
	PrepPriceKv();
	IntToString(defindex, buffer, sizeof(buffer));
	backpackTFPricelist.JumpToKey(buffer);
	backpackTFPricelist.JumpToKey("6");
	backpackTFPricelist.JumpToKey("0");
	float value = backpackTFPricelist.GetFloat("value");
	float valueHigh = backpackTFPricelist.GetFloat("value_high");
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

public Action Timer_DisplayHudText(Handle timer, ArrayList array) {
	if(array.Length == 0) {
		delete array;
		return Plugin_Stop;
	}
	char text[128], display[128];
	array.GetString(0, text, sizeof(text));
	SetHudTextParams(cvarHudXPos.FloatValue, cvarHudYPos.FloatValue, cvarHudHoldTime.FloatValue, cvarHudRed.IntValue, cvarHudGreen.IntValue, cvarHudBlue.IntValue, 255);
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
	backpackTFPricelist.Rewind();
	backpackTFPricelist.JumpToKey("prices");
}

public Action Command_PriceCheck(int client, int args) {
	if(backpackTFPricelist == null) {
		char key[32];
		cvarAPIKey.GetString(key, sizeof(key));
		if(strlen(key) == 0) {
			ReplyToCommand(client, "\x04[SM] \x01The server administrator has not filled in their API key yet. Please contact the server administrator.");
		} else {
			ReplyToCommand(client, "\x04[SM] \x01%t.", "The price list has not loaded yet");
		}
		return Plugin_Handled;
	}
	if(args == 0) {
		Menu menu = new Menu(Handler_ItemSelection);
		menu.SetTitle("Price Check");
		PrepPriceKv();
		backpackTFPricelist.GotoFirstSubKey();
		char name[128];
		do {
			if(!backpackTFPricelist.JumpToKey("item_info")) {
				continue;
			}
			backpackTFPricelist.GetString("item_name", name, sizeof(name));
			if(backpackTFPricelist.GetNum("proper_name") == 1) {
				Format(name, sizeof(name), "The %s", name);
			}
			menu.AddItem(name, name);
			backpackTFPricelist.GoBack();
		} while(backpackTFPricelist.GotoNextKey());
		menu.Display(client, cvarMenuHoldTime.IntValue);
		return Plugin_Handled;
	}
	int resultDefindex = -1;
	char defindex[8], name[128], itemName[128];
	GetCmdArgString(name, sizeof(name));
	bool exact = StripQuotes(name);
	PrepPriceKv();
	backpackTFPricelist.GotoFirstSubKey();
	ArrayList matches;
	if(!exact) {
		matches = new ArrayList(128);
	}
	do {
		backpackTFPricelist.GetSectionName(defindex, sizeof(defindex));
		if(!backpackTFPricelist.JumpToKey("item_info")) {
			continue;
		}
		backpackTFPricelist.GetString("item_name", itemName, sizeof(itemName));
		if(backpackTFPricelist.GetNum("proper_name") == 1) {
			Format(itemName, sizeof(itemName), "The %s", itemName);
		}
		backpackTFPricelist.GoBack();
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
	} while(backpackTFPricelist.GotoNextKey());
	if(!exact && matches.Length > 1) {
		Menu menu = new Menu(Handler_ItemSelection);
		menu.SetTitle("Search Results");
		int size = matches.Length;
		for(int i = 0; i < size; i++) {
			matches.GetString(i, itemName, sizeof(itemName));
			menu.AddItem(itemName, itemName);
		}
		menu.Display(client, GetConVarInt(cvarMenuHoldTime));
		delete matches;
		return Plugin_Handled;
	}
	if(!exact) {
		delete matches;
	}
	if(resultDefindex == -1) {
		ReplyToCommand(client, "\x04[SM] \x01No matching item was found.");
		return Plugin_Handled;
	}
	// At this point, we know that we've found our item. Its defindex is stored in resultDefindex as a cell
	// defindex was used to store the defindex of every item as we searched it, so it's not reliable
	if(resultDefindex == ITEM_REFINED) {
		SetGlobalTransTarget(client);
		Menu menu = new Menu(Handler_PriceListMenu);
		menu.SetTitle("%t\n%t\n%t\n ", "Price check", itemName, "Prices are estimates only", "Prices courtesy of backpack.tf");
		char buffer[32];
		Format(buffer, sizeof(buffer), "Unique: $%.2f USD", refToUsd);
		menu.AddItem("", buffer);
		menu.Display(client, GetConVarInt(cvarMenuHoldTime));
		return Plugin_Handled;
	}
	bool isCrate = (resultDefindex == ITEM_CRATE || resultDefindex == ITEM_SALVAGED_CRATE);
	bool onlyOneUnusual = (resultDefindex == ITEM_HEADTAKER || resultDefindex == ITEM_HAUNTED_SCRAP);
	PrepPriceKv();
	IntToString(resultDefindex, defindex, sizeof(defindex));
	backpackTFPricelist.JumpToKey(defindex);
	backpackTFPricelist.JumpToKey("item_info");
	backpackTFPricelist.GetString("item_name", itemName, sizeof(itemName));
	if(backpackTFPricelist.GetNum("proper_name") == 1) {
		Format(itemName, sizeof(itemName), "The %s", itemName);
	}
	backpackTFPricelist.GotoNextKey();

	SetGlobalTransTarget(client);
	Menu menu = new Menu(Handler_PriceListMenu);
	menu.SetTitle("%t\n%t\n%t\n ", "Price check", itemName, "Prices are estimates only", "Prices courtesy of backpack.tf");
	bool unusualDisplayed = false;
	float value, valueHigh;
	char currency[32], qualityIndex[16], quality[16], series[8], price[32], buffer[64];
	do {
		backpackTFPricelist.GetSectionName(qualityIndex, sizeof(qualityIndex));
		if(StrEqual(qualityIndex, "item_info") || StrEqual(qualityIndex, "alt_defindex")) {
			continue;
		}
		backpackTFPricelist.GotoFirstSubKey();
		do {
			if(StrEqual(qualityIndex, QUALITY_UNUSUAL) && !onlyOneUnusual) {
				if(!unusualDisplayed) {
					menu.AddItem(defindex, "Unusual: View Effects");
					unusualDisplayed = true;
				}
			} else {
				value = backpackTFPricelist.GetFloat("value");
				valueHigh = backpackTFPricelist.GetFloat("value_high");
				backpackTFPricelist.GetString("currency", currency, sizeof(currency));
				FormatPriceRange(value, valueHigh, currency, price, sizeof(price));

				if(!qualityNameTrie.GetString(qualityIndex, quality, sizeof(quality))) {
					LogError("Unknown quality index: %s. Please report this!", qualityIndex);
					continue;
				}
				if(isCrate) {
					backpackTFPricelist.GetSectionName(series, sizeof(series));
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
				menu.AddItem("", buffer, ITEMDRAW_DISABLED);
			}
		} while(backpackTFPricelist.GotoNextKey());
		backpackTFPricelist.GoBack();
	} while(backpackTFPricelist.GotoNextKey());
	menu.Display(client, GetConVarInt(cvarMenuHoldTime));
	return Plugin_Handled;
}

public int Handler_ItemSelection(Menu menu, MenuAction action, int client, int param) {
	if(action == MenuAction_End) {
		delete menu;
	}
	if(action != MenuAction_Select) {
		return;
	}
	char selection[128];
	if(menu.GetItem(param, selection, sizeof(selection)))
		FakeClientCommand(client, "sm_pricecheck \"%s\"", selection);
}

public int Handler_PriceListMenu(Menu menu, MenuAction action, int client, int param) {
	if(action == MenuAction_End) {
		delete menu;
	}
	if(action != MenuAction_Select) {
		return;
	}
	char defindex[32];
	if (menu.GetItem(param, defindex, sizeof(defindex)))
	{
		char name[64];
		PrepPriceKv();
		backpackTFPricelist.JumpToKey(defindex);
		backpackTFPricelist.JumpToKey("item_info");
		backpackTFPricelist.GetString("item_name", name, sizeof(name));
		if(backpackTFPricelist.GetNum("proper_name") == 1) {
			Format(name, sizeof(name), "The Unusual %s", name);
		} else {
			Format(name, sizeof(name), "Unusual %s", name);
		}
		backpackTFPricelist.GoBack();
	
		if(!backpackTFPricelist.JumpToKey(QUALITY_UNUSUAL)) {
			return;
		}
	
		backpackTFPricelist.GotoFirstSubKey();
	
		SetGlobalTransTarget(client);
		Menu menu2 = new Menu(Handler_PriceListMenu);
		SetMenuTitle(menu2, "%t\n%t\n%t\n ", "Price check", name, "Prices are estimates only", "Prices courtesy of backpack.tf");
		char effect[8], effectName[64], message[128], price[64], currency[32];
		float value, valueHigh;
		do {
			backpackTFPricelist.GetSectionName(effect, sizeof(effect));
			if(!unusualNameTrie.GetString(effect, effectName, sizeof(effectName))) {
				LogError("Unknown unusual effect: %s in Handler_PriceListMenu. Please report this!", effect);
				char path[PLATFORM_MAX_PATH];
				BuildPath(Path_SM, path, sizeof(path), "data/backpack-tf.%d.txt", GetTime());
				if(!FileExists(path)) {
					backpackTFPricelist.ExportToFile(path);
				}
				continue;
			}
			value = backpackTFPricelist.GetFloat("value");
			valueHigh = backpackTFPricelist.GetFloat("value_high");
			backpackTFPricelist.GetString("currency", currency, sizeof(currency));
			if(StrEqual(currency, "")) {
				continue;
			}
			FormatPriceRange(value, valueHigh, currency, price, sizeof(price), true);
	
			Format(message, sizeof(message), "%s: %s", effectName, price);
			menu2.AddItem("", message, ITEMDRAW_DISABLED);
		} while(backpackTFPricelist.GotoNextKey());
		menu2.Display(client, cvarMenuHoldTime.IntValue);
	}
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
	SteamWorks_GetClientSteamID(target, steamID, sizeof(steamID)); // we could use the regular Steam ID, but we already have SteamWorks, so we can just bypass backpack.tf's redirect directly
	char url[256];
	Format(url, sizeof(url), "https://backpack.tf/profiles/%s", steamID);
	AdvMOTD_ShowMOTDPanel(client, "backpack.tf", url, MOTDPANEL_TYPE_URL, true, true, true, OnMOTDFailure);
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
	Menu menu = new Menu(Handler_ClientMenu);
	menu.SetTitle("Select Player");
	char name[MAX_NAME_LENGTH], index[8];
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i) || IsFakeClient(i)) {
			continue;
		}
		GetClientName(i, name, sizeof(name));
		IntToString(GetClientUserId(i), index, sizeof(index));
		menu.AddItem(index, name);
	}
	menu.Display(client, GetConVarInt(cvarMenuHoldTime));
}

public int Handler_ClientMenu(Menu menu, MenuAction action, int client, int param) {
	if(action == MenuAction_End) {
		delete menu;
	}
	if(action != MenuAction_Select) {
		return;
	}
	char selection[32];
	if (menu.GetItem(param, selection, sizeof(selection)))
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
