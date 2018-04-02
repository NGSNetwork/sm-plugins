/**
* TheXeon
* ngs_buildinghats.sp
*
* Files:
* addons/sourcemod/plugins/ngs_buildinghats.smx
* cfg/sourcemod/buildhats.cfg
* addons/sourcemod/configs/buildinghats.cfg
*
*
* Dependencies:
* sourcemod.inc, clientprefs.inc, tf2_stocks.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <sourcemod>
#include <clientprefs>
#include <tf2_stocks>
#include <ngsutils>
#include <ngsupdater>

int g_ModelIndex[2049];
float g_flZOffset[2049];
float g_flModelScale[2049];
char g_strParticle[2049][36];
bool g_bWantsTheH[MAXPLAYERS+1];

int g_hatEnt[2049] = {INVALID_ENT_REFERENCE, ... };
int g_particleEnt[2049] = {INVALID_ENT_REFERENCE, ... };

int stringTable;
ArrayList hHatInfo = null;

float RollCooldown[MAXPLAYERS+1];

char g_sParticleList[][] =
{
	{"superrare_confetti_green"},
	{"superrare_confetti_purple"},
	{"superrare_ghosts"},
	{"superrare_greenenergy"},
	{"superrare_purpleenergy"},
	{"superrare_flies"},
	{"superrare_burning1"},
	{"superrare_burning2"},
	{"superrare_plasma1"},
	{"superrare_beams1"},
	{"unusual_storm"},
	{"unusual_blizzard"},
	{"unusual_orbit_nutsnbolts"},
	{"unusual_orbit_planets"},
	{"unusual_orbit_fire"},
	{"unusual_bubbles"},
	{"unusual_smoking"},
	{"unusual_steaming"},
	{"unusual_bubbles_green"},
	{"unusual_orbit_fire_dark"},
	{"unusual_skull_misty"},
	{"unusual_storm_knives"},
	{"unusual_orbit_jack_flaming"},
	{"unusual_fullmoon_cloudy_green"},
	{"unusual_fullmoon_cloudy_secret"},
	{"unusual_fullmoon_cloudy"},
	{"unusual_storm_knives"},
	{"unusual_storm_spooky"},
	{"unusual_zap_yellow"},
	{"unusual_orbit_cards_teamcolor_blue"},
	{"unusual_orbit_cards_teamcolor_red"},
	{"unusual_orbit_cash"},
	{"unusual_zap_green"},
	{"unusual_hearts_bubbling"},
	{"unusual_crisp_spotlights"},
	{"unusual_spotlights"},
	{"unusual_robot_holo_glow_green"},
	{"unusual_robot_holo_glow_orange"},
	{"unusual_robot_orbit_binary"},
	{"unusual_robot_orbit_binary2"},
	{"unusual_robot_orbiting_sparks"},
	{"unusual_robot_orbiting_sparks2"},
	{"unusual_robot_radioactive"},
	{"unusual_robot_time_warp"},
	{"unusual_robot_time_warp2"},
	{"unusual_robot_radioactive2"},
	{"unusual_spellbook_circle_purple"},
	{"unusual_spellbook_circle_green"},
	{"unusual_bats_flaming_proxy_green"},
	{"unusual_bats_flaming_proxy_purple"},
	{"unusual_bats_flaming_proxy_orange"},
	{"unusual_meteor_shower_parent_orange"},
	{"unusual_meteor_shower_parent_purple"},
	{"unusual_meteor_shower_parent_green"},
	{"unusual_tentmonster_purple_parent"},
	{"unusual_eyes_purple_parent"},
	{"unusual_eyes_orange_parent"},
	{"unusual_eyes_green_parent"},
	{"unusual_souls_purple_parent"},
	{"unusual_souls_green_parent"},
	{"unusual_eotl_frostbite"},
	{"unusual_eotl_oribiting_burning_duck_parent"},
	{"unusual_eotl_sunrise"},
	{"unusual_eotl_sunset"},
	{"unusual_invasion_abduction"},
	{"unusual_invasion_atomic"},
	{"unusual_invasion_atomic_green"},
	{"unusual_invasion_boogaloop"},
	{"unusual_invasion_boogaloop_2"},
	{"unusual_invasion_boogaloop_3"},
	{"unusual_invasion_codex"},
	{"unusual_invasion_codex_2"},
	{"unusual_invasion_nebula"},
	{"unusual_hw_deathbydisco_parent"},
	{"unusual_mystery_parent"},
	{"unusual_mystery_parent_green"},
	{"unusual_nether_blue"},
	{"unusual_nether_pink"},
	{"unusual_eldritch_flames_purple"},
	{"unusual_eldritch_flames_orange"}
};

ConVar g_hCvarEnabled;
bool g_bCvarEnabled;
ConVar g_hCvarUnusualChance;
float g_flCvarUnusualChance;
ConVar g_hCvarRerollCooldown;
int g_CvarRerollCooldown;

Menu g_hParticleMenu = null;
Cookie g_hClientCookie = null;

public Plugin myinfo = {
	name		= "[TF2] Building Hats",
	author		= "Pelipoika / TheXeon",
	description	= "Ain't that a cute little gun?",
	version		= "2.0.1",
	url			= "https://forums.alliedmods.net/showthread.php?p=2164412#post2164412"
}

public void OnPluginStart()
{
	HookConVarChange(g_hCvarEnabled = CreateConVar("sm_bhats_enabled", "1.0", "Enable Hats on Buildings \n 0 = Disabled \n 1 = Enabled", _, true, 0.0, true, 1.0), OnConVarChange);
	HookConVarChange(g_hCvarUnusualChance = CreateConVar("sm_bhats_unusualchance", "0.1", "Chance for a building to get an unusual effect on it's hat upon being built. 0.1 = 10%", _, true, 0.0), OnConVarChange);
	HookConVarChange(g_hCvarRerollCooldown = CreateConVar("sm_bhats_rollcooldown", "30", "Hat reroll cooldown (in seconds)", _, true, 0.0), OnConVarChange);

	HookEvent("player_builtobject",		Event_PlayerBuiltObject);
	HookEvent("player_upgradedobject",	Event_UpgradeObject);
	HookEvent("player_dropobject", 		Event_DropObject);
	HookEvent("player_carryobject",		Event_PickupObject);

	stringTable = FindStringTable("modelprecache");
	hHatInfo = new ArrayList(PLATFORM_MAX_PATH, 1);

	g_hClientCookie = new Cookie("BuildingHats", "sm_bhats_enabled", CookieAccess_Private);

	RegAdminCmd("sm_buildinghats",		 Command_iDontWantHatsOnMyThings, 0);
	RegAdminCmd("sm_bhats_reloadconfig", Command_Parse, ADMFLAG_ROOT);
	RegAdminCmd("sm_rerollhat", 		 Command_RerollHats, 0);
	RegAdminCmd("sm_buildinghateffect",  Command_ChooseBuildingEffect, ADMFLAG_ROOT);

	AutoExecConfig(true, "buildhats");

	for(int i = 0; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
			g_bWantsTheH[i] = true;
	}
}

public void OnConfigsExecuted()
{
	g_bCvarEnabled  = g_hCvarEnabled.BoolValue;
	g_flCvarUnusualChance = g_hCvarUnusualChance.FloatValue;
	g_CvarRerollCooldown = g_hCvarRerollCooldown.IntValue;
	ParseConfigurations();

	g_hParticleMenu = new Menu(Menu_SetEffect);
	g_hParticleMenu.SetTitle("[Building Hats] Hat Effects");
	for(int i = 0; i < sizeof(g_sParticleList); i++)
	{
		char info[128], display[128];
		Format(info, sizeof(info), "%s", g_sParticleList[i][0]);
		Format(display, sizeof(display), "%s", g_sParticleList[i][0]);
		g_hParticleMenu.AddItem(info, display);
	}
	g_hParticleMenu.ExitBackButton =  false;
}

public void OnClientAuthorized(int client)
{
	g_bWantsTheH[client] = true;
	RollCooldown[client] = 0.0;
}

public void OnClientCookiesCached(int client)
{
	char sValue[8];
	g_hClientCookie.GetValue(client, sValue, sizeof(sValue));

	if(sValue[0] == '\0')
		g_bWantsTheH[client] = true;
	else
		g_bWantsTheH[client] = (sValue[0] != '\0' && StringToInt(sValue));
}

public void OnMapEnd()
{
	delete g_hParticleMenu;
}

public void OnConVarChange(ConVar hConvar, const char[] strOldValue, const char[] strNewValue)
{
	g_bCvarEnabled  = g_hCvarEnabled.BoolValue;
	g_flCvarUnusualChance = g_hCvarUnusualChance.FloatValue;
	g_CvarRerollCooldown = g_hCvarRerollCooldown.IntValue;
}

public Action Command_ChooseBuildingEffect(int client, int args)
{
	if(IsValidClient(client))
		DisplayMenuSafely(g_hParticleMenu, client);

	return Plugin_Handled;
}

public int Menu_SetEffect(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsValidClient(param1))
	{
		char info[128];
		menu.GetItem(param2, info, sizeof(info));

		int iBuilding = -1;
		while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) != -1)
		{
			if(GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == param1 && GetEntProp(iBuilding, Prop_Send, "m_bPlacing") == 0 && GetEntProp(iBuilding, Prop_Send, "m_bCarried") == 0)
			{
				if(IsValidEntity(g_particleEnt[iBuilding]))
				{
					int particle = EntRefToEntIndex(g_particleEnt[iBuilding]);
					AcceptEntityInput(particle, "Stop");
					AcceptEntityInput(particle, "Kill");
				}

				int iParticle = CreateEntityByName("info_particle_system");
				if(IsValidEdict(iParticle))
				{
					float flPos[3];

					DispatchKeyValue(iParticle, "effect_name", info);
					DispatchSpawn(iParticle);

					SetVariantString("!activator");
					AcceptEntityInput(iParticle, "SetParent", iBuilding);
					ActivateEntity(iParticle);

					TFObjectType objectT = view_as<TFObjectType>(TF2_GetObjectType(iBuilding));
					if(objectT == TFObject_Dispenser)
					{
						SetVariantString("build_point_0");
					}
					else if(objectT == TFObject_Sentry)
					{
						if(GetEntProp(iBuilding, Prop_Send, "m_iUpgradeLevel") < 3)
							SetVariantString("build_point_0");
						else
							SetVariantString("rocket_r");
					}
					AcceptEntityInput(iParticle, "SetParentAttachment", iBuilding);

					GetEntPropVector(iParticle, Prop_Send, "m_vecOrigin", flPos);

					if(objectT == TFObject_Dispenser)
					{
						flPos[2] += 13.0;	//Make sure the effect is on top of the dispenser

						if(GetEntProp(iBuilding, Prop_Send, "m_iUpgradeLevel") == 3)
							flPos[2] += 8.0;	//Account for level 3 dispenser
					}

					if(GetEntProp(iBuilding, Prop_Send, "m_iUpgradeLevel") == 3 && objectT != TFObject_Dispenser)
					{
						flPos[2] += 6.5;	//Level 3 sentry offsets
						flPos[0] -= 11.0;	//Gotta get that effect on top of the missile thing
					}

					SetEntPropVector(iParticle, Prop_Send, "m_vecOrigin", flPos);
					AcceptEntityInput(iParticle, "start");

					g_particleEnt[iBuilding] = EntIndexToEntRef(iParticle);
					Format(g_strParticle[iBuilding], sizeof(g_strParticle), "%s", info);
				}
			}
		}

		menu.DisplayAt(param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
	}
}

public Action Command_RerollHats(int client, int args)
{
	if(IsValidClient(client))
	{
		if(CheckCommandAccess(client, "sm_buildinghats_access", 0))
		{
			if(RollCooldown[client] >= GetTickedTime())
			{
				ReplyToCommand(client, "Please wait %.1f seconds!", RollCooldown[client] - GetTickedTime());
				return Plugin_Handled;
			}
			else
			{
				int iBuilding = -1;
				while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) != -1)
				{
					if(GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == client
					&& GetEntProp(iBuilding, Prop_Send, "m_bPlacing") == 0
					&& GetEntProp(iBuilding, Prop_Send, "m_bCarried") == 0)
					{
						g_ModelIndex[iBuilding]  = INVALID_STRING_INDEX;
						g_flZOffset[iBuilding]   = 0.0;
						g_flModelScale[iBuilding]= 0.0;
						Format(g_strParticle[iBuilding], sizeof(g_strParticle), "");

						if (IsValidEntity(g_hatEnt[iBuilding]))
						{
							AcceptEntityInput(g_hatEnt[iBuilding], "Kill");
						}

						if(IsValidEntity(g_particleEnt[iBuilding]))
						{
							AcceptEntityInput(g_particleEnt[iBuilding], "Stop");
							AcceptEntityInput(g_particleEnt[iBuilding], "Kill");
						}

						g_particleEnt[iBuilding] = INVALID_ENT_REFERENCE;
						g_hatEnt[iBuilding] = INVALID_ENT_REFERENCE;

						CreateTimer(0.1, Timer_ReHat, iBuilding);
					}
				}

				RollCooldown[client] = GetTickedTime() + float(g_CvarRerollCooldown);
			}
		}
		else
			ReplyToCommand(client, "[SM] You do not have acces to this command.");
	}

	return Plugin_Handled;
}

public Action Command_iDontWantHatsOnMyThings(int client, int args)
{
	if(IsValidClient(client))
	{
		if(CheckCommandAccess(client, "sm_buildinghats_access", 0))
		{
			if(!g_bWantsTheH[client])
			{
				g_hClientCookie.SetValue(client, "1");
				OnClientCookiesCached(client);
				g_bWantsTheH[client] = true;
				PrintToChat(client, "[Building Hats] On");
			}
			else
			{
				g_hClientCookie.SetValue(client, "0");
				OnClientCookiesCached(client);

				g_bWantsTheH[client] = false;
				PrintToChat(client, "[Building Hats] Off");

				int iBuilding = -1;
				while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) != -1)
				{
					if(GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == client)
					{
						if (IsValidEntity(g_hatEnt[iBuilding]))
						{
							AcceptEntityInput(g_hatEnt[iBuilding], "Kill");
							g_hatEnt[iBuilding] = INVALID_ENT_REFERENCE;
						}
						if(IsValidEntity(g_particleEnt[iBuilding]))
						{
							AcceptEntityInput(g_particleEnt[iBuilding], "Stop");
							AcceptEntityInput(g_particleEnt[iBuilding], "Kill");
							g_particleEnt[iBuilding] = INVALID_ENT_REFERENCE;
						}

						if (GetEntProp(iBuilding, Prop_Send, "m_bMiniBuilding"))
						{
							SetVariantInt(0);
							AcceptEntityInput(iBuilding, "SetBodyGroup");
						}
					}
				}
			}
		}
		else
			ReplyToCommand(client, "[SM] You do not have access to this command.");
	}

	return Plugin_Handled;
}

public Action Command_Parse(int client, int args)
{
	hHatInfo.Resize(1);
	ReplyToCommand(client, "[Building Hats] Reloading config...");
	ParseConfigurations();
	return Plugin_Handled;
}

public Action Event_PickupObject(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(IsValidClient(client))
	{
		int iBuilding = event.GetInt("index");
		if(iBuilding > MaxClients && IsValidEntity(iBuilding))
		{
			if (IsValidEntity(g_hatEnt[iBuilding]))
			{
				AcceptEntityInput(g_hatEnt[iBuilding], "TurnOff");
			}
			if(IsValidEntity(g_particleEnt[iBuilding]))
			{
				AcceptEntityInput(g_particleEnt[iBuilding], "Stop");
			}
		}
	}

	return Plugin_Handled; // TODO: Determine if this should be Plugin_Continue
}

public Action Event_DropObject(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_bCvarEnabled)
		return Plugin_Continue;

	int client = GetClientOfUserId(event.GetInt("userid"));
	TFObjectType objectT = view_as<TFObjectType>(event.GetInt("object"));

	if(IsValidClient(client) && g_bWantsTheH[client])
	{
		if(!CheckCommandAccess(client, "sm_buildinghats_access", 0))
			return Plugin_Handled;

		int iBuilding = event.GetInt("index");
		if(/*iBuilding > MaxClients*/!IsValidClient(iBuilding) && IsValidEntity(iBuilding)) // TODO: See if IsValidClient is proper.
		{
			if(objectT == TFObject_Sentry && GetEntProp(iBuilding, Prop_Send, "m_bMiniBuilding"))
			{
				SetVariantInt(2);
				AcceptEntityInput(iBuilding, "SetBodyGroup");
				CreateTimer(2.0, Timer_TurnTheLightsOff, iBuilding);
			}

			if (IsValidEntity(g_hatEnt[iBuilding]))
			{
				AcceptEntityInput(g_hatEnt[iBuilding], "TurnOn");
			}

			if(IsValidEntity(g_particleEnt[iBuilding]))
			{
				AcceptEntityInput(g_particleEnt[iBuilding], "Start");
			}
		}
	}

	return Plugin_Handled;
}

