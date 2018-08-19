/**
* TheXeon
* ngs_nodecomm_test.sp
*
* Files:
* addons/sourcemod/plugins/ngs_nodecomm_test.smx
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
#include <nodecomm>
#include <ngsutils>
//#include <ngsupdater>

//#define DEBUG

public Plugin myinfo = {
	name = "[NGS] NodeJS Communicator",
	author = "TheXeon",
	description = "Communicate with a server to do processing there.",
	version = "0.0.1",
	url = "https://www.neogenesisnetwork.net/"
}

public void OnPluginStart()
{
	RegAdminCmd("sm_sendnodecommtest", CommmandSendNodeCommTest, ADMFLAG_GENERIC);
}

public Action CommmandSendNodeCommTest(int client, int args)
{
	if (!client) return Plugin_Handled;
	
	JSON_Object obj = new JSON_Object();
	obj.SetString("callbackID", "sendresultbackthroughforwardwiththisid");
	obj.SetBool("handlerID", "ontheexpressappusethistodeterminehandlingfunction");
	JSON_Object body = new JSON_Object();
	body.SetInt("clientID", 6);
	body.SetInt("userID", 5);
	obj.SetObject("body", body);
	int len = obj.Length * obj.Length;
	char[] json = new char[len + 1];
	obj.Encode(json, len);
	NodeComm_SendRequest(json);
}

public void NodeComm_ReceiveResponse(JSON_Object &response)
{
	
}