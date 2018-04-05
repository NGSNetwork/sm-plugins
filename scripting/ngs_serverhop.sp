/**
* TheXeon
* ngs_serverhop.sp
*
* Files:
* addons/sourcemod/plugins/ngs_serverhop.smx
* addons/sourcemod/configs/serverhop.cfg
* addons/sourcemod/translations/serverhop.phrases.txt
* cfg/sourcemod/plugin.serverhop.cfg
*
* Dependencies:
* tf2_stocks.inc, multicolors.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <socket>
#include <multicolors>
#include <ngsutils>
#include <ngsupdater>

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
Socket socket[MAX_SERVERS];
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
	version = "1.2.0",
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

	SMTimer timer = new SMTimer(REFRESH_TIME, RefreshServerInfo, _, TIMER_REPEAT);

	RegConsoleCmd("sm_hop", CommandHop, "Usage: sm_hop");
	RegConsoleCmd("sm_servers", CommandHop, "Usage: sm_servers");
	RegConsoleCmd("sm_list", CommandHop, "Usage: sm_list");

	char gameFolder[MAX_BUFFER_LENGTH];
	GetGameFolderName(gameFolder, sizeof(gameFolder));
	if (StrEqual(gameFolder, "tf", true)) isTF2 = true;

	char path[MAX_STR_LEN], hostip[24];
	Inet_NtoA(FindConVar("hostip").IntValue, hostip, sizeof(hostip));
	int hostport = FindConVar("hostport").IntValue;

	BuildPath(Path_SM, path, sizeof(path), "configs/serverhop.cfg");
	KeyValues kv = new KeyValues("Servers");
	if (!kv.ImportFromFile(path)) SetFailState("Error loading server list!");
	int i;
	kv.Rewind();
	kv.GotoFirstSubKey();
	do
	{
		kv.GetString("address", serverAddress[i], MAX_STR_LEN);
		serverPort[i] = kv.GetNum("port", 27015);
		if (StrEqual(serverAddress[i], hostip) && serverPort[i] == hostport) continue;
		kv.GetSectionName(serverName[i], MAX_STR_LEN);
		i++;
	}
	while (kv.GotoNextKey());
	delete kv;
	serverCount = i;
	timer.Trigger();
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

public void ServerMenu(int client)
{
	Menu menu = new Menu(HopMenuHandler);
	char serverNumStr[MAX_STR_LEN];
	char menuTitle[MAX_STR_LEN];
	Format(menuTitle, sizeof(menuTitle), "%T", "SelectServer", client);
	menu.SetTitle(menuTitle);
	for (int i = 0; i < serverCount; i++)
	{
		if (strlen(serverInfo[i]) > 0)
		{
			#if defined DEBUG then
				PrintToConsole(client, serverInfo[i]);
			#endif
			IntToString(i, serverNumStr, sizeof(serverNumStr));
			menu.AddItem(serverNumStr, serverInfo[i]);
		}
	}
	menu.Display(client, 20);
}

public int HopMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char infobuf[MAX_STR_LEN];
		char address[MAX_STR_LEN];
		GetMenuItem(menu, param2, infobuf, sizeof(infobuf));
		int serverNum = StringToInt(infobuf);
		// header
		KeyValues kvheader = new KeyValues("header");
		char menuTitle[MAX_STR_LEN];
		Format(menuTitle, sizeof(menuTitle), "%T", "AboutToJoinServer", param1);
		kvheader.SetString("title", menuTitle);
		kvheader.SetNum("level", 1);
		kvheader.SetString("time", "10");
		CreateDialog(param1, kvheader, DialogType_Msg);
		delete kvheader;
		// join confirmation dialog
		if (isTF2)
		{
			Format(address, MAX_STR_LEN, "%s:%i", serverAddress[serverNum], serverPort[serverNum]);
			ClientCommand(param1, "redirect %s", address);
			DisplayAskConnectBox(param1, 45.0, address);
		}
		else
		{
			KeyValues kv = CreateKeyValues("menu");
			kv.SetString("time", "10");
			Format(address, MAX_STR_LEN, "%s:%i", serverAddress[serverNum], serverPort[serverNum]);
			kv.SetString("title", address);
			CreateDialog(param1, kv, DialogType_AskConnect);
			delete kv;
		}

		// broadcast to all
		if (cv_broadcasthops.BoolValue)
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
		socket[i] = new Socket(SOCKET_UDP, OnSocketError);
		socket[i].SetArg(i);
		socket[i].Connect(OnSocketConnected, OnSocketReceive, OnSocketDisconnected, serverAddress[i], serverPort[i]);
	}
	SMTimer.Make(SERVER_TIMEOUT, CleanUp);
}

public Action CleanUp(Handle timer)
{
	for (int i = 0; i < serverCount; i++)
	{
		if (strlen(serverInfo[i]) == 0 && !socketError[i])
		{
			if(cv_log_errors.BoolValue) LogError("Server %s:%i is down: no timely reply received", serverAddress[i], serverPort[i]);
			delete socket[i];
		}
	}
	// all server info is up to date: advertise
	if (cv_advert.BoolValue)
	{
		if (advertInterval == cv_advert_interval.FloatValue)
		{
			Advertise();
		}
		advertInterval++;
		if (advertInterval > cv_advert_interval.FloatValue)
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

public int OnSocketConnected(Socket sock, any i)
{
	char requestStr[25];
	Format(requestStr, sizeof(requestStr), "%s", "\xFF\xFF\xFF\xFF\x54Source Engine Query");
	sock.Send(requestStr, 25);
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

public int OnSocketReceive(Socket sock, char[] receiveData, const int dataSize, any i)
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
	cv_serverformat.GetString(format, sizeof(format));
	ReplaceString(format, strlen(format), "%name", serverName[i], false);
	ReplaceString(format, strlen(format), "%map", mapName, false);
	ReplaceString(format, strlen(format), "%numplayers", numPlayers, false);
	ReplaceString(format, strlen(format), "%maxplayers", maxPlayers, false);
	serverInfo[i] = format;
	#if defined DEBUG then
		LogError(serverInfo[i]);
	#endif
	delete sock;
}

public int OnSocketDisconnected(Socket sock, any i)
{
	delete sock;
}

public int OnSocketError(Socket sock, const int errorType, const int errorNum, any i)
{
	if(cv_log_errors.BoolValue) LogError("Server %s:%i is down: socket error %d (errno %d)", serverAddress[i], serverPort[i], errorType, errorNum);
	socketError[i] = true;
	delete sock;
}

// Powerlord is king
/**
* @param binary binary IP, usually from hostip
* @param address buffer to save address to
* @param maxlength length of buffer
* @noreturn
*/
stock void Inet_NtoA(int binary, char[] address, int maxlength)
{
    int quads[4];
    quads[0] = binary >> 24 & 0x000000FF; // mask isn't necessary for this one, but do it anyway
    quads[1] = binary >> 16 & 0x000000FF;
    quads[2] = binary >> 8 & 0x000000FF;
    quads[3] = binary & 0x000000FF;

    Format(address, maxlength, "%d.%d.%d.%d", quads[0], quads[1], quads[2], quads[3]);
}