/*
	Version 1.2.0
	-=-=-=-=-=-=-
	- Plugin has been renamed to "viprooms" as it is no longer designed for only donators.
		- "Teleporting" now refers to entering a valid trigger_multiple entity to enter an area.
		- "Warping" now refers to issuing a !warp command to enter an area.
	- Removed "hold USE for x seconds" feature to activate a teleport after entering a trigger.
	- Teleports are no longer cancelled if the user exits the trigger_multiple entity.
	- Entering a trigger will now prompt the user with a menu, asking yes/no to teleport.
	- Configuration file has been renamed to sm_viprooms.ini
		- Areas can now be assigned a name, which will be displayed upon entering the trigger.
		- Areas can now be set to allow access to anyone, instead of requiring a specific flag.
		- Areas can now have a general override specified, in addition to specific flags.
	- Auth checks for areas now use CheckCommandAccess instead of hardcoded flag checks.
	- Removed hardcoded cvar that forced sm_donortele to move to a specific location.
	- Replaced sm_donortele command with sm_warp.
	- Command sm_warp now displays a list of available locations available to enter.
	- Cvar sm_viprooms_allow_warping added to globally disable the sm_warp command, if desired.
	- An additional entry has been added to sm_viprooms.ini, *_warping, to remove an entry from the sm_warp command.
	- Added a hardcoded #define to control the distance a player can move after entering a *_trigger before voiding the teleport confirm menu.

	Version 1.2.1
	-=-=-=-=-=-=-
	- Resolved issue where particles would remain attached if a client moved during a warp/teleport.
	
	Version 1.2.2
	-=-=-=-=-=-=-
	- Added g_fRefreshRate #define to control the rate at which warp/teleport hints/position checks occur.
	- Replaced "n_warping" with "n_activation", accepting values of 1/2/3. 1 = Physical only, 2 = Command only, 3 = Both.

	Version 1.2.3
	-=-=-=-=-=-=-
	- Added support for each location definition to have optional menu phrases that override the default translations.
	- Added support for an optional phrase to display whenever a client enters a teleportable location.
	- Added support for an optional phrase to be displayed when a client selects a location in sm_warp.
	- Added support for an optional phrase that displays after a user teleports or warps to a location.
	- Changed the hardcoded constants for maximum movement away from a teleport prompt and how frequently clients are queried to cvars.
	  - sm_viprooms_refresh_rate (def: 0.33), sm_viprooms_cancel_menu (def: 100)
	- Added support for an optional team to be required to access a teleport location or view it within sm_warp.
	- Added support for displaying a notification when a client teleports or warps.
	  - sm_viprooms_notify_action (-1 = disabled, 0 = everyone, otherwise it's the flag required to see notification)
	  - Translations: Phrase_Warp:Notify and Phrase_Teleport:Notify
	- Added support for allowing sm_warp #, where # is a valid entry from the cfg >= 0 and < total entries.
	  - Checks for being allowed to be warped to, checks users team. If valid, prompts user to warp.
	  - If user does not have access, defaults to listing available locations.
	- Modified translation Menu_Warp:Location to display [ID: #] after the name (to give the specific id for sm_warp)
	
*/

#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "1.2.3"

//Number of seconds menus to remain before closing. 0 = Infinite
#define WARP_MENU_DURATION 60
#define CONFIRM_MENU_DURATION 60

//Bit flags for activation codes.
#define ACTIVATE_ON_PHYSICAL 1
#define ACTIVATE_ON_COMMAND 2

char g_sParticle[64], g_sParticleRed[64], g_sParticleBlu[64], g_sNotify[8], g_sGameName[10];
float g_fCancelDistance, g_fParticleOffset[3], g_fRefreshRate, g_fMaximumMovement;
bool g_bLateLoad, g_bMapCfgExists, g_bParticlesAllowed, g_bParticle;

ConVar cvarEnabled;
ConVar cvarCancelDistance;
ConVar cvarCancelDamage;
ConVar cvarParticle;
ConVar cvarParticleRed;
ConVar cvarParticleBlu;
ConVar cvarParticleOffset;
ConVar cvarWarpingAllowed;
ConVar cvarMaximumMovement;
ConVar cvarRefreshRate;
ConVar cvarNotify;

//Dynamic arrays to load per-map settings.
ArrayList g_hArray_Teleports;
ArrayList g_hArray_Displays;
ArrayList g_hArray_Positions;
ArrayList g_hArray_Rotations;
ArrayList g_hArray_Flags;
ArrayList g_hArray_Overrides;
ArrayList g_hArray_Delays;
ArrayList g_hArray_Activations;
ArrayList g_hArray_Teams;
ArrayList g_hArray_PhraseSelect;
ArrayList g_hArray_PhraseTitle;
ArrayList g_hArray_PhraseConfirm;
ArrayList g_hArray_PhraseCancel;
ArrayList g_hArray_PhrasePrompt;
ArrayList g_hArray_PhraseNotify;

int g_iEntityIndex[2048] = { -1, ... };
float g_fTriggerLocation[2048][3];

int g_iClientEntity[MAXPLAYERS + 1] = { -1, ... };
int g_iClientParticle[MAXPLAYERS + 1] = { -1, ... };
float g_fClientEntering[MAXPLAYERS + 1];
float g_fClientLocation[MAXPLAYERS + 1][3];

Handle g_hTimer_Teleporting[MAXPLAYERS + 1] = { null, ... };
Handle g_hTimer_MonitorTeleport[MAXPLAYERS + 1] = { null, ... };
Handle g_hTimer_Warping[MAXPLAYERS + 1] = { null, ... };
Handle g_hTimer_MonitorWarp[MAXPLAYERS + 1] = { null, ... };

