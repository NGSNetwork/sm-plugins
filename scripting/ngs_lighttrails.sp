/**
* TheXeon
* ngs_autorestart.sp
*
* Files:
* addons/sourcemod/plugins/ngs_autorestart.smx
* cfg/sourcemod/autorestart.cfg
*
* Dependencies:
* sourcemod.inc, sdktools.inc, multicolors.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <ngsutils>
#include <ngsupdater>

public Plugin myinfo =
{
	name = "[NGS] Light Trails",
	author = "bSun Halt / TheXeon",
	description = "Gives a light trail",
	version = "1.0.0",
	url = "http://sourcemod.net"
}

static int SpriteTrail[MAXPLAYERS + 1];

public void OnPluginStart()
{
	RegAdminCmd("sm_trail", Command_Trail, ADMFLAG_GENERIC, "sm_trail <color/hex>");
}

public void OnMapStart()
{
	PrecacheModel("materials/sprites/spotlight.vmt");
}

public void OnClientPutInServer(int client)
{
	SpriteTrail[client] = INVALID_ENT_REFERENCE;
}

public void OnClientDisconnect(int client)
{
	if (IsValidEntity(SpriteTrail[client]))
	{
		AcceptEntityInput(SpriteTrail[client], "Kill");
		SpriteTrail[client] = INVALID_ENT_REFERENCE;
	}
}

public Action Command_Trail(int client, int args)
{
	if (args == 0)
	{
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Usage: sm_trail <color/hex>");
		return Plugin_Handled;
	}

	char arg[64];
	char TrailColor[64];
//	char ClientName[128];
	int trailcolornum;

//	Format(ClientName, sizeof(ClientName), "customname_%i", client);
//	DispatchKeyValue(client, "targetname", ClientName);
	int Trail = CreateEntityByName("env_spritetrail");
	DispatchKeyValue(Trail, "renderamt", "255");
	DispatchKeyValue(Trail, "rendermode", "1");
	DispatchKeyValue(Trail, "spritename", "materials/sprites/spotlight.vmt");
	DispatchKeyValue(Trail, "lifetime", "3.0");
	DispatchKeyValue(Trail, "startwidth", "8.0");
	DispatchKeyValue(Trail, "endwidth", "0.1");

	GetCmdArgString(arg, sizeof(arg));
	StrToLowerRemoveBlanks(arg, TrailColor, sizeof(TrailColor));

	if (IsValidEntity(SpriteTrail[client]))
	{
		AcceptEntityInput(SpriteTrail[client], "Kill");
		SpriteTrail[client] = INVALID_ENT_REFERENCE;
	}

	if (StrEqual(TrailColor, "off", false))
	{
		if (IsValidEntity(Trail))
		{
			AcceptEntityInput(Trail, "Kill");
		}
		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Your trail has been disabled!");
		return Plugin_Handled;
	}
	else if (MC_Trie != null && MC_Trie.GetValue(TrailColor, trailcolornum))
	{
		int rgbFromHex[3];
		rgbFromHex[0] = (trailcolornum >> 16) & 255;
		rgbFromHex[1] = (trailcolornum >> 8) & 255;
		rgbFromHex[2] = trailcolornum & 255;

		char rgbString[16];

		Format(rgbString, sizeof(rgbString), "%d %d %d", rgbFromHex[0], rgbFromHex[1], rgbFromHex[2]);
		DispatchKeyValue(Trail, "rendercolor", rgbString);
	}
	else
	{
		int decimalValue = StringToHex(TrailColor);
		int rgbFromHex[3];
		rgbFromHex[0] = (decimalValue >> 16) & 255;
		rgbFromHex[1] = (decimalValue >> 8) & 255;
		rgbFromHex[2] = decimalValue & 255;

		char rgbString[16];

		Format(rgbString, 16, "%d %d %d", rgbFromHex[0], rgbFromHex[1], rgbFromHex[2]);
		DispatchKeyValue(Trail, "rendercolor", rgbString);
	}

	DispatchSpawn(Trail);
	SpriteTrail[client] = Trail;

	float CurrentOrigin[3];
	GetClientAbsOrigin(client, CurrentOrigin);
	CurrentOrigin[2] += 10.0;
	TeleportEntity(Trail, CurrentOrigin, NULL_VECTOR, NULL_VECTOR);
//	SetVariantString(ClientName);

	AcceptEntityInput(Trail, "SetParent", -1, -1);
	AcceptEntityInput(Trail, "showsprite", -1, -1);

	CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You've been given a %s trail!", arg);

	return Plugin_Handled;
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsValidClient(i) && IsValidEntity(SpriteTrail[i]))
			AcceptEntityInput(SpriteTrail[i], "Kill");
}

// Stock converted from:
// https://github.com/GabiGrin/hex-to-rgb-string/blob/master/index.js
stock int StringToHex(char hex[64])
{
	Regex hexPattern = new Regex("/^#(?:[0-9a-f]{3}){1,2}$/i");
	if (!hex || hexPattern.Match(hex) == -1)
	{
		delete hexPattern;
		return 0;
	}
	ReplaceString(hex, sizeof(hex), "#", "");
	ReplaceString(hex, sizeof(hex), "0x", "", false);
	char splitString[6];
	if (strlen(hex) == 3)
	{
		for (int i = 0; i < 5; i += 2)
		{
			splitString[i] = hex[i/2];
			splitString[i + 1] = hex[i/2];
		}
	}
	else
		strcopy(splitString, sizeof(splitString), hex);

	delete hexPattern;
	return StringToInt(splitString, 16);
}


// Credit to berni: https://forums.alliedmods.net/showpost.php?p=1008853&postcount=4
stock int StrToLowerRemoveBlanks(const char[] str, char[] dest, int destsize) {

	int n=0, x=0;
	while (str[n] != '\0' && x < (destsize - 1)) { // Make sure we are inside bounds

		int character = str[n++]; // Caching

		if (character == ' ') { // Am I nothing ?
			// Let's do nothing !
			continue;
		}
		else if (IsCharUpper(character)) { // Am I big ?
			character = CharToLower(character); // Big becomes low
		}

		dest[x++] = character; // Write into our new string
	}

	dest[x++] = '\0'; // Finalize with the end ( = always 0 for strings)

	return x; // return number of bytes written for later proove
}
