#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>
#include <tf2items>
#include <betherobot>
#include <tf2attributes>

#define PLUGIN_VERSION "1.3"

public Plugin myinfo = {
	name = "Be the Robot: Sentry Buster",
	author = "MasterOfTheXP",
	description = "This in a nutshell -> http://gamebanana.com/tf2/sounds/17716",
	version = PLUGIN_VERSION,
	url = "http://mstr.ca/"
}

enum BusterStatus {
	BusterStatus_Human = 0, // Client is human (as far as Be the Buster is concerned.)
	BusterStatus_WantsToBeBuster, // Client wants to be a Sentry Buster, but can't because of defined rules.
	BusterStatus_Buster // SENTRY BUSTERRRRR
}

BusterStatus Status[MAXPLAYERS + 1];
bool AboutToExplode[MAXPLAYERS + 1];
float LastBusterTime; // Not for each player.

ConVar cvarFootsteps, cvarWearables, cvarBusterJump, cvarBusterAnnounce, cvarWearablesKill;
ConVar cvarFF, cvarBossScale;

public void OnPluginStart()
{
	RegConsoleCmd("sm_sentrybuster", Command_bethebuster);
	RegConsoleCmd("sm_buster", Command_bethebuster);
	
	AddCommandListener(Listener_taunt, "taunt");
	AddCommandListener(Listener_taunt, "+taunt");
	if (CommandExists("sm_giveweapon"))
	{
		AddCommandListener(Listener_giveweapon, "sm_giveweapon");
		AddCommandListener(Listener_giveweapon, "sm_givew");
		AddCommandListener(Listener_giveweapon, "sm_giveweapon_ex");
		AddCommandListener(Listener_giveweapon, "sm_givew_ex");
	}
	if (CommandExists("sm_resizereset"))
	{
		AddCommandListener(Listener_giveweapon, "sm_resizereset");
		AddCommandListener(Listener_giveweapon, "sm_resize");
	}
	
	AddNormalSoundHook(SoundHook);
	HookEvent("post_inventory_application", Event_Inventory, EventHookMode_Post);
	HookEvent("player_death", Event_Death, EventHookMode_Post);
	HookEvent("player_changeclass", Event_ChangeClass, EventHookMode_Post);
	
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");
	
	
	cvarBusterJump = CreateConVar("sm_betherobot_buster_jump","0","The height of Sentry Buster jumps. 0 makes it so they can't jump, 1 is normal, 2 is two times higher than normal...", FCVAR_NONE, true, 0.0);
	cvarBusterAnnounce = CreateConVar("sm_betherobot_buster_announce","0","Who should the Administrator warn about a Sentry Buster's presence? 1=Enemy team, 2=Your team. Default is 0 (no one)", FCVAR_NONE, true, 0.0);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		SDKHook(i, SDKHook_WeaponCanUse, OnWeaponCanUse);
	}
	for (int i = MaxClients + 1; i <= 2048; i++)
	{
		if (!IsValidEntity(i)) continue;
		char cls[10];
		GetEntityClassname(i, cls, sizeof(cls));
		if (StrContains(cls, "obj_sen", false) == 0) SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public void OnMapStart()
{
	CreateTimer(0.5, Timer_HalfSecond, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd()
{
	for (int i = 1; i <= MaxClients; i++)
		Status[i] = BusterStatus_Human;
}
	
public void OnConfigsExecuted()
{
	cvarFootsteps = FindConVar("sm_betherobot_footsteps");
	cvarWearables = FindConVar("sm_betherobot_wearables");
	cvarWearablesKill = FindConVar("sm_betherobot_wearables_kill");
	
	cvarFF = FindConVar("mp_friendlyfire");
	cvarBossScale = FindConVar("tf_mvm_miniboss_scale");
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse); 
}

public void OnClientDisconnect(int client)
{
	Status[client] = BusterStatus_Human;
	AboutToExplode[client] = false;
}

public Action Command_bethebuster(int client, int args)
{
	if (!IsValidClient(client) && args < 1)
	{
		char arg0[20];
		GetCmdArg(0, arg0, sizeof(arg0));
		ReplyToCommand(client, "[SM] Usage: %s <name|#userid> [1/0] - Transforms a player into a Sentry Buster. Beep beep.", arg0);
		return Plugin_Handled;
	}
	
	if (!CheckCommandAccess(client, "bethebuster", ADMFLAG_ROOT))
	{
		ReplyToCommand(client, "[SM] %t.", "No Access");
		return Plugin_Handled;
	}
	
	char arg1[MAX_TARGET_LENGTH], arg2[4];
	bool toggle = view_as<bool>(2);
	if (args < 1 || !CheckCommandAccess(client, "bethebuster_admin", ADMFLAG_ROOT))
	{
		if (BeTheRobot_GetRobotStatus(client)) BeTheRobot_SetRobot(client, false);
		if (!ToggleBuster(client))
			ReplyToCommand(client, "[SM] You can't be a Sentry Buster right now, but you'll be one as soon as you can.");
		return Plugin_Handled;
	}
	else
	{
		GetCmdArg(1, arg1, sizeof(arg1));
		if (args > 1)
		{
			GetCmdArg(2, arg2, sizeof(arg2));
			toggle = view_as<bool>(StringToInt(arg2));
		}
	}
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	if ((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE|args < 1 ? COMMAND_FILTER_NO_IMMUNITY : 0, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	for (int i = 0; i < target_count; i++)
		ToggleBuster(target_list[i], toggle);
	if (toggle != false && toggle != true) ShowActivity2(client, "[SM] ", "Toggled Sentry Buster on %s.", target_name);
	else ShowActivity2(client, "[SM] ", "%sabled Sentry Buster on %s.", toggle ? "En" : "Dis", target_name);
	return Plugin_Handled;
}

stock bool ToggleBuster(int client, bool toggle=view_as<bool>(2), bool wasBuster=false)
{
	if (toggle) BeTheRobot_SetRobot(client, false);
	if (Status[client] == BusterStatus_WantsToBeBuster && toggle != false && toggle != true) return true;
	if (!Status[client] && !toggle) return true;
	if (Status[client] == BusterStatus_Buster && toggle && BeTheRobot_CheckRules(client) && !wasBuster) return true;
	if (Status[client] != BusterStatus_Buster)
	{
		if (!BeTheRobot_CheckRules(client))
		{
			Status[client] = BusterStatus_WantsToBeBuster;
			return false;
		}
	}
	if (toggle || (toggle == view_as<bool>(2) && Status[client] == BusterStatus_Human))
	{
		TF2_RemovePlayerDisguise(client);
		TF2_RemoveAllWeapons(client);
		TF2_SetPlayerClass(client, TFClass_DemoMan);
		TF2_RemoveAllWeapons(client);
		char atts[128];
		Format(atts, sizeof(atts), "138 ; 0.0 ; "); // -100% damage to players (0)
		Format(atts, sizeof(atts), "%s137 ; 38.461540", atts); // +3746% damage to buildings (2500)
		int wepEnt = SpawnWeapon(client, "tf_weapon_stickbomb", 307, 10, 6, atts);
		if (IsValidEntity(wepEnt)) SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", wepEnt);
		SetEntProp(wepEnt, Prop_Send, "m_iDetonated", 1);
		SetEntityHealth(client, 2500);
		SetVariantString("models/bots/demo/bot_sentry_buster.mdl");
		AcceptEntityInput(client, "SetCustomModel");
		SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
		SetEntPropFloat(client, Prop_Send, "m_flModelScale", cvarBossScale.FloatValue);
		
		// Sound tomfoolery
		if (!wasBuster)
		{
			EmitSoundToAll("mvm/sentrybuster/mvm_sentrybuster_intro.wav", client);
			EmitSoundToAll("mvm/sentrybuster/mvm_sentrybuster_loop.wav", client);
			CreateTimer(GetRandomFloat(5.0, 6.0), Timer_PlayBusterIntro, GetClientUserId(client));
			
			char AnnouncerSnd[PLATFORM_MAX_PATH];
			int BusterAnnounce = cvarBusterAnnounce.IntValue, team = GetClientTeam(client);
			if ((LastBusterTime + 360.0) > GetTickedTime()) Format(AnnouncerSnd, sizeof(AnnouncerSnd), "vo/mvm_sentry_buster_alerts0%i.wav", GetRandomInt(2,3));
			else
			{
				int rand = GetRandomInt(3,7);
				if (rand == 3) rand = 1;
				Format(AnnouncerSnd, sizeof(AnnouncerSnd), "vo/mvm_sentry_buster_alerts0%i.wav", rand);
			}
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!BusterAnnounce) break;
				if (!IsValidClient(i)) continue;
				int zteam = GetClientTeam(i);
				if (team == zteam && !(BusterAnnounce & 2)) continue;
				if (team != zteam && !(BusterAnnounce & 1)) continue;
				EmitSoundToClient(i, AnnouncerSnd);
			}
			LastBusterTime = GetTickedTime();
		}
		
		Status[client] = BusterStatus_Buster;
		SetWearableAlpha(client, 0);
		
		TF2Attrib_SetByDefIndex(client, 26, 2325.0);
		TF2Attrib_SetByDefIndex(client, 107, 2.0);
		TF2Attrib_SetByDefIndex(client, 252, 0.5);
		TF2Attrib_SetByDefIndex(client, 329, 0.5);
		TF2Attrib_SetByDefIndex(client, 402, 1.0);
		TF2Attrib_SetByDefIndex(client, 326, cvarBusterJump.FloatValue);
		TF2Attrib_SetByDefIndex(client, 275, 1.0);
		if (cvarFootsteps.BoolValue) TF2Attrib_SetByDefIndex(client, 330, 7.0);
	}
	else if (!wasBuster && (!toggle || (toggle == view_as<bool>(2) && Status[client] == BusterStatus_Buster)))
	{
		SetVariantString("");
		AcceptEntityInput(client, "SetCustomModel");
		Status[client] = BusterStatus_Human;
		if (IsPlayerAlive(client)) TF2_RegeneratePlayer(client);
		StopSound(client, SNDCHAN_AUTO, "mvm/sentrybuster/mvm_sentrybuster_loop.wav");
		SetEntPropFloat(client, Prop_Send, "m_flModelScale", 1.0);
		AboutToExplode[client] = false;
		SetWearableAlpha(client, 255);
		
		TF2Attrib_RemoveByDefIndex(client, 26);
		TF2Attrib_RemoveByDefIndex(client, 107);
		TF2Attrib_RemoveByDefIndex(client, 252);
		TF2Attrib_RemoveByDefIndex(client, 329);
		TF2Attrib_RemoveByDefIndex(client, 402);
		TF2Attrib_RemoveByDefIndex(client, 326);
		TF2Attrib_RemoveByDefIndex(client, 275);
		if (cvarFootsteps.BoolValue) TF2Attrib_RemoveByDefIndex(client, 330);
	}
	return true;
}

public Action Listener_taunt(int client, const char[] command, int args)
{
	if (Status[client] == BusterStatus_Buster)
	{
		if (AboutToExplode[client]) return Plugin_Continue;
		if (GetEntProp(client, Prop_Send, "m_hGroundEntity") == -1) return Plugin_Continue;
		GetReadyToExplode(client);
	}
	return Plugin_Continue;
}

public Action Listener_giveweapon(int client, char[] command, int args)
{
	if (client == 0 && args > 0)
	{
		char arg1[32];
		GetCmdArg(1, arg1, sizeof(arg1));
		int target = FindTarget(client, arg1);
		if (!IsValidClient(target)) return Plugin_Handled;
		if (Status[target] == BusterStatus_Buster)
		{
			ToggleBuster(target, false);
			SetEntityHealth(target, 150);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action Event_Inventory(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	CreateTimer(0.3, OnRespawnBuster, userid);
}

public Action OnRespawnBuster(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsValidClient(client) || !IsPlayerAlive(client)) return;
	if (Status[client] == BusterStatus_WantsToBeBuster)
	{
		TF2_RemoveAllWeapons(client);
		ToggleBuster(client, true);
	}
	else if (Status[client] == BusterStatus_Buster)
	{
		TF2_RemoveAllWeapons(client);
		ToggleBuster(client, true, true);
	}
}

public Action Event_ChangeClass(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (Status[client] == BusterStatus_WantsToBeBuster)
	{
		ToggleBuster(client, true);
	}
	else if (Status[client] == BusterStatus_Buster)
	{
		ToggleBuster(client, true, true); // patchiest patch
		ToggleBuster(client, true, true);
	}
}

public Action Event_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER) return;
	if (Status[client] == BusterStatus_Buster)
	{
		StopSound(client, SNDCHAN_AUTO, "mvm/sentrybuster/mvm_sentrybuster_loop.wav");
		CreateTimer(0.0, Timer_UnBuster, GetClientUserId(client)); // If you do it too soon, you'll hear a Demoman pain sound :3 Doing it on the next frame seems to be fine.
	}
	
	return;
}

public Action Timer_HalfSecond(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i)) continue;
		if (Status[i] == BusterStatus_WantsToBeBuster) ToggleBuster(i, true);
	}
}