public Plugin myinfo = {
	name = "[NGS] Vip Areas", 
	author = "Twisted|Panda / TheXeon", 
	description = "Provides functionality for entering restricted areas.",
	version = PLUGIN_VERSION, 
	url = "https://neogenesisnetwork.net/"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("sm_viprooms.phrases");
	CreateConVar("sm_viprooms_version", PLUGIN_VERSION, "Vip Areas: Version", FCVAR_SPONLY|FCVAR_CHEAT|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	GetGameFolderName(g_sGameName, sizeof(g_sGameName));

	cvarEnabled = CreateConVar("sm_viprooms_enable", "1", "Enables/disables all features of the plugin.", FCVAR_NONE, true, 0.0, true, 1.0);
	cvarCancelDistance = CreateConVar("sm_viprooms_cancel_distance", "0.0", "The maximum distance a player can travel from his/her original teleport location before cancelling the teleport. (-1 = Disabled, #.# = Distance)", FCVAR_NONE, true, -1.0);
	cvarCancelDistance.AddChangeHook(OnSettingsChange);
	cvarCancelDamage = CreateConVar("sm_viprooms_cancel_damage", "1", "If enabled, a teleport will be cancelled if the initiating client takes damage after initiating a teleport.", FCVAR_NONE, true, 0.0, true, 1.0);
	if (!StrEqual(g_sGameName, "tf", false))
	{
		cvarParticle = CreateConVar("sm_viprooms_particle", "burningplayer_smoke", "The desired particle to use for the teleport effect.", FCVAR_NONE);
		cvarParticle.AddChangeHook(OnSettingsChange);
	}
	else
	{
		cvarParticleRed = CreateConVar("sm_viprooms_particle_red", "flaregun_energyfield_red", "The desired particle to use for the teleport effect on RED.", FCVAR_NONE);
		cvarParticleRed.AddChangeHook(OnSettingsChange);
		cvarParticleBlu = CreateConVar("sm_viprooms_particle_blu", "flaregun_energyfield_blue", "The desired particle to use for the teleport effect on BLU.", FCVAR_NONE);
		cvarParticleBlu.AddChangeHook(OnSettingsChange);
	}
	cvarParticleOffset = CreateConVar("sm_viprooms_particle_offset", "0 0 0", "The desired offset to use for the particle: note, it's attached to the head!", FCVAR_NONE);
	cvarParticleOffset.AddChangeHook(OnSettingsChange);
	cvarWarpingAllowed = CreateConVar("sm_viprooms_allow_warping", "1", "If enabled, the sm_warp command will be available for use.", FCVAR_NONE, true, 0.0, true, 1.0);
	
	cvarRefreshRate = CreateConVar("sm_viprooms_refresh_rate", "0.33", "The frequency, in seconds, that players are monitored for teleporting / warping.", FCVAR_NONE, true, 0.1);
	cvarRefreshRate.AddChangeHook(OnSettingsChange);
	cvarMaximumMovement = CreateConVar("sm_viprooms_cancel_menu", "100", "The maximum distance a player can move from away from a teleport location prompt before it no longer works.", FCVAR_NONE, true, 0.0);
	cvarMaximumMovement.AddChangeHook(OnSettingsChange);
	cvarNotify = CreateConVar("sm_viprooms_notify_action", "-1", "Determines who receives the notification that a player has teleported or warped. (-1 = Disabled, 0 = Everyone, otherwise the specified flag the user must possess, such as b)", FCVAR_NONE);
	cvarNotify.AddChangeHook(OnSettingsChange);

	g_fCancelDistance = cvarCancelDistance.FloatValue;
	if (!StrEqual(g_sGameName, "tf", false))
	{
		GetConVarString(cvarParticle, g_sParticle, sizeof(g_sParticle));
		g_bParticle = !StrEqual(g_sParticle, "");
	}
	else
	{
		GetConVarString(cvarParticleRed, g_sParticleRed, sizeof(g_sParticleRed));
		GetConVarString(cvarParticleBlu, g_sParticleBlu, sizeof(g_sParticleBlu));
		g_bParticle = (!StrEqual(g_sParticleRed, "") || !StrEqual(g_sParticleBlu, ""));
	}
	char sBuffer[3][8], sTemp[64];
	GetConVarString(cvarParticleOffset, sTemp, sizeof(sTemp));
	ExplodeString(sTemp, " ", sBuffer, 3, 8);
	for (int i = 0; i <= 2; i++)
		g_fParticleOffset[i] = StringToFloat(sBuffer[i]);
	g_fRefreshRate = GetConVarFloat(cvarRefreshRate);
	g_fMaximumMovement = GetConVarFloat(cvarMaximumMovement);
	GetConVarString(cvarNotify, g_sNotify, sizeof(g_sNotify));

	HookEvent("player_death", Event_OnPlayerDeath);
	HookEvent("player_team", Event_OnPlayerTeam);
	
	RegConsoleCmd("sm_warp", Command_Warp); 
	g_hArray_Teleports = CreateArray(8);
	g_hArray_Displays = CreateArray(16);
	g_hArray_Positions = CreateArray(3);
	g_hArray_Rotations = CreateArray(3);
	g_hArray_Flags = CreateArray();
	g_hArray_Overrides = CreateArray(16);
	g_hArray_Delays = CreateArray();
	g_hArray_Activations = CreateArray();
	g_hArray_Teams = CreateArray();
	////////////////
	g_hArray_PhraseSelect = CreateArray(64);
	g_hArray_PhraseTitle = CreateArray(64);
	g_hArray_PhraseConfirm = CreateArray(16);
	g_hArray_PhraseCancel = CreateArray(16);
	g_hArray_PhrasePrompt = CreateArray(64);
	g_hArray_PhraseNotify = CreateArray(64);
	
	GetGameFolderName(sTemp, sizeof(sTemp));
	g_bParticlesAllowed = StrEqual(sTemp, "tf");
	
	Define_Configs();
}

public void OnSettingsChange(ConVar cvar, const char[] oldvalue, const char[] newvalue)
{
	if(cvar == cvarCancelDistance)
		g_fCancelDistance = StringToFloat(newvalue);
	else if(cvar == cvarParticle)
	{
		strcopy(g_sParticle, sizeof(g_sParticle), newvalue);
		g_bParticle = !StrEqual(g_sParticle, "");
	}
	else if(cvar == cvarParticleRed)
	{
		strcopy(g_sParticleRed, sizeof(g_sParticleRed), newvalue);
		g_bParticle = (!StrEqual(g_sParticleRed, "") || !StrEqual(g_sParticleBlu, ""));
	}
	else if(cvar == cvarParticleBlu)
	{
		strcopy(g_sParticleBlu, sizeof(g_sParticleBlu), newvalue);
		g_bParticle = (!StrEqual(g_sParticleRed, "") || !StrEqual(g_sParticleBlu, ""));
	}
	else if(cvar == cvarParticleOffset)
	{
		char sBuffer[3][8];
		ExplodeString(newvalue, " ", sBuffer, 3, 8);
		for (int i = 0; i <= 2; i++)
			g_fParticleOffset[i] = StringToFloat(sBuffer[i]);
	}
	else if(cvar == cvarRefreshRate)
		g_fRefreshRate = StringToFloat(newvalue);
	else if(cvar == cvarMaximumMovement)
		g_fMaximumMovement = StringToFloat(newvalue);
	else if(cvar == cvarNotify)
		strcopy(g_sNotify, sizeof(g_sNotify), newvalue);
}

public void OnClientPutInServer(int client)
{
	if(cvarEnabled.BoolValue)
	{
		SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
	}
}

public void OnClientDisconnect(int client)
{
	if(cvarEnabled.BoolValue)
	{
		DeleteClientParticle(client);
		g_iClientEntity[client] = -1;

		if(g_hTimer_Teleporting[client] != null && CloseHandle(g_hTimer_Teleporting[client]))
			g_hTimer_Teleporting[client] = null;

		if(g_hTimer_MonitorTeleport[client] != null && CloseHandle(g_hTimer_MonitorTeleport[client]))
			g_hTimer_MonitorTeleport[client] = null;

		if(g_hTimer_Warping[client] != null && CloseHandle(g_hTimer_Warping[client]))
			g_hTimer_Warping[client] = null;

		if(g_hTimer_MonitorWarp[client] != null && CloseHandle(g_hTimer_MonitorWarp[client]))
			g_hTimer_MonitorWarp[client] = null;
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(cvarEnabled.BoolValue && g_bMapCfgExists && entity >= 0)
	{
		if(StrEqual(classname, "trigger_multiple", false))
			CreateTimer(0.0, Timer_OnEntityCreated, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void OnEntityDestroyed(int entity)
{
	if(cvarEnabled.BoolValue && entity >= 0)
	{
		g_iEntityIndex[entity] = -1;
	}
}

public Action Timer_OnEntityCreated(Handle timer, any ref)
{
	int entity = EntRefToEntIndex(ref);
	if (entity != INVALID_ENT_REFERENCE)
	{
		int iIndex;
		char sBuffer[64];
		GetEntPropString(entity, Prop_Data, "m_iName", sBuffer, sizeof(sBuffer));
		if ((iIndex = FindStringInArray(g_hArray_Teleports, sBuffer)) != -1)
		{
			SDKHook(entity, SDKHook_StartTouch, Hook_OnStartTouch);
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", g_fTriggerLocation[entity]);

			g_iEntityIndex[entity] = iIndex;
		}
	}
}

public void OnConfigsExecuted()
{
	if(cvarEnabled.BoolValue)
	{
		Define_Configs();
		
		if(g_bLateLoad)
		{
			if(g_bMapCfgExists)
			{
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i))
					{
						SDKHook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
					}
				}
				
				int iIndex;
				char sClassname[32], sBuffer[32];
				for (int i = MaxClients + 1; i <= 2047; i++)
				{
					if(IsValidEntity(i) && IsValidEdict(i))
					{
						GetEdictClassname(i, sClassname, sizeof(sClassname));
						if(StrEqual(sClassname, "trigger_multiple", false))
						{
							GetEntPropString(i, Prop_Data, "m_iName", sBuffer, sizeof(sBuffer));
							if((iIndex = FindStringInArray(g_hArray_Teleports, sBuffer)) != -1)
							{
								SDKHook(i, SDKHook_StartTouch, Hook_OnStartTouch);
								GetEntPropVector(i, Prop_Send, "m_vecOrigin", g_fTriggerLocation[i]);
								
								g_iEntityIndex[i] = iIndex;
							}
						}
					}
				}
			}

			g_bLateLoad = false;
		}
	}
}

public void Event_OnPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if(cvarEnabled.BoolValue)
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		if(!client || !IsClientInGame(client))
			return;
			
		DeleteClientParticle(client);
		g_iClientEntity[client] = -1;

		if(g_hTimer_Teleporting[client] != null && CloseHandle(g_hTimer_Teleporting[client]))
			g_hTimer_Teleporting[client] = null;

		if(g_hTimer_MonitorTeleport[client] != null && CloseHandle(g_hTimer_MonitorTeleport[client]))
			g_hTimer_MonitorTeleport[client] = null;

		if(g_hTimer_Warping[client] != null && CloseHandle(g_hTimer_Warping[client]))
			g_hTimer_Warping[client] = null;

		if(g_hTimer_MonitorWarp[client] != null && CloseHandle(g_hTimer_MonitorWarp[client]))
			g_hTimer_MonitorWarp[client] = null;
	}
	
	return;
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if(cvarEnabled.BoolValue)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(!client || !IsClientInGame(client))
			return;

		DeleteClientParticle(client);
		g_iClientEntity[client] = -1;

		if(g_hTimer_Teleporting[client] != null && CloseHandle(g_hTimer_Teleporting[client]))
			g_hTimer_Teleporting[client] = null;

		if(g_hTimer_MonitorTeleport[client] != null && CloseHandle(g_hTimer_MonitorTeleport[client]))
			g_hTimer_MonitorTeleport[client] = null;

		if(g_hTimer_Warping[client] != null && CloseHandle(g_hTimer_Warping[client]))
			g_hTimer_Warping[client] = null;

		if(g_hTimer_MonitorWarp[client] != null && CloseHandle(g_hTimer_MonitorWarp[client]))
			g_hTimer_MonitorWarp[client] = null;
	}
	
	return;
}

