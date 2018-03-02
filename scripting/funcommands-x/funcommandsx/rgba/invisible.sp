//Invisible: by Spazman0

/*****************************************************************


			G L O B A L   V A R S


*****************************************************************/
new bool:g_Invisible[MAXPLAYERS+1] = {false, ...};
new g_AlphaTarget[MAXPLAYERS+1];

/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/
public SetupInvisible()
{
	RegAdminCmd("sm_invis", Command_Invis, ADMFLAG_SLAY,"sm_invis <name or #userid> <1|0> - toggles or sets player invisibility");
	RegAdminCmd("sm_invisplayer", Command_InvisPlayer, ADMFLAG_SLAY,"sm_invisplayer <name or #userid> <1|0> - toggles or sets player invisibility (does not affect weapon)");
	RegAdminCmd("sm_alpha", Command_Alpha, ADMFLAG_SLAY,"sm_alpha <name or #userid> <0-255> - sets player alpha");	
}

/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/
public bool:OnClientConnect_Invisible(client, String:rejectmsg[], maxlen)
{
	g_Invisible[client] = false;
	return true;
}

public Action:Command_Invis(client, args)
{
	decl String:target[65];
	decl String:toggleStr[2];
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS];
	decl target_count;
	decl bool:tn_is_ml;
	
	new toggle = 2;
	
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_invis <#userid|name> <1|0>");
		return Plugin_Handled;
	}
		
	GetCmdArg(1, target, sizeof(target));	
	
	if (args > 1)
	{
		GetCmdArg(2, toggleStr, sizeof(toggleStr));
		if (StrEqual(toggleStr[0],"1"))
		{
			toggle = 1;
		}
		else if (StrEqual(toggleStr[0],"0"))
		{
			toggle = 0;
		}
		else
		{
			ReplyToCommand(client, "[SM] Usage: sm_invis <#userid|name> <1|0>");
			return Plugin_Handled;	
		}
	}
	
	if ((target_count = ProcessTargetString(
			target,
			client,
			target_list,
			MAXPLAYERS,
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		PerformInvis(client, target_list[i], toggle);
	}
	
	ShowActivity2(client, "[SM] ", "%t", "Toggled invisible on target",  target_name );
	
	return Plugin_Handled; 
}



public Action:Command_InvisPlayer(client, args)
{
	decl String:target[65];
	decl String:toggleStr[2];
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS];
	decl target_count;
	decl bool:tn_is_ml;
	
	new toggle = 2;
	
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_invisplayer <#userid|name> <1|0>");
		return Plugin_Handled;
	}
		
	GetCmdArg(1, target, sizeof(target));	
	
	if (args > 1)
	{
		GetCmdArg(2, toggleStr, sizeof(toggleStr));
		if (StrEqual(toggleStr[0],"1"))
		{
			toggle = 1;
		}
		else if (StrEqual(toggleStr[0],"0"))
		{
			toggle = 0;
		}
		else
		{
			ReplyToCommand(client, "[SM] Usage: sm_invisplayer <#userid|name> <1|0>");
			return Plugin_Handled;	
		}
	}
	
	if ((target_count = ProcessTargetString(
			target,
			client,
			target_list,
			MAXPLAYERS,
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		PerformInvis(client, target_list[i], toggle, false);
	}
	
	ShowActivity2(client, "[SM] ", "%t", "Toggled invisible on target",  target_name );
	
	return Plugin_Handled; 
}

public Action:Command_Alpha(client, args)
{
	decl String:target[65];
	decl String:alphaStr[20];
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS];
	decl target_count;
	decl bool:tn_is_ml;
	
	new alpha = 0;
	
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_alpha <#userid|name> <0-255>");
		return Plugin_Handled;
	}
		
	GetCmdArg(1, target, sizeof(target));
	GetCmdArg(2, alphaStr, sizeof(alphaStr));
	StringToIntEx(alphaStr, alpha);
	
	if ((target_count = ProcessTargetString(
			target,
			client,
			target_list,
			MAXPLAYERS,
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		PerformSetAlpha(client, target_list[i], alpha);
	}
	
	ShowActivity2(client, "[SM] ", "%t", "Set alpha on target",  target_name, alpha );
	
	return Plugin_Handled; 
}

/*****************************************************************


			P L U G I N   F U N C T I O N S


*****************************************************************/
PerformInvis(client, target, toggle, bool:weapon = true)
{
 	switch(toggle)
 	{
 		case(2):
 		{
			if (g_Invisible[target] == false)
			{
				CreateInvis(target, weapon);
				LogAction(client, target, "\"%L\" made \"%L\" invisible", client, target);
			}
			else
			{
				KillInvis(target);
				LogAction(client, target, "\"%L\" made \"%L\" visible", client, target);
			}
 		}
 		case(1):
 		{
 			CreateInvis(target, weapon);
 			LogAction(client, target, "\"%L\" made \"%L\" invisible", client, target);
 		}
 		case(0):
 		{
 			KillInvis(target);
 			LogAction(client, target, "\"%L\" made \"%L\" visible", client, target);
 		}
 	}
}

KillInvis(target)
{
	g_PlayerColor[target][3] = 255;
	g_AffectWeapon[target] = true;
	DoRGBA(target,RENDER_TRANSCOLOR);
	g_Invisible[target] = false;	
}

CreateInvis(target, bool:weapon)	
{
	g_PlayerColor[target][3] = 0;
	g_AffectWeapon[target] = weapon;
	DoRGBA(target,RENDER_TRANSCOLOR, weapon);
	g_Invisible[target] = true;
}

PerformSetAlpha(client, target, alpha)
{		
	g_PlayerColor[target][3] = alpha;
	
	DoRGBA(target,RENDER_TRANSCOLOR);
	LogAction(client, target, "\"%L\" set alpha on \"%L\" to %i", client, target, alpha);
}

/*****************************************************************


			A D M I N   M E N U   F U N C T I O N S


*****************************************************************/
Setup_AdminMenu_Invis_Player(TopMenuObject:parentmenu)
{
	AddToTopMenu(hTopMenu, 
		"sm_invis",
		TopMenuObject_Item,
		AdminMenu_Invis,
		parentmenu,
		"sm_invis",
		ADMFLAG_SLAY);
	AddToTopMenu(hTopMenu, 
		"sm_invisplayer",
		TopMenuObject_Item,
		AdminMenu_InvisPlayer,
		parentmenu,
		"sm_invisplayer",
		ADMFLAG_SLAY);
	AddToTopMenu(hTopMenu, 
		"sm_alpha",
		TopMenuObject_Item,
		AdminMenu_Alpha,
		parentmenu,
		"sm_alpha",
		ADMFLAG_SLAY);
}


public AdminMenu_Invis(Handle:topmenu, 
					  TopMenuAction:action,
					  TopMenuObject:object_id,
					  param,
					  String:buffer[],
					  maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Invisible player", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayInvisMenu(param);
	}
}

DisplayInvisMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_Invis);
	
	decl String:title[100];
	Format(title, sizeof(title), "%T:", "Invisible player", client);
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	
	AddTargetsToMenu(menu, client, true, false);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}


public MenuHandler_Invis(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu != INVALID_HANDLE)
		{
			DisplayTopMenu(hTopMenu, param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		new userid, target;
		
		GetMenuItem(menu, param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "[SM] %t", "Unable to target");
		}
		else
		{
			new String:name[32];
			GetClientName(target, name, sizeof(name));
			
			PerformInvis(param1, target, 2);
			ShowActivity2(param1, "[SM] ", "%t", "Toggled invisible on target",  name );
		}
		
		/* Re-draw the menu if they're still valid */
		if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
		{
			DisplayInvisMenu(param1);
		}
	}
}



public AdminMenu_InvisPlayer(Handle:topmenu, 
					  TopMenuAction:action,
					  TopMenuObject:object_id,
					  param,
					  String:buffer[],
					  maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Invisible player only", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayInvisPlayerMenu(param);
	}
}

DisplayInvisPlayerMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_InvisPlayer);
	
	decl String:title[100];
	Format(title, sizeof(title), "%T:", "Invisible player", client);
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	
	AddTargetsToMenu(menu, client, true, false);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_InvisPlayer(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu != INVALID_HANDLE)
		{
			DisplayTopMenu(hTopMenu, param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		new userid, target;
		
		GetMenuItem(menu, param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "[SM] %t", "Unable to target");
		}
		else
		{
			new String:name[32];
			GetClientName(target, name, sizeof(name));
			
			PerformInvis(param1, target, 2, false);
			ShowActivity2(param1, "[SM] ", "%t", "Toggled invisible on target",  name );
		}
		
		/* Re-draw the menu if they're still valid */
		if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
		{
			DisplayInvisMenu(param1);
		}
	}
}



public AdminMenu_Alpha(Handle:topmenu, 
					  TopMenuAction:action,
					  TopMenuObject:object_id,
					  param,
					  String:buffer[],
					  maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Set player alpha", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayAlphaMenu(param);
	}
}

DisplayAlphaMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_Alpha);
	
	decl String:title[100];
	Format(title, sizeof(title), "%T:", "Set player alpha", client);
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	
	AddTargetsToMenu(menu, client, true, false);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}




public MenuHandler_Alpha(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu != INVALID_HANDLE)
		{
			DisplayTopMenu(hTopMenu, param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		new userid, target;
		
		GetMenuItem(menu, param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "[SM] %t", "Unable to target");
		}
		else
		{
			g_AlphaTarget[param1] = userid;
			DisplayAlphaAmountMenu(param1);
			return;	// Return, because we went to a new menu and don't want the re-draw to occur.
		}
		
		/* Re-draw the menu if they're still valid */
		if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
		{
			DisplayAlphaMenu(param1);
		}
	}
	
	return;
}

DisplayAlphaAmountMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_AlphaAmount);
	
	decl String:title[100];
	Format(title, sizeof(title), "%s:", "Alpha amount", client);
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	
	AddMenuItem(menu, "0", "0 - Invisible");
	AddMenuItem(menu, "50", "50");
	AddMenuItem(menu, "100", "100");
	AddMenuItem(menu, "150", "150");
	AddMenuItem(menu, "200", "200");
	AddMenuItem(menu, "255", "255 - Opaque");
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}


public MenuHandler_AlphaAmount(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu != INVALID_HANDLE)
		{
			DisplayTopMenu(hTopMenu, param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		new target;
		new amount = 1;
		decl String:info[32];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		amount = StringToInt(info);
		
		if ((target = GetClientOfUserId(g_AlphaTarget[param1])) == 0)
		{
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "[SM] %t", "Unable to target");
		}
		else
		{
			new String:name[32];
			GetClientName(target, name, sizeof(name));
			
			PerformSetAlpha(param1, target, amount );
			ShowActivity2(param1, "[SM] ", "%t", "Set alpha on target",  name, amount );
		}
		
		/* Re-draw the menu if they're still valid */
		if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
		{
			DisplayAlphaMenu(param1);
		}
	}
}