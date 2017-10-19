#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <connect>

public Plugin myinfo = {
	name = "[NGS] SourceSleuth IPBan Helper",
	author = "TheXeon",
	description = "Not authed? No problem!",
	version = "0.0.1",
	url = "https://www.neogenesisnetwork.net/"
}

public bool OnClientPreConnectEx(const char[] name, char password[255], const char[] ip, const char[] steamID, char rejectReason[255])
{
	PrintToServer("ID is %s", steamID);
	/*if (StrContains("STEAM_ID_STOP_IGNORING_RETVALS", auth, false) != -1)
	{
		if (IsPlayerAlive(client))
		{
			ChangeClientTeam(client, 1);
			PrintToChat(client, "Your client has not been authed, please reconnect.");
		}
		BaseComm_SetClientGag(client, true);
		BaseComm_SetClientMute(client, true);
		ServerCommand("namelockid %d 1", userid);
	}
	else
		return Plugin_Stop;*/
	/*if (StrContains(steamID, "STEAM_0:1:43646473", false) != -1)
	{
		Format(rejectReason, 255, "A test!");
		return false;
	}*/
	return true;
}

public void OnClientConnected(int client)
{
	PrintToServer("Client serial is %d", GetClientSerial(client));
}

