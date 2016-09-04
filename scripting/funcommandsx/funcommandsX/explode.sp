//Explode: by Arg!

/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/
public SetupExplode()
{
	RegAdminCmd("sm_explode", Command_Explode, ADMFLAG_SLAY, "sm_explode <#userid|name> - Explodes player(s) if alive");
}

/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/
public Action:Command_Explode(client, args)
{
	decl String:target[32];
	decl String:target_name[MAX_NAME_LENGTH];
	decl target_list[MAXPLAYERS];
	decl target_count;
	decl bool:tn_is_ml;
	
	//validate args
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_explode <#userid|name>");
		return Plugin_Handled;
	}
	
	//get argument
	GetCmdArg(1, target, sizeof(target));		
	
	//get target(s)
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
	
	for (new i = 0; i < target_count; i++)
	{
		PerformExplode(client,target_list[i]);
	}
	
	ShowActivity2(client, "[SM] ", "%t", "was exploded",  target_name);
	
	return Plugin_Handled;
	
}

/*****************************************************************


			P L U G I N   F U N C T I O N S


*****************************************************************/
PerformExplode(client, target)
{
	FakeClientCommand(target, "explode"); 
	
	LogAction(client,target, "\"%L\" exploded \"%L\"" , client, target);
}

/*****************************************************************


			A D M I N   M E N U   F U N C T I O N S


*****************************************************************/
Setup_AdminMenu_Explode_Player(TopMenuObject:parentmenu)
{
	AddToTopMenu(hTopMenu, 
		"sm_explode",
		TopMenuObject_Item,
		AdminMenu_Explode,
		parentmenu,
		"sm_explode",
		ADMFLAG_SLAY);
}

public AdminMenu_Explode(Handle:topmenu, 
					  TopMenuAction:action,
					  TopMenuObject:object_id,
					  param,
					  String:buffer[],
					  maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Explode player", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayExplodeMenu(param);
	}
}

DisplayExplodeMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_Explode);
	
	decl String:title[100];
	Format(title, sizeof(title), "%T:", "Explode player", client);
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	
	AddTargetsToMenu(menu, client, true, false);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}


public MenuHandler_Explode(Handle:menu, MenuAction:action, param1, param2)
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
			
			PerformExplode(param1,target);
			ShowActivity2(param1, "[SM] ", "%t", "was exploded",  name);
		}
		
		/* Re-draw the menu if they're still valid */
		if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
		{
			DisplayExplodeMenu(param1);
		}
	}
}