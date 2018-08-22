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
#pragma dynamic 16384

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <json>
#include <socket>
#include <ngsutils>
#include <ngsupdater>

#define DEBUG

public Plugin myinfo = {
	name = "[NGS] NodeJS Communicator",
	author = "TheXeon",
	description = "Shed your heavy work to a different process.",
	version = "0.0.1",
	url = "https://www.neogenesisnetwork.net/"
}

Socket relaySocket;
bool canHandleRequests;

ConVar cvarServerAddr;
Handle responseForward;

public void OnPluginStart()
{
	AutoExecConfig_SetCreateDirectory(true);
	AutoExecConfig_SetCreateFile(true);
	bool appended;
	cvarServerAddr = AutoExecConfig_CreateConVarCheckAppend(appended, "ngs_nodecomm_server_addr", "localhost:3480", "Address to communicate with.", FCVAR_PROTECTED);
	AutoExecConfig_ExecAndClean(appended);
	
	responseForward = CreateGlobalForward("NodeComm_ReceiveResponse", ET_Single, Param_CellByRef);
}

public void OnConfigsExecuted()
{
	if (relaySocket != null) return;
	char serverIP[48], splitIP[2][48];
	cvarServerAddr.GetString(serverIP, sizeof(serverIP));
	int split = ExplodeString(serverIP, ":", splitIP, sizeof(splitIP), sizeof(splitIP[]));
	int port = (split < 2) ? 3480 : StringToInt(splitIP[1]);
	
	PrintToServer("Attepting to connect to server %s:%d!", splitIP[0], port);
	relaySocket = new Socket(SOCKET_TCP, OnSocketError);
	relaySocket.Connect(OnSocketConnect, OnSocketReceive, OnSocketDisconnect, serverIP[0], port);
}

public void OnSocketConnect(Socket socket, any args)
{
	canHandleRequests = true;
	PrintToServer("relaySocket successfully connected to the server!");
}

public void OnSocketDisconnect(Socket socket, any args)
{
	canHandleRequests = false;
	delete relaySocket;
}

public void OnSocketError(Socket socket, const int errorType, const int errorNum, any arg)
{
	LogError("Connection socket error with type %d, error number %d! Attempting to restart after a short delay", errorType, errorNum);
	SMTimer.Make(10.0, OnErrorTimerComplete, socket);
}

public Action OnErrorTimerComplete(Handle myself, any data)
{
	OnSocketDisconnect(data, 0);
	OnConfigsExecuted();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("NodeComm_SendRequest", Native_SendRequest);
	RegPluginLibrary("ngs_nodecomm");
	return APLRes_Success;
}

public int Native_SendRequest(Handle plugin, int numParams)
{
	if (!canHandleRequests) return;
	int len;
	GetNativeStringLength(1, len);
	
	if (len <= 0)
	{
		return;
	}
	
	char[] json = new char[len + 1];
	GetNativeString(1, json, len + 1);
	
	#if defined DEBUG
	PrintToServer("Sending %s to the socket!", json);
	#endif
	relaySocket.Send(json, len + 1);
}

public void OnPluginEnd()
{
	if (relaySocket != null)
	{
		relaySocket.Disconnect();
		delete relaySocket;
	}
}

public void OnSocketReceive(Socket socket, char[] receiveData, const int dataSize, any arg)
{
	#if defined DEBUG
	PrintToServer("Received data %s from socket.", receiveData);
	#endif
	JSON_Object obj = json_decode(receiveData);
	
	if (obj == null)
		return;
	
	Action result;
	Call_StartForward(responseForward);
	Call_PushCellRef(obj);
	Call_Finish(result);
	
	delete obj;
}