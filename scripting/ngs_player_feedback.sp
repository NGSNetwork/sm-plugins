/**
* TheXeon
* ngs_player_feedback.sp
*
* Files:
* addons/sourcemod/plugins/ngs_player_toolkit.smx
*
* Dependencies:
* autoexecconfig.inc, clientprefs.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <autoexecconfig>
#include <clientprefs>
#include <ngsutils>
#include <ngsupdater>

ConVar cvarPromptPercent, cvarRedirectAddress;

Cookie promptCookie;

int promptTimeStamps[MAXPLAYERS + 1], playerLifeCount[MAXPLAYERS + 1];

//--------------------//

public Plugin myinfo = {
	name = "[NGS] Player Feedback",
	author = "TheXeon",
	description = "Facilitate our beta program!",
	version = "1.0.0",
	url = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	AutoExecConfig_SetCreateDirectory(true);
	AutoExecConfig_SetFile("ngs_player_feedback");
	AutoExecConfig_SetCreateFile(true);
	
	bool appended;
	cvarPromptPercent = AutoExecConfig_CreateConVarCheckAppend(appended, "ngs_feedback_prompt_percent", "0.25", "Percent to use to determine how many people should be prompted.");
	cvarRedirectAddress = AutoExecConfig_CreateConVarCheckAppend(appended, "ngs_feedback_prompt_address", "neogenesisnetwork.net:29015", "What address to use to redirect people.");
	AutoExecConfig_ExecAndClean(appended);
	
	promptCookie = new Cookie("ServerJoinFeedbackPrompt", "Timestamp of last prompt check.", CookieAccess_Private);

	HookEvent("player_spawn", OnPlayerSpawn);

	for (int i = MaxClients; i > 0; --i)
	{
		if (!AreClientCookiesCached(i))
		{
			continue;
		}
		OnClientCookiesCached(i);
	}
}

public void OnClientPutInServer(int client)
{
	promptTimeStamps[client] = 0;
	playerLifeCount[client] = 0;
}

public void OnClientDisconnect(int client)
{
	promptTimeStamps[client] = 0;
	playerLifeCount[client] = 0;
}

public void OnClientCookiesCached(int client)
{
	char sValue[32];
	promptCookie.GetValue(client, sValue, sizeof(sValue));

	promptTimeStamps[client] = (sValue[0] != '\0') ? StringToInt(sValue) : 0;
}

public void OnClientPostAdminCheck(int client)
{
	if (AreClientCookiesCached(client))
	{
		OnClientCookiesCached(client);
  	}
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(client)) return;
	
	if (playerLifeCount[client] < 3)
	{
		playerLifeCount[client]++;
		return;
	}
	
	int currenttime = GetTime();
	char timestamp[64];
	IntToString(currenttime, timestamp, sizeof(timestamp));
	if (isValidCandidate(client, currenttime))
	{
		Menu menu = new Menu(PromptMenuHandler);
		menu.SetTitle("We are working on a new map and\nyou have been chosen to help beta-test it!\nWould you like to join?");
		menu.AddItem("yes", "Yes!");
		menu.AddItem("no", "No, don't show me again for 3 days.");
		menu.ExitButton = false;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	
	promptTimeStamps[client] = currenttime;
	promptCookie.SetValue(client, timestamp);
}

public bool isValidCandidate(int client, int time)
{
	return (time - promptTimeStamps[client] > 259200) && 
	((GetRandomFloat() <= cvarPromptPercent.FloatValue) || 
	CheckCommandAccess(client, "sm_ngsextra_donor_override", ADMFLAG_RESERVATION));
}

public int PromptMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			char info[16];
			if (menu.GetItem(param2, info, sizeof(info)))
			{
				if (StrEqual(info, "yes"))
				{
					Menu menu2 = new Menu(PromptMenuHandler);
					menu2.SetTitle("Would you like to be redirected there now?");
					menu2.AddItem("yesredirect", "Yes!");
					menu2.AddItem("no", "No, don't show me again for 3 days.");
					menu2.ExitButton = false;
					menu2.Display(param1, MENU_TIME_FOREVER);
				}
				else if (StrEqual(info, "yesredirect"))
				{
					char serverip[128];
					cvarRedirectAddress.GetString(serverip, sizeof(serverip));
					ClientCommand(param1, "redirect %s", serverip);
				}
			}
		}
	}
}