public Action Event_UpgradeObject(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_bCvarEnabled)
		return Plugin_Continue;

	TFObjectType objectT = view_as<TFObjectType>(event.GetInt("object"));

	int iBuilding = event.GetInt("index");
	if(iBuilding > MaxClients && IsValidEntity(iBuilding))
	{
		int builder = GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder");
		if(IsValidClient(builder) && !g_bWantsTheH[builder] || !CheckCommandAccess(builder, "sm_buildinghats_access", 0))
			return Plugin_Handled;

		if(objectT == TFObject_Sentry)
		{
			if (IsValidEntity(g_hatEnt[iBuilding]))
			{
				AcceptEntityInput(g_hatEnt[iBuilding], "Kill");
				g_hatEnt[iBuilding] = INVALID_ENT_REFERENCE;
			}

			if(IsValidEntity(g_particleEnt[iBuilding]))
			{
				AcceptEntityInput(g_particleEnt[iBuilding], "Stop");
				AcceptEntityInput(g_particleEnt[iBuilding], "Kill");
				g_particleEnt[iBuilding] = INVALID_ENT_REFERENCE;
			}

			CreateTimer(2.0, Timer_ReHat, iBuilding);
		}
		if(objectT == TFObject_Dispenser && GetEntProp(iBuilding, Prop_Send, "m_iUpgradeLevel") == 2)
		{
			if (IsValidEntity(g_hatEnt[iBuilding]))
			{
				AcceptEntityInput(g_hatEnt[iBuilding], "Kill");
				g_hatEnt[iBuilding] = INVALID_ENT_REFERENCE;
			}

			if(IsValidEntity(g_particleEnt[iBuilding]))
			{
				AcceptEntityInput(g_particleEnt[iBuilding], "Stop");
				AcceptEntityInput(g_particleEnt[iBuilding], "Kill");
				g_particleEnt[iBuilding] = INVALID_ENT_REFERENCE;
			}

			CreateTimer(2.0, Timer_ReHat, iBuilding);
		}
	}

	return Plugin_Handled;
}