public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (cvarEnabled.BoolValue && cvarCancelDamage.BoolValue && victim > 0 && victim <= MaxClients)
	{
		if(g_hTimer_Teleporting[victim] != null)
		{
			CloseHandle(g_hTimer_Teleporting[victim]);
			g_hTimer_Teleporting[victim] = null;

			if(g_hTimer_MonitorTeleport[victim] != null && CloseHandle(g_hTimer_MonitorTeleport[victim]))
				g_hTimer_MonitorTeleport[victim] = null;

			char sDisplay[64];
			GetArrayString(g_hArray_Displays, g_iEntityIndex[g_iClientEntity[victim]], sDisplay, sizeof(sDisplay));
			PrintToChat(victim, "%t%t", "Prefix_Chat", "Phrase_Teleport:Damage", sDisplay);
			PrintHintText(victim, "%t", "Phrase_Teleport:Failure");

			DeleteClientParticle(victim);
			g_iClientEntity[victim] = -1;
		}

		if(g_hTimer_Warping[victim] != null)
		{
			CloseHandle(g_hTimer_Warping[victim]);
			g_hTimer_Warping[victim] = null;

			if(g_hTimer_MonitorWarp[victim] != null && CloseHandle(g_hTimer_MonitorWarp[victim]))
				g_hTimer_MonitorWarp[victim] = null;

			char sDisplay[64];
			GetArrayString(g_hArray_Displays, g_iEntityIndex[g_iClientEntity[victim]], sDisplay, sizeof(sDisplay));
			PrintToChat(victim, "%t%t", "Prefix_Chat", "Phrase_Warp:Damage", sDisplay);
			PrintHintText(victim, "%t", "Phrase_Warp:Failure");

			DeleteClientParticle(victim);
		}
	}
	
	return Plugin_Continue;
}

