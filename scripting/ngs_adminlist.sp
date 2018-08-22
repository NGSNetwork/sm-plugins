/**
* TheXeon
* ngs_adminlist.sp
*
* Files:
* addons/sourcemod/plugins/ngs_adminlist.smx
* cfg/sourcemod/plugin.ngs_adminlist.cfg
*
* Dependencies:
* autoexecconfig.inc, ngsutils.inc, ngsupdater.inc, multicolors.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <autoexecconfig>
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
	bool appended;
	AdminListEnabled = AutoExecConfig_CreateConVarCheckAppend(appended, "sm_ngsadminlist_on", "1", "Turns the admin list feature on and off.");
	AutoExecConfig_ExecAndClean(appended);

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
			CReplyToCommand(client, "%t", "AdministratorsOnline", buffer);
		}
		else CReplyToCommand(client, "%t %t", "ChatTag", "NoAdministratorsOnline");
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
			CReplyToCommand(client, "%t", "DonorsOnline", buffer);
		}
		else CReplyToCommand(client, "%t %t", "ChatTag", "NoDonorsOnline");
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
			CReplyToCommand(client, "%t", "DJsOnline", buffer);
		}
		else CReplyToCommand(client, "%t %t", "ChatTag", "NoDJsOnline");
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
				CReplyToCommand(client, "%t", "AdministratorsOnline", buffer);
			}
			if (commManCount > 0)
			{
				char buffer[1024];
				ImplodeStrings(marketerNames, commManCount, ", ", buffer, sizeof(buffer));
				CReplyToCommand(client, "%t", "MarketersOnline", buffer);
			}
			if (devCount > 0)
			{
				char buffer[1024];
				ImplodeStrings(developerNames, devCount, ", ", buffer, sizeof(buffer));
				CReplyToCommand(client, "%t", "DevelopersOnline", buffer);
			}
		}
		else CReplyToCommand(client, "%t %t", "ChatTag", "NoStaffOnline");
	}
	return Plugin_Handled;
}
