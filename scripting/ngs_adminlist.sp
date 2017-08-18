#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <morecolors>

#define PLUGIN_VERSION "1.5"

ConVar AdminListEnabled;

public Plugin myinfo = {
	name = "[NGS] Admin List",
	author = "Fredd / TheXeon",
	description = "Prints admins and donors to clients.",
	version = PLUGIN_VERSION,
	url = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	CreateConVar("adminlist_version", PLUGIN_VERSION, "[NGS] Admin List Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	AdminListEnabled = CreateConVar("adminlist_on", "1", "Turns the admin list feature on and off.");
	
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
			if (IsValidClient(i) && CheckCommandAccess(i, "sm_admin", ADMFLAG_GENERIC))
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
			if (IsValidClient(i) && CheckCommandAccess(i, "sm_donorlist_override", ADMFLAG_RESERVATION) && !CheckCommandAccess(i, "sm_admin", ADMFLAG_GENERIC))
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
			if(IsValidClient(i) && CheckCommandAccess(i, "sm_djlist_override", ADMFLAG_CUSTOM2) && !CheckCommandAccess(i, "sm_admin", ADMFLAG_GENERIC))
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
		char adminNames[MAXPLAYERS + 1][MAX_NAME_LENGTH + 1], communityAdvisorNames[MAXPLAYERS + 1][MAX_NAME_LENGTH + 1], 
			communityManagerNames[MAXPLAYERS + 1][MAX_NAME_LENGTH + 1], developerNames[MAXPLAYERS + 1][MAX_NAME_LENGTH + 1];
		int adminListCount = 0, commAdvCount = 0, commManCount = 0, devCount = 0;
		for(int i = 1 ; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
			{
				if (CheckCommandAccess(i, "sm_admin", ADMFLAG_GENERIC) && !CheckCommandAccess(i, "sm_devlist_override", ADMFLAG_CUSTOM5))
				{
					GetClientName(i, adminNames[adminListCount], sizeof(adminNames[]));
					adminListCount++;
					continue;
				}
				else if (CheckCommandAccess(i, "sm_devlist_override", ADMFLAG_CUSTOM5))
				{
					GetClientName(i, developerNames[devCount], sizeof(developerNames[]));
					devCount++;
					continue;
				}
				else if (CheckCommandAccess(i, "sm_commadvlist_override", ADMFLAG_CUSTOM3) && !CheckCommandAccess(i, "sm_devlist_override", ADMFLAG_CUSTOM5))
				{
					GetClientName(i, communityAdvisorNames[commAdvCount], sizeof(communityAdvisorNames[]));
					commAdvCount++;
					continue;
				}
				else if (CheckCommandAccess(i, "sm_commmanlist_override", ADMFLAG_CUSTOM4) &&  !CheckCommandAccess(i, "sm_devlist_override", ADMFLAG_CUSTOM5))
				{
					GetClientName(i, communityManagerNames[commManCount], sizeof(communityManagerNames[]));
					commManCount++;
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
			if (commAdvCount > 0)
			{
				char buffer[1024];
				ImplodeStrings(communityAdvisorNames, commAdvCount, ", ", buffer, sizeof(buffer));
				CReplyToCommand(client, "{GREEN}[SM] Community Advisors online: {CORNFLOWERBLUE}%s.", buffer);
			}
			if (commManCount > 0)
			{
				char buffer[1024];
				ImplodeStrings(communityManagerNames, commManCount, ", ", buffer, sizeof(buffer));
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

public bool IsValidClient(int client)
{
	if(client > 4096) client = EntRefToEntIndex(client);
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsFakeClient(client)) return false;
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}