////////////////////////////////////////////////////////////
//
//			Fysics Control
//				(for TF2)
//			by thaCURSEDpie
//
//			2012-08-19
//
//			version 1.0.4
//
//
//			This plugin aims to give server-admins
//			greater control over the game's physics.
//
////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////
//
//			Includes et cetera
//
////////////////////////////////////////////////////////////
#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION			 	"1.0.4"
#define SHORT_DESCRIPTION	 		"Fysics Control by thaCURSEDpie"
#define ADMINCMD_MIN_LEVEL			ADMFLAG_SLAY

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
// #include <smlib>
#include <tf2_stocks>


////////////////////////////////////////////////////////////
//
//			Global vars
//
////////////////////////////////////////////////////////////
//-- Constants
const float Pi						= 3.1415926535898;

//-- Handles
ConVar hEnabled, hAirstrafeMult, hBhopMult, hBhopMaxDelay, hBhopZMult, hBhopAngleRatio, hBhopLazyMode,
	hAllowBounce, hBounceMult, hBhopMaxSpeed, hBhopEnabled, hAirstrafeIgnoreScouts;

//-- Values
float fAirstrafeMult			= 1.0;
float fBhopMult				 	= 1.0;
float fBhopMaxDelay				= 0.2;
float fBhopZMult				= 1.0;
float fBhopAngleRatio			= 0.5;
bool bAirstrafeIgnoreScouts = true;
bool bModEnabled				= true;
bool bBhopLazyMode			 	= false;
bool bAllowBounce				= false;
bool bBhopEnabled				= true;	
float fBounceMult				= 1.0;
float fBhopMaxSpeed				= -1.0;

//-- Player properties
float fAirstrafeMults[MAXPLAYERS];
float fBhopMults[MAXPLAYERS];
float fBhopZMults[MAXPLAYERS];
float fOldVels[MAXPLAYERS][3];
float fBhopAngleRatios[MAXPLAYERS];
bool bIsInAir[MAXPLAYERS];
bool bJumpPressed[MAXPLAYERS];
float fMomentTouchedGround[MAXPLAYERS];
float fBhopMaxDelays[MAXPLAYERS];
int iBounceInfo[MAXPLAYERS];
bool bIsAllowedToBounce[MAXPLAYERS];
bool bBhopLazyModes[MAXPLAYERS];
float fBounceMults[MAXPLAYERS];
float fBhopMaxSpeeds[MAXPLAYERS];
bool bIsAllowedToBhop[MAXPLAYERS];

////////////////////////////////////////////////////////////
//
//			Mod description
//
////////////////////////////////////////////////////////////
public Plugin myinfo = {
	name		 	= "[NGS] Fysics Control",
	author		   	= "thaCURSEDpie / TheXeon",
	description	 	= "This plugin aims to give server admins more control over the game physics.",
	version		  	= PLUGIN_VERSION,
	url			  	= "http://www.sourcemod.net"
}


