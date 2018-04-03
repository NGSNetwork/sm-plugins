/**
* TheXeon
* ngs_connect_reservedslots.sp
*
* Files:
* addons/sourcemod/plugins/ngs_connect_reservedslots.smx
* cfg/sourcemod/ngs-connect-reservedslots.cfg
*
* Dependencies:
* sourcemod.inc, afk_manager.inc, connect.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <sourcemod>
#include <afk_manager>
#include <connect>
#include <ngsutils>
#include <ngsupdater>

ConVar g_hcvarKickType;
ConVar g_hcvarEnabled;
ConVar g_hcvarReason;

public Plugin myinfo =
{
	name = "[NGS] Reserved Slots - Connect",
	author = "luki1412 / TheXeon",
	description = "Simple plugin for reserved slots using Connect",
	version = "1.0.5",
	url = "https://neogenesisnetwork.net/"
}

public void OnPluginStart()
{
	g_hcvarEnabled = CreateConVar("sm_brsc_enabled", "1", "Enables/disables this plugin", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hcvarKickType = CreateConVar("sm_brsc_type", "1", "Who gets kicked out: 1 - Highest ping player, 2 - Longest connection time player, 3 - Random player, 4 - AFK Player", FCVAR_NONE, true, 1.0, true, 3.0);
	g_hcvarReason = CreateConVar("sm_brsc_reason", "Kicked for reserved slot! Connect to our other server or donate to get instant access.", "Reason used when kicking players", FCVAR_NONE);

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
		int target = SelectKickClient(g_hcvarKickType.IntValue);

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

int SelectKickClient(int mode)
{
	float highestValue;
	int highestValueId = 0;

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

		switch (mode)
		{
			case 1:
			{
				value = GetClientAvgLatency(i, NetFlow_Outgoing);
			}
			case 2:
			{
				value = GetClientTime(i);
			}
			case 4:
			{
				value = (AFKM_IsClientAFK(i) && AFKM_GetClientAFKTime(i) > 30) ? GetRandomFloat(0.1, 100.0) : 0.0;
			}
			default:
			{
				value = GetRandomFloat(0.1, 100.0);
			}
		}

		if (IsClientObserver(i) && GetClientTime(i) > 20)
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

	if (highestValueId == 0) return SelectKickClient(1);
	return highestValueId;
}
