/**
* TheXeon
* ngs_lighttrails.sp
*
* Files:
* addons/sourcemod/plugins/ngs_lighttrails.smx
*
* Dependencies:
* sdktools.inc, tf2_stocks.inc, multicolors.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

// #define DEBUG

#include <sdktools>
#include <tf2_stocks>
#include <multicolors>
#include <ngsutils>
#include <ngsupdater>

public Plugin myinfo =
{
	name = "[NGS] Light Trails",
	author = "bSun Halt / TheXeon",
	description = "Gives a light trail",
	version = "1.0.3",
	url = "https://www.neogenesisnetwork.net"
}

int SpriteTrail[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};
Menu trailsMenu;

public void OnPluginStart()
{
	RegAdminCmd("sm_trail", Command_Trail, ADMFLAG_GENERIC, "sm_trail <color/hex>");
	MC_CheckTrie();
	PrepTrailsMenu();

	HookEvent("player_death", EventPlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", EventPlayerSpawn);
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
	KillTrail(client);
}

public Action EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	HideTrail(client);
	return Plugin_Continue;
}

public void EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	ShowTrail(client);
}

void PrepTrailsMenu()
{
	trailsMenu = new Menu(ChooseColorMenuHandler);
	trailsMenu.SetTitle("=== NGS Trail Menu ===");
	trailsMenu.AddItem("off", "Off!");
	trailsMenu.AddItem("chooseyourown", "Make your own!");
	if (MC_Trie != null)
	{
		StringMapSnapshot snapshot = MC_Trie.Snapshot();
		for (int i = 0; i < snapshot.Length; i++)
		{
			char[] buffer = new char[snapshot.KeyBufferSize(i)];
			snapshot.GetKey(i, buffer, snapshot.KeyBufferSize(i));
			trailsMenu.AddItem(buffer, buffer);
		}
		delete snapshot;
	}
}

public Action Command_Trail(int client, int args)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	if (args == 0)
	{
		trailsMenu.Display(client, MENU_TIME_FOREVER);
		return Plugin_Handled;
	}

	char arg[64];
	char TrailColor[64];
	char ClientName[128];
	int trailcolornum;

	Format(ClientName, sizeof(ClientName), "customname_%i", client);
	DispatchKeyValue(client, "targetname", ClientName);
	int Trail = CreateEntityByName("env_spritetrail");
	DispatchKeyValue(Trail, "renderamt", "255");
	DispatchKeyValue(Trail, "rendermode", "1");
	DispatchKeyValue(Trail, "spritename", "materials/sprites/spotlight.vmt");
	DispatchKeyValue(Trail, "lifetime", "3.0");
	DispatchKeyValue(Trail, "startwidth", "8.0");
	DispatchKeyValue(Trail, "endwidth", "0.1");

	GetCmdArgString(arg, sizeof(arg));
	StrToLowerRemoveBlanks(arg, TrailColor, sizeof(TrailColor));

	KillTrail(client);

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

		CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You've been given a {%s}%s{DEFAULT} trail!", TrailColor, TrailColor);

		Format(rgbString, sizeof(rgbString), "%d %d %d", rgbFromHex[0], rgbFromHex[1], rgbFromHex[2]);
		DispatchKeyValue(Trail, "rendercolor", rgbString);
	}
	else
	{
		int decimalValue = StringToHex(TrailColor);
		char rgbString[16];
		if (decimalValue == -1)
		{
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} Invalid color/hex! You've been given a {BLACK}black{DEFAULT} trail!");
			Format(rgbString, sizeof(rgbString), "0 0 0");
		}
		else
		{
			char printHex[16];
			int rgbFromHex[3];
			rgbFromHex[0] = (decimalValue >> 16) & 255;
			rgbFromHex[1] = (decimalValue >> 8) & 255;
			rgbFromHex[2] = decimalValue & 255;
			Format(rgbString, sizeof(rgbString), "%d %d %d", rgbFromHex[0], rgbFromHex[1], rgbFromHex[2]);
			Format(printHex, sizeof(printHex), "%X%X%X%X%X%X", 
				(decimalValue >> 20) & 15, (decimalValue >> 16) & 15, (decimalValue >> 12) & 15,
				(decimalValue >> 8) & 15, (decimalValue >> 4) & 15, decimalValue & 15);
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} You've been given a \x07%scolored{DEFAULT} trail!", printHex, decimalValue);
		}
		DispatchKeyValue(Trail, "rendercolor", rgbString);
	}

	DispatchSpawn(Trail);
	SpriteTrail[client] = EntIndexToEntRef(Trail);

	float CurrentOrigin[3];
	GetClientAbsOrigin(client, CurrentOrigin);
	CurrentOrigin[2] += 10.0;
	TeleportEntity(Trail, CurrentOrigin, NULL_VECTOR, NULL_VECTOR);
	SetVariantString(ClientName);

	AcceptEntityInput(Trail, "SetParent");
	AcceptEntityInput(Trail, "showsprite");

	return Plugin_Handled;
}

public int ChooseColorMenuHandler(Menu menu, MenuAction action, int client, int choice)
{
	if (action == MenuAction_Select)
	{
		char item[MAX_BUFFER_LENGTH];
		if (menu.GetItem(choice, item, sizeof(item)))
		{
			if (StrEqual("chooseyourown", item))
			{
				CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Provide a hex number or existing color for the trail command. Usage: sm_trail <color/hex>");
			}
			else
			{
				FakeClientCommand(client, "sm_trail %s", item);
			}
		}
	}
}

stock void KillTrail(int client)
{
	if (SpriteTrail[client] == INVALID_ENT_REFERENCE) return;
	int entIndex = EntRefToEntIndex(SpriteTrail[client]);
	if (IsValidEntity(entIndex))
	{
		AcceptEntityInput(entIndex, "Kill");
		SpriteTrail[client] = INVALID_ENT_REFERENCE;
	}
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsValidClient(i))
			OnClientDisconnect(i);
}

stock void ShowTrail(int client)
{
	if (IsValidClient(client, true) && SpriteTrail[client] != INVALID_ENT_REFERENCE)
	{
		int entIndex = EntRefToEntIndex(SpriteTrail[client]);
		PrintToServerDebug("Client %d is getting their trail shown!", client);
		if (IsValidEntity(entIndex))
		{
			DispatchKeyValue(entIndex, "renderamt", "255");
			DispatchKeyValue(entIndex, "lifetime", "3.0");
		}
	}
}

stock void HideTrail(int client)
{
	if (IsValidClient(client) && SpriteTrail[client] != INVALID_ENT_REFERENCE)
	{
		int entIndex = EntRefToEntIndex(SpriteTrail[client]);
		if (IsValidEntity(entIndex))
		{
			PrintToServerDebug("Client %d is getting their trail hidden!", client);
			DispatchKeyValue(entIndex, "renderamt", "0");
			DispatchKeyValue(entIndex, "lifetime", "0.0");
		}
	}
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if (condition == TFCond_Cloaked || 
		condition == TFCond_Disguised || 
		condition == TFCond_Disguising)
	{
		HideTrail(client);
	}
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if ((condition == TFCond_Cloaked && 
			(!TF2_IsPlayerInCondition(client, TFCond_Disguised) &&
			!TF2_IsPlayerInCondition(client, TFCond_Disguising))) || 
		((condition == TFCond_Disguised || 
			condition == TFCond_Disguising) && 
			!TF2_IsPlayerInCondition(client, TFCond_Cloaked)))
	{
		ShowTrail(client);
	}
}

// Stock converted from:
// https://github.com/GabiGrin/hex-to-rgb-string/blob/master/index.js
stock int StringToHex(char hex[64])
{
	Regex hexPattern = new Regex("^(?:[0-9a-f]{3}){1,2}$", PCRE_CASELESS);
	ReplaceString(hex, sizeof(hex), "#", "");
	ReplaceString(hex, sizeof(hex), "0x", "", false);
	int match = hexPattern.Match(hex);
	if (match != -1)
	{
		char substring[16];
		hexPattern.GetSubString(0, substring, sizeof(substring));
		if (substring[0] == '\0') // All this logic because PCRE_NOTEMPTY doesn't generate properly
		{
			delete hexPattern;
			return -1;
		}
	}
	else
	{
		delete hexPattern;
		return -1;
	}
	char splitString[64];
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