public Action Timer_ReHat(Handle timer, any iBuilding)
{
	if(!g_bCvarEnabled)
		return Plugin_Continue;

	if(!IsValidClient(iBuilding) && IsValidEntity(iBuilding)) // TODO: Use IsValidClient
	{
		char strPath[PLATFORM_MAX_PATH], strOffz[16], strScale[16], strAnima[128];
		int row = (hHatInfo.Length / 4) - 1;
		int index = (GetRandomInt(0, row)) * 4;

		hHatInfo.GetString(index+1, strPath, sizeof(strPath));
		hHatInfo.GetString(index+2, strOffz, sizeof(strOffz));
		hHatInfo.GetString(index+3, strScale, sizeof(strScale));
		hHatInfo.GetString(index+4, strAnima, sizeof(strAnima));

		TFObjectType objectT = view_as<TFObjectType>(TF2_GetObjectType(iBuilding));

		if(objectT == TFObject_Sentry)
			ParentHatEntity(iBuilding, strPath, StringToFloat(strOffz), StringToFloat(strScale), TFObject_Sentry, strAnima);
		else if(objectT == TFObject_Dispenser)
			ParentHatEntity(iBuilding, strPath, StringToFloat(strOffz), StringToFloat(strScale), TFObject_Dispenser, strAnima);
	}

	return Plugin_Handled;
}

