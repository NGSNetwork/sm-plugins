#pragma semicolon 1

#include <sdktools>
#include <sourcemod>
#include <steamtools>

#define VERSION "1.0"
#define BACKPACK_TF_URL		"http://backpack.tf/api/IGetPrices/v3/"

//-------------------------------------------------------------------------------------------------
public Plugin myinfo = {
	name = "[NGS] Find Item",
	author = "TheXeon",
	description = "Finds an item from someone's backpack.",
	version = VERSION,
	url = "matespastdates.servegame.com"
};

public void OnPluginStart()
{
	char path[MAX_NAME_LENGTH];
	RegConsoleCmd("sm_find", Command_Find, "Finds supplied weapon name and quality in people's backpacks.");
	BuildPath(Path_SM, path, sizeof(path), "data/backpack-tf.txt");
	if(!FileExists(path)) {
		return Plugin_Stop;
	}
}

public Action Command_Find(client, args)
{
	if(args == 0) {
		Handle menu = CreateMenu(Handler_ItemSelection);
		SetMenuTitle(menu, "Find Item");
		PrepPriceKv();
		KvGotoFirstSubKey(backpackTFPricelist);
		char name[128];
		do {
			if(!KvJumpToKey(backpackTFPricelist, "item_info")) {
				continue;
			}
			KvGetString(backpackTFPricelist, "item_name", name, sizeof(name));
			if(KvGetNum(backpackTFPricelist, "proper_name") == 1) {
				Format(name, sizeof(name), "The %s", name);
			}
			AddMenuItem(menu, name, name);
			KvGoBack(backpackTFPricelist);
		} while(KvGotoNextKey(backpackTFPricelist));
		DisplayMenu(menu, client, GetConVarInt(cvarMenuHoldTime));
		return Plugin_Handled;
	}
	int resultDefindex = -1;
	char defindex[8], name[128], itemName[128];
	GetCmdArgString(name, sizeof(name));
	bool exact = StripQuotes(name);
	PrepPriceKv();
	KvGotoFirstSubKey(backpackTFPricelist);
	Handle matches;
	if(!exact) {
		matches = CreateArray(128);
	}
	do {
		KvGetSectionName(backpackTFPricelist, defindex, sizeof(defindex));
		if(!KvJumpToKey(backpackTFPricelist, "item_info")) {
			continue;
		}
		KvGetString(backpackTFPricelist, "item_name", itemName, sizeof(itemName));
		if(KvGetNum(backpackTFPricelist, "proper_name") == 1) {
			Format(itemName, sizeof(itemName), "The %s", itemName);
		}
		KvGoBack(backpackTFPricelist);
		if(exact) {
			if(StrEqual(itemName, name, false)) {
				resultDefindex = StringToInt(defindex);
				break;
			}
		} else {
			if(StrContains(itemName, name, false) != -1) {
				resultDefindex = StringToInt(defindex); // In case this is the only match, we store the resulting defindex here so that we don't need to search to find it again
				PushArrayString(matches, itemName);
			}
		}
	} while(KvGotoNextKey(backpackTFPricelist));
	if(!exact && GetArraySize(matches) > 1) {
		Handle menu = CreateMenu(Handler_ItemSelection);
		SetMenuTitle(menu, "Search Results");
		int size = GetArraySize(matches);
		for(new i = 0; i < size; i++) {
			GetArrayString(matches, i, itemName, sizeof(itemName));
			AddMenuItem(menu, itemName, itemName);
		}
		DisplayMenu(menu, client, GetConVarInt(cvarMenuHoldTime));
		CloseHandle(matches);
		return Plugin_Handled;
	}
	if(!exact) {
		CloseHandle(matches);
	}
	if(resultDefindex == -1) {
		ReplyToCommand(client, "\x04[SM] \x01No matching item was found.");
		return Plugin_Handled;
	}
	// We now know the name of the item, time to make it work.
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			// Only trigger for client indexes actually in the game
			HTTPRequestHandle request = Steam_CreateHTTPRequest(HTTPMethod_GET, BACKPACK_TF_URL);
		}
	}
	
	return Plugin_Handled;
}