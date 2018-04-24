/**
* TheXeon
* ngs_connect_backpackvalue.sp
*
* Files:
* addons/sourcemod/plugins/ngs_connect_backpackvalue.smx
* cfg/sourcemod/ngs-connect-backpackvalue.cfg
*
* Dependencies:
* sdktools.inc, SteamWorks.inc, regex.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <sdktools>
#include <sdkhooks>
#include <SteamWorks>
#include <regex>
#include <ngsutils>
#include <ngsupdater>

#define DEBUG

ConVar cvarKickEnabled;
ConVar cvarScoreboardEnabled;
ConVar cvarKickAmount;
ConVar cvarBPTFKey;

bool bptfKeySet;
int playerBpValue[MAXPLAYERS + 1] = {-1, ...};
int playerCurrentTeam[MAXPLAYERS + 1];
int teamscores[2];

public Plugin myinfo = 
{
	name = "[NGS] BackpackValue",
	author = "TheXeon",
	description = "Kick people who don't have a certain bp value.",
	version = "1.0.5",
	url = "https://neogenesisnetwork.net/"
}

public void OnPluginStart()
{
	cvarKickEnabled = CreateConVar("sm_bpa_kick_enabled", "1", "Enable kicking people if their bp doesn\'t meet the required amount.", FCVAR_NONE, true, 1.0, true, 3.0);
	cvarBPTFKey = CreateConVar("sm_bpa_bptf_key", "key", "Key used to retrieve backpack.tf api data (uses backpacktf plugin's if exists.");
	cvarScoreboardEnabled = CreateConVar("sm_bpa_scoreboard_enabled", "1", "Enable changing of scoreboard points to bp money value.", FCVAR_NONE);
	cvarKickAmount = CreateConVar("sm_bpa_kick_amount", "25", "Amount in USD that a player\'s bp should be to connect.", FCVAR_NONE);
	AutoExecConfig(true, "ngs-connect-backpackvalue");
	HookEvent("player_team", EventPlayerChangeTeam);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			OnClientPostAdminCheck(i);
		}
	}
}

public void OnConfigsExecuted()
{
	char key[48];
	cvarBPTFKey.GetString(key, sizeof(key));
	if (StrEqual(key, "key"))
	{
		ConVar cvarKeyFromOther = FindConVar("backpack_tf_api_key");
		if (cvarKeyFromOther != null)
		{
			cvarKeyFromOther.GetString(key, sizeof(key));
			if (!StrEqual(key, ""))
			{
				cvarBPTFKey.SetString(key);
				bptfKeySet = true;
			}
			else
			{
				LogError("Backpack.tf key is not set!");
				bptfKeySet = false;
			}
		}
		else
		{
			LogError("Backpack.tf key is not set!");
			bptfKeySet = false;
		}
	}
	else
	{
		bptfKeySet = true;
	}
}

public void OnMapStart()
{
	if (cvarScoreboardEnabled.BoolValue)
	{
		int iIndex = FindEntityByClassname(MaxClients + 1, "tf_player_manager");
		if (iIndex == -1)
		{
			SetFailState("Unable to find tf_player_manager entity");
		}
		SDKHook(iIndex, SDKHook_ThinkPost, Hook_OnThinkPost);

		teamscores = {0, 0};
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
			{
				int clientteam = GetClientTeam(i);
				if (clientteam > 1 && clientteam < 4 && playerBpValue[i] > -1)
				{
					teamscores[clientteam - 2] += playerBpValue[i];
				}
			}
		}
		SetTeamScores();
	}
}

public void OnClientDisconnect(int client)
{
	if (playerBpValue[client] > -1)
	{
		teamscores[playerCurrentTeam[client] - 2] -= playerBpValue[client];
	}
}

// Thank bl4nk https://forums.alliedmods.net/showpost.php?p=1473377&postcount=2
public void Hook_OnThinkPost(int iEnt)
{
	static int iTotalScoreOffset = -1;
	if (iTotalScoreOffset == -1)
	{
		iTotalScoreOffset = FindSendPropInfo("CTFPlayerResource", "m_iTotalScore");
	}

	int iTotalScore[MAXPLAYERS+1];
	GetEntDataArray(iEnt, iTotalScoreOffset, iTotalScore, MaxClients+1);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && playerBpValue[i] > -1)
		{
			iTotalScore[i] = playerBpValue[i];
		}
	}
    
	SetEntDataArray(iEnt, iTotalScoreOffset, iTotalScore, MaxClients+1);
}

void SetTeamScores()
{
	SetTeamScore(2, teamscores[0]);
	SetTeamScore(3, teamscores[1]);
}

public void OnClientPostAdminCheck(int client)
{
	if (!cvarKickEnabled.BoolValue || !IsValidClient(client) || !bptfKeySet) return;
	playerBpValue[client] = -1;
	playerCurrentTeam[client] = 0;
	char auth[64], key[64];
	if (GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth)))
	{
		cvarBPTFKey.GetString(key, sizeof(key));
		SWHTTPRequest request = new SWHTTPRequest(k_EHTTPMethodGET, "https://backpack.tf/api/users/info/v1");
		request.SetParam("steamids", auth);
		request.SetParam("key", key);
		request.SetUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:58.0) Gecko/20100101 Firefox/58.0");
		request.SetCallbacks(OnRequestDone);
		request.SetContextValue(GetClientUserId(client));
		request.Send();
		#if defined DEBUG
			PrintToServer("Sent request for client %L!", client);
		#endif
	}
}

public void OnRequestDone(SWHTTPRequest request, bool failure, bool successful, EHTTPStatusCode status, any userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsValidClient(client))
	{
		delete request;
		return;
	}

	if(successful && status == k_EHTTPStatusCode200OK)
	{
		char buffer[4096];
		char bpvalue[24];
		char path[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, path, sizeof(path), "data/backpackvalue.txt");
		if (request.WriteResponseToFile(path))
		{
			Regex regex = new Regex("(\"value\"): (.*),[\r\n]");
			File file = OpenFile(path, "r");
			while (!file.EndOfFile())
			{
				file.ReadLine(buffer, sizeof(buffer));
				int matches;
				// original was:	/("value"): (.*),[\r\n]/i
				if ((matches = regex.Match(buffer)) > 0)
				{
					regex.GetSubString(0, bpvalue, sizeof(bpvalue));
					#if defined DEBUG
						PrintToServer("Client %N's bpvalue is %s and there are %d matches.", client, bpvalue, matches);
					#endif
					int bpval = RoundToNearest(StringToFloat(buffer));
					if (cvarKickEnabled.BoolValue && bpval < cvarKickAmount.IntValue)
					{
						KickClient(client, "Kicked for not meeting bp value requirements.");
					}
					else
					{
						playerBpValue[client] = bpval;
						if (cvarScoreboardEnabled.BoolValue)
						{
							int clientteam = GetClientTeam(client);
							if (clientteam > 1 && clientteam < 4 && playerBpValue[client] > -1)
							{
								teamscores[clientteam - 2] += playerBpValue[client];
							}
							SetTeamScores();
						}
					}
					break;
				}
				else
				{
					#if !defined DEBUG
						LogError("Error parsing backpack value for %L, no match found.", client);
					#else
						PrintToServer("From file, read %s", buffer);
					#endif
				}
			}
			delete file;
			delete regex;
		}
		else
		{
			#if !defined DEBUG
				LogError("Could not write file to path %s!", path);
			#else
				PrintToServer("File was not written at path %s, response size was %d!", path, request.ResponseSize);
			#endif
		}
	}
	else if (status == k_EHTTPStatusCode400BadRequest)
	{
		LogError("backpack.tf API failed: You have not set an API key");
	}
	delete request;
}

public void EventPlayerChangeTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (!cvarKickEnabled.BoolValue) return;
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(client))
	{
		return;
	}

	int oldteam = event.GetInt("oldteam");
	int newteam = event.GetInt("team");
	if (oldteam > 1 && oldteam < 4 && playerBpValue[client] > -1)
	{
		teamscores[oldteam - 2] -= playerBpValue[client];
	}

	if (newteam > 1 && newteam < 4 && playerBpValue[client] > -1)
	{
		teamscores[newteam - 2] += playerBpValue[client];
		playerCurrentTeam[client] = newteam;
	}
	SetTeamScores();
}