//sayactions: by Arg!
/*****************************************************************


			G L O B A L   V A R S


*****************************************************************/
new Handle:g_Cvar_SayAction_Me = INVALID_HANDLE;


/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/
public SetupSayActions()
{
	g_Cvar_SayAction_Me  = CreateConVar("sm_sa_me", "1", "Allows use of FuncommandsX 'me' action");
	
	RegConsoleCmd("sm_me", Command_Me, "Outputs a 'me' action to chat");
}

/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/

public Action:Command_Me(client, args)
{
	decl String:actionStr[129];
	decl String:playerName[65];
	decl String:action[194];

	if( !GetConVarInt(g_Cvar_SayAction_Me) )
	{
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_me <'me' action message>");
		return Plugin_Handled;
	}
	
	GetCmdArgString( actionStr, sizeof(actionStr) );
		
	if( !client )
	{
		playerName = "Console";
	}
	else if( !BaseComm_IsClientGagged( client ) )
	{
		GetClientName(client,playerName,sizeof(playerName));
	}
	else
	{
		return Plugin_Handled;
	}
	
	Format( action, sizeof(action), "%c%s %s", 3, playerName, actionStr );
	
	for (new i = 1, iClients = GetClientCount(); i <= iClients; i++) 
	{
		if (IsClientInGame(i) && !IsFakeClient(i) ) 
		{
			SayText2(i, action);
		}
	}
	
	return Plugin_Handled;
}




/*****************************************************************


			P L U G I N   F U N C T I O N S


*****************************************************************/
