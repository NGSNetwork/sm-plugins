#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <multicolors>
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
	
	char arg[64];
	char TrailColor[64];
	char ClientName[128];
	int trailcolornum;
	
	Format(ClientName, sizeof(ClientName), "customname_%i", Client);
	DispatchKeyValue(Client, "targetname", ClientName);
	int Trail = CreateEntityByName("env_spritetrail");
	DispatchKeyValue(Trail, "renderamt", "255");
	DispatchKeyValue(Trail, "rendermode", "1");
	DispatchKeyValue(Trail, "spritename", "materials/sprites/spotlight.vmt");
	DispatchKeyValue(Trail, "lifetime", "3.0");
	DispatchKeyValue(Trail, "startwidth", "8.0");
	DispatchKeyValue(Trail, "endwidth", "0.1");
	
	GetCmdArgString(arg, sizeof(arg));
	StrToLowerRemoveBlanks(arg, TrailColor, sizeof(TrailColor));
	
	if (SpriteTrail[Client] != -1)
		AcceptEntityInput(SpriteTrail[Client], "Kill");
		
	if (StrEqual(TrailColor, "off", false))
	{
		if (SpriteTrail[Client] != -1)
		{
			AcceptEntityInput(Trail, "Kill");
			SpriteTrail[Client] = -1;
		}
		return Plugin_Handled;
	}
	else if (MC_Trie != null && MC_Trie.GetValue(TrailColor, trailcolornum))
	{
		int rgbFromHex[3];
		rgbFromHex[0] = (trailcolornum >> 16) & 255;
		rgbFromHex[1] = (trailcolornum >> 8) & 255;
		rgbFromHex[2] = trailcolornum & 255;
		
		char rgbString[16];
		
		Format(rgbString, 16, "%d %d %d", rgbFromHex[0], rgbFromHex[1], rgbFromHex[2]);
		DispatchKeyValue(Trail, "rendercolor", rgbString);
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
	
	CReplyToCommand(Client, "{GREEN}[SM]{DEFAULT} You've been given a %s trail!", arg);
	
	return Plugin_Handled;
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
		if (SpriteTrail[i] != -1)
			AcceptEntityInput(SpriteTrail[i], "Kill");
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
	