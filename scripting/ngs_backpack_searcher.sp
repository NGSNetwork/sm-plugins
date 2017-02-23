#pragma dynamic 524288
#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <SteamWorks>
#include <morecolors>

#define PLUGIN_VERSION "1.0"
#define STEAM_API "http://api.steampowered.com/IEconItems_440/GetPlayerItems/v0001/"

Handle backpackTFPricelist;
ConVar steamApiKey;

bool hasItem;
int defIndexOfItem = 0;

public Plugin myinfo = {
	name        = "[TF2] Backpack Searcher",
	author      = "TheXeon",
	description = "Searches through people's backpacks for a particular item.",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_find", CommandFind, "Find an item in a player's backpack.");
	steamApiKey = CreateConVar("sm_find_steam_api_key", "", "Key to use to query backpacks.");
	AutoExecConfig();
}

public Action CommandFind(int client, int args)
{
	if(backpackTFPricelist != INVALID_HANDLE) {
		CloseHandle(backpackTFPricelist);
	}
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "data/backpack-tf.txt");
	backpackTFPricelist = CreateKeyValues("Response");
	FileToKeyValues(backpackTFPricelist, path);
	if (args < 1)
	{
		Menu menu = new Menu(Handler_ItemSelection);
		menu.SetTitle("Which item?");
		PrepPriceKv();
		KvGotoFirstSubKey(backpackTFPricelist);
		char name[128];
		do
		{
			if(!KvJumpToKey(backpackTFPricelist, "item_info"))
			{
				continue;
			}
			KvGetString(backpackTFPricelist, "item_name", name, sizeof(name));
			if(KvGetNum(backpackTFPricelist, "proper_name") == 1)
			{
				Format(name, sizeof(name), "The %s", name);
			}
			menu.AddItem(name, name);
			KvGoBack(backpackTFPricelist);
		} 
		while(KvGotoNextKey(backpackTFPricelist));
		menu.Display(client, MENU_TIME_FOREVER);
		return Plugin_Handled;
	}
	else
	{
		int resultDefindex = -1;
		char defindex[8], name[128], itemName[128];
		GetCmdArgString(name, sizeof(name));
		bool exact = StripQuotes(name);
		PrepPriceKv();
		KvGotoFirstSubKey(backpackTFPricelist);
		Handle matches;
		if(!exact)
		{
			matches = CreateArray(128);
		}
		do
		{
			KvGetSectionName(backpackTFPricelist, defindex, sizeof(defindex));
			if(!KvJumpToKey(backpackTFPricelist, "item_info")) 
			{
				continue;
			}
			KvGetString(backpackTFPricelist, "item_name", itemName, sizeof(itemName));
			if(KvGetNum(backpackTFPricelist, "proper_name") == 1)
			{
				Format(itemName, sizeof(itemName), "The %s", itemName);
			}
			KvGoBack(backpackTFPricelist);
			if(exact)
			{
				if(StrEqual(itemName, name, false))
				{
					resultDefindex = StringToInt(defindex);
					break;
				}
			}
			else
			{
				if(StrContains(itemName, name, false) != -1)
				{
					resultDefindex = StringToInt(defindex); // In case this is the only match, we store the resulting defindex here so that we don't need to search to find it again
					PushArrayString(matches, itemName);
				}
			}
		}
		while(KvGotoNextKey(backpackTFPricelist));
		if(!exact && GetArraySize(matches) > 1)
		{
			Menu menu = new Menu(Handler_ItemSelection);
			menu.SetTitle("Which item?");
			int size = GetArraySize(matches);
			for(int i = 0; i < size; i++) {
				GetArrayString(matches, i, itemName, sizeof(itemName));
				menu.AddItem(itemName, itemName);
			}
			menu.Display(client, MENU_TIME_FOREVER);
			CloseHandle(matches);
			return Plugin_Handled;
		}
		if(!exact) {
			CloseHandle(matches);
		}
		if(resultDefindex == -1) {
			CReplyToCommand(client, "{GREEN}[SM]{DEFAULT} No matching item was found.");
			return Plugin_Handled;
		}
		Menu menu = new Menu(Handler_PlayerSelection);
		LogMessage("Populating menu!");
		menu.SetTitle("Players with the item!");
		for (int i = 1; i <= MaxClients; i++)
		{
			if(SearchInBackpack(i, resultDefindex))
			{
				menu.AddItem("DIESONNE", "DIESONNE");
			}
		}
		LogMessage("Displaying menu!");
		menu.Display(client, 20);
		return Plugin_Handled;
	}
}

