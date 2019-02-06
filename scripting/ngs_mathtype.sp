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

#tryinclude <SteamWorks>
#tryinclude <multicolors>
#tryinclude <ngsutils>
#tryinclude <ngsupdater>

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

        Timber.d("Received %s from user %L.", buffer, client);

        SWHTTPRequest mathRequest = new SWHTTPRequest(k_EHTTPMethodGET, MATHJSURL);
        mathRequest.SetParam("expr", buffer);

        char precision[24];
        digitsPrecision.GetString(precision, sizeof(precision));

        if (digitsPrecision.IntValue >= 0) {
            mathRequest.SetParam("precision", precision);
        }

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
    
    if(eStatusCode != k_EHTTPStatusCode200OK || !bRequestSuccessful) {
        if (client != 0) {
            CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Could not complete request, sorry!");
        }

        Timber.e("Math.js request failed for userid %d! Status code is %d, success was %s, response was %s.", userid, eStatusCode, (bRequestSuccessful) ? "true" : "false", buffer);
    } else if (client != 0) {
        CPrintToChat(client, "{GREEN}[SM]{DEFAULT} Answer is: %s", buffer);
    }
}