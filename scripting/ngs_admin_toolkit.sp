#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2>
#include <morecolors>
#include <clientprefs>
#undef REQUIRE_PLUGIN
#include <basecomm>
#include <sourcecomms>

#define PLUGIN_VERSION "1.2.5"

bool basecommExists = false;
bool sourcecommsExists = false;
bool muteNonAdminsEnabled = false;
bool isPlayerNameBanned[MAXPLAYERS + 1];
int playerSpecingID[MAXPLAYERS + 1];

Handle nameBannedCookie = INVALID_HANDLE;

//--------------------//

public Plugin myinfo = {
	name = "[NGS] Admin Tools",
	author = "TheXeon",
	description = "Admin commands for NGS people.",
	version = PLUGIN_VERSION,
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
	RegAdminCmd("sm_checkcommandaccess", CommandCheckCommandAccess, ADMFLAG_GENERIC, "Usage: sm_checkcommandaccess <#userid|name> <cmdstring>");
	RegAdminCmd("sm_getclientinfo", CommandGetClientInfo, ADMFLAG_GENERIC, "Usage: sm_getclientinfo <#userid|name> <varstring>");
	RegAdminCmd("sm_queryclientconvar", CommandQueryClientConVar, ADMFLAG_GENERIC, "Usage: sm_queryclientconvar <#userid|name> <varstring>");
	// TODO: Uncomment everything in this area.
	//RegAdminCmd("sm_specplayer", CommandSpecPlayer, ADMFLAG_GENERIC, "Usage: sm_specplayer <#userid|name>");
	RegAdminCmd("sm_getlookingpos", CommandGetLookingPosition, ADMFLAG_GENERIC, "Usage: sm_getlookingpos");
	
	CreateConVar("tf_ngsadmintoolkit_version", PLUGIN_VERSION, "Version of [NGS] Admin Toolkit");
	
	LoadTranslations("common.phrases");
	
	nameBannedCookie = RegClientCookie("NameBanned", "Is the player name-banned?", CookieAccess_Private);
	
	//HookEvent("player_spawn", OnPlayerSpawn);
	//HookEvent("player_team", OnPlayerTeam);
	
	for (int i = MaxClients; i > 0; --i)
	{
		if (!AreClientCookiesCached(i))
		{
			continue;
		}
		OnClientCookiesCached(i);
	}
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "basecomm"))
		basecommExists = true;
	if (StrEqual(name, "sourcecomms"))
		sourcecommsExists = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "basecomm"))
		basecommExists = false;
	if (StrEqual(name, "sourcecomms"))
		sourcecommsExists = false;
}

public void OnClientCookiesCached(int client)
{
    char sValue[8];
    GetClientCookie(client, nameBannedCookie, sValue, sizeof(sValue));
    
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
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_nameban <#userid|name>");
		return Plugin_Handled;
	}
	
	char arg1[MAX_BUFFER_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	int target = FindTarget(client, arg1, false, false);
	if (target == -1) return Plugin_Handled;
	
	if (isPlayerNameBanned[target])
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} That player has already been name banned. Use sm_nameunban to unban them.");
		return Plugin_Handled;
	}
	
	if (CommandExists("sm_rename"))
	{
		int userid = GetClientUserId(target);
		ServerCommand("sm_rename #%d IHaveANameNow#%d", userid, userid);
		if (CommandExists("sm_namelock"))
			ServerCommand("sm_namelock #%d 1", userid);
		SetClientCookie(target, nameBannedCookie, "1");
  	}
  	
  	LogAction(client, target, "%N banned %N's name!", client, target);
  	return Plugin_Handled;
}

public Action CommandNameUnban(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_nameunban <#userid|name>");
		return Plugin_Handled;
	}
	
	char arg1[MAX_BUFFER_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	int target = FindTarget(client, arg1, false, false);
	if (target == -1) return Plugin_Handled;
	
	if (!isPlayerNameBanned[target])
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} That player has not been name banned. Use sm_nameban to ban them.");
		return Plugin_Handled;
	}
	
	if (CommandExists("sm_namelock"))
    {
		int userid = GetClientUserId(target);
		ServerCommand("sm_namelock #%d 0", userid);
		SetClientCookie(target, nameBannedCookie, "0");
		CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Your name has been unlocked, feel free to change it.");
  	}
  	
  	LogAction(client, target, "%N unbanned %N's name!", client, target);
  	return Plugin_Handled;
}