public bool SearchInBackpack(int client, int defindex)
{
	LogMessage("Looping through client %d", client);
	if (!IsValidClient(client)) return false;
	hasItem = false;
	defIndexOfItem = defindex;
	char auth[MAX_BUFFER_LENGTH];
	GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
	char key[MAX_BUFFER_LENGTH];
	GetConVarString(steamApiKey, key, sizeof(key));
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, STEAM_API);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "key", key);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "format", "vdf");
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "steamid", auth);
	SteamWorks_SetHTTPCallbacks(request, OnBackpackInfoReceived);
	SteamWorks_SendHTTPRequest(request);
	
	/*
	int len = 0;
	SteamWorks_GetHTTPResponseBodySize(request, len);
	char[] response = new char[len];
	SteamWorks_GetHTTPResponseBodyData(request, response, len);
	LogMessage(response);
    
	char defIndexBuffer[MAX_BUFFER_LENGTH];
	LogMessage("Formatting the stuff!");
	Format(defIndexBuffer, sizeof(defIndexBuffer), "\"defindex\"\t\"%d\"\n\t\t\t\"level", defIndexOfItem);
	if (StrContains(response, defIndexBuffer, false) != -1)	hasItem = true;
	
	*/
	if (hasItem) return true;
	else return false;
}

public int OnBackpackInfoReceived(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode, Handle data)
{
	/*
    char collectionId[128];
    ArrayList mapIds = CreateArray(128);

    DataPack pack = view_as<DataPack>(data);
    pack.Reset();
    pack.ReadString(collectionId, sizeof(collectionId));
    ArrayList list = view_as<ArrayList>(pack.ReadCell());

    int numMaps = pack.ReadCell();
    for (int i = 0; i < numMaps; i++) {
        char mapId[128];
        pack.ReadString(mapId, sizeof(mapId));
        mapIds.PushString(mapId);
    }
	*/
	if (failure || !requestSuccessful) {
		LogError("Steamworks collection request failed, HTTP status code = %d", statusCode);
		// delete pack;
		// delete mapIds;
		return;
	}

	int len = 0;
	SteamWorks_GetHTTPResponseBodySize(request, len);
	char[] response = new char[len];
	SteamWorks_GetHTTPResponseBodyData(request, response, len);
	
	char path[256];
	BuildPath(Path_SM, path, sizeof(path), "data/playersinventory.log");
	SteamWorks_WriteHTTPResponseBodyToFile(request, path);
	LogMessage(response);
	
	
	char defIndexBuffer[MAX_BUFFER_LENGTH];
	LogMessage("Formatting the stuff!");
	Format(defIndexBuffer, sizeof(defIndexBuffer), "\"defindex\"\t\"%d\"\n\t\t\t\"level", defIndexOfItem);
	if (StrContains(response, defIndexBuffer, false) != -1)	hasItem = true;
	/*
	delete pack;
	delete mapIds;
	delete kv;
	*/
}

public int Handler_ItemSelection(Menu menu, MenuAction action, int client, int param) {
	if(action == MenuAction_End) {
		delete menu;
	}
	if(action != MenuAction_Select) {
		return;
	}
	char selection[128];
	menu.GetItem(param, selection, sizeof(selection));
	FakeClientCommand(client, "sm_find \"%s\"", selection);
}

public int Handler_PlayerSelection(Menu menu, MenuAction action, int client, int param) {
	if(action == MenuAction_End) {
		delete menu;
	}
	if(action != MenuAction_Select) {
		return;
	}
	delete menu;
}

void PrepPriceKv() {
	KvRewind(backpackTFPricelist);
	KvJumpToKey(backpackTFPricelist, "prices");
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