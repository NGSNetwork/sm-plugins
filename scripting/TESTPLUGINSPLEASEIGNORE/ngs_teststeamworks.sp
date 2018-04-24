/// FROM https://forums.alliedmods.net/showpost.php?p=2386954&postcount=12

#include <sourcemod>
#include <steamworks>

public OnPluginStart()
{
    RegServerCmd("send", sendRequest);
}

public Action sendRequest(args) {
    char[] sURL = "https://www.google.com/search";

    //Get handle
    Handle HTTPRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, sURL);

    //Set timeout to 10 seconds
    bool setnetwork = SteamWorks_SetHTTPRequestNetworkActivityTimeout(HTTPRequest, 10);
    //Set a Get parameter, makes URL look like: http://asd.overcore.eu/ahoj.php?parameter=12345
    bool setparam = SteamWorks_SetHTTPRequestGetOrPostParameter(HTTPRequest, "q", "test");
    //Set a header value because we can
    bool setheader = SteamWorks_SetHTTPRequestHeaderValue(HTTPRequest, "server", "TestFuton");
    //SteamWorks thing, set context value so we know what call we sent for the callback.
    bool setcontext = SteamWorks_SetHTTPRequestContextValue(HTTPRequest, 5);
    //Set callback function to get response data
    bool setcallback = SteamWorks_SetHTTPCallbacks(HTTPRequest, getCallback);


    if(!setnetwork || !setparam || !setheader || !setcontext || !setcallback) {
        PrintToServer("Error in setting request properties, cannot send request");
        CloseHandle(HTTPRequest);
        return Plugin_Handled;
    }

    //Initialize the request.
    bool sentrequest = SteamWorks_SendHTTPRequest(HTTPRequest);
    if(!sentrequest) {
        PrintToServer("Error in sending request, cannot send request");
        CloseHandle(HTTPRequest);
        return Plugin_Handled;
    }


    //Send the request to the front of the queue
    SteamWorks_PrioritizeHTTPRequest(HTTPRequest);
    return Plugin_Handled;
}

public getCallback(Handle:hRequest, bool:bFailure, bool:bRequestSuccessful, EHTTPStatusCode:eStatusCode, any:data1) {

    if(!bRequestSuccessful) {
        PrintToServer("There was an error in the request");
        CloseHandle(hRequest);
        return;
    }

    if(eStatusCode == k_EHTTPStatusCode200OK) {
        PrintToServer("The request returned new data, http code 200");
    } else if(eStatusCode == k_EHTTPStatusCode304NotModified) {
        PrintToServer("The request did not return new data, but did not error, http code 304");
        return;
    } else if(eStatusCode == k_EHTTPStatusCode404NotFound) {
        PrintToServer("The requested URL could not be found, http code 404");
        return;
    } else if(eStatusCode == k_EHTTPStatusCode500InternalServerError) {
        PrintToServer("The requested URL had an internal error, http code 500");
        return;
    } else {
        char errmessage[128];
        Format(errmessage, 128, "The requested returned with an unexpected HTTP Code %d", eStatusCode);
        PrintToServer(errmessage);
        CloseHandle(hRequest);
        return;
    }

    int headersize;
    bool headerexists = SteamWorks_GetHTTPResponseHeaderSize(hRequest, "customreceivedheader", headersize);
    if(headerexists == false) {
        PrintToServer("received header 'customreceivedheader' does not exist");
    } else {
        //If header exists, print its value.
        char buffer[64];
        bool headerexist2 = SteamWorks_GetHTTPResponseHeaderValue(hRequest, "customreceivedheader", buffer, headersize);
        if(headerexist2 == true) {
            PrintToServer(buffer);
        } else {
            PrintToServer("some error in getting header after we got size");   
        }
    }

    int bodysize;
    bool bodyexists = SteamWorks_GetHTTPResponseBodySize(hRequest, bodysize);
    if(bodyexists == false) {
        PrintToServer("Could not get body response size");
        CloseHandle(hRequest);
        return;
    }

    char bodybuffer[10000];
    if(bodysize > 10000) {
        PrintToServer("The requested URL returned with more data than expected");
        CloseHandle(hRequest);
        return;
    }

    bool gotdata = SteamWorks_GetHTTPResponseBodyData(hRequest, bodybuffer, bodysize);
    if(gotdata == false) {
        PrintToServer("Could not get body data or body data is blank");
        CloseHandle(hRequest);
        return;
    }

    //Print successfull response to server.
    PrintToServer(bodybuffer);
    CloseHandle(hRequest);
}  