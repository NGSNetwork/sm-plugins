//FF: by Arg!

/*****************************************************************


			G L O B A L   V A R S


*****************************************************************/
new Handle:Cvar_FF = INVALID_HANDLE;

/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/
public SetupFF()
{
	RegAdminCmd("sm_ff", Command_SmFF, ADMFLAG_SLAY, "toggles friendly fire");
	
	Cvar_FF = FindConVar("mp_friendlyfire");
}

/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/
public Action:Command_SmFF(client, args)
{
	if( DoFF(client) )
	{
		ShowActivity2(client, "[SM] ", "%t", "Enabled friendly fire");
	}
	else
	{
		ShowActivity2(client, "[SM] ", "%t", "Disabled friendly fire");
	}
	
	return Plugin_Handled;
}

/*****************************************************************


			P L U G I N   F U N C T I O N S


*****************************************************************/
bool:DoFF(client)
{
	//toggle ff
	if( GetConVarBool(Cvar_FF) )
	{
		SetConVarBool(Cvar_FF, false);
		PrintToChatAll("\x04Friendly fire \x01disabled!");
		LogMessage( "\"%L\" disabled friendly fire", client );
		return false;
	}
	else
	{
		SetConVarBool(Cvar_FF, true);
		PrintToChatAll("\x04Friendly fire \x01enabled!");
		LogMessage( "\"%L\" enabled friendly fire", client );
		return true;
	}
}

/*****************************************************************


			A D M I N   M E N U   F U N C T I O N S


*****************************************************************/
Setup_AdminMenu_FF_Server(TopMenuObject:parentmenu)
{
	AddToTopMenu(hTopMenu,
		"sm_ff",
		TopMenuObject_Item,
		AdminMenu_ToggleFF,
		parentmenu,
		"sm_ff",
		ADMFLAG_SLAY);
}


public AdminMenu_ToggleFF(Handle:topmenu, 
					  TopMenuAction:action,
					  TopMenuObject:object_id,
					  param,
					  String:buffer[],
					  maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		if(GetConVarBool(Cvar_FF))
		{
			Format(buffer, maxlength, "%T", "Friendly Fire Off", param);
		}
		else
		{
			Format(buffer, maxlength, "%T", "Friendly Fire On", param);
		}
		
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if( DoFF(param) )
		{
			ShowActivity2(param, "[SM] ", "%t", "Enabled friendly fire");
		}
		else
		{
			ShowActivity2(param, "[SM] ", "%t", "Disabled friendly fire");
		}
		
		RedisplayAdminMenu(topmenu, param);	
	}
}