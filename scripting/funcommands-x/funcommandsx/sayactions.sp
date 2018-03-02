//sayactions: by Arg!
/*****************************************************************


			G L O B A L   V A R S


*****************************************************************/
ConVar g_Cvar_SayAction_Me;

#include <sourcecomms>
/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/
public void SetupSayActions()
{
	g_Cvar_SayAction_Me  = CreateConVar("sm_sa_me", "1", "Allows use of FuncommandsX 'me' action");
	
	RegConsoleCmd("sm_me", Command_Me, "Outputs a 'me' action to chat");
}

/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/

public Action Command_Me(int client, int args)
{
	char actionStr[129], playerName[65], action[194];

	if(!g_Cvar_SayAction_Me.BoolValue)
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
	else if (!BaseComm_IsClientGagged(client) || SourceComms_GetClientGagType(client) == bNot)
	{
		GetClientName(client,playerName,sizeof(playerName));
	}
	else
	{
		return Plugin_Handled;
	}
	
	Format( action, sizeof(action), "%c%s %s", 3, playerName, actionStr );
	
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsClientInGame(i) && !IsFakeClient(i)) 
		{
			SayText2(i, action);
		}
	}
	
	return Plugin_Handled;
}




/*****************************************************************


			P L U G I N   F U N C T I O N S


*****************************************************************/