public Action Hook_OnStartTouch(int entity, int client)
{
	if (cvarEnabled.BoolValue && client > 0 && client <= MaxClients && g_iEntityIndex[entity] != -1)
	{
		//Client already has a Teleport or Warp in progress.
		if(g_hTimer_Teleporting[client] != null || g_hTimer_Warping[client] != null)
			return Plugin_Continue;
	
		int iActivation = GetArrayCell(g_hArray_Activations, g_iEntityIndex[entity]);
		if(iActivation & ACTIVATE_ON_PHYSICAL)
		{
			//Ensure client has authorization to Teleport.
			char sOverride[32];
			GetArrayString(g_hArray_Overrides, g_iEntityIndex[entity], sOverride, sizeof(sOverride));
			int iFlag = GetArrayCell(g_hArray_Flags, g_iEntityIndex[entity]);
			if(!iFlag || CheckCommandAccess(client, sOverride, iFlag))
			{
				int iTeam = g_hArray_Teams.Get(g_iEntityIndex[entity]);
				if(!iTeam || GetClientTeam(client) == iTeam)
				{
					char sDisplay[256];
					GetArrayString(g_hArray_PhrasePrompt, g_iEntityIndex[entity], sDisplay, sizeof(sDisplay));
					if(!StrEqual(sDisplay, ""))
						PrintToChat(client, "%t%s", "Prefix_Chat", sDisplay);

					Menu_ConfirmTeleport(client, entity);
				}
			}
		}
	}

	return Plugin_Continue;
}

void Menu_ConfirmTeleport(int client, int entity)
{
	char sTemp[256], sDisplay[256];
	Menu hMenu = new Menu(MenuHandler_ConfirmTeleport);

	GetArrayString(g_hArray_PhraseTitle, g_iEntityIndex[entity], sDisplay, sizeof(sDisplay));
	if(StrEqual(sDisplay, ""))
	{
		GetArrayString(g_hArray_Displays, g_iEntityIndex[entity], sTemp, sizeof(sTemp));
		Format(sDisplay, sizeof(sDisplay), "%T", "Menu_Teleport:Title", client, sTemp);
	}

	hMenu.SetTitle(sDisplay);
	SetMenuExitButton(hMenu, false);
	SetMenuExitBackButton(hMenu, false);

	GetArrayString(g_hArray_PhraseConfirm, g_iEntityIndex[entity], sDisplay, sizeof(sDisplay));
	if(StrEqual(sDisplay, ""))
		Format(sDisplay, sizeof(sDisplay), "%T", "Menu_Teleport:Confirm", client);
	Format(sTemp, sizeof(sTemp), "1 %d", entity);
	hMenu.AddItem(sTemp, sDisplay);

	GetArrayString(g_hArray_PhraseCancel, g_iEntityIndex[entity], sDisplay, sizeof(sDisplay));
	if(StrEqual(sDisplay, ""))
		Format(sDisplay, sizeof(sDisplay), "%T", "Menu_Teleport:Cancel", client);
	Format(sDisplay, sizeof(sDisplay), "0 %d", entity);
	hMenu.AddItem(sDisplay, sTemp);

	hMenu.Display(client, CONFIRM_MENU_DURATION);
}

