/** Commented as tf2items isnt using new-style syntax yet.
#pragma newdecls required
*/
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
		CloseHandle(conf);
		return;
	}
	
	RegConsoleCmd("sm_taunt", Cmd_TauntMenu, "Taunt Menu");
	RegConsoleCmd("sm_taunts", Cmd_TauntMenu, "Taunt Menu");
	
	CloseHandle(conf);
	LoadTranslations("common.phrases");
	CreateConVar("tf_tauntmenu_version", PLUGIN_VERSION, "[NGS] Taunt Menu Version", FCVAR_NOTIFY);
	
	
	PrecacheModel("models/player/items/taunts/cash_wad.mdl", true);
	PrecacheModel("models/player/items/taunts/medic_xray_taunt.mdl", true);
	PrecacheModel("models/player/items/taunts/victory_mug.mdl", true);
	PrecacheModel("models/player/items/taunts/balloon_animal_pyro/balloon_animal_pyro.mdl", true);
	PrecacheModel("models/player/items/taunts/beer_crate/beer_crate.mdl", true);
	PrecacheModel("models/player/items/taunts/chicken_bucket/chicken_bucket.mdl", true);
	PrecacheModel("models/player/items/taunts/demo_nuke_bottle/demo_nuke_bottle.mdl", true);
	PrecacheModel("models/player/items/taunts/dizzy_bottle1/dizzy_bottle1.mdl", true);
	PrecacheModel("models/player/items/taunts/dizzy_bottle2/dizzy_bottle2.mdl", true);
	PrecacheModel("models/player/items/taunts/engys_new_chair/engys_new_chair.mdl", true);
	PrecacheModel("models/player/items/taunts/engys_new_chair/engys_new_chair_articulated.mdl", true);
	PrecacheModel("models/player/items/taunts/wupass_mug/wupass_mug.mdl", true);
	PrecacheModel("models/workshop/player/items/taunts/pyro_poolparty/pyro_poolparty.mdl", true);
	PrecacheModel("models/workshop/player/items/spy/taunt_spy_boxtrot/taunt_spy_boxtrot.mdl", true);
	PrecacheModel("models/workshop/player/items/sniper/killer_solo/killer_solo.mdl", true);
	PrecacheModel("models/workshop/player/items/sniper/taunt_most_wanted/taunt_most_wanted.mdl", true);
}

public Action Cmd_TauntMenu(int client, int args)
{
	if (GetClientTeam(client) < 1 || GetClientTeam(client) > 4 || !IsClientConnected(client))
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You must join a team to use this command.");
		return Plugin_Handled;
	}
	ShowMenu(client);
	return Plugin_Handled;
}

public Action ShowMenu(int client)
{
	TFClassType class = TF2_GetPlayerClass(client);
	Menu menu = CreateMenu(Taunt_MenuSelected);
	SetMenuTitle(menu, "===== NGS Taunt Menu =====");
	
	switch(class)
	{
		case TFClass_Scout:
		{
			AddMenuItem(menu, "1117", "Taunt: Battin' a Thousand");
			AddMenuItem(menu, "1119", "Taunt: Deep Fried Desire");
			AddMenuItem(menu, "1168", "Taunt: The Carlton");
			AddMenuItem(menu, "30572", "Taunt: The Boston Breakdance");
		}
		case TFClass_Sniper:
		{
			AddMenuItem(menu, "1116", "Taunt: I See You");
			AddMenuItem(menu, "30609", "Taunt: The Killer Solo");
			AddMenuItem(menu, "30614", "Taunt: Most Wanted");
		}
		case TFClass_Soldier:
		{
			AddMenuItem(menu, "1113", "Taunt: Fresh Brewed Victory");
			AddMenuItem(menu, "30673", "Taunt: Soldier's Requiem");
			AddMenuItem(menu, "30761", "Taunt: The Fubar Fanfare");
		}
		case TFClass_Heavy:
		{
			AddMenuItem(menu, "30616", "Taunt: The Proletariat Posedown");
		}
		case TFClass_DemoMan:
		{
			AddMenuItem(menu, "1114", "Taunt: Spent Well Spirits");
			AddMenuItem(menu, "1120", "Taunt: Oblooterated");
			AddMenuItem(menu, "30671", "Taunt: True Scotsman's Call");
		}
		case TFClass_Medic:
		{
			AddMenuItem(menu, "477", "Taunt: The Meet the Medic");
			AddMenuItem(menu, "1109", "Taunt: Results Are In");
		}
		
		case TFClass_Pyro:
		{
			AddMenuItem(menu, "1112", "Taunt: Party Trick");
			AddMenuItem(menu, "30570", "Taunt: Pool Party");
			AddMenuItem(menu, "30763", "Taunt: The Balloonibouncer");
		}
		case TFClass_Spy:
		{
			AddMenuItem(menu, "1108", "Taunt: Buy A Life");
			AddMenuItem(menu, "30615", "Taunt: The Box Trot");
			AddMenuItem(menu, "30762", "Taunt: Disco Fever");
		}
		case TFClass_Engineer:
		{
			AddMenuItem(menu, "1115", "Taunt: Rancho Relaxo");
			AddMenuItem(menu, "30618", "Taunt: Bucking Bronco");
		}
	}
	
	AddMenuItem(menu, "167", "Taunt: The High Five!");
	AddMenuItem(menu, "438", "Taunt: The Director's Vision");
	AddMenuItem(menu, "463", "Taunt: The Schadenfreude");
	AddMenuItem(menu, "1015", "Taunt: The Shred Alert");
	AddMenuItem(menu, "1106", "Taunt: Square Dance");
	AddMenuItem(menu, "1107", "Taunt: Flippin' Awesome");
	AddMenuItem(menu, "1110", "Taunt: Rock, Paper, Scissors");
	AddMenuItem(menu, "1111", "Taunt: Skullcracker");
	AddMenuItem(menu, "1118", "Taunt: Conga");
	AddMenuItem(menu, "1157", "Taunt: Kazotsky Kick");
	AddMenuItem(menu, "1162", "Taunt: Mannrobics");
	AddMenuItem(menu, "30621", "Taunt: Burstchester");
	AddMenuItem(menu, "30672", "Taunt: Zoomin' Broom");
	
	DisplayMenu(menu, client, 20);
}

public int Taunt_MenuSelected(Handle menu, MenuAction action, int iClient, int param2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	
	if(action == MenuAction_Select)
	{
		char info[12];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		ExecuteTaunt(iClient, StringToInt(info));
	}
}

public void ExecuteTaunt(int client, int itemdef)
{
	if (TF2_GetPlayerClass(client) == TFClass_Spy)
	{
		TF2_RemovePlayerDisguise(client);
	}
	Handle hItem = TF2Items_CreateItem(OVERRIDE_ALL|PRESERVE_ATTRIBUTES|FORCE_GENERATION);
	
	TF2Items_SetClassname(hItem, "tf_wearable_vm");
	TF2Items_SetQuality(hItem, 6);
	TF2Items_SetLevel(hItem, 1);
	TF2Items_SetNumAttributes(hItem, 0);
	TF2Items_SetItemIndex(hItem, itemdef);
	
	int ent = TF2Items_GiveNamedItem(client, hItem);
	Address pEconItemView = GetEntityAddress(ent) + view_as<Address>(FindSendPropInfo("CTFWearable", "m_Item"));
	
	SDKCall(hPlayTaunt, client, pEconItemView) ? 1 : 0;
	AcceptEntityInput(ent, "Kill");
}