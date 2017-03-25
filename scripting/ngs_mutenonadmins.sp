#include <sourcemod>
#include <sdktools>

public void OnPluginStart()
{
	RegConsoleCmd("sm_muteevery", Cmd_MuteEvery);
	RegConsoleCmd("sm_unmuteevery", Cmd_UnmuteEvery);
}



public Action Cmd_MuteEvery(int client, int args)
{
	int i;
	for (i = 1; i <= MaxClients; i++)
	{
		SetClientListeningFlags(i, VOICE_MUTED);
	}
	return Plugin_Handled;
}

public Action Cmd_UnmuteEvery(int client, int args)
{
	int i;
	for (i = 1; i <= MaxClients; i++)
	{
		SetClientListeningFlags(i, VOICE_NORMAL);
	}
	return Plugin_Handled;
}