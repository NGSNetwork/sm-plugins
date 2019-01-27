/**
* TheXeon
* ngs_adminlist.sp
*
* Files:
* addons/sourcemod/plugins/ngs_adminlist.smx
* cfg/sourcemod/plugin.ngs_adminlist.cfg
*
* Dependencies:
* sourcemod.inc, ngsutils.inc, ngsupdater.inc, multicolors.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <sourcemod>
#include <ngsutils>
#include <ngsupdater>
#include <multicolors>

ConVar AdminListEnabled;

public Plugin myinfo = {
	name = "[NGS] Admin List",
	author = "Fredd / TheXeon",
	description = "Prints admins and donors to clients.",
	version = "1.0.5",
	url = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	AdminListEnabled = CreateConVar("sm_ngsadminlist_on", "1", "Turns the admin list feature on and off.");

	RegConsoleCmd("sm_administrators", CommandListAdmins, "List admins to chat.");
	RegConsoleCmd("sm_admins", CommandListAdmins, "List admins to chat.");
	RegConsoleCmd("sm_listadmins", CommandListAdmins, "List admins to chat.");
	RegConsoleCmd("sm_donors", CommandListDonors, "List donors to chat.");
	RegConsoleCmd("sm_listdonors", CommandListDonors, "List donors to chat.");
	RegConsoleCmd("sm_donators", CommandListDonors, "List donors to chat.");
	RegConsoleCmd("sm_djs", CommandListDJs, "List DJs in chat.");
	RegConsoleCmd("sm_staff", CommandListStaff, "List all staff in chat.");
	RegConsoleCmd("sm_liststaff", CommandListStaff, "List all staff in chat.");
	RegConsoleCmd("sm_stafflist", CommandListStaff, "List all staff in chat.");

	AutoExecConfig();
}

public Action CommandListAdmins(int client, int args)
{
	if (AdminListEnabled.BoolValue)
	{
		char adminNames[MAXPLAYERS + 1][MAX_NAME_LENGTH + 1];
		int count = 0;
		for(int i = 1 ; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && CheckCommandAccess(i, "sm_ngsstaff_administra_override", ADMFLAG_ROOT))
			{
				GetClientName(i, adminNames[count], sizeof(adminNames[]));
				count++;
			}
		}
		if (count > 0)
		{
			char buffer[1024];
			ImplodeStrings(adminNames, count, ", ", buffer, sizeof(buffer));
			CReplyToCommand(client, "{GREEN}[SM] Administrators online: {CYAN}%s.", buffer);
		}
		else CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} There are no admins online. Use !calladmin to call an admin over.");
	}
	return Plugin_Handled;
}

public Action CommandListDonors(int client, int args)
{
	if (AdminListEnabled.BoolValue)
	{
		char DonorNames[MAXPLAYERS + 1][MAX_NAME_LENGTH + 1];
		int count = 0;
		for(int i = 1 ; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && CheckCommandAccess(i, "sm_ngsextra_donor_override", ADMFLAG_ROOT) && !CheckCommandAccess(i, "sm_ngsstaff_override", ADMFLAG_ROOT))
			{
				GetClientName(i, DonorNames[count], sizeof(DonorNames[]));
				count++;
			}
		}
		if (count > 0)
		{
			char buffer[1024];
			ImplodeStrings(DonorNames, count, ", ", buffer, sizeof(buffer));
			CReplyToCommand(client, "{GREEN}[SM] Donors online: {ORANGE}%s.", buffer);
		}
		else CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} There are no donors online.");
	}
	return Plugin_Handled;
}

public Action CommandListDJs(int client, int args)
{
	if (AdminListEnabled.BoolValue)
	{
		char DJNames[MAXPLAYERS + 1][MAX_NAME_LENGTH + 1];
		int count = 0;
		for(int i = 1 ; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && CheckCommandAccess(i, "sm_ngsother_dj_override", ADMFLAG_ROOT) && !CheckCommandAccess(i, "sm_ngsstaff_override", ADMFLAG_ROOT))
			{
				GetClientName(i, DJNames[count], sizeof(DJNames[]));
				count++;
			}
		}
		if (count > 0)
		{
			char buffer[1024];
			ImplodeStrings(DJNames, count, ", ", buffer, sizeof(buffer));
			CReplyToCommand(client, "{GREEN}[SM] DJs online: {PURPLE}%s.", buffer);
		}
		else CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} There are no DJs online.");
	}
	return Plugin_Handled;
}

public Action CommandListStaff(int client, int args)
{
	if (AdminListEnabled.BoolValue)
	{
		char adminNames[MAXPLAYERS + 1][MAX_NAME_LENGTH + 1], marketerNames[MAXPLAYERS + 1][MAX_NAME_LENGTH + 1],
			developerNames[MAXPLAYERS + 1][MAX_NAME_LENGTH + 1];
		int adminListCount = 0, commAdvCount = 0, commManCount = 0, devCount = 0;
		for(int i = 1 ; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
			{
				if (CheckCommandAccess(i, "sm_ngsstaff_dev_override", ADMFLAG_ROOT))
				{
					GetClientName(i, developerNames[devCount], sizeof(developerNames[]));
					devCount++;
					continue;
				}
				else if (CheckCommandAccess(i, "sm_ngsstaff_administra_override", ADMFLAG_ROOT))
				{
					GetClientName(i, adminNames[adminListCount], sizeof(adminNames[]));
					adminListCount++;
					continue;
				}
				else if (CheckCommandAccess(i, "sm_ngsstaff_marketer_override", ADMFLAG_ROOT))
				{
					GetClientName(i, marketerNames[commAdvCount], sizeof(marketerNames[]));
					commAdvCount++;
					continue;
				}
			}
		}
		if (adminListCount > 0 || commAdvCount > 0 || commManCount > 0 || devCount > 0)
		{
			if (adminListCount > 0)
			{
				char buffer[1024];
				ImplodeStrings(adminNames, adminListCount, ", ", buffer, sizeof(buffer));
				CReplyToCommand(client, "{GREEN}[SM] Administration online: {CYAN}%s.", buffer);
			}
			if (commManCount > 0)
			{
				char buffer[1024];
				ImplodeStrings(marketerNames, commManCount, ", ", buffer, sizeof(buffer));
				CReplyToCommand(client, "{GREEN}[SM] Marketers online: {CRIMSON}%s.", buffer);
			}
			if (devCount > 0)
			{
				char buffer[1024];
				ImplodeStrings(developerNames, devCount, ", ", buffer, sizeof(buffer));
				CReplyToCommand(client, "{GREEN}[SM] Developers online: {MAGENTA}%s.", buffer);
			}
		}
		else CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} There are no staff online. If you need an admin, call one with !calladmin.");
	}
	return Plugin_Handled;
}
