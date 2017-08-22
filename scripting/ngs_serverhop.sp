#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <socket>
#include <multicolors>

#define PLUGIN_VERSION "0.8.1"
#define MAX_SERVERS 10
#define REFRESH_TIME 60.0
#define SERVER_TIMEOUT 10.0
#define MAX_STR_LEN 160
#define MAX_INFO_LEN 200
//#define DEBUG

int serverCount = 0;
int advertCount = 0;
int advertInterval = 1;
char serverName[MAX_SERVERS][MAX_STR_LEN];
char serverAddress[MAX_SERVERS][MAX_STR_LEN];
int serverPort[MAX_SERVERS];
char serverInfo[MAX_SERVERS][MAX_INFO_LEN];
Handle socket[MAX_SERVERS];
bool socketError[MAX_SERVERS];
bool isTF2;
ConVar cv_serverformat;
ConVar cv_broadcasthops;
ConVar cv_advert;
ConVar cv_advert_interval;
ConVar cv_log_errors;

public Plugin myinfo = {
	name = "[NGS] Server Hop",
	author = "[GRAVE] rig0r / TheXeon",
	description = "Provides live server info with a join option!",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.servegame.com"
}

public void OnPluginStart()
{
	LoadTranslations("serverhop.phrases");
	// convar setup
	cv_serverformat = CreateConVar("sm_hop_serverformat", "%name - %map (%numplayers/%maxplayers)", "Defines how the server info should be presented.");
	cv_broadcasthops = CreateConVar("sm_hop_broadcasthops", "1", "Set to 1 if you want a broadcast message when a player hops to another server.");
	cv_advert = CreateConVar("sm_hop_advertise", "1", "Set to 1 to enable server advertisements.");
	cv_advert_interval = CreateConVar("sm_hop_advertisement_interval", "5", "Advertisement interval: advertise a server every x minute(s).");
	cv_log_errors = CreateConVar("sm_hop_log_errors", "0", "Log errors if server is down/malfunctioning.");

	AutoExecConfig(true, "plugin.serverhop");

	Handle timer = CreateTimer(REFRESH_TIME, RefreshServerInfo, _, TIMER_REPEAT);
	
	RegConsoleCmd("sm_hop", CommandHop, "Usage: sm_hop");
	RegConsoleCmd("sm_servers", CommandHop, "Usage: sm_servers");
	RegConsoleCmd("sm_list", CommandHop, "Usage: sm_list");
	
	char gameFolder[MAX_BUFFER_LENGTH];
	GetGameFolderName(gameFolder, sizeof(gameFolder));
	if (StrEqual(gameFolder, "tf", true)) isTF2 = true;
	
	char path[MAX_STR_LEN];
	Handle kv;
	BuildPath(Path_SM, path, sizeof(path), "configs/serverhop.cfg");
	kv = CreateKeyValues("Servers");
	if (!FileToKeyValues(kv, path)) LogToGame("Error loading server list!");
	int i;
	KvRewind(kv);
	KvGotoFirstSubKey(kv);
	do
	{
		KvGetSectionName(kv, serverName[i], MAX_STR_LEN);
		KvGetString(kv, "address", serverAddress[i], MAX_STR_LEN);
		serverPort[i] = KvGetNum(kv, "port", 27015);
		i++;
	}
	while (KvGotoNextKey(kv));
	serverCount = i;
	TriggerTimer(timer);
}

public Action CommandHop(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	ServerMenu(client);
	return Plugin_Handled;
}

public Action ServerMenu(int client)
{
	Handle menu = CreateMenu(MenuHandler);
	char serverNumStr[MAX_STR_LEN];
	char menuTitle[MAX_STR_LEN];
	Format(menuTitle, sizeof(menuTitle), "%T", "SelectServer", client);
	SetMenuTitle(menu, menuTitle);
	for (int i = 0; i < serverCount; i++)
	{
		if (strlen(serverInfo[i]) > 0)
		{
			#if defined DEBUG then
				PrintToConsole(client, serverInfo[i]);
			#endif
			IntToString(i, serverNumStr, sizeof(serverNumStr));
			AddMenuItem(menu, serverNumStr, serverInfo[i]);
		}
	}
	DisplayMenu(menu, client, 20);
}

public int MenuHandler(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char infobuf[MAX_STR_LEN];
		char address[MAX_STR_LEN];
		GetMenuItem(menu, param2, infobuf, sizeof(infobuf));
		int serverNum = StringToInt(infobuf);
		// header
		Handle kvheader = CreateKeyValues("header");
		char menuTitle[MAX_STR_LEN];
		Format(menuTitle, sizeof(menuTitle), "%T", "AboutToJoinServer", param1);
		KvSetString(kvheader, "title", menuTitle);
		KvSetNum(kvheader, "level", 1);
		KvSetString(kvheader, "time", "10");
		CreateDialog(param1, kvheader, DialogType_Msg);
		CloseHandle(kvheader);
		// join confirmation dialog
		if (isTF2)
		{
			Format(address, MAX_STR_LEN, "%s:%i", serverAddress[serverNum], serverPort[serverNum]);
			ClientCommand(param1, "redirect %s", address);
			DisplayAskConnectBox(param1, 45.0, address);
		}
		else
		{
			Handle kv = CreateKeyValues("menu");
			KvSetString(kv, "time", "10");
			Format(address, MAX_STR_LEN, "%s:%i", serverAddress[serverNum], serverPort[serverNum]);
			KvSetString(kv, "title", address);
			CreateDialog(param1, kv, DialogType_AskConnect);
			CloseHandle(kv);
		}
		
		// broadcast to all
		if (GetConVarBool(cv_broadcasthops))
		{
			char clientName[MAX_NAME_LENGTH];
			GetClientName(param1, clientName, sizeof(clientName));
			CPrintToChatAll("{CRIMSON}[hop]{DEFAULT} %t", "HopNotification", clientName, serverInfo[serverNum]);
		}
	}
}