public Action Event_PlayerBuiltObject(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_bCvarEnabled)
		return Plugin_Continue;

	int client = GetClientOfUserId(event.GetInt("userid"));
	TFObjectType objectT = view_as<TFObjectType>(event.GetInt("object"));

	if(IsValidClient(client) && g_bWantsTheH[client])
	{
		if(!CheckCommandAccess(client, "sm_buildinghats_access", 0))
			return Plugin_Handled;

		int iBuilding = event.GetInt("index");
		if(iBuilding > MaxClients && IsValidEntity(iBuilding))
		{
			if(!GetEntProp(iBuilding, Prop_Send, "m_bCarryDeploy"))
			{
				g_ModelIndex[iBuilding]  = INVALID_STRING_INDEX;
				g_flZOffset[iBuilding]   = 0.0;
				g_flModelScale[iBuilding]= 0.0;
				Format(g_strParticle[iBuilding], sizeof(g_strParticle), "");

				char strPath[PLATFORM_MAX_PATH], strOffz[16], strScale[16], strAnima[128];
				int row = (hHatInfo.Length / 4) - 1;
				int index = (GetRandomInt(0, row)) * 4;

				hHatInfo.GetString(index+1, strPath, sizeof(strPath));
				hHatInfo.GetString(index+2, strOffz, sizeof(strOffz));
				hHatInfo.GetString(index+3, strScale, sizeof(strScale));
				hHatInfo.GetString(index+4, strAnima, sizeof(strAnima));

				if(objectT == TFObject_Sentry)
				{
					if(GetEntProp(iBuilding, Prop_Send, "m_bMiniBuilding"))
					{
						SetVariantInt(2);
						AcceptEntityInput(iBuilding, "SetBodyGroup");
						CreateTimer(3.0, Timer_TurnTheLightsOff, iBuilding);
					}

					ParentHatEntity(iBuilding, strPath, StringToFloat(strOffz), StringToFloat(strScale), TFObject_Sentry, strAnima);
				//	PrintToChatAll("%s", strPath);
				}
				else if(objectT == TFObject_Dispenser)
				{
					ParentHatEntity(iBuilding, strPath, StringToFloat(strOffz), StringToFloat(strScale), TFObject_Dispenser, strAnima);
				//	PrintToChatAll("%s", strPath);
				}
			}
		}
	}

	return Plugin_Handled;
}

