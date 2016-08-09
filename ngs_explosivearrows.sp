#pragma newdecls required
#pragma semicolon 1

#include <sdktools>
#include <sourcemod>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <morecolors>

#define PLUGIN_VERSION "1.4"
#define spirite "spirites/zerogxplode.spr"

Handle g_Enabled = null;
Handle g_Dmg = null;
Handle g_Radius = null;
Handle g_Join = null;
Handle g_Type = null;
Handle g_Delay = null;

float g_pos[3], deathpos[MAXPLAYERS + 1][3];
bool g_Arrows[MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	char Game[32];
	GetGameFolderName(Game, sizeof(Game));
	if(!StrEqual(Game, "tf")) {
		Format(error, err_max, "This plugin only works for Team Fortress 2");
		return APLRes_Failure;
	}
	return APLRes_Success;
}

public Plugin myinfo = {
	name = "[NGS] Explosive Arrows",
	author = "Tak (Chaosxk) / TheXeon",
	description = "Are your arrows too weak? Buff them up (or add cosmetic 'splosions)!",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=203146"
}

public void OnPluginStart() {
	CreateConVar("explarrows_version", PLUGIN_VERSION, "Version of this plugin", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_Enabled = CreateConVar("sm_explarrows_enabled", "1", "Enables/Disables explosive arrows.");
	g_Dmg = CreateConVar("sm_explarrows_damage", "50", "How much damage should the arrows do?");
	g_Radius = CreateConVar("sm_explarrows_radius", "200", "What should the radius of damage be?");
	g_Join = CreateConVar("sm_explarrows_join", "0", "Should explosive arrows be on when joined? Off = 0, Public = 1, Admins = 2");
	g_Type = CreateConVar("sm_explarrows_type", "0", "What type of arrows to explode? (0 - Both, 1 - Huntsman arrows, 2 - Crusader's crossbow bolts");
	g_Delay = CreateConVar("sm_explarrows_delay", "0", "Delay before arrow explodes");

	RegConsoleCmd("sm_explarrowsme", Command_ArrowsMe, "Turn on explosive arrows for yourself.");
	RegConsoleCmd("sm_explosivearrowsme", Command_ArrowsMe, "Turn on explosive arrows for yourself.");
	RegAdminCmd("sm_explarrows", Command_Arrows, ADMFLAG_GENERIC, "Usage: sm_explarrows <client> <On: 1 ; Off = 0>.");
	RegAdminCmd("sm_explosivearrows", Command_Arrows, ADMFLAG_GENERIC, "Usage: sm_explarrows <client> <On: 1 ; Off = 0>.");

	HookEvent("player_death", Player_Death);

	LoadTranslations("common.phrases");
	AutoExecConfig(true, "explosivearrows");
}

public void OnMapStart() {
	PrecacheModel(spirite, true);
}

public Action Player_Death(Handle event, const char[] name, bool dontBroadcast) {
	if (!g_Enabled)
		return;
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client))
		return;
	GetClientAbsOrigin(client, deathpos[client]);
}
public void OnClientPostAdminCheck(int client) {
	g_Arrows[client] = false;
	deathpos[client][0] = 0.0;
	deathpos[client][1] = 0.0;
	deathpos[client][2] = 0.0;
	int joincvar = GetConVarInt(g_Join);
	switch (joincvar) {
		case 2: {
			g_Arrows[client] = CheckCommandAccess(client, "sm_explarrows_join_access", ADMFLAG_GENERIC, true);
		}
		case 1: {
			g_Arrows[client] = true;
		}
	}
}
public Action Command_ArrowsMe(int client, int args) {
	if(!g_Enabled)
		return Plugin_Handled;
	if(!IsValidClient(client))
		return Plugin_Handled;
	g_Arrows[client] = !g_Arrows[client];
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You have %s explosive arrows.", g_Arrows[client] ? "enabled" : "disabled");
	return Plugin_Handled;
}