public Action RefreshServerInfo(Handle timer)
{
	for (int i = 0; i < serverCount; i++)
	{
		serverInfo[i] = "";
		socketError[i] = false;
		socket[i] = SocketCreate(SOCKET_UDP, OnSocketError);
		SocketSetArg(socket[i], i);
		SocketConnect(socket[i], OnSocketConnected, OnSocketReceive, OnSocketDisconnected, serverAddress[i], serverPort[i]);
	}
	CreateTimer(SERVER_TIMEOUT, CleanUp);
}

public Action CleanUp(Handle timer)
{
	for (int i = 0; i < serverCount; i++)
	{
		if (strlen(serverInfo[i]) == 0 && !socketError[i])
		{
			if(cv_log_errors.BoolValue) LogError("Server %s:%i is down: no timely reply received", serverAddress[i], serverPort[i]);
			CloseHandle(socket[i]);
		}
	}
	// all server info is up to date: advertise
	if (cv_advert.BoolValue)
	{
		if (advertInterval == GetConVarFloat(cv_advert_interval))
		{	
			Advertise();
		}
		advertInterval++;
		if (advertInterval > GetConVarFloat(cv_advert_interval))
		{	
			advertInterval = 1;
		}
	}
}

public Action Advertise()
{
	// skip servers being marked as down
	while (strlen(serverInfo[advertCount]) == 0)
	{	
		#if defined DEBUG then
			LogError("Not advertising down server %i", advertCount);
		#endif
		advertCount++;
		if (advertCount >= serverCount)
		{		
			advertCount = 0;
			break;
		}
	}
	if (strlen(serverInfo[advertCount]) > 0)
	{
		CPrintToChatAll("{CRIMSON}[hop]{DEFAULT} %t", "Advert", serverInfo[advertCount], "!list");
		#if defined DEBUG then
			LogError("Advertising server %i (%s)", advertCount, serverInfo[advertCount]);
		#endif
		advertCount++;
		if (advertCount >= serverCount)
		{
			advertCount = 0;
		}
	}
}

public int OnSocketConnected(Handle sock, any i)
{
	char requestStr[25];
	Format(requestStr, sizeof(requestStr), "%s", "\xFF\xFF\xFF\xFF\x54Source Engine Query");
	SocketSend(sock, requestStr, 25);
}

char GetByte(char[] receiveData, int offset)
{
	return receiveData[offset];
}

char GetString(char[] receiveData, int dataSize, int offset)
{
	char serverStr[MAX_STR_LEN] = "";
	int j = 0;
	for (int i = offset; i < dataSize; i++)
	{
		serverStr[j] = receiveData[i];
		j++;
		if (receiveData[i] == '\x0')
		{
			break;
		}
	}
	return serverStr;
}

public int OnSocketReceive(Handle sock, char[] receiveData, const int dataSize, any i)
{
	char srvName[MAX_STR_LEN];
	char mapName[MAX_STR_LEN];
	char gameDir[MAX_STR_LEN];
	char gameDesc[MAX_STR_LEN];
	char numPlayers[MAX_STR_LEN];
	char maxPlayers[MAX_STR_LEN];
	// parse server info
	int offset = 2;
	srvName = GetString(receiveData, dataSize, offset);
	offset += strlen(srvName) + 1;
	mapName = GetString(receiveData, dataSize, offset);
	offset += strlen(mapName) + 1;
	gameDir = GetString(receiveData, dataSize, offset);
	offset += strlen(gameDir) + 1;
	gameDesc = GetString(receiveData, dataSize, offset);
	offset += strlen(gameDesc) + 1;
	offset += 2;
	IntToString(GetByte(receiveData, offset), numPlayers, sizeof(numPlayers));
	offset++;
	IntToString(GetByte(receiveData, offset), maxPlayers, sizeof(maxPlayers));
	char format[MAX_STR_LEN];
	GetConVarString(cv_serverformat, format, sizeof(format));
	ReplaceString(format, strlen(format), "%name", serverName[i], false);
	ReplaceString(format, strlen(format), "%map", mapName, false);
	ReplaceString(format, strlen(format), "%numplayers", numPlayers, false);
	ReplaceString(format, strlen(format), "%maxplayers", maxPlayers, false);
	serverInfo[i] = format;
	#if defined DEBUG then
		LogError(serverInfo[i]);
	#endif
	CloseHandle(sock);
}

public int OnSocketDisconnected(Handle sock, any i)
{
	CloseHandle(sock);
}

public int OnSocketError(Handle sock, const int errorType, const int errorNum, any i)
{
	if(GetConVarBool(cv_log_errors)) LogError("Server %s:%i is down: socket error %d (errno %d)", serverAddress[i], serverPort[i], errorType, errorNum);
	socketError[i] = true;
	CloseHandle(sock);
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