public Action Timer_TurnTheLightsOff(Handle timer, any iBuilding)
{
	if(!g_bCvarEnabled)
		return Plugin_Continue;

	if(!IsValidClient(iBuilding) && IsValidEntity(iBuilding)) // TODO: Make sure IsValidClient is proper
	{
		SetVariantInt(2);
		AcceptEntityInput(iBuilding, "SetBodyGroup");
	}

	return Plugin_Continue;
}

//Avert your eyes children.
void ParentHatEntity(int entity, const char[] smodel, float flZOffset = 0.0, float flModelScale, TFObjectType objectT, const char[] strAnimation)
{
	float pPos[3], pAng[3];
	int builder = GetEntPropEnt(entity, Prop_Send, "m_hBuilder");
	int prop = CreateEntityByName("prop_dynamic_override");

	char strModelPath[PLATFORM_MAX_PATH];

	if(g_ModelIndex[entity] != INVALID_STRING_INDEX)
		ReadStringTable(stringTable, g_ModelIndex[entity], strModelPath, PLATFORM_MAX_PATH);

	if(StrEqual(strModelPath, "", false))
		g_ModelIndex[entity] = PrecacheModel(smodel);

	if(IsValidEntity(prop))
	{
		if(!StrEqual(strModelPath, "", false))
			DispatchKeyValue(prop, "model", strModelPath);
		else
			DispatchKeyValue(prop, "model", smodel);

		if(g_flModelScale[entity] != 0.0)
			SetEntPropFloat(prop, Prop_Send, "m_flModelScale", g_flModelScale[entity]);
		else
			SetEntPropFloat(prop, Prop_Send, "m_flModelScale", flModelScale);

		DispatchSpawn(prop);
		AcceptEntityInput(prop, "Enable");
		SetEntProp(prop, Prop_Send, "m_nSkin", GetClientTeam(builder) - 2);

		SetVariantString("!activator");
		AcceptEntityInput(prop, "SetParent", entity);

		if(objectT == TFObject_Dispenser)
		{
			SetVariantString("build_point_0");
		}
		else if(objectT == TFObject_Sentry)
		{
			if(GetEntProp(entity, Prop_Send, "m_iUpgradeLevel") < 3)
				SetVariantString("build_point_0");
			else
				SetVariantString("rocket_r");
		}

		AcceptEntityInput(prop, "SetParentAttachment", entity);

		GetEntPropVector(prop, Prop_Send, "m_vecOrigin", pPos);
		GetEntPropVector(prop, Prop_Send, "m_angRotation", pAng);

		if(!StrEqual(strAnimation, "default", false))
		{
			SetVariantString(strAnimation);
			AcceptEntityInput(prop, "SetAnimation");
			SetVariantString(strAnimation);
			AcceptEntityInput(prop, "SetDefaultAnimation");
		}

		if(g_flZOffset[entity] != 0.0)
			pPos[2] += g_flZOffset[entity];
		else
			pPos[2] += flZOffset;

		if(objectT == TFObject_Dispenser)
		{
			pPos[2] += 13.0;	//Make sure the hat is on top of the dispenser
			pAng[1] += 180.0;	//Make hat face builder

			if(GetEntProp(entity, Prop_Send, "m_iUpgradeLevel") == 3)
			{
				pPos[2] += 8.0;	//Account for level 3 dispenser
			}
		}

		if(GetEntProp(entity, Prop_Send, "m_iUpgradeLevel") == 3 && objectT != TFObject_Dispenser)
		{
			pPos[2] += 6.5;		//Level 3 sentry offsets
			pPos[0] -= 11.0;	//Gotta get that hat on top of the missile thing
		}

		SetEntPropVector(prop, Prop_Send, "m_vecOrigin", pPos);
		SetEntPropVector(prop, Prop_Send, "m_angRotation", pAng);

		g_hatEnt[entity] = EntIndexToEntRef(prop);

		if(g_flZOffset[entity] == 0.0)
			g_flZOffset[entity] = flZOffset;

		if(g_flModelScale[entity] == 0.0)
			g_flModelScale[entity] = flModelScale;

		if(g_particleEnt[entity] == INVALID_ENT_REFERENCE && CheckCommandAccess(builder, "sm_buildinghats_unusuals", 0))
		{
			int iParticle = CreateEntityByName("info_particle_system");
			if(IsValidEdict(iParticle))
			{
				float flPos[3];
				bool kill = false;

				if(GetEntProp(entity, Prop_Send, "m_iUpgradeLevel") > 1 && StrEqual(g_strParticle[entity], "", false))
					kill = true;

				int sParticle = GetRandomInt(0, sizeof(g_sParticleList)-1);

				if(!StrEqual(g_strParticle[entity], "", false))
					DispatchKeyValue(iParticle, "effect_name", g_strParticle[entity]);
				else
				{
					if(g_flCvarUnusualChance == 1.0)	//100% Unusual chance fix?
						DispatchKeyValue(iParticle, "effect_name", g_sParticleList[sParticle][0]);
					else if(GetRandomFloat(0.0, 1.0) <= g_flCvarUnusualChance)
						DispatchKeyValue(iParticle, "effect_name", g_sParticleList[sParticle][0]);
					else
						kill = true;
				}

				if(!kill)
				{
					DispatchSpawn(iParticle);

					SetVariantString("!activator");
					AcceptEntityInput(iParticle, "SetParent", entity);
					ActivateEntity(iParticle);

					if(objectT == TFObject_Dispenser)
					{
						SetVariantString("build_point_0");
					}
					else if(objectT == TFObject_Sentry)
					{
						if(GetEntProp(entity, Prop_Send, "m_iUpgradeLevel") < 3)
							SetVariantString("build_point_0");
						else
							SetVariantString("rocket_r");
					}
					AcceptEntityInput(iParticle, "SetParentAttachment", entity);

					GetEntPropVector(iParticle, Prop_Send, "m_vecOrigin", flPos);

					if(objectT == TFObject_Dispenser)
					{
						flPos[2] += 13.0;	//Make sure the effect is on top of the dispenser

						if(GetEntProp(entity, Prop_Send, "m_iUpgradeLevel") == 3)
							flPos[2] += 8.0;	//Account for level 3 dispenser
					}

					if(GetEntProp(entity, Prop_Send, "m_iUpgradeLevel") == 3 && objectT != TFObject_Dispenser)
					{
						flPos[2] += 6.5;	//Level 3 sentry offsets
						flPos[0] -= 11.0;	//Gotta get that effect on top of the missile thing
					}

					SetEntPropVector(iParticle, Prop_Send, "m_vecOrigin", flPos);

					AcceptEntityInput(iParticle, "start");

					g_particleEnt[entity] = EntIndexToEntRef(iParticle);

					if(StrEqual(g_strParticle[entity], "", false))
						Format(g_strParticle[entity], sizeof(g_strParticle), "%s", g_sParticleList[sParticle][0]);
				}
				else
					AcceptEntityInput(iParticle, "Kill");
			}
		}
	}
}

