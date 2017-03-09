#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <morecolors>

#define PLUGIN_VERSION "1.5"


public Plugin myinfo = {
	name = "[NGS] TF2 Class Menu",
	author = "Tylerst / TheXeon",
	description = "Set your class from a menu.",
	version = PLUGIN_VERSION,
}

TFClassType chosenClass[MAXPLAYERS + 1];
Handle changeClassTimer[MAXPLAYERS + 1];
int g_iLastThingPlayerBuilt[MAXPLAYERS + 1] = -1;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	char Game[32];
	GetGameFolderName(Game, sizeof(Game));
	if(!StrEqual(Game, "tf"))
	{
		Format(error, err_max, "This plugin only works for Team Fortress 2");
		return APLRes_Failure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{	
	LoadTranslations("common.phrases");
	CreateConVar("sm_classmenu_version", PLUGIN_VERSION, "Change a player's class on the spot, Usage: sm_class", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	RegConsoleCmd("sm_class", CommandClassMenu, "Usage: sm_class");
	RegConsoleCmd("sm_classmenu", CommandClassMenu, "Usage: sm_classmenu");
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath);
}

public Action CommandClassMenu(int client, int args)
{
	if (!IsValidClient(client) || !IsPlayerAlive(client)) return Plugin_Handled;
	if (changeClassTimer[client] != null)
	{
		KillTimer(changeClassTimer[client]);
		changeClassTimer[client] = null;
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Reset your class change.");
	}
	Menu menu = new Menu(ClassMenuSelected);
	menu.SetTitle("===== NGS Class Menu =====");
	menu.AddItem("scout", "Scout");
	menu.AddItem("soldier", "Soldier");
	menu.AddItem("pyro", "Pyro");
	menu.AddItem("demoman", "Demoman");
	menu.AddItem("heavy", "Heavy");
	menu.AddItem("engineer", "Engineer");
	menu.AddItem("medic", "Medic");
	menu.AddItem("sniper", "Sniper");
	menu.AddItem("spy", "Spy");
	menu.AddItem("random", "Random");
	menu.Display(client, 20);
	return Plugin_Handled;
}

public int ClassMenuSelected(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_End)
	{
		delete menu;
	}
	else if(action == MenuAction_Select)
	{
		char info[12];
		menu.GetItem(param2, info, sizeof(info));
		if (!StrEqual(info, "random")) chosenClass[client] = TF2_GetClass(info);
		else chosenClass[client] = view_as<TFClassType>(GetRandomInt(1, 9));
		changeClassTimer[client] = CreateTimer(5.0, ClassChanger, client);
		CPrintToChat(client, "{GREEN}[SM]{DEFAULT} You will be changed in {PURPLE}5{DEFAULT} seconds.");
	}
}

public Action ClassChanger(Handle timer, any client)
{
	SetClass(client, chosenClass[client]);
	changeClassTimer[client] = null;
}

public void SetClass(int client, TFClassType class)
{
	if (!IsValidClient(client)) return;
	
	if (TF2_GetPlayerClass(client) == TFClass_Engineer)
	{
		int iEnt = -1;
		while ((iEnt = FindEntityByClassname(iEnt, "obj_sentrygun")) != INVALID_ENT_REFERENCE)
		{
			if (GetEntPropEnt(iEnt, Prop_Send, "m_hBuilder") == client)
			{
				AcceptEntityInput(iEnt, "Kill");
			}
		}
		while ((iEnt = FindEntityByClassname(iEnt, "obj_dispenser")) != INVALID_ENT_REFERENCE)
		{
			if (GetEntPropEnt(iEnt, Prop_Send, "m_hBuilder") == client)
			{
				AcceptEntityInput(iEnt, "Kill");
			}
		}
		while ((iEnt = FindEntityByClassname(iEnt, "obj_teleporter")) != INVALID_ENT_REFERENCE)
		{
			if (GetEntPropEnt(iEnt, Prop_Send, "m_hBuilder") == client && (TF2_GetObjectMode(iEnt) == TFObjectMode_Entrance || TF2_GetObjectMode(iEnt) == TFObjectMode_Exit))
			{
				AcceptEntityInput(iEnt, "Kill");
			}
		}
	}
	float setHealth = GetDefaultMaxHealth(class) * (GetClientHealth(client) / GetDefaultMaxHealth(TF2_GetPlayerClass(client)));
	TF2_SetPlayerClass(client, class);
	if(IsPlayerAlive(client))
	{
		SetEntityHealth(client, 25);
		TF2_RegeneratePlayer(client);
		SetEntityHealth(client, RoundToFloor(setHealth));
		int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
		if(IsValidEntity(weapon))
		{
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
		}
	}
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	LogMessage("[SM] %s changed class to %d.", name, class);
	return;	
}

float GetDefaultMaxHealth(TFClassType class)
{
	if (class == TFClass_Scout || class == TFClass_Spy || class == TFClass_Engineer || class == TFClass_Sniper) return 125.0;
	else if (class == TFClass_Medic) return 150.0;
	else if (class == TFClass_Pyro || class == TFClass_DemoMan) return 175.0;
	else if (class == TFClass_Soldier) return 200.0;
	else if (class == TFClass_Heavy) return 300.0;
	else return 125.0;
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
 	if (changeClassTimer[client] != null)
	{
		KillTimer(changeClassTimer[client]);
		changeClassTimer[client] = null;
		CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Your class change has been interrupted!");
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
 	if (changeClassTimer[client] != null)
	{
		KillTimer(changeClassTimer[client]);
		changeClassTimer[client] = null;
		CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Your class change has been interrupted!");
	}
}

public void OnClientDisconnect(int client)
{
	if (changeClassTimer[client] != null)
	{
		KillTimer(changeClassTimer[client]);
		changeClassTimer[client] = null;
	}
	g_iLastThingPlayerBuilt[client] = -1;
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