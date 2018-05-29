/**
* TheXeon
* ngs_tauntmenu.sp
*
* Files:
* addons/sourcemod/plugins/ngs_tauntmenu.smx
* addons/sourcemod/gamedata/tf2.tauntem.txt
*
* Dependencies:
* tf2items.inc, tf2_stocks.inc, morecolors.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define ALL_PLUGINS_LOADED_FUNC AllPluginsLoaded
#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <tf2items>
#include <tf2_stocks>
#include <morecolors>
#include <ngsutils>
#include <ngsupdater>

#undef REQUIRE_PLUGIN
#include <tf2idb>
#define REQUIRE_PLUGIN

//#define DEBUG

public Plugin myinfo = {
	name = "[NGS] Taunt Menu",
	author = "FlaminSarge, Nighty, xCoderx / TheXeon",
	description = "Displays a nifty taunt menu. TF2 only.",
	version = "1.4.1",
	url = "http://forums.alliedmods.net/showthread.php?t=242866"
}

Handle hPlayTaunt;
Menu classTaunt[10];

public void OnPluginStart()
{
	Handle conf = LoadGameConfigFile("tf2.tauntem");

	if (conf == null)
	{
		SetFailState("Unable to load gamedata/tf2.tauntem.txt. Get it from the forums or repo!");
		return;
	}

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(conf, SDKConf_Signature, "CTFPlayer::PlayTauntSceneFromItem");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	hPlayTaunt = EndPrepSDKCall();

	if (hPlayTaunt == null)
	{
		delete conf;
		SetFailState("Unable to initialize call to CTFPlayer::PlayTauntSceneFromItem. Wait patiently for a fix.");
		return;
	}
	delete conf;

	RegConsoleCmd("sm_taunt", Cmd_TauntMenu, "Taunt Menu");
	RegConsoleCmd("sm_tauntmenu", Cmd_TauntMenu, "Taunt Menu");
	RegConsoleCmd("sm_taunts", Cmd_TauntMenu, "Taunt Menu");

	LoadTranslations("common.phrases");
}

public void AllPluginsLoaded()
{
	LoadTauntMenus();
}

public void LoadTauntMenus()
{
	// Thanks to fakuivan for some inspiration
	ArrayList tauntIds = view_as<ArrayList>(TF2IDB_FindItemCustom("SELECT `id` FROM tf2idb_item WHERE `slot` IS 'taunt'"));
	int size = tauntIds.Length;
	int nameSize = 128;

	char[][] tauntNames = new char[size][nameSize];
	int[] tauntBits = new int[size];

	char name[128], tauntBuffer[128];
	for (int i = 0; i < size; i++)
	{
		int id = tauntIds.Get(i);
		TF2IDB_GetItemName(id, tauntBuffer, nameSize);
		if (StrContains(name, "Taunt:") != 0)
		{
			ReplaceString(tauntBuffer, nameSize, "Taunt", "");
			ReplaceString(tauntBuffer, nameSize, ":", "");
			ReplaceString(tauntBuffer, nameSize, "  ", " ");
			TrimString(tauntBuffer);
			Format(tauntNames[i], nameSize, "Taunt: %s", tauntBuffer);
		}
		else
		{
			strcopy(tauntNames[i], nameSize, tauntBuffer);
		}
		tauntBits[i] = TF2IDB_UsedByClasses_Compat(id);
		#if defined DEBUG
		PrintToServer("At index %d adding id: %d, name: %s (possibly %s formatted), bits: %d to arrays.", i, id, tauntNames[i], tauntBuffer, tauntBits[i]);
		PrintToServer("Retrieved string %s from names!", tauntNames[i]);
		#endif
	}
	char strId[12];
	for (int i = 1; i < sizeof(classTaunt); i++)
	{
		classTaunt[i] = new Menu(Taunt_MenuSelected);
		classTaunt[i].SetTitle("===== NGS Taunt Menu =====");
		int classBits = (1 << i);
		for (int j = 0; j < size; j++)
		{
			int bitfield = tauntBits[j];
			#if defined DEBUG
			PrintToServer("Retrieved bitfield %d for item %s index %d, testing it against %d.", bitfield, tauntNames[j], j, classBits);
			#endif
			bool wasSpecific;
			if (bitfield == 0b1111111110 || (wasSpecific = view_as<bool>(bitfield & classBits)))
			{
				int id = tauntIds.Get(j);
				IntToString(id, strId, sizeof(strId));
				#if defined DEBUG
				PrintToServer("Retrieved item %s at index %d from names.", tauntNames[j], j);
				#endif
				if (wasSpecific)
				{
					classTaunt[i].InsertItem(0, strId, tauntNames[j]);
				}
				else
				{
					classTaunt[i].AddItem(strId, tauntNames[j]);
				}
			}
		}
	}
	delete tauntIds;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_TF2)
	{
		LogError("This plugin is currently only for TF2!");
		return APLRes_Failure;
	}
	return APLRes_Success;
}

public void OnMapStart()
{
	PrecacheTaunts();
}

public Action Cmd_TauntMenu(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	if (!IsPlayerAlive(client))
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You can only use this when you are alive!");
		return Plugin_Handled;
	}
	int item = 0;
	if (args > 0)
	{
		char itemNum[8];
		GetCmdArg(1, itemNum, sizeof(itemNum));
		item = StringToInt(itemNum);
	}
	ShowMenu(client, item - 1);
	return Plugin_Handled;
}

public void ShowMenu(int client, int itemNum)
{
	int iClass = view_as<int>(TF2_GetPlayerClass(client));
	char itemBuffer[24];

	if (itemNum > -1 && classTaunt[iClass].GetItem(itemNum, itemBuffer, sizeof(itemBuffer)))
	{
		ExecuteTaunt(client, StringToInt(itemBuffer));
	}
	else
	{
		classTaunt[iClass].Display(client, 20);
	}
}

public int Taunt_MenuSelected(Menu menu, MenuAction action, int iClient, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[12];

		if (menu.GetItem(param2, info, sizeof(info)))
		{
			ExecuteTaunt(iClient, StringToInt(info));
		}
	}
}

public void ExecuteTaunt(int client, int itemdef)
{
	if (TF2_GetPlayerClass(client) == TFClass_Spy)
	{
		TF2_RemovePlayerDisguise(client);
	}
	TF2Item hItem = new TF2Item(OVERRIDE_ALL|PRESERVE_ATTRIBUTES|FORCE_GENERATION);

	hItem.SetClassname("tf_wearable_vm");
	hItem.Quality = 6;
	hItem.Level = 1;
	hItem.NumAttributes = 0;
	hItem.DefIndex = itemdef;

	int ent = hItem.GiveNamedItem(client);
	Address pEconItemView = GetEntityAddress(ent) + view_as<Address>(FindSendPropInfo("CTFWearable", "m_Item"));

	SDKCall(hPlayTaunt, client, pEconItemView) ? 1 : 0;
	AcceptEntityInput(ent, "Kill");
}

// TF2IDB stuff, thank you Faukivan
stock int TF2IDB_UsedByClasses_Compat(int i_id)
{
	if (GetFeatureStatus(FeatureType_Native, "TF2IDB_UsedByClasses") == FeatureStatus_Available)
	{
		//your include needs to declare ``TF2IDB_UsedByClasses`` for this to compile correctly,
		//and have ``REQUIRE_PLUGIN`` undefined.
		return TF2IDB_UsedByClasses(i_id);
	}
	char s_query[255 /* the query without the id is ~249 chars */ - 2 + 12];

	Format(s_query, sizeof(s_query),
		"SELECT replace(replace(replace(replace(replace(replace(replace(replace(replace(" ...
		"`class`, 'scout', 1), 'sniper', 2), 'soldier', 3), 'demoman', 4), 'medic', 5), 'heavy', 6), 'pyro', 7), 'spy', 8), 'engineer', 9) " ...
		"FROM `tf2idb_class` WHERE `id` IS %d",
		i_id);

	ArrayList h_classes = view_as<ArrayList>(TF2IDB_FindItemCustom(s_query));
	int i_bitmask;

	for (int i_iter = 0; i_iter < h_classes.Length; i_iter++)
	{
		int class = h_classes.Get(i_iter);
		i_bitmask |= (1 << class);
		#if defined DEBUG
		PrintToServer("For item %d, i_bitmask is now %d from class %d.", i_id, i_bitmask, class);
		#endif
	}
	return i_bitmask;
}

