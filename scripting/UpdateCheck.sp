#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <SteamWorks>

int g_iPatchVersion = 0;
int g_iAppID = 0;

Handle g_hForward = INVALID_HANDLE;

public Plugin myinfo =
{
    name 			=		"SteamWorks Update Check",				/* https://www.youtube.com/watch?v=Tq_0ht8HCcM */
    author			=		"Kyle Sanderson / TheXeon",
    description		=		"Queries SteamWeb for Updates.",
    version			=		"1.0b",
    url				=		"https://AlliedMods.net"
};

static stock bool ReadSteamINF(const char[] sPath, int &iAppID, int &iPatchVersion)
{
	File hFile = OpenFile(sPath, "r");
	if (hFile == null)
	{
		return false;
	}

	char sBuffer[256];

	do
	{
		if (!hFile.ReadLine(sBuffer, sizeof(sBuffer)))
		{
			continue;
		}

		TrimString(sBuffer);
		ReplaceString(sBuffer, sizeof(sBuffer), ".", ""); /* CS:GO uses decimals in steam.inf, WebAPI is Steam| style. */

		int iPos = FindCharInString(sBuffer, '=');
		if (iPos == -1)
		{
			continue;
		}

		sBuffer[iPos++] = '\0';
		switch (CharToLower(sBuffer[0]))
		{
			case 'a':
			{
				if (!StrEqual(sBuffer, "appID", false))
				{
					continue;
				}

				iAppID = StringToInt(sBuffer[iPos]);
			}

			case 'p':
			{
				if (!StrEqual(sBuffer, "PatchVersion", false))
				{
					continue;
				}

				iPatchVersion = StringToInt(sBuffer[iPos]);
			}
		}
	} while (!hFile.EndOfFile());

	delete hFile;
	return true;
}

public void OnPluginStart()
{
	if (!ReadSteamINF("steam.inf", g_iAppID, g_iPatchVersion) && !ReadSteamINF("../steam.inf", g_iAppID, g_iPatchVersion))
	{
		SetFailState("Unable to read steam.inf");
	}

	g_hForward = CreateGlobalForward("SteamWorks_RestartRequested", ET_Ignore);
}

public void OnMapStart()
{
	CreateTimer(120.0, OnCheckForUpdate, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public Action OnCheckForUpdate(Handle hTimer)
{
	static char sRequest[256];
	if (sRequest[0] == '\0')
	{
		FormatEx(sRequest, sizeof(sRequest), "http://api.steampowered.com/ISteamApps/UpToDateCheck/v0001/?appid=%u&version=%u&format=xml", g_iAppID, g_iPatchVersion);
	}

	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, sRequest);
	if (!hRequest || !SteamWorks_SetHTTPCallbacks(hRequest, OnTransferComplete) || !SteamWorks_SendHTTPRequest(hRequest))
	{
		delete hRequest;
	}

	return Plugin_Continue;
}

public void OnTransferComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode)
{
	if (!bFailure && bRequestSuccessful && eStatusCode == k_EHTTPStatusCode200OK)
	{
		SteamWorks_GetHTTPResponseBodyCallback(hRequest, APIWebResponse);
	}

	delete hRequest;
}

public void APIWebResponse(const char[] sData)
{
	int iPos = StrContains(sData, "<required_version>");
	if (iPos == -1)
	{
		return;
	}

	if (g_iPatchVersion != StringToInt(sData[iPos+18]))
	{
		Call_StartForward(g_hForward);
		Call_Finish();
	}
}