////////////////////////////////////////////////////////////
//
//			OnPluginStart
//
////////////////////////////////////////////////////////////
public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	//---- Cmds
	RegAdminCmd("sm_fc_reload", CmdReload, ADMINCMD_MIN_LEVEL, "Reloads Fysics Control");
	
	// Airstrafe
	RegAdminCmd("sm_airstrafe_mult", CmdAirstrafeMult, ADMINCMD_MIN_LEVEL, "Change an individual user's airstrafe multiplier");
	
	// Bhop
	RegAdminCmd("sm_bhop_mult", CmdBhopMult, ADMINCMD_MIN_LEVEL, "Change an individual users's horizontal bhop multiplier (-1 disables bhop)");
	RegAdminCmd("sm_bhop_zmult", CmdBhopZMult, ADMINCMD_MIN_LEVEL, "Change an indivicual users's vertical bhop multiplier");
	RegAdminCmd("sm_bhop_lazymode", CmdBhopLazyMode, ADMINCMD_MIN_LEVEL, "Allow/dissallow an individual user to bunnyhop by holding +jump");
	RegAdminCmd("sm_bhop_enabled", CmdBhopEnabled, ADMINCMD_MIN_LEVEL, "Change whether or not an individual user can bunnyhop");
	
	// Bounce
	RegAdminCmd("sm_bounce_mult", CmdBounceMult, ADMINCMD_MIN_LEVEL, "Change an individual users's bounce multiplier");
	RegAdminCmd("sm_bounce_enabled", CmdBounceEnabled, ADMINCMD_MIN_LEVEL, "Allow/dissallow an individual user to bounce");
		
	//---- Convars	
	CreateConVar("fc_version", PLUGIN_VERSION, SHORT_DESCRIPTION, FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
	
	// Overall mod
	hEnabled 			= CreateConVar("fc_enabled", "1", "Enable Fysics Control", FCVAR_NONE);
	
	// Airstrafe
	hAirstrafeMult 		= CreateConVar("fc_airstrafe_mult", "1.0", "The multiplier to apply to airstrafing", FCVAR_NONE, true, 0.0, true, 1.0);
	hAirstrafeIgnoreScouts = CreateConVar("fc_airstrafe_ignorescouts", "1", "Sets the airstrafe multiplier to ignore scouts, since this tends to screw up double-jumps", FCVAR_NONE);
	
	// Bhop
	hBhopEnabled 		= CreateConVar("fc_bhop_enabled", "1", "Whether or not players can bunnyhop", FCVAR_NONE);
	hBhopMult 			= CreateConVar("fc_bhop_mult", "1.0", "Horizontal boost to apply to bunnyhopping", FCVAR_NONE, true, 0.0);
	hBhopMaxDelay		= CreateConVar("fc_bhop_maxdelay", "0.2", "Maximum time in seconds, after which the player has touched the ground and can still get a bhop boost.", FCVAR_NONE);
	hBhopZMult 			= CreateConVar("fc_bhop_zmult", "1.0", "Boost to apply to vertical velocity when bunnyhopping", FCVAR_NONE);
	hBhopAngleRatio 	= CreateConVar("fc_bhop_angleratio", "0.5", "Ratio between old and new velocity to be used with bunnyhopping", FCVAR_NONE, true, 0.0, true, 1.0);
	hBhopLazyMode 		= CreateConVar("fc_bhop_lazymode", "0", "Whether or not player can bunnyhop simply by holding +jump", FCVAR_NONE);
	hBhopMaxSpeed		= CreateConVar("fc_bhop_maxspeed", "-1.0", "The maximum speed for bunnyhopping. Use -1.0 for no max speed.", FCVAR_NONE, true, -1.0);
	
	// Bounce
	hAllowBounce 		= CreateConVar("fc_bounce_enabled", "0", "Whether or not players can bounce", FCVAR_NONE);	
	hBounceMult 		= CreateConVar("fc_bounce_mult", "1.0", "Modifies the strenght of a bounce", FCVAR_NONE, true, 0.0);	
	
	//---- Convar changed hooks
	// Overall mod
	HookConVarChange(hEnabled, OnEnabledChanged);
	
	// Airstrafe
	HookConVarChange(hAirstrafeMult, OnAirstrafeMultChanged);	
	HookConVarChange(hAirstrafeIgnoreScouts, OnAirstrafeIgnoreScoutsChanged);
	
	// Bhop
	HookConVarChange(hBhopMult, OnBhopMultChanged);
	HookConVarChange(hBhopMaxDelay, OnBhopMaxDelayChanged);
	HookConVarChange(hBhopZMult, OnBhopZMultChanged);
	HookConVarChange(hBhopAngleRatio, OnBhopAngleRatioChanged);
	HookConVarChange(hBhopLazyMode, OnBhopLazyModeChanged);
	HookConVarChange(hBhopMaxSpeed, OnBhopMaxSpeedChanged);
	HookConVarChange(hBhopEnabled, OnBhopEnabledChanged);
	
	// Bounce
	HookConVarChange(hAllowBounce, OnAllowBounceChanged);	
	HookConVarChange(hBounceMult, OnBounceMultChanged);	
	
	Init();
}


////////////////////////////////////////////////////////////
//
//			Commands
//
////////////////////////////////////////////////////////////
public Action CmdReload(int client, int args)
{
	Init();
	ReplyToCommand(client, "Fysics Control reloaded!");
	
	return Plugin_Handled;
}

public Action CmdBhopMult(int client, int args)
{
	HandleCmdMult(client, args, "sm_bhop_mult", fBhopMults);
	
	return Plugin_Handled;
}