public int MenuHandler_ConfirmTeleport(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Select:
		{
			char sOption[10], sBuffer[2][5];
			menu.GetItem(param2, sOption, 10);
			ExplodeString(sOption, " ", sBuffer, 2, 5);
			
			if(StringToInt(sBuffer[0]))
			{
				int iEntity = StringToInt(sBuffer[1]);
				float fCurrent[3];
				GetClientAbsOrigin(param1, fCurrent);
				if(GetVectorDistance(g_fTriggerLocation[iEntity], fCurrent) > g_fMaximumMovement)
					return;	

				g_iClientEntity[param1] = iEntity;

				//Client has a warp in progress and does not need to teleport.
				if(g_hTimer_Warping[param1] != null)
				{
					char sDisplay[64];
					GetArrayString(g_hArray_Displays, g_iEntityIndex[iEntity], sDisplay, sizeof(sDisplay));

					PrintToChat(param1, "%t%t", "Prefix_Chat", "Phrase_Teleport:Warping", sDisplay);
				}
				else
				{
					CreateClientParticle(param1);
					g_fClientEntering[param1] = 0.0;
					if(g_fCancelDistance >= 0.0)
						GetClientAbsOrigin(param1, g_fClientLocation[param1]);

					int iTeam = GetArrayCell(g_hArray_Teams, g_iEntityIndex[iEntity]);
					if(iTeam && GetClientTeam(param1) != iTeam)
						return;
						
					float fDelay = GetArrayCell(g_hArray_Delays, g_iEntityIndex[iEntity]);
					PrintHintText(param1, "%t", "Phrase_Teleport:Progress", g_fClientEntering[param1]);

					DataPack hTeleportPack = null;
					g_hTimer_Teleporting[param1] = CreateDataTimer(fDelay, Timer_Teleporting, hTeleportPack, TIMER_FLAG_NO_MAPCHANGE);
					WritePackCell(hTeleportPack, param1);
					WritePackCell(hTeleportPack, iEntity);
					
					DataPack hMonitorPack = null;
					g_hTimer_MonitorTeleport[param1] = CreateDataTimer(g_fRefreshRate, Timer_MonitorTeleport, hMonitorPack, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
					WritePackCell(hMonitorPack, param1);
					WritePackCell(hMonitorPack, iEntity);
				}
			}
		}
	}
}

public Action Timer_Teleporting(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	int entity = pack.ReadCell();
	
	g_hTimer_Teleporting[client] = null;
	if(g_hTimer_MonitorTeleport[client] != null && CloseHandle(g_hTimer_MonitorTeleport[client]))
		g_hTimer_MonitorTeleport[client] = null;

	float fPosition[3], fRotation[3];
	char sDisplay[256];
	g_hArray_Positions.GetArray(g_iEntityIndex[entity], fPosition);
	g_hArray_Rotations.GetArray(g_iEntityIndex[entity], fRotation);
	TeleportEntity(client, fPosition, fRotation, NULL_VECTOR);

	GetArrayString(g_hArray_PhraseNotify, g_iEntityIndex[entity], sDisplay, sizeof(sDisplay));
	if(!StrEqual(sDisplay, ""))
		PrintToChat(client, "%t%s", "Prefix_Chat", sDisplay);
	else
	{
		GetArrayString(g_hArray_Displays, g_iEntityIndex[entity], sDisplay, sizeof(sDisplay));
		PrintToChat(client, "%t%t", "Prefix_Chat", "Phrase_Teleport:Enter", sDisplay);
		PrintHintText(client, "%t", "Phrase_Teleport:Success");
	}
	
	DeleteClientParticle(client);
	g_iClientEntity[client] = -1;
	
	if(!StrEqual(g_sNotify, "-1"))
	{
		if(StrEqual(g_sNotify, "0"))
			DisplayTeleportNotify(client, 0, sDisplay);
		else
			DisplayTeleportNotify(client, ReadFlagString(g_sNotify), sDisplay);
	}
	
	return Plugin_Continue;
}

public Action Timer_MonitorTeleport(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	int entity = pack.ReadCell();

	if(g_fCancelDistance >= 0.0)
	{
		float fCurrent[3];
		GetClientAbsOrigin(client, fCurrent);
		if(GetVectorDistance(g_fClientLocation[client], fCurrent) > g_fCancelDistance)
		{
			char sDisplay[256];
			GetArrayString(g_hArray_Displays, g_iEntityIndex[entity], sDisplay, sizeof(sDisplay));
			PrintToChat(client, "%t%t", "Prefix_Chat", "Phrase_Teleport:Movement", sDisplay);
			PrintHintText(client, "%t", "Phrase_Teleport:Failure");

			g_hTimer_MonitorTeleport[client] = null;
			if(g_hTimer_Teleporting[client] != null && KillTimer(g_hTimer_Teleporting[client]))
				g_hTimer_Teleporting[client] = null;
		
			g_iClientEntity[client] = -1;
			DeleteClientParticle(client);
			
			return Plugin_Stop;
		}
	}

	g_fClientEntering[client] += g_fRefreshRate;
	float fTemp = (g_fClientEntering[client] / view_as<float>(GetArrayCell(g_hArray_Delays, g_iEntityIndex[entity]))) * 100.0;
	PrintHintText(client, "%t", "Phrase_Teleport:Progress", fTemp);
	
	return Plugin_Continue;
}

