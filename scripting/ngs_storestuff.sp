#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <morecolors>
#include <clientprefs>
#include <store>

#define PLUGIN_VERSION  "1.0.1"

public Plugin myinfo = {
	name = "[NGS] Store Additions",
	author = "MasterOfTheXP / TheXeon",
	description = "Spawns bosses and other stuff where needed.",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.net/"
}

ConVar cvarHealth;
ConVar cvarHealthPerPlayer;
ConVar cvarHealthPerLevel;
ConVar host_timescale;

Handle sm_timewarp_cooldown;

int g_spawn_count;
int itemsTradedToday[MAXPLAYERS + 1];
float g_player_spawns[100][3];
float current_timescale;
float g_lastwarp;

bool time_warped = false;
float c_timewarp_cooldown;

int SpawnCooldown;

public void OnPluginStart()
{
	RegAdminCmd("sm_spawnmonoculuscenter", CommandSpawnMonoculusCenter, ADMFLAG_SLAY, "Spawns a monoculus in the center of the pokeball!");
	RegAdminCmd("sm_spawnspectralmonoculus", CommandTeamMonoculus, ADMFLAG_SLAY, "Spawns a spectral monoculus where the arg is looking!");
	host_timescale = FindConVar("host_timescale");
	current_timescale = 1.0;
	
	RegAdminCmd("sm_warptime", Command_warpTime, ADMFLAG_RCON);
	sm_timewarp_cooldown = CreateConVar( "sm_timewarp_cooldown", "180", "The serverwide cooldown for the timewarp item.", 0 );
	
	HookConVarChange( sm_timewarp_cooldown, OnConVarChanged );
	LoadTranslations("store.phrases");
	PrecacheMonoculus();
	findSpawnPoints();
	HookEvent("item_found", EventItemFound, EventHookMode_Post);
}

public void OnMapStart()
{
	PrecacheMonoculus();
	findSpawnPoints();
	SetConVarFloat( host_timescale, 1.0 );
	g_lastwarp = -c_timewarp_cooldown;
	
	PrecacheSound("ui/halloween_loot_spawn.wav", true);
	PrecacheSound("ui/halloween_loot_found.wav", true);
}

public void OnConfigsExecuted()
{
	cvarHealth = FindConVar("tf_eyeball_boss_health_base");
	cvarHealthPerPlayer = FindConVar("tf_eyeball_boss_health_per_player");
	cvarHealthPerLevel = FindConVar("tf_eyeball_boss_health_per_level");
}

public void OnConVarChanged( ConVar cvar, const char[] oldval, const char[] newval )
{
	c_timewarp_cooldown = GetConVarFloat( sm_timewarp_cooldown );
}

