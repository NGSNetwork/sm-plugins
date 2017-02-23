/****************************************************
*													*
*	Requires the included translations and configs	*
*													*
****************************************************/

#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <store>
#include <morecolors>

char g_currencyName[64];
int BetCooldown[MAXPLAYERS + 1];
int creditPot;

public Plugin myinfo = {
	name        = "[Store] Currency Betting",
	author      = "TheXeon",
	description = "Betting component for [Store]",
	version     = STORE_VERSION,
	url         = "https://neogenesisnetwork.net"
}

/**
 * Plugin is loading.
 */
public void OnPluginStart() 
{
	RegConsoleCmd("sm_bet", CommandBet, "Usage: sm_bet <amount>");
	RegConsoleCmd("sm_pot", CommandPot, "Usage: sm_pot");
	LoadTranslations("store.phrases");
}

/**
 * Configs just finished getting executed.
 */
public void OnAllPluginsLoaded()
{
	Store_GetCurrencyName(g_currencyName, sizeof(g_currencyName));
}

public void OnClientPutInServer(int client)
{ 
	BetCooldown[client] = 0; 
}

public Action CommandBet(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	if (args < 1)
	{
		CReplyToCommand(client, "%tPlease give an amount to bet!", "Store Tag Colored");
		return Plugin_Handled;
	}
	int currentTime = GetTime(); 
	if (currentTime - BetCooldown[client] < 7)
    {
   		CReplyToCommand(client, "%tYou must wait {PURPLE}%d{DEFAULT} seconds to bet again.", "Store Tag Colored", 7 - (currentTime - BetCooldown[client]));
   		return Plugin_Handled;
  	}
	BetCooldown[client] = currentTime;
	char sCreditsBet[MAX_BUFFER_LENGTH], playerName[MAX_NAME_LENGTH];
	int accountid = GetSteamAccountID(client);
	int clientcredits = Store_GetCreditsEx(accountid);
	GetCmdArg(1, sCreditsBet, sizeof(sCreditsBet));
	GetClientName(client, playerName, sizeof(playerName));
	int iCreditsBet = StringToInt(sCreditsBet);
	if (iCreditsBet < 1 || iCreditsBet > 250)
	{
		CReplyToCommand(client, "%tSorry, but you may only bet between 0 and 251 credits.", "Store Tag Colored");
		return Plugin_Handled;
	}
	if (iCreditsBet > clientcredits)
	{
		CReplyToCommand(client, "%tSorry, but you don't have enough %s to bet this.", "Store Tag Colored", g_currencyName);
		return Plugin_Handled;
	}
	Store_RemoveCredits(accountid, iCreditsBet);
	float chance = GetRandomFloat();
	if (chance <= 0.02)
	{
		Store_GiveCredits(accountid, (iCreditsBet * 5));
		CPrintToChatAll("%tJACKPOT! %s gained %d %s!", "Store Tag Colored", playerName, iCreditsBet * 5, g_currencyName);
		return Plugin_Handled;
	}
	else if (chance <= 0.3)
	{
		Store_GiveCredits(accountid, (iCreditsBet * 2));
		CPrintToChatAll("%tCongrats! %s gained %d %s!", "Store Tag Colored", playerName, iCreditsBet * 2, g_currencyName);
		return Plugin_Handled;
	}
	else if (GetClientCount() > 1)
	{
		creditPot += iCreditsBet;
		CReplyToCommand(client, "%tSorry, you did not get any %s this time! Your betted amount has been added to the pot.", "Store Tag Colored", g_currencyName);
		if ((creditPot / 25) >= GetClientCount(true))
		{
			int randPlayer;
			char randPlayerName[MAX_NAME_LENGTH];
			do
			{
				randPlayer = GetRandomInt(1, MaxClients);
			}
			while(!IsClientInGame(randPlayer));
			Store_GiveCredits(GetSteamAccountID(randPlayer), creditPot);
			GetClientName(randPlayer, randPlayerName, sizeof(randPlayerName));
			CPrintToChatAll("%tCongrats to {LIGHTGREEN}%s{DEFAULT}, they have received a {GENUINE}%d{DEFAULT} jackpot!", "Store Tag Colored", randPlayerName, creditPot);
			creditPot = 0;
		}
		return Plugin_Handled;
	}
	else
	{
		CReplyToCommand(client, "%tSorry, you did not get any %s this time!", "Store Tag Colored", g_currencyName);
		return Plugin_Handled;
	}
}

public Action CommandPot(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	if (GetClientCount() > 1) CReplyToCommand(client, "%tThe pot is at {PURPLE}%d{DEFAULT}! We need {YELLOW}%d{DEFAULT} more credits to start the giveaway!", "Store Tag Colored", creditPot, ((GetClientCount() * 25) - creditPot));
	else CReplyToCommand(client, "%tSorry, the pot is unavailable at this time. We need one more person to connect.", "Store Tag Colored");
	return Plugin_Handled;
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