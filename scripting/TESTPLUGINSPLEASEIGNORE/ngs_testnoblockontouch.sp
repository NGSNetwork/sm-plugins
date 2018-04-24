#pragma newdecls required
#pragma semicolon 1

#include <sdkhooks>
#include <ngsutils>
#include <collisionhook>
#include <friendly>
#include <free_duels>

ConVar friendlyNoblockValue;
bool isFriendly[MAXPLAYERS + 1];
//SMTimer noblockTimer[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[NGS] Test Antistuck with Friendlies",
	author = "TheXeon",
	description = "Testeroni antistuckeroni",
	version = "1.0",
	url = "https://www.neogenesisnetwork.net/"
}

public void OnPluginStart()
{
//	for (int i = 1; i <= MaxClients; i++)
//	{
//		if (IsValidClient(i))
//		{
//			SDKHook(i, SDKHook_StartTouchPost, StartTouchHook);
//			SDKHook(i, SDKHook_EndTouchPost, EndTouchHook);
//		}
//	}

	friendlyNoblockValue = FindConVar("sm_friendly_noblock");
}

public Action CH_ShouldCollide(int client, int other, bool &result)
{
	if (client >= 1 && client <= MaxClients && other >= 1 && other <= MaxClients)
	{
		if (isFriendly[client] ^ isFriendly[other] && friendlyNoblockValue.IntValue)
		{
			result = false;
			return Plugin_Changed;
		}
		else if (IsPlayerInDuel(client) ^ IsPlayerInDuel(other))
		{
			result = false;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public int TF2Friendly_OnEnableFriendly(int client)
{
	isFriendly[client] = true;
}

public int TF2Friendly_OnDisableFriendly(int client)
{
	isFriendly[client] = false;
}

public void OnClientPutInServer(int client)
{
//	SDKHook(client, SDKHook_StartTouchPost, StartTouchHook);
//	SDKHook(client, SDKHook_EndTouchPost, EndTouchHook);
	isFriendly[client] = false;
}
//
//public void OnClientDisconnect(int client)
//{
//	delete noblockTimer[client];
//}
//
//public void StartTouchHook(int client, int entity)
//{
//	if (IsValidClient(client) && IsValidClient(entity))
//	{
//		bool isClientFriendly = TF2Friendly_IsFriendly(client);
//		if (isClientFriendly ^ TF2Friendly_IsFriendly(entity))
//		{
////			PrintToChatAll("A friendly touched a nonfriendly, setting their collision!");
//			SetEntProp(isClientFriendly ? entity : client, Prop_Send, "m_CollisionGroup", friendlyNoblockValue.IntValue);
//		}
//	}
//}
//
//
//public void EndTouchHook(int client, int entity)
//{
//	if (IsValidClient(client) && IsValidClient(entity))
//	{
//		bool isClientFriendly = TF2Friendly_IsFriendly(client);
//		int clientToTime = isClientFriendly ? entity : client;
//		if (isClientFriendly ^ TF2Friendly_IsFriendly(entity))
//		{
//			if (noblockTimer[clientToTime] != null) return;
////			PrintToChatAll("%N stopped touching a friendly, starting collision reset at 0.5 sec!", clientToTime);
//			noblockTimer[clientToTime] = new SMTimer(0.5, OnEndTouchHookTimer, GetClientUserId(clientToTime));
//		}
//	}
//}
//
//public Action OnEndTouchHookTimer(Handle timer, any userid)
//{
//	int client = GetClientOfUserId(userid);
//	if (IsValidClient(client) && !TF2Friendly_IsFriendly(client) && !IsPlayerInDuel(client))
//	{
//		noblockTimer[client] = null;
////		PrintToChatAll("Resetting %N to regular collision.", client);
//		SetEntProp(client, Prop_Send, "m_CollisionGroup", 5);
//	}
//}