public Action CommandSpawnMonoculusCenter(int client, int args)
{
	if (args > 0)
	{
		char arg1[32], playerName[MAX_NAME_LENGTH];
		GetCmdArg(1, arg1, sizeof(arg1));
		
		int target = FindTarget(client, arg1, false, false);
		if (target == -1) return Plugin_Handled;
		int currentTime = GetTime();
		if (currentTime - SpawnCooldown < 180)
	    {
	   		CPrintToChat(target, "%tYou must wait {PURPLE}%d{DEFAULT} seconds to spawn this.", "Store Tag Colored", 180 - (currentTime - SpawnCooldown));
	   		return Plugin_Handled;
	  	}
	
		SpawnCooldown = currentTime;
		GetClientName(target, playerName, sizeof(playerName));
		CPrintToChatAll("%t{OLIVE}%s{DEFAULT} spawned in {PURPLE}MONOCULUS{DEFAULT}!", "Store Tag Colored", playerName);
	}
	
	int BaseHealth = GetConVarInt(cvarHealth), HealthPerPlayer = GetConVarInt(cvarHealthPerPlayer), HealthPerLevel = GetConVarInt(cvarHealthPerLevel);
	SetConVarInt(cvarHealth, 4200), SetConVarInt(cvarHealthPerPlayer, 300), SetConVarInt(cvarHealthPerLevel, 2000);
	int Ent = CreateEntityByName("eyeball_boss");
	SetEntProp(Ent, Prop_Data, "m_iTeamNum", 5);
	SetEntProp(Ent, Prop_Send, "m_CollisionGroup", 2);
	float monoculusLocation[3] = {-769.465576, -1130.268311, 646.594238};
	TeleportEntity(Ent, monoculusLocation, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(Ent);
	SetConVarInt(cvarHealth, BaseHealth), SetConVarInt(cvarHealthPerPlayer, HealthPerPlayer), SetConVarInt(cvarHealthPerLevel, HealthPerLevel);
	return Plugin_Handled;
}

public Action CommandTeamMonoculus(int client, int args)
{
	if (args < 1) return Plugin_Handled;
	
	char arg1[MAX_BUFFER_LENGTH], playerName[MAX_NAME_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	int target = FindTarget(client, arg1, false, false);
	if (target == -1) return Plugin_Handled;
	
	int BaseHealth = GetConVarInt(cvarHealth), HealthPerPlayer = GetConVarInt(cvarHealthPerPlayer), HealthPerLevel = GetConVarInt(cvarHealthPerLevel);
	SetConVarInt(cvarHealth, 4200), SetConVarInt(cvarHealthPerPlayer, 300), SetConVarInt(cvarHealthPerLevel, 2000);
	int Ent = CreateEntityByName("eyeball_boss");
	SetEntProp(Ent, Prop_Data, "m_iTeamNum", view_as<int>(GetClientTeam(target)));
	SetEntProp(Ent, Prop_Send, "m_CollisionGroup", 2);
	
	float start[3], angle[3], end[3]; 
	GetClientEyePosition(target, start); 
	GetClientEyeAngles(target, angle); 
	TR_TraceRayFilter(start, angle, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer, target); 
	if (TR_DidHit(INVALID_HANDLE)) 
	{ 
		TR_GetEndPosition(end, INVALID_HANDLE); 
	}
	if (NearSpawn(end))
	{
		CPrintToChat(target, "%tSorry, you can't spawn this near spawns.", "Store Tag Colored");
		return Plugin_Handled;
	}
	
	GetClientName(target, playerName, sizeof(playerName));
	if (GetClientTeam(target) == view_as<int>(TFTeam_Blue)) CPrintToChatAll("%t{OLIVE}%s{DEFAULT} spawned in {BLUE}SPECTRAL MONOCULUS{DEFAULT}!", "Store Tag Colored", playerName);
	else CPrintToChatAll("%t{OLIVE}%s{DEFAULT} spawned in {RED}SPECTRAL MONOCULUS{DEFAULT}!", "Store Tag Colored", playerName);
	
	end[2] += 50;
	TeleportEntity(Ent, end, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(Ent);
	EmitSoundToAll("ui/halloween_boss_summoned_fx.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_HOME);
	SetConVarInt(cvarHealth, BaseHealth), SetConVarInt(cvarHealthPerPlayer, HealthPerPlayer), SetConVarInt(cvarHealthPerLevel, HealthPerLevel);
	return Plugin_Handled;
}

public void EventItemFound(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("player");
	int accountID = GetSteamAccountID(client);
	int method = event.GetInt("method");
	if (itemsTradedToday[client] < 5 && method == 2)
	{
		Store_GiveCredits(accountID, 100);
		itemsTradedToday[client]++;
		CPrintToChat(client, "%tCongrats, you were awarded {PURPLE}100{DEFAULT} credits for trading an item today. You can get %d more credits today.", "Store Tag Colored", (500 - (itemsTradedToday[client] * 100)));
	}
}

public void OnClientConnected(int client)
{
	itemsTradedToday[client] = 0;
}

public Action Command_warpTime(int client, int args )
{
	if (args < 1) return Plugin_Handled;
	
	char arg1[MAX_BUFFER_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	int target = FindTarget(client, arg1, false, false);
	if (target == -1) return Plugin_Handled;
	
	warpTime(target);
	return Plugin_Handled;
}

bool warpTime(int client)
{

	if( time_warped ) {
		CPrintToChat(client,"%tTime is already warped!", "Store Tag Colored");
		return false;
	}
	
	float time = GetGameTime();
	if( time < g_lastwarp + c_timewarp_cooldown )
	{
		CPrintToChat( client, "%tTime has recently been warped. Please try again in {PURPLE}%d{DEFAULT} seconds.", "Store Tag Colored", RoundToCeil(g_lastwarp + c_timewarp_cooldown - time) );
		return false;
	}
	
	g_lastwarp = time;
	EmitSoundToAll( "ui/halloween_loot_spawn.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_HOME );
	TFTeam client_team = view_as<TFTeam>(GetClientTeam(client));
	
	char name[32];
	GetClientName( client, name, sizeof name );
	
	if (client_team == TFTeam_Blue) CPrintToChatAll("%t{BLUE}%s{DEFAULT} has warped time!", "Store Tag Colored", name);
	else CPrintToChatAll("%t{RED}%s{DEFAULT} has warped time!", "Store Tag Colored", name);
	
	time_warped = true;
	for( int i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) && !IsFakeClient(i) ) {
			fakeCheats( i, true );
		}
	}
	
	CreateTimer( 0.1, Timer_warpTimeInc, _, TIMER_REPEAT );
	CreateTimer( 15.0, Timer_unWarpTime );
	return true;
}


bool NearSpawn(float end[3])
{
	float target[3];
	target[0] = end[0];
	target[1] = end[1];
	for( int i = 0; i < g_spawn_count; i++ ) {
		target[2] = end[2] + (end[2] - g_player_spawns[i][2])*2;
		float distance = GetVectorDistance(g_player_spawns[i],target,true);
		if(distance < 562500){
			return true;
		}
	}
	return false;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask, any data)  
{ 
	return entity > MaxClients; 
}

void fakeCheats(int client, bool on_off ){
	SendConVarValue( client, FindConVar("sv_cheats"), on_off ? "1" : "0" );
}

void findSpawnPoints() {
	int ent = -1;
	g_spawn_count = 0;
	while( (ent = FindEntityByClassname(ent, "info_player_teamspawn")) != -1){
		GetEntPropVector( ent, Prop_Send, "m_vecOrigin", g_player_spawns[g_spawn_count]);
		g_spawn_count++;
	}
}

public Action Timer_warpTimeInc( Handle timer )
{
	current_timescale -= 0.03;
	
	SetConVarFloat(host_timescale, current_timescale);
	if( current_timescale <= 0.5 ){
		SetConVarFloat(host_timescale, 0.5);
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action Timer_unWarpTime( Handle timer ) {
	EmitSoundToAll( "ui/halloween_loot_found.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_HOME );
	CPrintToChatAll("%tThe {PURPLE}time warp{DEFAULT} has ended!", "Store Tag Colored");
	CreateTimer( 0.1, Timer_unWarpTimeInc, _, TIMER_REPEAT );
}

public Action Timer_unWarpTimeInc( Handle timer ) {

	current_timescale += 0.03;
	SetConVarFloat( host_timescale, current_timescale );
	
	if( current_timescale <= 1.0 )
	{
		SetConVarFloat(host_timescale, 1.0);
		for( int i = 1; i <= MaxClients; i++ ) {
			if( IsClientInGame(i) && !IsFakeClient(i) ) {
				fakeCheats(i,false);
			}
		}
		time_warped = false;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

void PrecacheMonoculus()
{
	PrecacheModel( "models/props_halloween/halloween_demoeye.mdl", true );
	PrecacheModel( "models/props_halloween/eyeball_projectile.mdl", true );

	PrecacheSound( "vo/halloween_eyeball/eyeball_biglaugh01.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_boss_pain01.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_laugh01.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_laugh02.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_laugh03.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_mad01.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_mad02.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_mad03.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_teleport01.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball01.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball02.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball03.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball04.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball05.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball06.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball07.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball08.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball09.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball10.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball11.wav", true );

	PrecacheSound( "ui/halloween_boss_summon_rumble.wav", true);
	PrecacheSound( "ui/halloween_boss_chosen_it.wav", true );
	PrecacheSound( "ui/halloween_boss_defeated_fx.wav", true );
	PrecacheSound( "ui/halloween_boss_defeated.wav", true );
	PrecacheSound( "ui/halloween_boss_player_becomes_it.wav", true );
	PrecacheSound( "ui/halloween_boss_summoned_fx.wav", true );
	PrecacheSound( "ui/halloween_boss_summoned.wav", true );
	PrecacheSound( "ui/halloween_boss_tagged_other_it.wav", true );
	PrecacheSound( "ui/halloween_boss_escape.wav", true );
	PrecacheSound( "ui/halloween_boss_escape_sixty.wav", true );
	PrecacheSound( "ui/halloween_boss_escape_ten.wav", true );
	PrecacheSound( "ui/halloween_boss_tagged_other_it.wav", true );
}

public bool IsValidClient (int client)
{
	if(client > 4096) client = EntRefToEntIndex(client);
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsFakeClient(client)) return false;
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}