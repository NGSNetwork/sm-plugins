/**
* TheXeon
* ngs_admin_toolkit.sp
*
* Files:
* addons/sourcemod/plugins/ngs_admin_toolkit.smx
*
* Dependencies:
* sourcemod.inc, sdktools.inc, sdkhooks.inc, tf2_stocks.inc, tf2.inc,
* multicolors.inc, clientprefs.inc, basecomm.inc, sourcecomms.inc,
* ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define LIBRARY_ADDED_FUNC OnLibAdded
#define LIBRARY_REMOVED_FUNC OnLibRemoved
#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2>
#include <multicolors>
#include <clientprefs>
#undef REQUIRE_PLUGIN
#include <basecomm>
#include <sourcecomms>
#define REQUIRE_PLUGIN
#include <ngsutils>
#include <ngsupdater>

bool basecommExists = false;
bool sourcecommsExists = false;
bool muteNonAdminsEnabled = false;
bool isPlayerNameBanned[MAXPLAYERS + 1];

Cookie nameBannedCookie = null;

//--------------------//

public Plugin myinfo = {
	name = "[NGS] Admin Tools",
	author = "TheXeon",
	description = "Admin commands for NGS people.",
	version = "1.2.6",
	url = "https://neogenesisnetwork.net"
}

public void OnPluginStart()
{
	RegAdminCmd("sm_forcerespawn", CommandForceRespawn, ADMFLAG_GENERIC, "Usage: sm_forcerespawn <#userid|name>");
	RegAdminCmd("sm_changeteam", CommandChangeTeam, ADMFLAG_GENERIC, "Usage: sm_changeteam <#userid|name> <team> (1 = Spec / 2 = Red / 3 = Blue)");
	RegAdminCmd("sm_sethealth", CommandSetHealth, ADMFLAG_GENERIC, "Usage: sm_sethealth <#userid|name> <amount>");
	RegAdminCmd("sm_bamall", CommandBamboozleAll, ADMFLAG_GENERIC, "Usage: sm_bamall <#userid|name>");
	RegAdminCmd("sm_mutenonadmins", CommandMuteNonAdmins, ADMFLAG_GENERIC, "Usage: sm_mutenonadmins");
	RegAdminCmd("sm_unmutenonadmins", CommandUnmuteNonAdmins, ADMFLAG_GENERIC, "Usage: sm_unmutenonadmins");
	RegAdminCmd("sm_nameban", CommandNameBan, ADMFLAG_GENERIC, "Usage: sm_nameban <#userid|name>");
	RegAdminCmd("sm_nameunban", CommandNameUnban, ADMFLAG_GENERIC, "Usage: sm_nameunban <#userid|name>");
	RegAdminCmd("sm_getlookingpos", CommandGetLookingPosition, ADMFLAG_GENERIC, "Usage: sm_getlookingpos");
	RegAdminCmd("sm_checkcommandaccess", CommandCheckCommandAccess, ADMFLAG_ROOT, "Usage: sm_checkcommandaccess <#userid|name> <cmdstring>");
	RegAdminCmd("sm_getclientinfo", CommandGetClientInfo, ADMFLAG_ROOT, "Usage: sm_getclientinfo <#userid|name> <varstring>");
	RegAdminCmd("sm_queryclientconvar", CommandQueryClientConVar, ADMFLAG_ROOT, "Usage: sm_queryclientconvar <#userid|name> <varstring>");


	LoadTranslations("common.phrases");
	LoadTranslations("ngs_admin_toolkit.phrases");

	nameBannedCookie = new Cookie("NameBanned", "Is the player name-banned?", CookieAccess_Private);

	for (int i = MaxClients; i > 0; --i)
	{
		if (!AreClientCookiesCached(i))
		{
			continue;
		}
		OnClientCookiesCached(i);
	}
}

public void OnLibAdded(const char[] name)
{
	if (StrEqual(name, "basecomm"))
		basecommExists = true;
	if (StrEqual(name, "sourcecomms"))
		sourcecommsExists = true;
}

public void OnLibRemoved(const char[] name)
{
	if (StrEqual(name, "basecomm"))
		basecommExists = false;
	if (StrEqual(name, "sourcecomms"))
		sourcecommsExists = false;
}

public void OnClientCookiesCached(int client)
{
	char sValue[8];
	nameBannedCookie.GetValue(client, sValue, sizeof(sValue));

	isPlayerNameBanned[client] = (sValue[0] != '\0' && StringToInt(sValue));
}

public void OnClientPostAdminCheck(int client)
{
	if (muteNonAdminsEnabled && !CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC))
		SetClientListeningFlags(client, VOICE_MUTED);

	if (AreClientCookiesCached(client) && isPlayerNameBanned[client] && CommandExists("sm_rename"))
	{
		int userid = GetClientUserId(client);
		ServerCommand("sm_rename #%d IHaveANameNow#%d", userid, userid);
		if (CommandExists("sm_namelock"))
			ServerCommand("sm_namelock #%d 1", userid);
  	}
}

public Action CommandNameBan(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "%t %t", "ChatTag", "NameBanUsage");
		return Plugin_Handled;
	}

	char arg1[MAX_BUFFER_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));

	int target = FindTarget(client, arg1, false, false);
	if (target == -1) return Plugin_Handled;

	if (isPlayerNameBanned[target])
	{
		CReplyToCommand(client, "%t %t", "ChatTag", "NameBanAlreadyBanned");
		return Plugin_Handled;
	}

	if (CommandExists("sm_rename"))
	{
		int userid = GetClientUserId(target);
		ServerCommand("sm_rename #%d IHaveANameNow#%d", userid, userid);
		if (CommandExists("sm_namelock"))
			ServerCommand("sm_namelock #%d 1", userid);
		nameBannedCookie.SetValue(target, "1");
	}

	LogAction(client, target, "%N banned %N's name!", client, target);
	return Plugin_Handled;
}

public Action CommandNameUnban(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "%t %t", "ChatTag", "NameUnbanUsage");
		return Plugin_Handled;
	}

	char arg1[MAX_BUFFER_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));

	int target = FindTarget(client, arg1, false, false);
	if (target == -1) return Plugin_Handled;

	if (!isPlayerNameBanned[target])
	{
		CReplyToCommand(client, "%t %t", "ChatTag", "NameUnbanAlreadyUnbanned");
		return Plugin_Handled;
	}

	if (CommandExists("sm_namelock"))
	{
		int userid = GetClientUserId(target);
		ServerCommand("sm_namelock #%d 0", userid);
		nameBannedCookie.SetValue(target, "0");
		CPrintToChat(client, "%t %t", "ChatTag", "NameUnbanNameUnlocked");
	}

	LogAction(client, target, "%N unbanned %N's name!", client, target);
	return Plugin_Handled;
}

public Action CommandForceRespawn(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "%t %t", "ChatTag", "ForceRespawnUsage");
		return Plugin_Handled;
	}
	char arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;

	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		TF2_RespawnPlayer(target_list[i]);
		LogAction(client, target_list[i], "\"%L\" respawned \"%L\"!", client, target_list[i]);
	}

	if (tn_is_ml)
	{
		CShowActivity2(client, "{GREEN}[SM]{DEFAULT} ", "Respawned %t!", target_name);
	}
	else
	{
		CShowActivity2(client, "{GREEN}[SM]{DEFAULT} ", "Respawned %s!", target_name);
	}
	return Plugin_Handled;
}

public Action CommandGetLookingPosition(int client, int args)
{
	if (!IsValidClient(client) || !IsPlayerAlive(client)) return Plugin_Handled;

	float start[3], angle[3], end[3];
	GetClientEyePosition(client, start);
	GetClientEyeAngles(client, angle);
	TR_TraceRayFilter(start, angle, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer, client);
	if (TR_DidHit())
	{
		TR_GetEndPosition(end);
	}
	CReplyToCommand(client, "%t %t", "ChatTag", "PositionLookingAt", end[0], end[1], end[2]);
	return Plugin_Handled;
}


public bool TraceEntityFilterPlayer(int entity, int contentsMask, any data)
{
	return entity > MaxClients;
}

public Action CommandChangeTeam(int client, int args)
{
	if (args < 2)
	{
		CReplyToCommand(client, "%t %t", "ChatTag", "ChangeTeamUsage");
	}

	char arg1[MAX_NAME_LENGTH], arg2[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	int Team;

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;

	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	int argteam = StringToInt(arg2);
	if (argteam < 4 && argteam > 0)
	{
		Team = argteam;
	}
	else
	{
		CReplyToCommand(client, "%t %t", "ChatTag", "ChangeTeamChooseTeam");
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		ChangeClientTeam(target_list[i], Team);
		LogAction(client, target_list[i], "\"%L\" moved \"%L\" to team %d.", client, target_list[i], Team);
	}

	if (tn_is_ml)
		CShowActivity2(client, "{GREEN}[SM]{DEFAULT} ", "Moved %t to team %d!", target_name, Team);
	else
		CShowActivity2(client, "{GREEN}[SM]{DEFAULT} ", "Moved %s to team %d!", target_name, Team);
	return Plugin_Handled;
}

public Action CommandSetHealth(int client, int args)
{
	char arg1[MAX_TARGET_LENGTH], arg2[10];
	int iHealth;

	EngineVersion engine = GetEngineVersion();

	if (args < 2)
	{
		CReplyToCommand(client, "%t %t", "ChatTag", "SetHealthUsage");
		return Plugin_Handled;
	}
	else
	{
		GetCmdArg(1, arg1, sizeof(arg1));
		GetCmdArg(2, arg2, sizeof(arg2));
		iHealth = StringToInt(arg2);
	}

	if (iHealth < 0)
	{
		iHealth = 0;
	}

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;

	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		if (engine == Engine_TF2)
		{
			if (iHealth == 0)
				FakeClientCommand(target_list[i], "explode");
			else
			{
				SetEntProp(target_list[i], Prop_Data, "m_iMaxHealth", iHealth);
				SetEntityHealth(target_list[i], iHealth);
			}
		}

		else
		{
			if (iHealth == 0)
				SetEntityHealth(target_list[i], 1);
			else
				SetEntityHealth(target_list[i], iHealth);
		}

		LogAction(client, target_list[i], "\"%L\" set \"%L\"'s health to  %i", client, target_list[i], iHealth);
	}

	if (tn_is_ml)
		CShowActivity2(client, "{GREEN}[SM]{DEFAULT} ", "Set {LIGHTGREEN}%t{DEFAULT}'s health to {LIGHTGREEN}%d{DEFAULT}.", target_name, iHealth);
	else
		CShowActivity2(client, "{GREEN}[SM]{DEFAULT} ", "Set {LIGHTGREEN}%s{DEFAULT}'s health to {LIGHTGREEN}%d{DEFAULT}.", target_name, iHealth);

	return Plugin_Handled;
}

public Action CommandBamboozleAll(int client, int args)
{
	if (args < 1) return Plugin_Handled;
	char arg1[MAX_BUFFER_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));

	int target = FindTarget(client, arg1, false, false);
	if (target == -1) return Plugin_Handled;

	SetHudTextParams(-1.0, 0.1, 3.0, 255, 0, 0, 255, 1, 1.0, 1.0, 1.0);
	Handle hHudText = CreateHudSynchronizer();
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			EmitSoundToClient(i, "vo/demoman_specialcompleted11.mp3");
			EmitSoundToClient(i, "vo/demoman_specialcompleted11.mp3");
			ShowSyncHudText(i, hHudText, "BAMBOOZLED");
			LogAction(target, i, "\"%L\" bamboozled \"%L\"!", target, i);
		}
	}
	delete hHudText;

	CPrintToChatAll("%t %t", "ChatTag", "BamboozledEveryone", target);
	CPrintToChatAll("%t %t", "ChatTag", "BamboozledFeelIt");
	return Plugin_Handled;
}

public Action CommandMuteNonAdmins(int client, int args)
{
	if (muteNonAdminsEnabled)
	{
		CReplyToCommand(client, "%t %t", "ChatTag", "MuteNonAdminsUsage");
	}
	else
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && !CheckCommandAccess(i, "sm_admin", ADMFLAG_GENERIC))
			{
				SetClientListeningFlags(i, VOICE_MUTED);
			}
		}
		CShowActivity2(client, "{GREEN}[SM]{DEFAULT} ", "Muted all nonadmins!");
		LogAction(client, -1, "Muted all nonadmins!");
		muteNonAdminsEnabled = true;
	}
	return Plugin_Handled;
}

public Action CommandUnmuteNonAdmins(int client, int args)
{
	if (!muteNonAdminsEnabled)
	{
		CReplyToCommand(client, "%t %t", "ChatTag", "UnmuteNonAdminsUsage");
	}
	else
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && ((sourcecommsExists && SourceComms_GetClientMuteType(i) == bNot) || (basecommExists && !BaseComm_IsClientMuted(i))))
			{
				SetClientListeningFlags(i, VOICE_NORMAL);
			}
		}
		CShowActivity2(client, "{GREEN}[SM]{DEFAULT} ", "Unmuted all nonadmins!");
		LogAction(client, -1, "Unmuted all nonadmins!");
		muteNonAdminsEnabled = false;
	}
	return Plugin_Handled;
}

public Action CommandCheckCommandAccess(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "%t %t", "ChatTag", "CheckCommandAccessUsage");
		return Plugin_Handled;
	}

	char arg1[MAX_BUFFER_LENGTH], arg2[MAX_BUFFER_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	int target = FindTarget(client, arg1, true);
	if (!IsValidClient(target)) return Plugin_Handled;

	AdminId admin = GetUserAdmin(target);
	if (CheckCommandAccess(target, arg2, ADMFLAG_ROOT))
		CReplyToCommand(client, "%t %t", "ChatTag", "CheckCommandAccessHasCCA", target, arg2);
	else
		CReplyToCommand(client, "%t %t", "ChatTag", "CheckCommandAccessDoesNotHaveCCA", target, arg2);
	if (CheckAccess(admin, arg2, ADMFLAG_ROOT))
		CReplyToCommand(client, "%t %t", "ChatTag", "CheckCommandAccessHasCA", target, arg2);
	else
		CReplyToCommand(client, "%t %t", "ChatTag", "CheckCommandAccessDoesNotHaveCA", target, arg2);
	return Plugin_Handled;
}

public Action CommandGetClientInfo(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "%t %t", "ChatTag", "GetClientInfoUsage");
		return Plugin_Handled;
	}

	char arg1[MAX_BUFFER_LENGTH], arg2[MAX_BUFFER_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	int target = FindTarget(client, arg1, true);
	if (!IsValidClient(target)) return Plugin_Handled;

	char varString[MAX_BUFFER_LENGTH];

	if (GetClientInfo(target, arg2, varString, sizeof(varString)))
		CReplyToCommand(client, "%t %t", "ChatTag", "GetClientInfoValueIs", target, arg2, varString);
	else
		CReplyToCommand(client, "%t %t", "ChatTag", "GetClientInfoNoValue", target);
	return Plugin_Handled;
}

public Action CommandQueryClientConVar(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "%t %t", "ChatTag", "QueryClientConvarUsage");
		return Plugin_Handled;
	}

	char arg1[MAX_BUFFER_LENGTH], arg2[MAX_BUFFER_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	int target = FindTarget(client, arg1, true);
	if (!IsValidClient(target)) return Plugin_Handled;

	QueryClientConVar(target, arg2, ClientConVar, client);
	return Plugin_Handled;
}

void ClientConVar(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any value)
{
	if (cookie == QUERYCOOKIE_FAILED)
	{
		CReplyToCommand(value, "%t %t", "ChatTag", "ClientConVarFailed" client);
		return;
	}
	switch (result)
	{
		case ConVarQuery_Okay:
			CReplyToCommand(value, "%t %t", "ChatTag", "ClientConVarIs", client, cvarName, cvarValue);
		case ConVarQuery_Protected:
			CReplyToCommand(value, "%t %t", "ChatTag", "ClientConVarProtected", client, cvarName);
		default:
			CReplyToCommand(value, "%t %t", "ChatTag", "ClientConVarNotFound", client);
	}
}