public Action Command_Warp(int client, int args)
{
	if(!cvarEnabled.BoolValue || !IsValidClient(client) || !IsPlayerAlive(client))
		return Plugin_Handled;
	else if(!cvarWarpingAllowed.BoolValue)
	{
		PrintToChat(client, "%t%t", "Prefix_Chat", "Phrase_Warp:Disabled");
		return Plugin_Handled; 
	}
	else if(g_hTimer_Teleporting[client] != null)
	{
		PrintToChat(client, "%t%t", "Prefix_Chat", "Phrase_Warp:Teleporting");
		return Plugin_Handled; 
	}
	else if(g_hTimer_Warping[client] != null)
	{
		PrintToChat(client, "%t%t", "Prefix_Chat", "Phrase_Warp:Warping");
		return Plugin_Handled; 
	}

	int iActivation, iTeam, iSize = g_hArray_Teleports.Length;
	if(iSize)
	{
		char sShortcut[64];
		GetCmdArg(1, sShortcut, sizeof(sShortcut));
		if(!StrEqual(sShortcut, ""))
		{
			int iArea = StringToInt(sShortcut);
			if(iArea >= 0 && iArea < iSize)
			{
				iActivation = GetArrayCell(g_hArray_Activations, iArea);
				if(iActivation & ACTIVATE_ON_COMMAND)
				{
					iTeam = GetArrayCell(g_hArray_Teams, iArea);
					if(!iTeam || GetClientTeam(client) == iTeam)
					{
						char sTemp[256], sDisplay[256];
						GetArrayString(g_hArray_PhraseSelect, iArea, sDisplay, sizeof(sDisplay));
						if(!StrEqual(sDisplay, ""))
							PrintToChat(client, "%t%s", "Prefix_Chat", sDisplay);
						
						Menu hMenu = new Menu(MenuHandler_ConfirmWarp);

						GetArrayString(g_hArray_PhraseTitle, iArea, sDisplay, sizeof(sDisplay));
						if(StrEqual(sDisplay, ""))
						{
							GetArrayString(g_hArray_Displays, iArea, sTemp, sizeof(sTemp));
							Format(sDisplay, sizeof(sDisplay), "%T", "Menu_Warp:Title", client, sTemp);
						}

						hMenu.SetTitle(sDisplay);
						SetMenuExitButton(hMenu, true);
						SetMenuExitBackButton(hMenu, false);

						GetArrayString(g_hArray_PhraseConfirm, iArea, sDisplay, sizeof(sDisplay));
						if(StrEqual(sDisplay, ""))
							Format(sDisplay, sizeof(sDisplay), "%T", "Menu_Warp:Confirm", client);
						Format(sTemp, sizeof(sTemp), "1 %d", iArea);
						hMenu.AddItem(sTemp, sDisplay);

						GetArrayString(g_hArray_PhraseCancel, iArea, sDisplay, sizeof(sDisplay));
						if(StrEqual(sDisplay, ""))
							Format(sDisplay, sizeof(sDisplay), "%T", "Menu_Warp:Cancel", client);
						Format(sTemp, sizeof(sTemp), "0 %d", iArea);
						AddMenuItem(hMenu, sTemp, sDisplay);

						DisplayMenu(hMenu, client, CONFIRM_MENU_DURATION);
						return Plugin_Handled; 
		
					}
				}
			}
		}
	
		char sOverride[32];
		int iTotal; 
		int[] iAllowed = new int[iSize + 1];
		for (int i = 0; i < iSize; i++)
		{
			iActivation = g_hArray_Activations.Get(i);
			if (iActivation & ACTIVATE_ON_COMMAND)
			{
				iTeam = g_hArray_Teams.Get(i);
				if(!iTeam || GetClientTeam(client) == iTeam)
				{
					g_hArray_Overrides.GetString(i, sOverride, sizeof(sOverride));
					int iFlag = g_hArray_Flags.Get(i);
					if(!iFlag || CheckCommandAccess(client, sOverride, iFlag))
						iAllowed[iTotal++] = i;
				}
			}
		}
		
		if (iTotal)
		{
			char sTemp[192], sDisplay[64];
			Menu hMenu = new Menu(MenuHandler_ListWarps);

			Format(sTemp, sizeof(sTemp), "%T", "Menu_Warp:List", client);
			hMenu.SetTitle(sTemp);
			SetMenuExitButton(hMenu, true);
			SetMenuExitBackButton(hMenu, false);
			
			for (int i = 0; i < iTotal; i++)
			{					
				g_hArray_Displays.GetString(iAllowed[i], sDisplay, sizeof(sDisplay));

				Format(sTemp, sizeof(sTemp), "%T", "Menu_Warp:Location", client, sDisplay, i);
				Format(sDisplay, sizeof(sDisplay), "%d", iAllowed[i]);
				hMenu.AddItem(sDisplay, sTemp);
			}

			hMenu.Display(client, WARP_MENU_DURATION);
		}
		else
			PrintToChat(client, "%t%t", "Prefix_Chat", "Phrase_Warp:Unavailable");
	}
	else
		PrintToChat(client, "%t%t", "Prefix_Chat", "Phrase_Warp:Unavailable");

	return Plugin_Handled; 
}

public int MenuHandler_ListWarps(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			char sIndex[8], sTemp[256], sDisplay[256];
			menu.GetItem(param2, sIndex, 8);
			int iIndex = StringToInt(sIndex);

			GetArrayString(g_hArray_PhraseSelect, iIndex, sDisplay, sizeof(sDisplay));
			if(!StrEqual(sDisplay, ""))
				PrintToChat(param1, "%t%s", "Prefix_Chat", sDisplay);
			
			Menu hMenu = new Menu(MenuHandler_ConfirmWarp);

			g_hArray_PhraseTitle.GetString(iIndex, sDisplay, sizeof(sDisplay));
			if(StrEqual(sDisplay, ""))
			{
				g_hArray_Displays.GetString(iIndex, sTemp, sizeof(sTemp));
				Format(sDisplay, sizeof(sDisplay), "%T", "Menu_Warp:Title", param1, sTemp);
			}

			hMenu.SetTitle(sDisplay);
			SetMenuExitButton(hMenu, true);
			SetMenuExitBackButton(hMenu, false);

			GetArrayString(g_hArray_PhraseConfirm, iIndex, sDisplay, sizeof(sDisplay));
			if(StrEqual(sDisplay, ""))
				Format(sDisplay, sizeof(sDisplay), "%T", "Menu_Warp:Confirm", param1);
			Format(sTemp, sizeof(sTemp), "1 %d", iIndex);
			hMenu.AddItem(sTemp, sDisplay);

			g_hArray_PhraseCancel.GetString(iIndex, sDisplay, sizeof(sDisplay));
			if(StrEqual(sDisplay, ""))
				Format(sDisplay, sizeof(sDisplay), "%T", "Menu_Warp:Cancel", param1);
			Format(sTemp, sizeof(sTemp), "0 %d", iIndex);
			hMenu.AddItem(sTemp, sDisplay);

			hMenu.Display(param1, CONFIRM_MENU_DURATION);
		}
	}
}