public Action Command_Arrows(int client, int args) {
	if(!g_Enabled)
		return Plugin_Handled;
	if(!IsValidClient(client))
		return Plugin_Handled;
	char arg1[65], arg2[65];

	if(args < 1) {
		CReplyToCommand(client, "{DEFAULT}Usage: sm_explarrows <client> (<On: 1 ; Off = 0>)");
		return Plugin_Handled;
	}

	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	bool button = !!StringToInt(arg2);

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	if((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for(int i = 0; i < target_count; i++) {
		if (args == 1)
			g_Arrows[target_list[i]] = !g_Arrows[target_list[i]];
		else
			g_Arrows[target_list[i]] = button;
	}
	if (tn_is_ml)
		CShowActivity2(client, "{GREEN}[SM]{DEFAULT} ", "{LIGHTGREEN}%N{DEFAULT} has %s {LIGHTGREEN}%t's{DEFAULT} explosive arrows.", client, g_Arrows[client] ? "enabled" : "disabled", target_name);
	else
		CShowActivity2(client, "{GREEN}[SM]{DEFAULT} ", "{LIGHTGREEN}%N{DEFAULT} has %s {LIGHTGREEN}%s's{DEFAULT} explosive arrows.", client, g_Arrows[client] ? "enabled" : "disabled", target_name);
	return Plugin_Handled;
}

public void OnEntityCreated(int entity, const char[] classname) {
	if(!g_Enabled)
		return;
	bool arrow = StrEqual(classname, "tf_projectile_arrow");
	bool bolt = StrEqual(classname, "tf_projectile_healing_bolt");
	if (!bolt && !arrow)
		return;
	int type = GetConVarInt(g_Type);
	if (!type || (type == 1 && arrow) || (type == 2 && bolt)) {
		SDKHook(entity, SDKHook_StartTouchPost, OnEntityTouch);
	}
}

public Action OnEntityTouch(int entity, int other) {
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	float pos2[3];
	if(!IsValidClient(client))
		return Plugin_Continue;
	if(!g_Arrows[client])
		return Plugin_Continue;
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", g_pos);
	if (other > 0 && other <= MaxClients)
		GetClientAbsOrigin(other, pos2);
	Handle pack;
	CreateDataTimer(GetConVarFloat(g_Delay), Timer_Explode, pack, TIMER_FLAG_NO_MAPCHANGE);
	WritePackCell(pack, GetClientUserId(client));
	WritePackCell(pack, (other > 0 && other <= MaxClients) ? GetClientUserId(other) : INVALID_ENT_REFERENCE);
	WritePackCell(pack, (other > 0 && other <= MaxClients) ? GetEntProp(other, Prop_Send, "m_iDeaths") : 0);
	WritePackFloat(pack, g_pos[0]);
	WritePackFloat(pack, g_pos[1]);
	WritePackFloat(pack, g_pos[2]);
	WritePackFloat(pack, pos2[0]);
	WritePackFloat(pack, pos2[1]);
	WritePackFloat(pack, pos2[2]);
	return Plugin_Continue;
}
public Action Timer_Explode(Handle timer, Handle pack) {
	ResetPack(pack);
	float pos1[3], pos2[3];
	int client = GetClientOfUserId(ReadPackCell(pack));
	int victim = GetClientOfUserId(ReadPackCell(pack));
	int deaths = ReadPackCell(pack);
	pos1[0] = ReadPackFloat(pack);
	pos1[1] = ReadPackFloat(pack);
	pos1[2] = ReadPackFloat(pack);
	pos2[0] = ReadPackFloat(pack);
	pos2[1] = ReadPackFloat(pack);
	pos2[2] = ReadPackFloat(pack);
	if (victim > 0 && victim <= MaxClients && IsClientInGame(victim) && IsPlayerAlive(victim)) {
		if (deaths < GetEntProp(victim, Prop_Send, "m_iDeaths")) { 	//should probably use spawncount instead but whatever
			pos2[0] = deathpos[victim][0];
			pos2[1] = deathpos[victim][1];
			pos2[2] = deathpos[victim][2];
		}
		SubtractVectors(pos1, pos2, pos1);	//somebody please doublecheck that this gets relative position correctly. It *should* but I might have negated it accidentally
		GetClientAbsOrigin(victim, pos2);
		AddVectors(pos1, pos2, pos1);
	}
	DoExplosion(client, GetConVarInt(g_Dmg), GetConVarInt(g_Radius), pos1);
}
stock void DoExplosion(int owner, int damage, int radius, float pos[3]) {
	int explode = CreateEntityByName("env_explosion");
	if(!IsValidEntity(explode))
		return;
	DispatchKeyValue(explode, "targetname", "explode");
	DispatchKeyValue(explode, "spawnflags", "2");
	DispatchKeyValue(explode, "rendermode", "5");
	DispatchKeyValue(explode, "fireballsprite", spirite);

	SetEntPropEnt(explode, Prop_Data, "m_hOwnerEntity", owner);
	SetEntProp(explode, Prop_Data, "m_iMagnitude", damage);
	SetEntProp(explode, Prop_Data, "m_iRadiusOverride", radius);

	TeleportEntity(explode, pos, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(explode);
	ActivateEntity(explode);
	AcceptEntityInput(explode, "Explode");
	AcceptEntityInput(explode, "Kill");
}
stock bool IsValidClient(int iClient, bool bReplay = true) {
	if(iClient <= 0 || iClient > MaxClients)
		return false;
	if(!IsClientInGame(iClient))
		return false;
	if(bReplay && (IsClientSourceTV(iClient) || IsClientReplay(iClient)))
		return false;
	return true;
}