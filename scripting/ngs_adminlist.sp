#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <morecolors>

#define PLUGIN_VERSION "1.3"

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
}

public Action CommandListAdmins(int client, int args)
{
	if(GetConVarInt(AdminListEnabled) == 1)
	{   
		char AdminNames[MAXPLAYERS + 1][MAX_NAME_LENGTH + 1];
		int count = 0;
		for(int i = 1 ; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				AdminId adminid = GetUserAdmin(i);
				if(GetAdminFlag(adminid, Admin_Generic))
				{
					GetClientName(i, AdminNames[count], sizeof(AdminNames[]));
					count++;
				}
			} 
		}
		if (count > 0)
		{
			char buffer[1024];
			ImplodeStrings(AdminNames, count, ", ", buffer, sizeof(buffer));
			CReplyToCommand(client, "{GREEN}Admins online are: {CYAN}%s.", buffer);
		}
		else CReplyToCommand(client, "{GREEN}[SM] There are no admins online. Use !calladmin to call an admin over.");
	}
	return Plugin_Handled;
}

public Action CommandListDonors(int client, int args)
{
	if(GetConVarInt(AdminListEnabled) == 1)
	{   
		char DonorNames[MAXPLAYERS + 1][MAX_NAME_LENGTH + 1];
		int count = 0;
		for(int i = 1 ; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				AdminId AdminID = GetUserAdmin(i);
				if(GetAdminFlag(AdminID, Admin_Reservation) && !GetAdminFlag(AdminID, Admin_Generic))
				{
					GetClientName(i, DonorNames[count], sizeof(DonorNames[]));
					count++;
				}
			} 
		}
		if (count > 0)
		{
			char buffer[1024];
			ImplodeStrings(DonorNames, count, ", ", buffer, sizeof(buffer));
			CReplyToCommand(client, "{GREEN}[SM] Donors online are: {ORANGE}%s.", buffer);
		}
		else CReplyToCommand(client, "{GREEN}[SM] There are no donors online.");
	}
	return Plugin_Handled;
}

public Action CommandListDJs(int client, int args)
{
	if(GetConVarInt(AdminListEnabled) == 1)
	{   
		char DJNames[MAXPLAYERS + 1][MAX_NAME_LENGTH + 1];
		int count = 0;
		for(int i = 1 ; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				AdminId AdminID = GetUserAdmin(i);
				if(GetAdminFlag(AdminID, Admin_Custom2) && !GetAdminFlag(AdminID, Admin_Generic))
				{
					GetClientName(i, DJNames[count], sizeof(DJNames[]));
					count++;
				}
			} 
		}
		if (count > 0)
		{
			char buffer[1024];
			ImplodeStrings(DJNames, count, ", ", buffer, sizeof(buffer));
			CReplyToCommand(client, "{GREEN}[SM] DJs online are: {PURPLE}%s.", buffer);
		}
		else CReplyToCommand(client, "{GREEN}[SM] There are no DJs online.");
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