public Action CmdBhopZMult(int client, int args)
{
	HandleCmdMult(client, args, "sm_bhop_zmult", fBhopZMults);
	
	return Plugin_Handled;
}

public Action CmdAirstrafeMult(int client, int args)
{
	HandleCmdMult(client, args, "sm_airstrafe_mult", fAirstrafeMults);
	
	return Plugin_Handled;
}

public Action CmdBounceMult(int client, int args)
{
	HandleCmdMult(client, args, "sm_bounce_zmult", fBounceMults);
	
	return Plugin_Handled;
}

public Action CmdBhopEnabled(int client, int args)
{
	HandleCmdBool(client, args, "sm_bhop_enabled", bIsAllowedToBhop);
	
	return Plugin_Handled;
}

public Action CmdBounceEnabled(int client, int args)
{
	HandleCmdBool(client, args, "sm_bounce_enabled", bIsAllowedToBounce);
	
	return Plugin_Handled;
}

public Action CmdBhopLazyMode(int client, int args)
{
	HandleCmdBool(client, args, "sm_bhop_lazymode", bBhopLazyModes);
	
	return Plugin_Handled;
}


////////////////////////////////////////////////////////////
//
//			Command handling
//
////////////////////////////////////////////////////////////
public void HandleCmdBool(int client, int args, char[] cmdName, bool[] targetArray)
{
	if (args < 2)
	{
		char buf[300] = "[SM] Usage: ";
		StrCat(buf, sizeof(buf), cmdName);
		StrCat(buf, sizeof(buf), " <#userid|name> [amount]");
		
		ReplyToCommand(client, buf);
		
		return;
	}
	
	int clients[MAXPLAYERS], nTargets;
	char targetName[MAX_TARGET_LENGTH];
	
	if (GetTargetedClients(client, clients, nTargets, targetName) == 1)
	{
		return;
	}
	
	char arg2[20];
	GetCmdArg(2, arg2, sizeof(arg2));
	int amount = StringToInt(arg2);
	
	if (amount < 0)		// This line will cause a tag mismatch warning. As bools are represented as either "1" or "0" in-game, there is nothing wrong with this method (as far as I know).
	{
		ReplyToCommand(client, "[SM] %t", "Invalid Amount");
		
		return;
	}
	
	for (int i = 0; i < nTargets; i++)
	{
		targetArray[clients[i]] = view_as<bool>(amount);
	}
	
	ReplyToCommand(client, "[FC] Successfully applied cmd %s with value %b to %s!", cmdName, amount, targetName);
}

public void HandleCmdMult(int client, int args, char[] cmdName, float[] targetArray)
{
	if (args < 2)
	{
		char buf[300] = "[SM] Usage: ";
		StrCat(buf, sizeof(buf), cmdName);
		StrCat(buf, sizeof(buf), " <#userid|name> [amount]");
		
		ReplyToCommand(client, buf);
		
		return;
	}
	
	int clients[MAXPLAYERS];
	int nTargets = 0;
	
	char targetName[MAX_TARGET_LENGTH];
	
	if (GetTargetedClients(client, clients, nTargets, targetName) == 1)
	{
		return;
	}
	
	float amount = 0.0;
	
	char arg2[20];
	GetCmdArg(2, arg2, sizeof(arg2));
	
	if (StringToFloatEx(arg2, amount) == 0 || amount < 0)
	{
		ReplyToCommand(client, "[SM] %t", "Invalid Amount");
		
		return;
	}
	
	for (int i = 0; i < nTargets; i++)
	{
		targetArray[clients[i]] = amount;
	}
	
	ReplyToCommand(client, "[FC] Successfully applied cmd %s with value %f to %s!", cmdName, amount, targetName);
}