// Looks like this stuff doesnt even work.
public void PrecacheTaunts()
{
	PrecacheModel("models/player/items/taunts/cash_wad.mdl", false);
	PrecacheModel("models/player/items/taunts/medic_xray_taunt.mdl", false);
	PrecacheModel("models/player/items/taunts/victory_mug.mdl", false);
	PrecacheModel("models/player/items/taunts/balloon_animal_pyro/balloon_animal_pyro.mdl", false);
	PrecacheModel("models/player/items/taunts/beer_crate/beer_crate.mdl", false);
	PrecacheModel("models/player/items/taunts/chicken_bucket/chicken_bucket.mdl", false);
	PrecacheModel("models/player/items/taunts/demo_nuke_bottle/demo_nuke_bottle.mdl", false);
	PrecacheModel("models/player/items/taunts/dizzy_bottle1/dizzy_bottle1.mdl", false);
	PrecacheModel("models/player/items/taunts/dizzy_bottle2/dizzy_bottle2.mdl", false);
	PrecacheModel("models/player/items/taunts/engys_new_chair/engys_new_chair.mdl", false);
	PrecacheModel("models/player/items/taunts/engys_new_chair/engys_new_chair_articulated.mdl", false);
	PrecacheModel("models/player/items/taunts/wupass_mug/wupass_mug.mdl", false);
	PrecacheModel("models/workshop/player/items/taunts/pyro_poolparty/pyro_poolparty.mdl", false);
	PrecacheModel("models/workshop/player/items/spy/taunt_spy_boxtrot/taunt_spy_boxtrot.mdl", false);
	PrecacheModel("models/workshop/player/items/sniper/killer_solo/killer_solo.mdl", false);
	PrecacheModel("models/workshop/player/items/sniper/taunt_most_wanted/taunt_most_wanted.mdl", false);
	PrecacheModel("models/player/items/taunts/bumpercar/parts/bumpercar.mdl", false);
	PrecacheModel("models/player/items/heavy/heavy_table_flip_prop.mdl", false);
	PrecacheModel("models/player/items/heavy/heavy_table_flip_joule_prop.mdl", false);
	PrecacheModel("models/workshop/player/items/engineer/bucking_bronco/bucking_bronco.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/taunt_burstchester/taunt_burstchester_scout.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/taunt_burstchester/taunt_burstchester_sniper.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/taunt_burstchester/taunt_burstchester_soldier.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/taunt_burstchester/taunt_burstchester_demo.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/taunt_burstchester/taunt_burstchester_medic.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/taunt_burstchester/taunt_burstchester_heavy.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/taunt_burstchester/taunt_burstchester_pyro.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/taunt_burstchester/taunt_burstchester_spy.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/taunt_burstchester/taunt_burstchester_engineer.mdl", false);
	PrecacheModel("models/workshop/player/items/demo/bagpipes/bagpipes.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/zoomin_broom/zoomin_broom_scout.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/zoomin_broom/zoomin_broom_sniper.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/zoomin_broom/zoomin_broom_soldier.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/zoomin_broom/zoomin_broom_demo.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/zoomin_broom/zoomin_broom_medic.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/zoomin_broom/zoomin_broom_heavy.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/zoomin_broom/zoomin_broom_pyro.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/zoomin_broom/zoomin_broom_spy.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/zoomin_broom/zoomin_broom_engineer.mdl", false);
	PrecacheModel("models/workshop/player/items/soldier/taunt_maggots_condolence/taunt_maggots_condolence.mdl", false);
	PrecacheModel("models/workshop/player/items/soldier/fumblers_fanfare/fumblers_fanfare.mdl", false);
	PrecacheModel("models/workshop/player/items/pyro/spring_rider/spring_rider.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/secondrate_sorcery/secondrate_sorcery_scout.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/secondrate_sorcery/secondrate_sorcery_sniper.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/secondrate_sorcery/secondrate_sorcery_soldier.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/secondrate_sorcery/secondrate_sorcery_demo.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/secondrate_sorcery/secondrate_sorcery_medic.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/secondrate_sorcery/secondrate_sorcery_heavy.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/secondrate_sorcery/secondrate_sorcery_pyro.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/secondrate_sorcery/secondrate_sorcery_spy.mdl", false);
	PrecacheModel("models/workshop/player/items/all_class/secondrate_sorcery/secondrate_sorcery_engineer.mdl", false);
	PrecacheModel("models/workshop/player/items/sniper/taunt_didgeridrongo/taunt_didgeridrongo.mdl", false);
	PrecacheModel("models/workshop/player/items/demo/taunt_scotsmans_stagger/taunt_scotsmans_stagger.mdl", false);
	PrecacheModel("models/player/items/heavy/brutal_guitar.mdl", false);
	PrecacheModel("models/player/items/heavy/brutal_guitar_xl.mdl", false);
}
