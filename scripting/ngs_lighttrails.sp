#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <regex>

public Plugin myinfo =
{
	name = "Light Trails",
	author = "bSun Halt",
	description = "Gives a light trail",
	version = "Light Trails 1.0",
	url = "http://sourcemod.net"
}

static SpriteTrail[33];
Regex hexPattern;

public void OnPluginStart()
{
	hexPattern = new Regex("/^#(?:[0-9a-f]{3}){1,2}$/i");
	RegAdminCmd("sm_trail", Command_Trail, ADMFLAG_GENERIC, "sm_trail <color>");
}

public void OnClientPutInServer(int Client)
{
	SpriteTrail[Client] = -1;
}


public Action Command_Trail(int Client, int Args)
{
	if (Args < 1 || Args > 1)
	{
		PrintToChat(Client, "[SM] sm_trail <color>");
		return Plugin_Handled;
	}
	
	char TrailColor[32];
	char ClientName[128];
	Format(ClientName, sizeof(ClientName), "customname_%i", Client);
	DispatchKeyValue(Client, "targetname", ClientName);
	int Trail = CreateEntityByName("env_spritetrail");
	DispatchKeyValue(Trail, "renderamt", "255");
	DispatchKeyValue(Trail, "rendermode", "1");
	DispatchKeyValue(Trail, "spritename", "materials/sprites/spotlight.vmt");
	DispatchKeyValue(Trail, "lifetime", "3.0");
	DispatchKeyValue(Trail, "startwidth", "8.0");
	DispatchKeyValue(Trail, "endwidth", "0.1");
	
	GetCmdArg(1, TrailColor, sizeof(TrailColor));
	
	if (SpriteTrail[Client] != -1)
		AcceptEntityInput(SpriteTrail[Client], "Kill");
	
	if (StrEqual(TrailColor, "red", false))
	{
		DispatchKeyValue(Trail, "rendercolor", "255 0 0");
	}
	else if(StrEqual(TrailColor, "blue", false))
	{
		DispatchKeyValue(Trail, "rendercolor", "0 0 255");
	}
	else if(StrEqual(TrailColor, "yellow", false))
	{
		DispatchKeyValue(Trail, "rendercolor", "255 255 0");
	}
	else if(StrEqual(TrailColor, "green", false))
	{
		DispatchKeyValue(Trail, "rendercolor", "0 255 0");
	}
	else if(StrEqual(TrailColor, "purple", false))
	{
		DispatchKeyValue(Trail, "rendercolor", "255 0 255");
	}
	else if(StrEqual(TrailColor, "orange", false))
	{
		DispatchKeyValue(Trail, "rendercolor", "255 153 0");
	}
	else if(StrEqual(TrailColor, "cyan", false))
	{
		DispatchKeyValue(Trail, "rendercolor", "0 255 255");
	}
	else if(StrEqual(TrailColor, "pink", false))
	{
		DispatchKeyValue(Trail, "rendercolor", "255 0 102");
	}
	else if(StrEqual(TrailColor, "off", false))
	{
		if (SpriteTrail[Client] != -1)
		{
			AcceptEntityInput(Trail, "Kill");
			SpriteTrail[Client] = -1;
		}
		return Plugin_Handled;
	}
	else
	{
		int decimalValue = HexToBase16Int(TrailColor);
		int rgbFromHex[3];
		rgbFromHex[0] = (decimalValue >> 16) & 255;
		rgbFromHex[1] = (decimalValue >> 8) & 255;
		rgbFromHex[2] = decimalValue & 255;
		
		char rgbString[16];
		
		Format(rgbString, 16, "%d %d %d", rgbFromHex[0], rgbFromHex[1], rgbFromHex[2]);
		DispatchKeyValue(Trail, "rendercolor", rgbString);
	}
	
	DispatchSpawn(Trail);
	SpriteTrail[Client] = Trail;
	
	float CurrentOrigin[3];
	GetClientAbsOrigin(Client, CurrentOrigin);
	CurrentOrigin[2] += 10.0;
	TeleportEntity(Trail, CurrentOrigin, NULL_VECTOR, NULL_VECTOR);
	SetVariantString(ClientName);
	
	AcceptEntityInput(Trail, "SetParent", -1, -1);
	AcceptEntityInput(Trail, "showsprite", -1, -1);
	
	PrintToChat(Client, "[SM] You've been given a %s trail!", TrailColor);
	
	return Plugin_Handled;
}

// Stock converted from:
// https://github.com/GabiGrin/hex-to-rgb-string/blob/master/index.js
stock int HexToBase16Int(char[] hex)
{
	if (!hex || hexPattern.Match(hex) == -1)
		return 0;
	ReplaceString(hex, 16, "#", "");
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
		strcopy(splitString, 6, hex);
	
	return StringToInt(splitString, 16);
}
	