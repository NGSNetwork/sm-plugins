#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <morecolors>
#include <tf2>
#include <tf2_stocks>
#undef REQUIRE_PLUGIN
#include <adminmenu>

#define PLUGIN_VERSION 			"1.4"

Handle sm_rweapons_show = null;
Handle hAdminMenu = null;

public Plugin myinfo = {
	name = "[NGS] Remove Weapons / Civilian Mode",
	author = "Starman2098 / TheXeon",
	description = "Lets an admin remove a players weapons or a player enter civlian mode.",
	version = PLUGIN_VERSION,
	url = "http://www.starman2098.com"
}

public void OnPluginStart()
{
	CreateConVar("sm_rwepciv_version", PLUGIN_VERSION, "Remove weapons plugin Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	sm_rweapons_show = CreateConVar("sm_rweapons_show", "1", "Toggles target messages on and off, 0 for off, 1 for on. - Default 1");
	RegAdminCmd("sm_rweapons", CommandRemoveWeapons, ADMFLAG_KICK,"sm_rweapons <user id | name>");
	LoadTranslations("common.phrases");
	AutoExecConfig();
	Handle topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(topmenu);
	}
}

public Action CommandRemoveWeapons(int client, int args)
{
	char target[MAXPLAYERS], target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	GetCmdArg(1, target, sizeof(target));
	if (args != 1)
	{
		CReplyToCommand(client, "{GREEN}[SM]{NORMAL} Usage: sm_rweapons <name>");
		return Plugin_Handled;
	}

	if (target[client] == -1)
	{
		return Plugin_Handled;
	}

	if ((target_count = ProcessTargetString(
			target,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		PerformRemoveWeapons(client,target_list[i]);
	}	
	return Plugin_Handled;
}

public Action PerformRemoveWeapons(int client, int target)
{
	if((GetConVarInt(sm_rweapons_show) < 0) || (GetConVarInt(sm_rweapons_show) > 1))
	{
		ReplyToCommand(client, "[SM] Usage: sm_rweapons_show <0 - off | 1 - on> - Defaulting to 1");
		SetConVarInt(sm_rweapons_show, 1);
		return Plugin_Handled;
	}

	if(GetConVarInt(sm_rweapons_show) == 0)
	{
		TF2_RemoveAllWeapons(target);
		LogAction(client, target, "\"%L\" removed weapons on \"%L\"", client, target);
		return Plugin_Handled;
	}

	if(GetConVarInt(sm_rweapons_show) == 1)
	{
		TF2_RemoveAllWeapons(target);
		LogAction(client, target, "\"%L\" removed weapons on \"%L\".", client, target);
		CReplyToCommand(client, "You removed {LIGHTGREEN}%N's{NORMAL} weapons.", target);
		ShowActivity2(client, "", "%N has removed %N's weapons.", client,target);
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public void OnAdminMenuReady(Handle topmenu)
{
	if (topmenu == hAdminMenu)
	{
		return;
	}
	
	hAdminMenu = topmenu;

	TopMenuObject player_commands = FindTopMenuCategory(hAdminMenu, ADMINMENU_PLAYERCOMMANDS);

	if (player_commands != INVALID_TOPMENUOBJECT)
	{
		AddToTopMenu(hAdminMenu,
			"sm_rweapons",
			TopMenuObject_Item,
			AdminMenu_Particles, 
			player_commands,
			"sm_rweapons",
			ADMFLAG_KICK);
	}
}
 
public void AdminMenu_Particles(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Remove Weapons");
	}
	else if( action == TopMenuAction_SelectOption)
	{
		DisplayPlayerMenu(param);
	}
}

void DisplayPlayerMenu(int client)
{
	Handle menu = CreateMenu(MenuHandler_Players);
	
	char title[100];
	Format(title, sizeof(title), "Choose Player:");
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	
	AddTargetsToMenu(menu, client, true, true);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandler_Players(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hAdminMenu != null)
		{
			DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		int userid, target;
		
		GetMenuItem(menu, param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			CPrintToChat(param1, "{GREEN}[SM]{NORMAL} %s", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			CPrintToChat(param1, "{GREEN}[SM]{NORMAL} %s", "Unable to target");
		}
		else
		{			
			PerformRemoveWeapons(param1, target);
			if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
			{
				DisplayPlayerMenu(param1);
			}
			
		}
	}

}
