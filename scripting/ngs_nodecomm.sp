/**
* TheXeon
* ngs_nodecomm.sp
*
* Files:
* addons/sourcemod/plugins/ngs_nodecomm.smx
*
* Dependencies:
* json.inc, websocket.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define ALL_PLUGINS_LOADED_FUNC AllPluginsLoaded
#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <json>
#include <websocket>
#include <ngsutils>
#include <ngsupdater>

//#define DEBUG

public Plugin myinfo = {
	name = "[NGS] NodeJS Communicator",
	author = "TheXeon",
	description = "Shed your heavy work to a different process.",
	version = "0.0.1",
	url = "https://www.neogenesisnetwork.net/"
}

WebsocketHandle relaySocket;
ArrayList childSockets;

ConVar cvarServerAddr;
Handle responseForward;

public void OnPluginStart()
{
	AutoExecConfig_SetCreateDirectory(true);
	AutoExecConfig_SetCreateFile(true);
	bool appended;
	cvarServerAddr = AutoExecConfig_CreateConVarCheckAppend(appended, "ngs_nodecomm_server_addr", "localhost:3480", "Address to allow communication on.", FCVAR_PROTECTED);
	AutoExecConfig_ExecAndClean(appended);
	
	childSockets = new ArrayList();
	responseForward = CreateGlobalForward("NodeComm_ReceiveResponse", ET_Single, Param_CellByRef);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("NodeComm_SendRequest", Native_SendRequest);
	RegPluginLibrary("ngs_nodecomm");
	return APLRes_Success;
}

public void AllPluginsLoaded()
{
	char serverIP[48], splitIP[2][48];
	cvarServerAddr.GetString(serverIP, sizeof(serverIP));
	int split = ExplodeString(serverIP, ":", splitIP, sizeof(splitIP), sizeof(splitIP[]));
	int port = (split < 2) ? 3480 : StringToInt(splitIP[1]);
	
	if (relaySocket == INVALID_WEBSOCKET_HANDLE)
		relaySocket = Websocket_Open(splitIP[0], port, OnWebsocketIncoming, OnWebsocketMasterError, OnWebsocketMasterClose);
}

public int Native_SendRequest(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);
	
	if (len <= 0)
	{
		return;
	}
	
	char[] json = new char[len + 1];
	GetNativeString(1, json, len + 1);
	
	int iSize = childSockets.Length;
	for (int i = 0; i < iSize; i++)
		Websocket_Send(childSockets.Get(i), SendType_Text, json);
}

public void OnPluginEnd()
{
	if(relaySocket != INVALID_WEBSOCKET_HANDLE)
		Websocket_Close(relaySocket);
}

public Action OnWebsocketIncoming(WebsocketHandle websocket, WebsocketHandle newWebsocket, const char[] remoteIP, int remotePort, char protocols[256])
{
	Format(protocols, sizeof(protocols), "");
	Websocket_HookChild(newWebsocket, OnWebsocketReceive, OnWebsocketDisconnect, OnChildWebsocketError);
	childSockets.Push(newWebsocket);
	return Plugin_Continue;
}

public void OnWebsocketMasterError(WebsocketHandle websocket, const int errorType, const int errorNum)
{
	LogError("MASTER SOCKET ERROR: handle: %d type: %d, errno: %d", view_as<int>(websocket), errorType, errorNum);
	relaySocket = INVALID_WEBSOCKET_HANDLE;
}

public void OnWebsocketMasterClose(WebsocketHandle websocket)
{
	relaySocket = INVALID_WEBSOCKET_HANDLE;
}

public void OnChildWebsocketError(WebsocketHandle websocket, const int errorType, const int errorNum)
{
	LogError("CHILD SOCKET ERROR: handle: %d, type: %d, errno: %d", view_as<int>(websocket), errorType, errorNum);
	childSockets.Erase(childSockets.FindValue(websocket));
}

public void OnWebsocketReceive(WebsocketHandle websocket, WebsocketSendType iType, const char[] receiveData, const int dataSize)
{
	if(iType == SendType_Text)
	{
		JSON_Object obj = json_decode(receiveData);
		
		if (obj == null)
			return;
		
		Call_StartForward(responseForward);
		Call_PushCellRef(obj);
		Call_Finish();
		
//		// relay this chat to other sockets connected
//		int iSize = childSockets.Length;
//		for (int i = 0; i < iSize; i++)
//			// Don't echo the message back to the user sending it!
//			if(childSockets.Get(i) != websocket)
//				Websocket_Send(childSockets.Get(i), SendType_Text, receiveData);
	}
}

public void OnWebsocketDisconnect(WebsocketHandle websocket)
{
	childSockets.Erase(childSockets.FindValue(websocket));
}