public int MenuHandler_ConfirmWarp(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			char sOption[10], sBuffer[2][5];
			menu.GetItem(param2, sOption, 10);
			ExplodeString(sOption, " ", sBuffer, 2, 5);
			
			if(StringToInt(sBuffer[0]))
			{	
				int iIndex = StringToInt(sBuffer[1]);
				
				CreateClientParticle(param1);
				g_fClientEntering[param1] = 0.0;
				if(g_fCancelDistance >= 0.0)
					GetClientAbsOrigin(param1, g_fClientLocation[param1]);

				int iTeam = g_hArray_Teams.Get(iIndex);
				if(iTeam && GetClientTeam(param1) != iTeam)
					return;
					
				float fDelay = g_hArray_Delays.Get(iIndex);
				PrintHintText(param1, "%t", "Phrase_Warp:Progress", g_fClientEntering[param1]);

				DataPack g_hWarpPack = null;
				g_hTimer_Warping[param1] = CreateDataTimer(fDelay, Timer_Warping, g_hWarpPack, TIMER_FLAG_NO_MAPCHANGE);
				g_hWarpPack.WriteCell(param1);
				g_hWarpPack.WriteCell(iIndex);
				
				DataPack hMonitorWarpPack = null;
				g_hTimer_MonitorWarp[param1] = CreateDataTimer(g_fRefreshRate, Timer_MonitorWarp, hMonitorWarpPack, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				hMonitorWarpPack.WriteCell(param1);
				hMonitorWarpPack.WriteCell(iIndex);
			}
		}
	}
}

public Action Timer_Warping(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	int index = pack.ReadCell();
	
	g_hTimer_Warping[client] = null;
	if(g_hTimer_MonitorWarp[client] != null && KillTimer(g_hTimer_MonitorWarp[client]))
		g_hTimer_MonitorWarp[client] = null;

	float fPosition[3], fRotation[3];
	char sDisplay[256];
	g_hArray_Positions.GetArray(index, fPosition);
	g_hArray_Rotations.GetArray(index, fRotation);
	if(fRotation[0] || fRotation[1] || fRotation[2])
		TeleportEntity(client, fPosition, fRotation, NULL_VECTOR);
	else
		TeleportEntity(client, fPosition, NULL_VECTOR, NULL_VECTOR);

	g_hArray_PhraseNotify.GetString(index, sDisplay, sizeof(sDisplay));
	if(!StrEqual(sDisplay, ""))
		PrintToChat(client, "%t%s", "Prefix_Chat", sDisplay);
	else
	{
		g_hArray_Displays.GetString(index, sDisplay, sizeof(sDisplay));
		PrintToChat(client, "%t%t", "Prefix_Chat", "Phrase_Warp:Enter", sDisplay);
		PrintHintText(client, "%t", "Phrase_Warp:Success");
	}
	
	DeleteClientParticle(client);

	if(!StrEqual(g_sNotify, "-1"))
	{
		if(StrEqual(g_sNotify, "0"))
			DisplayWarpNotify(client, 0, sDisplay);
		else
			DisplayWarpNotify(client, ReadFlagString(g_sNotify), sDisplay);
	}
	
	return Plugin_Continue;
}

public Action Timer_MonitorWarp(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	int index = pack.ReadCell();

	if(g_fCancelDistance >= 0.0)
	{
		float fCurrent[3];
		GetClientAbsOrigin(client, fCurrent);
		if(GetVectorDistance(g_fClientLocation[client], fCurrent) > g_fCancelDistance)
		{
			char sDisplay[64];
			g_hArray_Displays.GetString(index, sDisplay, sizeof(sDisplay));
			PrintToChat(client, "%t%t", "Prefix_Chat", "Phrase_Warp:Movement", sDisplay);
			PrintHintText(client, "%t", "Phrase_Warp:Failure");

			g_hTimer_MonitorWarp[client] = null;
			if(g_hTimer_Warping[client] != null && KillTimer(g_hTimer_Warping[client]))
				g_hTimer_Warping[client] = null;

			DeleteClientParticle(client);
			return Plugin_Stop;
		}
	}

	g_fClientEntering[client] += g_fRefreshRate;
	float fTemp = (g_fClientEntering[client] / view_as<float>(GetArrayCell(g_hArray_Delays, index))) * 100.0;
	PrintHintText(client, "%t", "Phrase_Warp:Progress", fTemp);
	
	return Plugin_Continue;
}

