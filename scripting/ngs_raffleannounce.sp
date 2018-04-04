/**
* TheXeon
* ngs_raffleannounce.sp
*
* Files:
* addons/sourcemod/plugins/ngs_raffleannounce.smx
*
* Dependencies:
* advanced_motd.inc, multicolors.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <advanced_motd>
#include <multicolors>
#include <ngsutils>
#include <ngsupdater>

#define NGSRAFFLEURL "https://steamcommunity.com/groups/NGSRaffle#announcements/detail/"

Handle hHudText;

char raffleID[MAX_BUFFER_LENGTH];
char raffleItem[MAX_BUFFER_LENGTH];
int raffleType = 0;

//--------------------//

public Plugin myinfo = {
	name = "[NGS] Raffle Announce",
	author = "TheXeon",
	description = "Announces NGS group raffles!",
	version = "1.2.0",
	url = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_setraffle", CommandSetRaffle, "Usage: sm_setraffle <raffle announcement id> <0 = free, 1 = invite, 2 = paid, 3 = donor-only, 4 = member-only> <featured item(s)>");
	RegConsoleCmd("sm_announceraffle", CommandAnnounceRaffle, "Usage: sm_announceraffle");
	RegConsoleCmd("sm_canclethefuckignraffle", CommandCancelRaffle, "Usage: sm_cancelraffle");
	RegConsoleCmd("sm_cancelraffle", CommandCancelRaffle, "Usage: sm_cancelraffle");
	RegConsoleCmd("sm_joinraffle", CommandJoinRaffle, "Opens raffle in MOTD page.");
	RegConsoleCmd("sm_hideraffle", CommandHideRaffle, "Hides the current raffle.");
	LoadTranslations("common.phrases");
}

public Action CommandSetRaffle(int client, int args)
{
	if (!CheckCommandAccess(client, "sm_raffleadmin_override", ADMFLAG_GENERIC)) return Plugin_Handled;
	
	if (args < 2)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_setraffle <raffle announcement id> <0 = free, 1 = invite, 2 = paid, 3 = donor-only, 4 = member-only> <featured item(s)>");
		return Plugin_Handled;
	}
	
	
	char arg2[MAX_BUFFER_LENGTH];
	
	GetCmdArg(1, raffleID, sizeof(raffleID));
	GetCmdArg(2, arg2, sizeof(arg2));
	if (args > 2) GetCmdArg(3, raffleItem, sizeof(raffleItem));
	
	if (StrEqual(arg2, "free", false)) raffleType = 0;
	else if (StrEqual(arg2, "invite", false)) raffleType = 1;
	else if (StrEqual(arg2, "paid", false)) raffleType = 2;
	else if (StrEqual(arg2, "donor-only", false)) raffleType = 3;
	else if (StrEqual(arg2, "member-only", false)) raffleType = 4;
	else raffleType = StringToInt(arg2);
	
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Set raffle announcement ID to %s!", raffleID);
	AnnounceRaffle();
	
	return Plugin_Handled;
}

public Action CommandAnnounceRaffle(int client, int args)
{
	if (!CheckCommandAccess(client, "sm_raffleadmin_override", ADMFLAG_GENERIC)) return Plugin_Handled;
	
	if (StrEqual(raffleID, "", false))
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} There is currently no raffle going on.");
		return Plugin_Handled;
	}
	AnnounceRaffle();
	return Plugin_Handled;
}

public Action CommandHideRaffle(int client, int args)
{
	if (IsValidClient(client) && hHudText != null)
	{
		ClearSyncHud(client, hHudText);
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Raffle message has been hidden.");
	}
	return Plugin_Handled;
}

public Action CommandCancelRaffle(int client, int args)
{
	if (!CheckCommandAccess(client, "sm_raffleadmin_override", ADMFLAG_GENERIC)) return Plugin_Handled;
	raffleID = NULL_STRING;
	raffleItem = NULL_STRING;
	ClearAndDeleteHudText();
	hHudText = CreateHudSynchronizer();

	SetHudTextParams(-1.0, 0.1, 5.0, 255, 0, 0, 255, 1, 1.0, 1.0, 1.0);
    
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			ShowSyncHudText(i, hHudText, "Raffle has been canceled...");
		}
	}
	
	return Plugin_Handled;
}

public Action CommandJoinRaffle(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	if (StrEqual(raffleID, "", false))
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} There is currently no raffle going on.");
		return Plugin_Handled;
	}
	char raffleLink[MAX_BUFFER_LENGTH];
	Format(raffleLink, sizeof(raffleLink), "%s%s", NGSRAFFLEURL, raffleID);
	AdvMOTD_ShowMOTDPanel(client, "NGS Raffle", raffleLink, MOTDPANEL_TYPE_URL, true, true, true, OnMOTDFailure);
	return Plugin_Handled;
}

public void AnnounceRaffle()
{
	ClearAndDeleteHudText();
	hHudText = CreateHudSynchronizer();
	SetHudTextParams(-1.0, 0.1, 30.0, 255, 0, 0, 255, 1, 1.0, 1.0, 1.0);
    
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			switch (raffleType)
			{
				case 0:
				{
					if (StrEqual(raffleItem, "", false)) ShowSyncHudText(i, hHudText, "A free raffle has started! Use !joinraffle to tune in.");
					else ShowSyncHudText(i, hHudText, "A free raffle has started! Use !joinraffle to tune in.\n Featured item(s): %s", raffleItem);
				}
				
				case 1:
				{
					if (StrEqual(raffleItem, "", false)) ShowSyncHudText(i, hHudText, "An invite raffle has started! Use !joinraffle to tune in.");
					else ShowSyncHudText(i, hHudText, "An invite raffle has started! Use !joinraffle to tune in.\n Featured item(s): %s", raffleItem);
				}
				
				case 2:
				{
					if (StrEqual(raffleItem, "", false)) ShowSyncHudText(i, hHudText, "A paid raffle has started! Use !joinraffle to tune in.");
					else ShowSyncHudText(i, hHudText, "A paid raffle has started! Use !joinraffle to tune in.\n Featured item(s): %s", raffleItem);
				}
				
				case 3:
				{
					if (StrEqual(raffleItem, "", false)) ShowSyncHudText(i, hHudText, "A donor-only raffle has started! Use !joinraffle to tune in.");
					else ShowSyncHudText(i, hHudText, "A donor-only raffle has started! Use !joinraffle to tune in.\n Featured item(s): %s", raffleItem);
				}
				
				case 4:
				{
					if (StrEqual(raffleItem, "", false)) ShowSyncHudText(i, hHudText, "A member-only raffle has started! Use !joinraffle to tune in.");
					else ShowSyncHudText(i, hHudText, "A member-only raffle has started! Use !joinraffle to tune in.\n Featured item(s): %s", raffleItem);
				}
			}
		}
	}
}

public void ClearAndDeleteHudText()
{
	if (hHudText != null)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
				ClearSyncHud(i, hHudText);
		}
		delete hHudText;
	}
}

public int OnMOTDFailure(int client, MOTDFailureReason reason) 
{
	switch(reason) 
	{
		case MOTDFailure_Disabled: CPrintToChat(client, "{GREEN}[SM]{DEFAULT} You cannot join raffles with HTML MOTDs disabled!");
		case MOTDFailure_Matchmaking: CPrintToChat(client, "{GREEN}[SM]{DEFAULT} You cannot join raffles after joining via Quickplay!");
		case MOTDFailure_QueryFailed: CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Unable to join raffle!");
	}
}