// Gets the clients the admin wants to target
// 		I got this somewhere from the SourceMod wiki, can't remember where :-(
public int GetTargetedClients(int admin, int clients[MAXPLAYERS], int &targetCount, char[] targetName)
{
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	bool tn_is_ml;
	
	if ((targetCount = ProcessTargetString(
			arg,
			admin,
			clients,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			targetName,
			MAX_TARGET_LENGTH,
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(admin, targetCount);
		
		return 1;
	}
	
	return 0;
}


////////////////////////////////////////////////////////////
//
//			Init
//
////////////////////////////////////////////////////////////
public void Init()
{
	//-- Init some arrays and values
	for (int i = 1; i <= MaxClients; i++)
	{
		hAirstrafeMult.SetFloat(fAirstrafeMult);
		hBhopMult.SetFloat(fBhopMult);
		hBhopMaxDelay.SetFloat(fBhopMaxDelay);
		hBhopZMult.SetFloat(fBhopZMult);
		hBhopAngleRatio.SetFloat(fBhopAngleRatio);
		hAllowBounce.SetBool(bAllowBounce);
		hBhopLazyMode.SetBool(bBhopLazyMode);
		hBhopEnabled.SetBool(bBhopEnabled);
		hBounceMult.SetFloat(fBounceMult);
		hBhopMaxSpeed.SetFloat(fBhopMaxSpeed);
		
		fAirstrafeMults[i] = fAirstrafeMult;
		fBhopMults[i] = fBhopMult;
		fBhopMaxDelays[i] = fBhopMaxDelay;
		fBhopZMults[i] = fBhopZMult;
		fBhopAngleRatios[i] = fBhopAngleRatio;
		bIsAllowedToBounce[i] = bAllowBounce;
		bBhopLazyModes[i] = bBhopLazyMode;
		fBounceMults[i] = fBounceMult;
		fBhopMaxSpeeds[i] = fBhopMaxSpeed;
		bIsAllowedToBhop[i] = bBhopEnabled;
		
		if (IsValidClient(i))
		{
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
			SDKHook(i, SDKHook_PostThink, OnPostThink);
		}
	}
}


////////////////////////////////////////////////////////////
//
//			OnClientPutInServer
//
////////////////////////////////////////////////////////////
public void OnClientPutInServer(int client)
{	
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_PostThink, OnPostThink);
}


////////////////////////////////////////////////////////////
//
//			Convars Changed Hooks
//
////////////////////////////////////////////////////////////
public void OnEnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	bModEnabled = convar.BoolValue;
}

public void OnBhopEnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	bBhopEnabled = convar.BoolValue;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		bIsAllowedToBhop[i] = bBhopEnabled;
	}
}

public void OnAirstrafeMultChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	fAirstrafeMult = GetConVarFloat(convar);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		fAirstrafeMults[i] = fAirstrafeMult;
	}
}

public void OnAirstrafeIgnoreScoutsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	bAirstrafeIgnoreScouts = convar.BoolValue;
}

public void OnAllowBounceChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	bAllowBounce = convar.BoolValue;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		bIsAllowedToBounce[i] = bAllowBounce;
	}
}

public void OnBounceMultChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	fBounceMult = GetConVarFloat(convar);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		fBounceMults[i] = fBounceMult;
	}
}

public void OnBhopLazyModeChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	bBhopLazyMode = GetConVarBool(convar);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		bBhopLazyModes[i] = bBhopLazyMode;
	}
}

public void OnBhopMaxSpeedChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	fBhopMaxSpeed = GetConVarFloat(convar);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		fBhopMaxSpeeds[i] = fBhopMaxSpeed;
	}
}

public void OnBhopMultChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{	
	fBhopMult = GetConVarFloat(convar);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		fBhopMults[i] = fBhopMult;
	}
}

public void OnBhopAngleRatioChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{	
	fBhopAngleRatio = GetConVarFloat(convar);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		fBhopAngleRatios[i] = fBhopAngleRatio;
	}
}

public void OnBhopZMultChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{	
	fBhopZMult = GetConVarFloat(convar);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		fBhopZMults[i] = fBhopZMult;
	}
}

public void OnBhopMaxDelayChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	float oldMult = fBhopMaxDelay;
	
	fBhopMaxDelay = GetConVarFloat(convar);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (fBhopMaxDelays[i] == oldMult)
		{
			fBhopMaxDelays[i] = fBhopMaxDelay;
		}
	}
}


////////////////////////////////////////////////////////////
//
//			OnPlayerRunCmd
//
////////////////////////////////////////////////////////////
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!bModEnabled)
	{
		return Plugin_Continue;
	}
	
	if (bIsInAir[client])
	{			
		if (!bAirstrafeIgnoreScouts || TF2_GetPlayerClass(client) != TFClass_Scout)
		{
			vel[0] *= fAirstrafeMults[client];
			vel[1] *= fAirstrafeMults[client];
		}
		
		if (bIsAllowedToBounce[client])
		{
			if (buttons & IN_JUMP && buttons & IN_DUCK)
			{
				iBounceInfo[client] = 1;
			}
			else
			{
				iBounceInfo[client] = 0;
			}
		}
	}
	else
	{	
		if (iBounceInfo[client] == 1)
		{
			if (buttons & IN_JUMP && buttons & IN_DUCK)
			{
				iBounceInfo[client] = 2;
			}
		}
		else if (buttons & IN_JUMP)
		{
			bJumpPressed[client] = true;
		}
	}
	
	return Plugin_Continue;
}