public Action CommandForceRespawn(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_forcerespawn [target]");
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
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Position you are looking at is x = %f, y = %f, z = %f.", end[0], end[1], end[2]);
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
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_changeteam [name] <team: 1/2/3>");
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
	
	if (StringToInt(arg2) < 4 && StringToInt(arg2) > 0)
	{
		Team = StringToInt(arg2);
	} 
	else
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Please choose a team!");
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
	char arg1[MAX_TARGET_LENGTH], arg2[10], mod[32];
	int iHealth;

	GetGameFolderName(mod, sizeof(mod));

	if (args < 2)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_sethealth <#userid|name> <amount>");
		return Plugin_Handled;
	}
	else {
		GetCmdArg(1, arg1, sizeof(arg1));
		GetCmdArg(2, arg2, sizeof(arg2));
		iHealth = StringToInt(arg2);
	}

	if (iHealth < 0) {
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Health must be greater then zero.");
		return Plugin_Handled;
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
		if (StrEqual(mod, "tf", false)) 
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
	char arg1[MAX_BUFFER_LENGTH], playerName[MAX_NAME_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	int target = FindTarget(client, arg1, false, false);
	if (target == -1) return Plugin_Handled;
	GetClientName(target, playerName, sizeof(playerName));
		
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			EmitSoundToClient(i, "vo/demoman_specialcompleted11.mp3");
			EmitSoundToClient(i, "vo/demoman_specialcompleted11.mp3");
			Handle hHudText = CreateHudSynchronizer();
			SetHudTextParams(-1.0, 0.1, 3.0, 255, 0, 0, 255, 1, 1.0, 1.0, 1.0);
			ShowSyncHudText(i, hHudText, "BAMBOOZLED");
			CloseHandle(hHudText);
			LogAction(target, i, "\"%s\" bamboozled \"%L\"!", playerName, i);
		}
	}
	
	CPrintToChatAll("{GREEN}[SM]{DEFAULT} {LIGHTGREEN}%s{DEFAULT} just {RED}B{ORANGE}A{YELLOW}M{GREEN}B{BLUE}O{PURPLE}O{MAGENTA}Z{BLACK}L{WHITE}E{GREEN}D{DEFAULT} {LIGHTGREEN}EVERYONE{DEFAULT}!", playerName);
	CPrintToChatAll("{GREEN}[SM]{DEFAULT} FEEL THE {BLACK}B{BLUE}A{YELLOW}M{GREEN}B{ORANGE}O{PURPLE}O{MAGENTA}Z{RED}L{WHITE}E{DEFAULT}!");
	return Plugin_Handled;
}

public Action CommandMuteNonAdmins(int client, int args)
{
	if (muteNonAdminsEnabled)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Nonadmins are already muted. Use sm_unmutenonadmins to unmute.");
		return Plugin_Handled;
	}
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
	return Plugin_Handled;
}

public Action CommandUnmuteNonAdmins(int client, int args)
{
	if (!muteNonAdminsEnabled)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Nonadmins aren''t muted. Use sm_mutenonadmins to mute.");
		return Plugin_Handled;
	}
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
	return Plugin_Handled;
}

public Action CommandCheckCommandAccess(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_checkcommandaccess <#userid|name> <cmdstring>");
		return Plugin_Handled;
	}
		
	char arg1[MAX_BUFFER_LENGTH], arg2[MAX_BUFFER_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	int target = FindTarget(client, arg1, true);
	if (!IsValidClient(target)) return Plugin_Handled;
	
	AdminId admin = GetUserAdmin(target);
	if (CheckCommandAccess(target, arg2, ADMFLAG_ROOT))
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} {LIGHTGREEN}%N{DEFAULT} has CheckCommandAccess access to {OLIVE}%s{DEFAULT}!", target, arg2);
	else
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} {LIGHTGREEN}%N{DEFAULT} doesn\'t have CheckCommandAccess access to {OLIVE}%s{DEFAULT}!", target, arg2);
	if (CheckAccess(admin, arg2, ADMFLAG_ROOT))
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} {LIGHTGREEN}%N{DEFAULT} has CheckAccess access to {OLIVE}%s{DEFAULT}!", target, arg2);
	else
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} {LIGHTGREEN}%N{DEFAULT} doesn\'t have CheckAccess access to {OLIVE}%s{DEFAULT}!", target, arg2);
	return Plugin_Handled;
}

public Action CommandGetClientInfo(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_getclientinfo <#userid|name> <cmdstring>");
		return Plugin_Handled;
	}
		
	char arg1[MAX_BUFFER_LENGTH], arg2[MAX_BUFFER_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	int target = FindTarget(client, arg1, true);
	if (!IsValidClient(target)) return Plugin_Handled;
	
	char varString[MAX_BUFFER_LENGTH];
	
	if (GetClientInfo(target, arg2, varString, sizeof(varString)))
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} {LIGHTGREEN}%N{DEFAULT}\'s value for {YELLOW}%s{DEFAULT} is {OLIVE}%s{DEFAULT}!", target, arg2, varString);
	else
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Could not get client info of {LIGHTGREEN}%N{DEFAULT}!", target);
	return Plugin_Handled;
}

public Action CommandQueryClientConVar(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_queryclientconvar <#userid|name> <cmdstring>");
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
	switch (result)
	{
		case ConVarQuery_Okay:
			CReplyToCommand(value, "{GREEN}[SM]{DEFAULT} {LIGHTGREEN}%N{DEFAULT}\'s value for {YELLOW}%s{DEFAULT} is {OLIVE}%s{DEFAULT}!", client, cvarName, cvarValue);
		case ConVarQuery_Protected:
			CReplyToCommand(value, "{GREEN}[SM]{DEFAULT} {LIGHTGREEN}%N{DEFAULT}\'s value for {YELLOW}%s{DEFAULT} is {PURPLE}PROTECTED{DEFAULT}!", client, cvarName);
		default:
			CReplyToCommand(value, "{GREEN}[SM]{DEFAULT} Invalid ConVar or ConVar not found for {LIGHTGREEN}%N{DEFAULT}!", client);
	}
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