void Define_Configs()
{
	g_hArray_Teleports.Clear();
	g_hArray_Displays.Clear();
	g_hArray_Positions.Clear();
	g_hArray_Rotations.Clear();
	g_hArray_Flags.Clear();
	g_hArray_Overrides.Clear();
	g_hArray_Delays.Clear();
	g_hArray_Activations.Clear();
	g_hArray_Teams.Clear();
	//////////////
	g_hArray_PhraseSelect.Clear();
	g_hArray_PhraseTitle.Clear();
	g_hArray_PhraseConfirm.Clear();
	g_hArray_PhraseCancel.Clear();
	g_hArray_PhrasePrompt.Clear();
	g_hArray_PhraseNotify.Clear();
	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/sm_viprooms.ini");

	KeyValues hKeyValue = new KeyValues("viprooms");
	if(FileToKeyValues(hKeyValue, sPath))
	{
		float fBuffer[3];
		char sBuffer[256], sCurrent[256], sExplode[3][8];
		GetCurrentMap(sCurrent, sizeof(sCurrent));
		KvGotoFirstSubKey(hKeyValue);
		do
		{
			KvGetSectionName(hKeyValue, sBuffer, sizeof(sBuffer));
			if((g_bMapCfgExists = StrEqual(sBuffer, sCurrent, false)))
			{
				bool bExists = true;
				int iIndex = 1;
				while(bExists)
				{
					Format(sCurrent, sizeof(sCurrent), "%d_activate", iIndex);
					hKeyValue.GetString(sCurrent, sBuffer, sizeof(sBuffer));
					if((bExists = !StrEqual(sBuffer, "")))
					{
						PushArrayCell(g_hArray_Activations, StringToInt(sBuffer));

						Format(sCurrent, sizeof(sCurrent), "%d_trigger", iIndex);
						hKeyValue.GetString(sCurrent, sBuffer, sizeof(sBuffer), "");
						PushArrayString(g_hArray_Teleports, sBuffer);

						Format(sCurrent, sizeof(sCurrent), "%d_display", iIndex);
						hKeyValue.GetString(sCurrent, sBuffer, sizeof(sBuffer), "");
						PushArrayString(g_hArray_Displays, sBuffer);
						
						Format(sCurrent, sizeof(sCurrent), "%d_position", iIndex);
						hKeyValue.GetString(sCurrent, sBuffer, sizeof(sBuffer), "0.0 0.0 0.0");
						ExplodeString(sBuffer, " ", sExplode, 3, 8);
						for (int i = 0; i <= 2; i++)
							fBuffer[i] = StringToFloat(sExplode[i]);
						g_hArray_Positions.PushArray(fBuffer);
						
						Format(sCurrent, sizeof(sCurrent), "%d_rotation", iIndex);
						hKeyValue.GetString(sCurrent, sBuffer, sizeof(sBuffer), "0.0 0.0 0.0");
						ExplodeString(sBuffer, " ", sExplode, 3, 8);
						for (int i = 0; i <= 2; i++)
							fBuffer[i] = StringToFloat(sExplode[i]);
						g_hArray_Rotations.PushArray(fBuffer);
						
						Format(sCurrent, sizeof(sCurrent), "%d_delay", iIndex);
						hKeyValue.GetString(sCurrent, sBuffer, sizeof(sBuffer), "0.0");
						g_hArray_Delays.Push(StringToFloat(sBuffer));
						
						Format(sCurrent, sizeof(sCurrent), "%d_flag", iIndex);
						hKeyValue.GetString(sCurrent, sBuffer, sizeof(sBuffer), "");
						g_hArray_Flags.Push(ReadFlagString(sBuffer));
						
						Format(sCurrent, sizeof(sCurrent), "%d_override", iIndex);
						hKeyValue.GetString(sCurrent, sBuffer, sizeof(sBuffer), "SM_VIPROOMS_OVERRIDE");
						g_hArray_Overrides.PushString(sBuffer);
						
						Format(sCurrent, sizeof(sCurrent), "%d_team", iIndex);
						hKeyValue.GetString(sCurrent, sBuffer, sizeof(sBuffer), "0");
						g_hArray_Teams.Push(StringToInt(sBuffer));
						
						///////////////
						
						Format(sCurrent, sizeof(sCurrent), "%d_select", iIndex);
						hKeyValue.GetString(sCurrent, sBuffer, sizeof(sBuffer), "");
						g_hArray_PhraseSelect.PushString(sBuffer);
						
						Format(sCurrent, sizeof(sCurrent), "%d_title", iIndex);
						hKeyValue.GetString(sCurrent, sBuffer, sizeof(sBuffer), "");
						g_hArray_PhraseTitle.PushString(sBuffer);
						
						Format(sCurrent, sizeof(sCurrent), "%d_confirm", iIndex);
						hKeyValue.GetString(sCurrent, sBuffer, sizeof(sBuffer), "");
						g_hArray_PhraseConfirm.PushString(sBuffer);
						
						Format(sCurrent, sizeof(sCurrent), "%d_cancel", iIndex);
						hKeyValue.GetString(sCurrent, sBuffer, sizeof(sBuffer), "");
						g_hArray_PhraseCancel.PushString(sBuffer);
						
						Format(sCurrent, sizeof(sCurrent), "%d_prompt", iIndex);
						hKeyValue.GetString(sCurrent, sBuffer, sizeof(sBuffer), "");
						g_hArray_PhrasePrompt.PushString(sBuffer);
						
						Format(sCurrent, sizeof(sCurrent), "%d_notify", iIndex);
						hKeyValue.GetString(sCurrent, sBuffer, sizeof(sBuffer), "");
						g_hArray_PhraseNotify.PushString(sBuffer);
					}

					iIndex++;
				}

				break;
			}
		}
		while (KvGotoNextKey(hKeyValue));

		delete hKeyValue;
	}
}

void CreateClientParticle(int client)
{
	if(g_bParticle && g_bParticlesAllowed)
	{
		char particle[64];
		if (!StrEqual(g_sGameName, "tf", false))
			Format(particle, sizeof(particle), g_sParticle);
		else
			Format(particle, sizeof(particle), GetClientTeam(client) == 2 ? g_sParticleRed : g_sParticleBlu);
		
		if (!StrEqual(particle, ""))
		{
			int iEntity = CreateEntityByName("info_particle_system");
			if (IsValidEdict(iEntity) && IsPlayerAlive(client))
			{
				float fOrigin[3];
				GetEntPropVector(client, Prop_Send, "m_vecOrigin", fOrigin);
				for (int i = 0; i <= 2; i++)
					fOrigin[i] += g_fParticleOffset[i];
				TeleportEntity(iEntity, fOrigin, NULL_VECTOR, NULL_VECTOR);
				DispatchKeyValue(iEntity, "effect_name", particle);
				SetVariantString("!activator");
				AcceptEntityInput(iEntity, "SetParent", client, iEntity, 0);
				DispatchSpawn(iEntity);
				ActivateEntity(iEntity);
				AcceptEntityInput(iEntity, "Start");

				g_iClientParticle[client] = iEntity;
			}
		}
	}
}

void DisplayTeleportNotify(int client, int flags, const char[] display)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && (!flags || GetUserFlagBits(i) & flags))
		{
			PrintToChat(i, "%T", "Phrase_Teleport:Notify", client, display);
		}
	}
}

void DisplayWarpNotify(int client, int flags, const char[] display)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && (!flags || GetUserFlagBits(i) & flags))
		{
			PrintToChat(i, "%T", "Phrase_Warp:Notify", client, display);
		}
	}
}

void DeleteClientParticle(int client)
{
	if (g_iClientParticle[client] != -1)
	{
		if (IsValidEntity(g_iClientParticle[client]))
		{
			AcceptEntityInput(g_iClientParticle[client], "Deactivate");
			AcceptEntityInput(g_iClientParticle[client], "Kill");
		}
			
		g_iClientParticle[client] = -1;
	}
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