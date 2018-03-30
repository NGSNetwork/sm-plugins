/**
* TheXeon
* ngs_explosivearrows.sp
*
* Files:
* addons/sourcemod/plugins/ngs_explosivearrows.smx
* cfg/sourcemod/explosivearrows.cfg
*
* Dependencies:
* sourcemod.inc, sdktools.inc, sdkhooks.inc, 
* tf2.inc, tf2_stocks.inc, multicolors.inc, 
* ngsupdater.inc, ngsutils.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <multicolors>
#include <ngsupdater>
#include <ngsutils>

#define zerogsprite "spirites/zerogxplode.spr"

ConVar g_Enabled, g_Dmg, g_Radius, g_Join, g_Type, g_Delay;

float g_pos[3], deathpos[MAXPLAYERS + 1][3];
bool g_bArrowsEnabled[MAXPLAYERS + 1];
bool g_bDisableArrowsOnDeath[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[NGS] Explosive Arrows",
	author = "Tak (Chaosxk) / TheXeon",
	description = "Are your arrows too weak? Buff them up (or add cosmetic 'splosions)!",
	version = "1.0.5",
	url = "http://forums.alliedmods.net/showthread.php?t=203146"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_TF2)
	{
		Format(error, err_max, "This plugin only works for Team Fortress 2");
		return APLRes_Failure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_Enabled = CreateConVar("sm_explarrows_enabled", "1", "Enables/Disables explosive arrows.");
	g_Dmg = CreateConVar("sm_explarrows_damage", "50", "How much damage should the arrows do?");
	g_Radius = CreateConVar("sm_explarrows_radius", "200", "What should the radius of damage be?");
	g_Join = CreateConVar("sm_explarrows_join", "0", "Should explosive arrows be on when joined? Off = 0, Public = 1, Admins = 2");
	g_Type = CreateConVar("sm_explarrows_type", "0", "What type of arrows to explode? (0 - Both, 1 - Huntsman arrows, 2 - Crusader's crossbow bolts");
	g_Delay = CreateConVar("sm_explarrows_delay", "0", "Delay before arrow explodes");

	RegConsoleCmd("sm_explarrowsme", Command_ArrowsMe, "Toggle explosive arrows for yourself.");
	RegConsoleCmd("sm_explosivearrowsme", Command_ArrowsMe, "Toggle explosive arrows for yourself.");
	RegAdminCmd("sm_explarrows", Command_Arrows, ADMFLAG_GENERIC, "Usage: sm_explarrows <client> <Ignore (toggle if no persistent): -1 ; On: 1 ; Off = 0> <Persistent: 1 ; 0>.");
	RegAdminCmd("sm_explosivearrows", Command_Arrows, ADMFLAG_GENERIC, "Usage: sm_explarrows <client> <Ignore (toggle if no persistent): -1 ; On: 1 ; Off = 0> <Persistent: 1 ; 0>.");

	HookEvent("player_death", Player_Death);

	LoadTranslations("common.phrases");
	AutoExecConfig(true, "explosivearrows");
}

public void OnMapStart()
{
	PrecacheModel(zerogsprite, true);
}

public Action Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_Enabled.BoolValue)
		return Plugin_Continue;
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(client))
		return Plugin_Continue;
	GetClientAbsOrigin(client, deathpos[client]);
	if (g_bDisableArrowsOnDeath[client] && g_bArrowsEnabled[client])
	{
		g_bDisableArrowsOnDeath[client] = false;
		g_bArrowsEnabled[client] = false;
		CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Explosive arrows disabled.");
	}
	return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client)
{
	g_bArrowsEnabled[client] = false;
	g_bDisableArrowsOnDeath[client] = false;
	deathpos[client][0] = 0.0;
	deathpos[client][1] = 0.0;
	deathpos[client][2] = 0.0;
	switch (g_Join.IntValue)
	{
		case 2:
		{
			g_bArrowsEnabled[client] = CheckCommandAccess(client, "sm_explarrows_join_access", ADMFLAG_GENERIC, true);
		}
		case 1:
		{
			g_bArrowsEnabled[client] = true;
		}
	}
}
public Action Command_ArrowsMe(int client, int args)
{
	if (!g_Enabled.BoolValue)
		return Plugin_Handled;
	if (!IsValidClient(client))
		return Plugin_Handled;
	g_bArrowsEnabled[client] = !g_bArrowsEnabled[client];
	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You have %s explosive arrows.", g_bArrowsEnabled[client] ? "enabled" : "disabled");
	return Plugin_Handled;
}

public Action Command_Arrows(int client, int args)
{
	if (!g_Enabled.BoolValue)
		return Plugin_Handled;
	char arg1[65], arg2[16], arg3[16];

	if (args < 1)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_explarrows <client> <-1/0/1> <0/1 (persistent)>)");
		return Plugin_Handled;
	}

	GetCmdArg(1, arg1, sizeof(arg1));
	if (args > 1) GetCmdArg(2, arg2, sizeof(arg2));
	if (args > 2) GetCmdArg(3, arg3, sizeof(arg3));
	int buttonVal = StringToInt(arg2);
	bool persistent = view_as<bool>(StringToInt(arg3));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	if ((target_count = ProcessTargetString(
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

	for(int i = 0; i < target_count; i++)
	{
		switch (args)
		{
			case 1:
			{
				g_bArrowsEnabled[target_list[i]] = !g_bArrowsEnabled[target_list[i]];
				CPrintToChat(target_list[i], "{GREEN}[SM]{DEFAULT} Your explosive arrows have been toggled %s.", (g_bArrowsEnabled[target_list[i]]) ? "on" : "off");
			}
			case 2:
			{
				if (buttonVal == -1) 
				{
					g_bArrowsEnabled[target_list[i]] = !g_bArrowsEnabled[target_list[i]];
				}
				else
				{
					g_bArrowsEnabled[target_list[i]] = view_as<bool>(buttonVal);
				}
				CPrintToChat(target_list[i], "{GREEN}[SM]{DEFAULT} Your explosive arrows have been turned %s.", (g_bArrowsEnabled[target_list[i]]) ? "on" : "off");
			}
			case 3:
			{
				if (buttonVal != -1) g_bArrowsEnabled[target_list[i]] = view_as<bool>(buttonVal);
				g_bDisableArrowsOnDeath[target_list[i]] = !persistent;
				CPrintToChat(target_list[i], "{GREEN}[SM]{DEFAULT} Your explosive arrows have been toggled %s%s.", (g_bArrowsEnabled[target_list[i]]) ? "on" : "off", (persistent) ? "" : " and will toggle off on death");
			}
		}
	}
	return Plugin_Handled;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_Enabled.BoolValue)
		return;
	bool arrow = StrEqual(classname, "tf_projectile_arrow");
	bool bolt = StrEqual(classname, "tf_projectile_healing_bolt");
	if (!bolt && !arrow)
		return;
	int type = g_Type.IntValue;
	if (!type || (type == 1 && arrow) || (type == 2 && bolt))
	{
		SDKHook(entity, SDKHook_StartTouchPost, OnEntityTouch);
	}
}

public Action OnEntityTouch(int entity, int other)
{
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	float pos2[3];
	if (!IsValidClient(client))
		return Plugin_Continue;
	if (!g_bArrowsEnabled[client])
		return Plugin_Continue;
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", g_pos);
	if (IsValidClient(other))
		GetClientAbsOrigin(other, pos2);
	bool otherValid = IsValidClient(other);
	DataPack pack;
	CreateDataTimer(g_Delay.FloatValue, Timer_Explode, pack, TIMER_FLAG_NO_MAPCHANGE);
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell((otherValid) ? GetClientUserId(other) : INVALID_ENT_REFERENCE);
	pack.WriteCell((otherValid) ? GetEntProp(other, Prop_Send, "m_iDeaths") : 0);
	pack.WriteFloat(g_pos[0]);
	pack.WriteFloat(g_pos[1]);
	pack.WriteFloat(g_pos[2]);
	pack.WriteFloat(pos2[0]);
	pack.WriteFloat(pos2[1]);
	pack.WriteFloat(pos2[2]);
	return Plugin_Continue;
}

public Action Timer_Explode(Handle timer, DataPack pack)
{
	pack.Reset();
	float pos1[3], pos2[3];
	int client = GetClientOfUserId(pack.ReadCell());
	int victim = GetClientOfUserId(pack.ReadCell());
	int deaths = pack.ReadCell();
	pos1[0] = pack.ReadFloat();
	pos1[1] = pack.ReadFloat();
	pos1[2] = pack.ReadFloat();
	pos2[0] = pack.ReadFloat();
	pos2[1] = pack.ReadFloat();
	pos2[2] = pack.ReadFloat();
	if (IsValidClient(victim, true))
	{
		if (deaths < GetEntProp(victim, Prop_Send, "m_iDeaths"))
		{ 	//should probably use spawncount instead but whatever
			pos2[0] = deathpos[victim][0];
			pos2[1] = deathpos[victim][1];
			pos2[2] = deathpos[victim][2];
		}
		SubtractVectors(pos1, pos2, pos1);	//somebody please doublecheck that this gets relative position correctly. It *should* but I might have negated it accidentally
		GetClientAbsOrigin(victim, pos2);
		AddVectors(pos1, pos2, pos1);
	}
	DoExplosion(client, g_Dmg.IntValue, g_Radius.IntValue, pos1);
}

stock void DoExplosion(int owner, int damage, int radius, float pos[3])
{
	int explode = CreateEntityByName("env_explosion");
	if (!IsValidEntity(explode))
		return;
	DispatchKeyValue(explode, "targetname", "explode");
	DispatchKeyValue(explode, "spawnflags", "2");
	DispatchKeyValue(explode, "rendermode", "5");
	DispatchKeyValue(explode, "fireballsprite", zerogsprite);

	SetEntPropEnt(explode, Prop_Data, "m_hOwnerEntity", owner);
	SetEntProp(explode, Prop_Data, "m_iMagnitude", damage);
	SetEntProp(explode, Prop_Data, "m_iRadiusOverride", radius);

	TeleportEntity(explode, pos, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(explode);
	ActivateEntity(explode);
	AcceptEntityInput(explode, "Explode");
	AcceptEntityInput(explode, "Kill");
}