////////////////////////////////////////////////////////////
//
//			OnTakeDamage
//
////////////////////////////////////////////////////////////
public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!IsValidClient(victim))
	{
		return Plugin_Continue;
	}
	
	if (damagetype & DMG_FALL)
	{
		if (iBounceInfo[victim] == 1) // Block damage is the player is bouncing
		{
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}


////////////////////////////////////////////////////////////
//
//			OnPostThink
//
////////////////////////////////////////////////////////////
public void OnPostThink(int client)
{
	if (!bModEnabled || !IsValidEntity(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}	
	
	if (iBounceInfo[client] == 2)
	{
		iBounceInfo[client] = 0;
		
		fOldVels[client][2] *= -fBounceMults[client];
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fOldVels[client]);
	}
	else if (bJumpPressed[client])
	{			
		bJumpPressed[client] = false;
		
		if (bBhopEnabled && bIsAllowedToBhop[client] && GetTickedTime() - fMomentTouchedGround[client] <= fBhopMaxDelays[client])
		{			
			float fNewVel[3];
			
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", fNewVel);
			
			float fAngle = GetVectorAngle(fNewVel[0], fNewVel[1]);
			float fOldAngle = GetVectorAngle(fOldVels[client][0], fOldVels[client][1]);
			
			float fSpeed = SquareRoot(fOldVels[client][0] * fOldVels[client][0] + fOldVels[client][1] * fOldVels[client][1]);
			fSpeed *= fBhopMults[client];
			
			float fNewAngle = (fAngle * fBhopAngleRatios[client] + fOldAngle) / (fBhopAngleRatios[client] + 1);
			
			// There are some strange instances we need to filter out, else the player sometimes gets propelled backwards
			if ((fOldAngle < 0) && (fNewAngle >= 0))
			{
				fNewAngle = fAngle;
			}
			else if ((fNewAngle < 0) && (fOldAngle >= 0) )
			{
				fNewAngle = fAngle;
			}		
			
			if (bBhopLazyModes[client])
			{
				fNewVel[2] = 300.0;
			}
			
			if (fSpeed > fBhopMaxSpeeds[client] && fBhopMaxSpeeds[client] >= 0.0)
			{
				fSpeed = fBhopMaxSpeeds[client];
			}
			
			fNewVel[0] = fSpeed * Cosine(fAngle);
			fNewVel[1] = fSpeed * Sine(fAngle);			
			fNewVel[2] *= fBhopZMults[client];
			
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fNewVel);
		}
	}
	
	// Find out if the player is on the ground or in the air
	int iGroundEntity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
	
	if (iGroundEntity == -1)
	{					
		// Air	
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", fOldVels[client]);
		bIsInAir[client] = true;
	}
	else
	{		
		// Ground or entity
		if (bIsInAir[client])
		{
			fMomentTouchedGround[client] = GetTickedTime();
			bIsInAir[client] = false;
		}
	}
}


/////////////////////////////////////////////////////////
//
//		 GetVectorAngle
//
//		 Notes:
//		  Get the angle for the respective vector
//		  
/////////////////////////////////////////////////////////
float GetVectorAngle(float x, float y)
{
	// set this to an arbitrary value, which we can use for error-checking
	float theta=1337.00;
	
	// some math :)
	if (x>0)
	{
		theta = ArcTangent(y/x);
	}
	else if ((x<0) && (y>=0))
	{
		theta = ArcTangent(y/x) + Pi;
	}
	else if ((x<0) && (y<0))
	{
		theta = ArcTangent(y/x) - Pi;
	}
	else if ((x==0) && (y>0))
	{
		theta = 0.5 * Pi;
	}
	else if ((x==0) && (y<0))
	{
		theta = -0.5 * Pi;
	}
	
	// let's return the value
	return theta;		
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
