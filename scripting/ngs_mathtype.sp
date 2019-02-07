/**
* TheXeon
* ngs_mathtype.sp
*
* Files:
* addons/sourcemod/plugins/ngs_mathtype.smx
*
* Dependencies:
* SteamWorks.inc, multicolors.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

// #define DEBUG

#include <json>
#include <SteamWorks>
#include <multicolors>
#include <ngsutils>
#include <ngsupdater>

#define MATHJSURL       "http://api.mathjs.org/v4/"

public Plugin myinfo = {
    name = "[NGS] Math Type",
    author = "TheXeon",
    description = "Process math equations through math.js",
    version = "1.0.0",
    url = "https://www.neogenesisnetwork.net"
}

ConVar digitsPrecision;
int cooldownNum;

public void OnPluginStart() {
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    bool appended;
    Timber.plantToFile(appended);
    digitsPrecision = AutoExecConfig_CreateConVarCheckAppend(appended, "mathtype_precision", "-1", "How many digits precision should be returned by math.js.\n-1 to disable, otherwise number precision");
    AutoExecConfig_ExecAndClean(appended);

    cooldownNum = GetTime();

    AddCommandListener(OnClientSayMessage, "say");
    AddCommandListener(OnClientSayMessage, "say_team");
}

public Action OnClientSayMessage(int client, const char[] command, int argc) {
    if (!IsValidClient(client)) return Plugin_Continue;

    // Might cause lag, unsure
    char buffer[MAX_BUFFER_LENGTH];
    GetCmdArgString(buffer, sizeof(buffer));
    StripQuotes(buffer);
    TrimString(buffer);

    if (buffer[0] == '=') {
        int cooldownAmt = GetTime() - cooldownNum;
        if (cooldownAmt < 10) {
            buffer[0] = ' ';
            CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Sorry! We can't process this right now, please wait {LIGHTGREEN}%d{DEFAULT} more seconds and for the previous request to process. For reference, you asked{YELLOW}%s{DEFAULT}.", 10 - cooldownAmt, buffer);
            return Plugin_Continue;
        }

        buffer[0] = ' '; // replace equal sign
        TrimString(buffer);

        Timber.d("Received %s from user %L.", buffer, client);

        JSON_Object obj = new JSON_Object();
        obj.SetString("expr", buffer);

        if (digitsPrecision.IntValue >= 0) {
            obj.SetInt("precision", digitsPrecision.IntValue);
        }

        char jsonEncode[MAX_BUFFER_LENGTH * 3 + 1];
        obj.Encode(jsonEncode, sizeof(jsonEncode));
        delete obj;

        SWHTTPRequest mathRequest = new SWHTTPRequest(k_EHTTPMethodPOST, MATHJSURL);
        mathRequest.SetRawPostBody("application/json", jsonEncode, sizeof(jsonEncode));
        mathRequest.SetContextValue(GetClientUserId(client));
        mathRequest.SetCallbacks(OnMathJSReceived);
        mathRequest.Send();
        Timber.d("Sending math.js HTTP request for %L", client);
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

public void OnMathJSReceived(SWHTTPRequest hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any userid) {
    cooldownNum = GetTime();

    int client = 0;
    if (userid != 0)
    {
        client = GetClientOfUserId(userid);
    }

    char[] buffer = new char[hRequest.ResponseSize + 1];
    hRequest.GetBodyData(buffer, hRequest.ResponseSize);
    delete hRequest;

    JSON_Object obj = new JSON_Object();
    obj.Decode(buffer);
    
    if(eStatusCode != k_EHTTPStatusCode200OK || !bRequestSuccessful || obj.GetKeyType("error") != Type_Null) {
        if (client != 0) {
            CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Could not complete request, sorry!");
        }

        char error[MAX_BUFFER_LENGTH];
        obj.GetString("error", error, sizeof(error));
        Timber.e("Math.js request failed for userid %d! Status code is %d, success was %s, error response was %s.", userid, eStatusCode, (bRequestSuccessful) ? "true" : "false", error);
    } else if (client != 0) {
        char answer[MAX_BUFFER_LENGTH];
        obj.GetString("answer", answer, sizeof(answer));
        CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Answer is: %s", answer);
    }
    obj.Cleanup();
    delete obj;
}