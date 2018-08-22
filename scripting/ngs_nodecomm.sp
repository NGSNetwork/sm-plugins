/**
* TheXeon
* ngs_nodecomm.sp
*
* Files:
* addons/sourcemod/plugins/ngs_nodecomm.smx
*
* Dependencies:
* json.inc, socket.inc, ngsutils.inc, ngsupdater.inc
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
SMTimer heartbeatTimer, timeoutTimer;

ConVar cvarServerAddr;
Handle responseForward, heartbeatForward;

public void OnPluginStart()
{
	AutoExecConfig_SetCreateDirectory(true);
	AutoExecConfig_SetCreateFile(true);
	bool appended;
	cvarServerAddr = AutoExecConfig_CreateConVarCheckAppend(appended, "ngs_nodecomm_server_addr", "localhost:3480", "Address to communicate with.", FCVAR_PROTECTED);
	AutoExecConfig_ExecAndClean(appended);
	
	responseForward = CreateGlobalForward("NodeComm_ReceiveResponse", ET_Single, Param_CellByRef);
	heartbeatForward = CreateGlobalForward("NodeComm_HeartbeatResult", ET_Ignore, Param_Cell);
}

public void OnConfigsExecuted()
{
	if (relaySocket != null) return;
	char serverIP[48], splitIP[2][48];
	cvarServerAddr.GetString(serverIP, sizeof(serverIP));
	int split = ExplodeString(serverIP, ":", splitIP, sizeof(splitIP), sizeof(splitIP[]));
	int port = (split < 2) ? 3480 : StringToInt(splitIP[1]);
	
	PrintToServer("Attempting to connect to server %s:%d!", splitIP[0], port);
	relaySocket = new Socket(SOCKET_TCP, OnSocketError);
	#if defined DEBUG
	relaySocket.SetOption(DebugMode, 1);
	#endif
	relaySocket.Connect(OnSocketConnect, OnSocketReceive, OnSocketDisconnect, serverIP[0], port);
}

public void OnSocketConnect(Socket socket, any args)
{
	PrintToServer("relaySocket successfully connected to the server!");
	heartbeatTimer = new SMTimer(7.0, OnHeartbeatTimerComplete, _, TIMER_REPEAT);
}

public void OnSocketDisconnect(Socket socket, any args)
{
	#if defined DEBUG
	PrintToServer("Socket disconnecting, deleting relaySocket!");
	#endif
	delete heartbeatTimer;
	delete timeoutTimer;
	delete relaySocket;
}

public void OnSocketError(Socket socket, const int errorType, const int errorNum, any arg)
{
	LogError("Connection socket error with type %d, error number %d! Attempting to restart after a short delay", errorType, errorNum);
	SMTimer.Make(10.0, OnErrorTimerComplete);
}

public Action OnErrorTimerComplete(Handle timer)
{
	OnSocketDisconnect(null, 0);
	OnConfigsExecuted();
}

public Action OnHeartbeatTimerComplete(Handle timer)
{
	if (relaySocket != null)
	{
		relaySocket.Send("{\"__heartbeat__\":\"h\"}");
		timeoutTimer = new SMTimer(5.0, OnTimeoutTimerComplete);
	}
}

public Action OnTimeoutTimerComplete(Handle timer)
{
	timeoutTimer = null;
	Call_StartForward(heartbeatForward);
	Call_PushCell(false);
	Call_Finish();
	OnSocketError(null, 0, 0, 0);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("NodeComm_SendRequest", Native_SendRequest);
	RegPluginLibrary("ngs_nodecomm");
	return APLRes_Success;
}

public int Native_SendRequest(Handle plugin, int numParams)
{
	if (relaySocket != null && !relaySocket.IsConnected) return;
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
	
	if (obj.HasKey("__heartbeat__"))
	{
		delete timeoutTimer;
		Call_StartForward(heartbeatForward);
		Call_PushCell(view_as<int>(true));
		Call_Finish();
	}
	else
	{
		Action result;
		Call_StartForward(responseForward);
		Call_PushCellRef(obj);
		Call_Finish(result);
	}
	
	delete obj;
}