#include <sourcemod>
#include <connect>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "1.0.0"

ConVar g_hcvarKickType;
ConVar g_hcvarEnabled;
ConVar g_hcvarReason;

public Plugin myinfo = 
{
	name = "[NGS] Reserved Slots - Connect",
	author = "luki1412 / TheXeon",
	description = "Simple plugin for reserved slots using Connect",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.net/"
}

public void OnPluginStart()
{
	ConVar g_hcvarVer = CreateConVar("sm_brsc_version", PLUGIN_VERSION, "Basic Reserved Slots using Connect - version cvar", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hcvarEnabled = CreateConVar("sm_brsc_enabled", "1", "Enables/disables this plugin", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hcvarKickType = CreateConVar("sm_brsc_type", "1", "Who gets kicked out: 1 - Highest ping player, 2 - Longest connection time player, 3 - Random player", FCVAR_NONE, true, 1.0, true, 3.0);
	g_hcvarReason = CreateConVar("sm_brsc_reason", "Kicked for reserved slot! Connect to our other server or donate to get instant access.", "Reason used when kicking players", FCVAR_NONE);
	
	g_hcvarVer.SetString(PLUGIN_VERSION);	
	AutoExecConfig(true, "ngs-connect-reservedslots");
}

public bool OnClientPreConnectEx(const char[] name, char password[255], const char[] ip, const char[] steamID, char rejectReason[255])
{
	if (!g_hcvarEnabled.BoolValue || GetClientCount() < MaxClients)
	{
		return true;
	}

	AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, steamID);
	
	if (admin == INVALID_ADMIN_ID)
	{
		LogMessage("%s didn\'t have an adminid.", steamID);
		return true;
	}
	LogMessage("%s should flagcheck right after this.", steamID);
	if (GetAdminFlag(admin, Admin_Reservation))
	{
		LogMessage("%s flag was good, should kick right after this.", steamID);
		int target = SelectKickClient();
						
		if (target)
		{
			LogMessage("%s about to kick %N.", steamID, target);
			char rReason[255];
			g_hcvarReason.GetString(rReason, sizeof(rReason));
			KickClientEx(target, "%s", rReason);
		}
	}
	
	return true;
}

int SelectKickClient()
{	
	float highestValue;
	int highestValueId;
	
	float highestSpecValue;
	int highestSpecValueId;
	
	bool specFound;
	
	float value;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || CheckCommandAccess(i, "sm_reskick_immunity", ADMFLAG_RESERVATION))
		{
			continue;
		}
		
		value = 0.0;
	
		switch (g_hcvarKickType.IntValue)
		{
			case 1:
			{
				value = GetClientAvgLatency(i, NetFlow_Outgoing);
			}
			case 2:
			{
				value = GetClientTime(i);
			}
			default:
			{
				value = GetRandomFloat(0.0, 100.0);
			}
		}

		if (IsClientObserver(i))
		{			
			specFound = true;
			
			if (value > highestSpecValue)
			{
				highestSpecValue = value;
				highestSpecValueId = i;
			}
		}
		
		if (value >= highestValue)
		{
			highestValue = value;
			highestValueId = i;
		}
	}
	
	if (specFound)
	{
		return highestSpecValueId;
	}
	
	return highestValueId;
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