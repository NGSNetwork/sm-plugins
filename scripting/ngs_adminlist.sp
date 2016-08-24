#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <morecolors.inc>

#define PLUGIN_VERSION "1.3"

Handle AdminListEnabled = null;
Handle AdminListMode = null;
Handle AdminListMenu = null;

public Plugin myinfo = {
	name = "[NGS] Admin List",
	author = "Fredd / TheXeon",
	description = "Prints admins and donors to clients.",
	version = PLUGIN_VERSION,
	url = "https://matespastdates.servegame.com"
}

public void OnPluginStart()
{
	CreateConVar("adminlist_version", PLUGIN_VERSION, "[NGS] Admin List Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	AdminListEnabled		= CreateConVar("adminlist_on", "1", "Turns the admin list feature on and off.");
	AdminListMode			= CreateConVar("adminlist_mode", "1", "Changes how the list appears. 1 = Chat, 2 = SideList.");
	
	RegConsoleCmd("sm_admins", CommandListAdmins, "List admins to chat.");
	RegConsoleCmd("sm_listadmins", CommandListAdmins, "List admins to chat.");
	RegConsoleCmd("sm_donors", CommandListDonors, "List donors to chat.");
	RegConsoleCmd("sm_listdonors", CommandListDonors, "List donors to chat.");
	RegConsoleCmd("sm_donators", CommandListDonors, "List donors to chat.");
}

public Action CommandListAdmins(int client, int args)
{
	if(GetConVarInt(AdminListEnabled) == 1)
	{   
		switch(GetConVarInt(AdminListMode))
		{
			case 1:
			{
				char AdminNames[MAXPLAYERS+1][MAX_NAME_LENGTH+1];
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
				char buffer[1024];
				ImplodeStrings(AdminNames, count, ", ", buffer, sizeof(buffer));
				CReplyToCommand(client, "{GREEN}Admins online are: {CYAN}%s.", buffer);
			}
			case 2:
			{
				char AdminName[MAX_NAME_LENGTH];
				AdminListMenu = CreateMenu(MenuListHandler);
				SetMenuTitle(AdminListMenu, "Admins Online:");
								
				for(int i = 1; i <= GetMaxClients(); i++)
				{
					if(IsClientInGame(i))
					{
						AdminId AdminID = GetUserAdmin(i);
						if(AdminID != INVALID_ADMIN_ID)
						{
							GetClientName(i, AdminName, sizeof(AdminName));
							AddMenuItem(AdminListMenu, AdminName, AdminName);
						}
					} 
				}
				SetMenuExitButton(AdminListMenu, true);
				DisplayMenu(AdminListMenu, client, 15);
			}
		}
	}
	return Plugin_Continue;
}

public Action CommandListDonors(int client, int args)
{
	if(GetConVarInt(AdminListEnabled) == 1)
	{   
		switch(GetConVarInt(AdminListMode))
		{
			case 1:
			{
				char DonorNames[MAXPLAYERS+1][MAX_NAME_LENGTH+1];
				int count = 0;
				for(int i = 1 ; i <= MaxClients; i++)
				{
					if(IsClientInGame(i))
					{
						AdminId AdminID = GetUserAdmin(i);
						if(GetAdminFlag(AdminID, Admin_Reservation) && !GetAdminFlag(AdminID, Admin_Generic))
						{
							GetClientName(i, DonorNames[count], sizeof(DonorNames[]));
							count++;
						}
					} 
				}
				char buffer[1024];
				ImplodeStrings(DonorNames, count, ", ", buffer, sizeof(buffer));
				CReplyToCommand(client, "{GREEN}Donors online are: {ORANGE}%s.", buffer);
			}
			case 2:
			{
				char AdminName[MAX_NAME_LENGTH];
				AdminListMenu = CreateMenu(MenuListHandler);
				SetMenuTitle(AdminListMenu, "Donors Online:");
								
				for(int i = 1; i <= GetMaxClients(); i++)
				{
					if(IsClientInGame(i))
					{
						AdminId AdminID = GetUserAdmin(i);
						if(AdminID != INVALID_ADMIN_ID && GetAdminFlag(AdminID, Admin_Reservation))
						{
							GetClientName(i, AdminName, sizeof(AdminName));
							AddMenuItem(AdminListMenu, AdminName, AdminName);
						}
					} 
				}
				SetMenuExitButton(AdminListMenu, true);
				DisplayMenu(AdminListMenu, client, 15);
			}
		}
	}
	return Plugin_Continue;
}

public int MenuListHandler(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}