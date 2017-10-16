#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>

bool spawnprotect[MAXPLAYERS+1];
Handle spawnProtectionTimer[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[NGS] SayText Test User Message",
	author = "TheXeon",
	description = "Testing saytext user messages TF2",
	version = "1.0",
	url = "https://www.neogenesisnetwork.net/"
}

public void OnPluginStart()
{
	HookUserMessage(GetUserMessageId("SayText2"), fn_SayText2, true);
}

public Action fn_SayText2(UserMsg msg_id, Handle bf, const int[] players, int playersNum, bool reliable, bool init) 
{
	StartMessageAll()
	BfWriteByte(hBf, clientid);  
	BfWriteByte(hBf, 0);  
	BfWriteString(hBf, message); 
	EndMessage();  
}

public Action Timer_SayText2(Handle hndl)
{
    PrintToChatAll("UserMessage: SayText2 was Called");
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