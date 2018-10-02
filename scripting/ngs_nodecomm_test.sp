/**
* TheXeon
* ngs_nodecomm_test.sp
*
* Files:
* addons/sourcemod/plugins/ngs_nodecomm_test.smx
*
* Dependencies:
* json.inc, nodecomm.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1
#pragma dynamic 16384

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

#include <json>
#include <nodecomm>
#include <ngsutils>
//#include <ngsupdater>

#define DEBUG

public Plugin myinfo = {
	name = "[NGS] NodeJS Communicator Tester",
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
	JSON_Object body = new JSON_Object();
	body.SetInt("client", client);
	body.SetInt("userid", (client <= 0) ? 0 : GetClientUserId(client));
	
	int len = 4096;
	char[] json = new char[len + 1];
	body.Encode(json, len);
	NodeComm_SendRequest("testplugin", "testpluginresponse", true, json);
	body.Cleanup();
	delete body;
	return Plugin_Handled;
}

public Action NodeComm_ReceiveResponse(JSON_Object &response)
{
	char[] responseStr = new char[1024];
	response.Encode(responseStr, 1024);
	PrintToServer("Got response from the server: \n%s", responseStr);
}

public void NodeComm_HeartbeatResult(bool successful)
{
	PrintToServer("Response on heartbeat was %b", successful);
}