public Action Timer_PlayBusterIntro(Handle timer, any uid)
{
	int client = GetClientOfUserId(uid);
	if (!IsValidClient(client)) return;
	if (Status[client] != BusterStatus_Buster) return;
	if (!IsPlayerAlive(client)) return;
	if (!AboutToExplode[client]) return;
	EmitSoundToAll("mvm/sentrybuster/mvm_sentrybuster_intro.wav", client);
	CreateTimer(GetRandomFloat(5.0, 6.0), Timer_PlayBusterIntro, GetClientUserId(client));
}

public Action Timer_RemoveRagdoll(Handle timer, any uid)
{
	int client = GetClientOfUserId(uid);
	if (!IsValidClient(client)) return;
	int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if (!IsValidEntity(ragdoll) || ragdoll <= MaxClients) return;
	AcceptEntityInput(ragdoll, "Kill");
}

public Action Timer_UnBuster(Handle timer, any uid)
{
	int client = GetClientOfUserId(uid);
	if (!IsValidClient(client)) return;
	ToggleBuster(client, false);
}

public Action SoundHook(int clients[64], int &numClients, char sound[PLATFORM_MAX_PATH], int &Ent, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	if (volume == 0.0 || volume == 0.9997) return Plugin_Continue;
	if (!IsValidClient(Ent)) return Plugin_Continue;
	int client = Ent;
	if (Status[client] == BusterStatus_Buster)
	{
		if (StrContains(sound, "announcer", false) != -1) return Plugin_Continue;
		if (StrContains(sound, "/mvm", false) != -1 || StrContains(sound, "\\mvm", false) != -1) return Plugin_Continue;
		if (StrContains(sound, "vo/", false) != -1) return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (IsValidClient(victim))
	{
		if (Status[victim] != BusterStatus_Buster || victim == attacker) return Plugin_Continue;
		float dmg = ((damagetype & DMG_CRIT) ? damage*3 : damage) + 10.0; // +10 to attempt to account for damage rampup.
		if (AboutToExplode[victim])
		{
			damage = 0.0;
			return Plugin_Changed;
		}
		else if (dmg > GetClientHealth(victim))
		{
			damage = 0.0;
			GetReadyToExplode(victim);
			FakeClientCommand(victim, "taunt");
			return Plugin_Changed;
		}
	}
	else if (IsValidClient(attacker)) // This is a Sentry.
	{
		if (Status[attacker] == BusterStatus_Buster && !AboutToExplode[attacker])
		{
			damage = 0.0;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public Action OnWeaponCanUse(int client, int weapon)  
{
	if (Status[client] == BusterStatus_Buster)
	{
		ToggleBuster(client, false);
		SetEntityHealth(client, 150);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}  

public void OnEntityCreated(int Ent, const char[] cls)
{
	if (GetGameTime() < 0.5) return;
	if (Ent < MaxClients || Ent > 2048) return;
	if (StrContains(cls, "obj_sen", false) == 0)
		SDKHook(Ent, SDKHook_Spawn, OnSentrySpawned);
}

public Action OnSentrySpawned(int Ent)
{
	SDKHook(Ent, SDKHook_OnTakeDamage, OnTakeDamage);
}

stock void GetReadyToExplode(int client)
{
	EmitSoundToAll("mvm/sentrybuster/mvm_sentrybuster_spin.wav", client);
	StopSound(client, SNDCHAN_AUTO, "mvm/sentrybuster/mvm_sentrybuster_loop.wav");
	CreateTimer(2.0, Bewm, GetClientUserId(client));
	AboutToExplode[client] = true;
}

public Action Bewm(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsValidClient(client)) return Plugin_Handled;
	if (!IsPlayerAlive(client)) return Plugin_Handled;
	AboutToExplode[client] = false;
	int explosion = CreateEntityByName("env_explosion");
	float clientPos[3];
	GetClientAbsOrigin(client, clientPos);
	if (explosion)
	{
		DispatchSpawn(explosion);
		TeleportEntity(explosion, clientPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(explosion, "Explode", -1, -1, 0);
		RemoveEdict(explosion);
	}
	bool FF = cvarFF.BoolValue;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i)) continue;
		if (!IsPlayerAlive(i)) continue;
		if (GetClientTeam(i) == GetClientTeam(client) && !FF) continue;
		float zPos[3];
		GetClientAbsOrigin(i, zPos);
		float Dist = GetVectorDistance(clientPos, zPos);
		if (Dist > 300.0) continue;
		DoDamage(client, i, 2500);
	}
	for (int i = MaxClients + 1; i <= 2048; i++)
	{
		if (!IsValidEntity(i)) continue;
		char cls[20];
		GetEntityClassname(i, cls, sizeof(cls));
		if (!StrEqual(cls, "obj_sentrygun", false) &&
		!StrEqual(cls, "obj_dispenser", false) &&
		!StrEqual(cls, "obj_teleporter", false)) continue;
		float zPos[3];
		GetEntPropVector(i, Prop_Send, "m_vecOrigin", zPos);
		float Dist = GetVectorDistance(clientPos, zPos);
		if (Dist > 300.0) continue;
		SetVariantInt(2500);
		AcceptEntityInput(i, "RemoveHealth");
	}
	EmitSoundToAll("mvm/sentrybuster/mvm_sentrybuster_explode.wav", client);
	AttachParticle(client, "fluidSmokeExpl_ring_mvm");
	DoDamage(client, client, 2500);
	FakeClientCommand(client, "explode");
	CreateTimer(0.0, Timer_RemoveRagdoll, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}

stock int SpawnWeapon(int client, char[] name, int itemIndex, int level, int qual, char[] att) // from VS Saxton Hale Mode.
{
	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, itemIndex);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);
	char atts[32][32];
	int count = ExplodeString(att, " ; ", atts, 32, 32);
	if (count > 0)
	{
		TF2Items_SetNumAttributes(hWeapon, count/2);
		int j = 0;
		for (int i = 0; i < count; i += 2)
		{
			TF2Items_SetAttribute(hWeapon, j, StringToInt(atts[i]), StringToFloat(atts[i + 1]));
			j++;
		}
	}
	else
		TF2Items_SetNumAttributes(hWeapon, 0);
	if (hWeapon == INVALID_HANDLE)
	return -1;
	int entity = TF2Items_GiveNamedItem(client, hWeapon);
	CloseHandle(hWeapon);
	EquipPlayerWeapon(client, entity);
	return entity;
}

stock void DoDamage(int client, int target, int amount) // from Goomba Stomp.
{
	int pointHurt = CreateEntityByName("point_hurt");
	if (pointHurt)
	{
		DispatchKeyValue(target, "targetname", "explodeme");
		DispatchKeyValue(pointHurt, "DamageTarget", "explodeme");
		char dmg[15];
		Format(dmg, 15, "%i", amount);
		DispatchKeyValue(pointHurt, "Damage", dmg);
		DispatchKeyValue(pointHurt, "DamageType", "0");

		DispatchSpawn(pointHurt);
		AcceptEntityInput(pointHurt, "Hurt", client);
		DispatchKeyValue(pointHurt, "classname", "point_hurt");
		DispatchKeyValue(target, "targetname", "");
		RemoveEdict(pointHurt);
	}
}

stock bool AttachParticle(int Ent, char[] particleType, bool cache = false) // from L4D Achievement Trophy
{
	int particle = CreateEntityByName("info_particle_system");
	if (!IsValidEdict(particle)) return false;
	char tName[128];
	float f_pos[3];
	if (cache) f_pos[2] -= 3000;
	else
	{
		GetEntPropVector(Ent, Prop_Send, "m_vecOrigin", f_pos);
		f_pos[2] += 60;
	}
	TeleportEntity(particle, f_pos, NULL_VECTOR, NULL_VECTOR);
	Format(tName, sizeof(tName), "target%i", Ent);
	DispatchKeyValue(Ent, "targetname", tName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(tName);
	AcceptEntityInput(particle, "SetParent", particle, particle, 0);
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	CreateTimer(10.0, DeleteParticle, particle);
	return true;
}

public Action DeleteParticle(Handle timer, any Ent)
{
	if (!IsValidEntity(Ent)) return;
	char cls[25];
	GetEdictClassname(Ent, cls, sizeof(cls));
	if (StrEqual(cls, "info_particle_system", false)) AcceptEntityInput(Ent, "Kill");
	return;
}

stock int SetWearableAlpha(int client, int alpha, bool override = false)
{
	if (cvarWearables.BoolValue && !override) return 0;
	int count;
	for (int z = MaxClients + 1; z <= 2048; z++)
	{
		if (!IsValidEntity(z)) continue;
		char cls[35];
		GetEntityClassname(z, cls, sizeof(cls));
		if (!StrEqual(cls, "tf_wearable") && !StrEqual(cls, "tf_powerup_bottle")) continue;
		if (client != GetEntPropEnt(z, Prop_Send, "m_hOwnerEntity")) continue;
		if (!GetConVarBool(cvarWearablesKill))
		{
			SetEntityRenderMode(z, RENDER_TRANSCOLOR);
			SetEntityRenderColor(z, 255, 255, 255, alpha);
		}
		else if (alpha == 0) AcceptEntityInput(z, "Kill");
		count++;
	}
	return count;
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
