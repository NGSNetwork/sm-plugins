#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>

public void OnPluginStart()
{
	RegConsoleCmd("redirect", CommandRedirect);
}

public Action CommandRedirect(int client, int args)
{
	char argstring[128];
	GetCmdArgString(argstring, sizeof(argstring));
	PrintToServer(argstring);
	return Plugin_Continue;
}