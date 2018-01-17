#pragma newdecls required
#pragma semicolon 1

#include <sdktools>
#include <tf2items>
#include <tf2>
#include <tf2_stocks>
#include <morecolors>

#define PLUGIN_VERSION "1.3"

public Plugin myinfo = {
	name = "[NGS] Taunt Menu",
	author = "FlaminSarge, Nighty, xCoderx / TheXeon",
	description = "Displays a nifty taunt menu. TF2 only.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=242866"
}

Handle hPlayTaunt;

public void OnPluginStart()
{
	Handle conf = LoadGameConfigFile("tf2.tauntem");
	
	if (conf == null)
	{
		SetFailState("Unable to load gamedata/tf2.tauntem.txt. Good luck figuring that out.");
		return;
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(conf, SDKConf_Signature, "CTFPlayer::PlayTauntSceneFromItem");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	hPlayTaunt = EndPrepSDKCall();
	
	if (hPlayTaunt == null)
	{
		SetFailState("Unable to initialize call to CTFPlayer::PlayTauntSceneFromItem. Wait patiently for a fix.");
		delete conf;
		return;
	}
	
	RegConsoleCmd("sm_taunt", Cmd_TauntMenu, "Taunt Menu");
	RegConsoleCmd("sm_taunts", Cmd_TauntMenu, "Taunt Menu");
	
	delete conf;
	LoadTranslations("common.phrases");
	CreateConVar("tf_tauntmenu_version", PLUGIN_VERSION, "[NGS] Taunt Menu Version");
	PrecacheTaunts();
}

public void OnMapStart()
{
	PrecacheTaunts();
}

public Action Cmd_TauntMenu(int client, int args)
{
	if (GetClientTeam(client) < 1 || GetClientTeam(client) > 4 || !IsClientConnected(client))
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You must join a team to use this command.");
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
	TFClassType class = TF2_GetPlayerClass(client);
	Menu menu = new Menu(Taunt_MenuSelected);
	menu.SetTitle("===== NGS Taunt Menu =====");
	
	switch(class)
	{
		case TFClass_Scout:
		{
			menu.AddItem("1117", "Taunt: Battin' a Thousand");
			menu.AddItem("1119", "Taunt: Deep Fried Desire");
			menu.AddItem("1168", "Taunt: The Carlton");
			menu.AddItem("30572", "Taunt: The Boston Breakdance");
			menu.AddItem("30917", "Taunt: The Trackman's Touchdown");
			menu.AddItem("30920", "Taunt: The Bunnyhopper");
			menu.AddItem("30921", "Taunt: Runner's Rhythm");
		}
		case TFClass_Sniper:
		{
			menu.AddItem("1116", "Taunt: I See You");
			menu.AddItem("30609", "Taunt: The Killer Solo");
			menu.AddItem("30614", "Taunt: Most Wanted");
			menu.AddItem("30839", "Taunt: Didgeridrongo");
		}
		case TFClass_Soldier:
		{
			menu.AddItem("1113", "Taunt: Fresh Brewed Victory");
			menu.AddItem("30673", "Taunt: Soldier's Requiem");
			menu.AddItem("30761", "Taunt: The Fubar Fanfare");
		}
		case TFClass_Heavy:
		{
			menu.AddItem("30616", "Taunt: The Proletariat Posedown");
			menu.AddItem("1174", "Taunt: The Table Tantrum");
			menu.AddItem("1175", "Taunt: The Boiling Point");
			menu.AddItem("30843", "Taunt: The Russian Arms Race");
			menu.AddItem("30844", "Taunt: The Soviet Strongarm");
		}
		case TFClass_DemoMan:
		{
			menu.AddItem("1114", "Taunt: Spent Well Spirits");
			menu.AddItem("1120", "Taunt: Oblooterated");
			menu.AddItem("30671", "Taunt: True Scotsman's Call");
			menu.AddItem("30840", "Taunt: Scotsmann's Stagger");
		}
		case TFClass_Medic:
		{
			menu.AddItem("477", "Taunt: The Meet the Medic");
			menu.AddItem("1109", "Taunt: Results Are In");
			menu.AddItem("30918", "Taunt: Surgeon's Squeezebox");
		}
		
		case TFClass_Pyro:
		{
			menu.AddItem("1112", "Taunt: Party Trick");
			menu.AddItem("30570", "Taunt: Pool Party");
			menu.AddItem("30763", "Taunt: The Balloonibouncer");
			menu.AddItem("30876", "Taunt: The Headcase");
			menu.AddItem("30919", "Taunt: The Skating Scorcher");
		}
		case TFClass_Spy:
		{
			menu.AddItem("1108", "Taunt: Buy A Life");
			menu.AddItem("30615", "Taunt: The Box Trot");
			menu.AddItem("30762", "Taunt: Disco Fever");
			menu.AddItem("30922", "Taunt: Luxury Lounge");
		}
		case TFClass_Engineer:
		{
			menu.AddItem("1115", "Taunt: Rancho Relaxo");
			menu.AddItem("30618", "Taunt: Bucking Bronco");
			menu.AddItem("30842", "Taunt: The Dueling Banjo");
			menu.AddItem("30845", "Taunt: The Jumping Jack");
		}
	}
	
	menu.AddItem("167", "Taunt: The High Five!");
	menu.AddItem("438", "Taunt: The Director's Vision");
	menu.AddItem("463", "Taunt: The Schadenfreude");
	menu.AddItem("1015", "Taunt: The Shred Alert");
	menu.AddItem("1106", "Taunt: Square Dance");
	menu.AddItem("1107", "Taunt: Flippin' Awesome");
	menu.AddItem("1110", "Taunt: Rock, Paper, Scissors");
	menu.AddItem("1111", "Taunt: Skullcracker");
	menu.AddItem("1118", "Taunt: Conga");
	menu.AddItem("1157", "Taunt: Kazotsky Kick");
	menu.AddItem("1162", "Taunt: Mannrobics");
	menu.AddItem("30621", "Taunt: Burstchester");
	menu.AddItem("30672", "Taunt: Zoomin' Broom");
	menu.AddItem("1172", "Taunt: The Victory Lap");
	menu.AddItem("30816", "Taunt: Second Rate Sorcery");
	menu.AddItem("1182", "Taunt: Yeti Punch");
	menu.AddItem("1183", "Taunt: Yeti Smash");
	
	char itemBuffer[24];
	if (itemNum > -1 && menu.GetItem(itemNum, itemBuffer, sizeof(itemBuffer)))
	{
		ExecuteTaunt(client, StringToInt(itemBuffer));
		delete menu;
	}
	else
	{
		menu.Display(client, 20);
	}
}

public int Taunt_MenuSelected(Menu menu, MenuAction action, int iClient, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	
	if (action == MenuAction_Select)
	{
		char info[12];
		
		menu.GetItem(param2, info, sizeof(info));
		ExecuteTaunt(iClient, StringToInt(info));
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