bool ParseConfigurations()
{
	char strPath[PLATFORM_MAX_PATH];
	char strFileName[PLATFORM_MAX_PATH];
	Format(strFileName, sizeof(strFileName), "configs/buildinghats.cfg");
	BuildPath(Path_SM, strPath, sizeof(strPath), strFileName);

	LogMessage("[Building Hats] Executing configuration file %s", strPath);

	if (FileExists(strPath, true))
	{
		KeyValues kvConfig = new KeyValues("TF2_Buildinghats");
		if (kvConfig.ImportFromFile(strPath) == false) SetFailState("[Building Hats] Error while parsing the configuration file.");
		kvConfig.GotoFirstSubKey();

		do
		{
			char strMpath[PLATFORM_MAX_PATH], strOffz[16], strScale[16], strAnima[128];

			kvConfig.GetString("modelpath",	strMpath, sizeof(strMpath));
			kvConfig.GetString("offset", 	strOffz,  sizeof(strOffz));
			kvConfig.GetString("modelscale", strScale, sizeof(strScale));
			kvConfig.GetString("animation",  strAnima, sizeof(strAnima));

			PrecacheModel(strMpath);

			hHatInfo.PushString(strMpath);
			hHatInfo.PushString(strOffz);
			hHatInfo.PushString(strScale);
			hHatInfo.PushString(strAnima);
		}
		while (kvConfig.GotoNextKey());

		delete kvConfig;
	}
}

stock void DisplayMenuSafely(Menu menu, int client)
{
    if(IsValidClient(client))
    {
        if (menu == null)
        {
            PrintToConsole(client, "ERROR: Unable to open Menu.");
        }
        else
        {
            menu.Display(client, MENU_TIME_FOREVER);
        }
    }
}
