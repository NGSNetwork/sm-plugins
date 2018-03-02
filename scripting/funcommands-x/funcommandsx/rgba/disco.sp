//Disco: by Arg!

/*****************************************************************


			G L O B A L   V A R S


*****************************************************************/
new Handle:g_DiscoTimer;
new Handle:cvar_DiscoInterval;
new Handle:cvar_AutoDisco;
new Handle:cvar_AutoDiscoTime;


/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/
public SetupDisco()
{	
	g_DiscoTimer = INVALID_HANDLE;
	cvar_DiscoInterval = INVALID_HANDLE;
	
	RegAdminCmd("sm_disco", Command_SmDisco, ADMFLAG_SLAY, "sm_disco [1|0] - toggles disco mode or force on or off");
	
	cvar_DiscoInterval = CreateConVar("sm_discointerval", "0.6", "Set disco mode change color interval", FCVAR_PLUGIN, true, 0.0, true, 10.0);
	HookConVarChange(cvar_DiscoInterval, DiscoIntervalChanged);
	
	cvar_AutoDisco = CreateConVar("sm_autodisco", "0", "Automatically starts disco mode on map change and runs for sm_autodiscotime");
	cvar_AutoDiscoTime = CreateConVar("sm_autodiscotime", "60.0", "Time in seconds to run auto disco mode");
}

public OnMapStart_Disco()
{
	decl Float:interval;
	
	if( GetConVarInt(cvar_AutoDisco) )
	{	
		interval = GetConVarFloat(cvar_AutoDiscoTime);
	
		//1 off timer to kill auto disco
		CreateTimer(interval, Timer_AutoDisco);
		
		CreateDisco();
		LogMessage("Disco mode enabled due to auto disco");
	}
}

public OnMapEnd_Disco()
{
	if( g_DiscoTimer != INVALID_HANDLE )
	{
		KillTimer(g_DiscoTimer);
		g_DiscoTimer = INVALID_HANDLE;	
	}
}

/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/
public Action:Command_SmDisco(client, args)
{
	decl String:toggleStr[2];
	
	new toggle = 2;
	
	if (args > 0)
	{
		GetCmdArg(1, toggleStr, sizeof(toggleStr));
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
			ReplyToCommand(client, "[SM] Usage: sm_disco [1|0]");
			return Plugin_Handled;	
		}
	}
	
	//handle disco mode
	if(	PerformDisco(client, toggle) )
	{
		ShowActivity2(client, "[SM] ", "%t", "Enabled disco mode");
	}
	else
	{
		ShowActivity2(client, "[SM] ", "%t", "Disabled disco mode");
	}
	
	return Plugin_Handled; 
}

public Action:Timer_Disco(Handle:timer)
{	
	new maxclients = GetMaxClients();
	decl colIndex;
	
	for( new i = 1; i <= maxclients; i++ )
	{
		if( IsClientConnected(i) && IsClientInGame(i) )
		{
			colIndex = GetRandomInt(0,(sizeof(g_sTColors) -1 ));
			
			SetColor(i,colIndex );

			DoRGBA(i, RENDER_NORMAL);
		}
	}
	
	return Plugin_Handled;
}

public DiscoIntervalChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	decl Float:newVal;
	
	//are we running mode rite now?
	if( g_DiscoTimer != INVALID_HANDLE )
	{
		newVal = StringToFloat( newValue );
		
		//is the cvar set to a valid value
		if( newVal > 0.0 )
		{
			//kill the timer and recrate
			KillTimer(g_DiscoTimer);
			g_DiscoTimer = INVALID_HANDLE;	
			
			CreateDisco();
		}
	}
}

public Action:Timer_AutoDisco(Handle:timer)
{	
	KillDisco();
	LogMessage("Disco mode disabled due to auto disco time elapsed");
	
	return Plugin_Handled;
}

/*****************************************************************


			P L U G I N   F U N C T I O N S


*****************************************************************/
bool:PerformDisco(client, toggle)
{
 	switch(toggle)
 	{
 		case(2):
 		{
			if (g_DiscoTimer == INVALID_HANDLE)
			{
				CreateDisco();
				LogMessage("\"%L\" enabled disco mode", client);
				PrintCenterTextAll("%t", "Disco on message");
				return true;
			}
			else
			{
				KillDisco();
				LogMessage("\"%L\" disabled disco mode", client);
				return false;
			}
 		}
 		case(1):
 		{
				CreateDisco();
				LogMessage("\"%L\" enabled disco mode", client);
				PrintCenterTextAll("Disco mode on, get down and boogie!");
				return true;
 		}
 		case(0):
 		{
				KillDisco();
				LogMessage("\"%L\" disabled disco mode", client);
				return false;
 		}
 	}
 	
 	return false;
}

CreateDisco()
{	
	decl Float:interval;
	
	interval = GetConVarFloat(cvar_DiscoInterval);
	
	//validate convar value
	if( interval <= 0.0 )
	{
		interval = 1.0;
	}
	
	//create timer if applicible
	if( g_DiscoTimer == INVALID_HANDLE )
	{
		g_DiscoTimer = CreateTimer(interval, Timer_Disco, 0, TIMER_REPEAT);
	}	
}

KillDisco()
{
	if( g_DiscoTimer != INVALID_HANDLE )
	{
		KillTimer(g_DiscoTimer);
		g_DiscoTimer = INVALID_HANDLE;	
	}
	
	//restore players
	new maxclients = GetMaxClients();
	
	for( new i = 1; i <= maxclients; i++ )
	{
		SetColor(i, 0);
		
		if( IsClientConnected(i) && IsClientInGame(i) )
		{			
			DoRGBA(i, RENDER_NORMAL);
		}
	}
	
}

/*****************************************************************


			A D M I N   M E N U   F U N C T I O N S


*****************************************************************/
Setup_AdminMenu_Disco_Server(TopMenuObject:parentmenu)
{
	AddToTopMenu(hTopMenu,
		"sm_disco",
		TopMenuObject_Item,
		AdminMenu_ToggleDisco,
		parentmenu,
		"sm_disco",
		ADMFLAG_SLAY);
}

public AdminMenu_ToggleDisco(Handle:topmenu, 
					  TopMenuAction:action,
					  TopMenuObject:object_id,
					  param,
					  String:buffer[],
					  maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		if(g_DiscoTimer != INVALID_HANDLE)
		{
			Format(buffer, maxlength, "%T", "Disco Mode Off", param);
		}
		else
		{
			Format(buffer, maxlength, "%T", "Disco Mode On", param);
		}
	}
	else if (action == TopMenuAction_SelectOption)
	{	
		if(	PerformDisco(param, 2) )
		{
			ShowActivity2(param, "[SM] ", "%t", "Enabled disco mode");
		}
		else
		{
			ShowActivity2(param, "[SM] ", "%t", "Disabled disco mode");
		}
		
		RedisplayAdminMenu(topmenu, param);	
	}
}