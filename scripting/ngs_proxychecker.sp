/**
* TheXeon
* ngs_proxychecker.sp
*
* Files:
* addons/sourcemod/plugins/ngs_proxychecker.smx
* cfg/sourcemod/proxychecker.cfg
*
* Dependencies:
* SteamWorks.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

//#define DEBUG

#include <SteamWorks>
#include <ngsutils>
#include <ngsupdater>

ConVar contactEmail, getIpIntelProbability;

bool disallowRequests;
StringMap processCache;
StringMap requestCache;
SMTimer processCacheTimer;
int numRequests, numRequestsPerMin;

public Plugin myinfo = {
	name        = "[NGS] Proxy Checker",
	author      = "TheXeon",
	description = "Simple checker against API for proxies/VPNs.",
	version     = "1.2.0",
	url         = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	contactEmail = CreateConVar("sm_proxychecker_email", "dummy@dummy.dummy", "Contact email for free APIs to use.");
	getIpIntelProbability = CreateConVar("sm_proxychecker_getintel_prob", "0.95", "Probablity to use with GetIPIntel.");
	AutoExecConfig(true, "proxychecker");
	requestCache = new StringMap();
	SMTimer.Make(60.0, OnRequestPerMinuteTimer, _, TIMER_REPEAT);
}

public void OnClientPutInServer(int client)
{
	if (!IsFakeClient(client) && numRequests < 500)
	{
		float probability;
		char ip[24];
		GetClientIP(client, ip, sizeof(ip));

		if (requestCache != null && requestCache.GetValue(ip, probability) && probability < getIpIntelProbability.FloatValue)
		{
			#if defined DEBUG
			PrintToServer("Retrieved probability %.02f from cache for client %L.", probability, client);
			#endif
			return;
		}

		DataPack pack = new DataPack(), dummy;
		if (processCache != null && disallowRequests)
		{
			pack.WriteCell(GetClientUserId(client));
			pack.WriteString(ip);
			if (!processCache.GetValue(ip, dummy))
			{
				processCache.SetValue(ip, pack);
			}
			else
			{
				delete pack;
			}
		}
		else
		{
			pack.WriteCell(GetClientUserId(client));
			pack.WriteString(ip);
			SendGetIPIntelRequest(pack);
		}
	}
}

void SendGetIPIntelRequest(DataPack pack)
{
	if (numRequests >= 500 || numRequestsPerMin >= 15)
	{
		delete pack; // TODO: Actually queue these, otherwise we are ignoring some requests.
		return;
	}
	numRequests++;
	numRequestsPerMin++;
	char contactAddr[256], ip[24];
	pack.Reset();
	pack.ReadCell();
	pack.ReadString(ip, sizeof(ip));
	contactEmail.GetString(contactAddr, sizeof(contactAddr));
	if (StrEqual("dummy@dummy.dummy", contactAddr))
	{
		LogError("SPAMMY ERRORS! Please change the email used with the proxy checker to something valid!");
		delete pack;
		return;
	}
	SWHTTPRequest request = new SWHTTPRequest(k_EHTTPMethodGET, "https://check.getipintel.net/check.php");
	request.SetParam("ip", ip);
	request.SetParam("contact", contactAddr);
	request.SetContextValue(pack);
	request.SetCallbacks(OnGetIPIntelRequestDone);
	request.Send();
	#if defined DEBUG
	PrintToServer("Sending request for ip %s for contact %s.", ip, contactAddr);
	#endif
}

public void OnGetIPIntelRequestDone(SWHTTPRequest hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, DataPack pack)
{
	pack.Reset();
	int userid = pack.ReadCell();
	char ip[24];
	pack.ReadString(ip, sizeof(ip));
	if(eStatusCode != k_EHTTPStatusCode200OK || !bRequestSuccessful)
	{
		if (eStatusCode == k_EHTTPStatusCode400BadRequest)
		{
			char[] buffer = new char[hRequest.ResponseSize + 1];
			hRequest.GetBodyData(buffer, hRequest.ResponseSize);
			float response = StringToFloat(buffer);
			LogError("Get IP Intel request failed for userid %d! Check GetIPIntel for error code %.0f with status 400!", userid, response);
			delete pack;
		}
		else if (eStatusCode == k_EHTTPStatusCode429TooManyRequests)
		{
			LogError("Get IP Intel request failed for userid %d! At %d requests as of async request completion, caching requests!", userid, numRequests);
			if (processCache == null)
			{
				processCache = new StringMap();
				disallowRequests = true;
			}
			DataPack dummy; // dont delete if used.
			if (!processCache.GetValue(ip, dummy))
			{
				processCache.SetValue(ip, pack);
			}
			if (processCacheTimer == null)
			{
				processCacheTimer = new SMTimer(86500.0, OnCacheTimerComplete); // wait 24 hours + 100 seconds.
			}
		}
		else
		{
			LogError("Get IP Intel request failed for userid %d! Status code is %d, success was %s.", userid, eStatusCode, (bRequestSuccessful) ? "true" : "false");
			delete pack;
		}
		delete hRequest;
		return;
	}

	int client = 0;
	if (userid != 0)
	{
		client = GetClientOfUserId(userid);
	}

	char[] buffer = new char[hRequest.ResponseSize + 1];
	hRequest.GetBodyData(buffer, hRequest.ResponseSize);
	delete hRequest;
	delete pack;

	float probability = StringToFloat(buffer);
	#if defined DEBUG
	PrintToServer("Probability for proxy is %.2f for ip %s!", probability, ip);
	#endif
	if (probability >= getIpIntelProbability.FloatValue)
	{
		ServerCommand("sm_banip %s 0 Suspicion of proxy with probability %.2f", ip, probability);
		if (userid != 0 && client != 0) // might be redundant, only client is needed.
		{
			KickClient(client, "%.2f percent Suspicion of proxy server.");
		}
	}
	requestCache.SetValue(ip, probability); // TODO: Make cache erase after a while
	#if defined DEBUG
	PrintToServer("Caching probability %.02f for client %L.", probability, client);
	#endif
}

public Action OnCacheTimerComplete(Handle timer)
{
	numRequests = 0; // this will cause a bit of rounding weirdness
	processCacheTimer = null;
	disallowRequests = false;
	SMTimer.Make(60.0, ProcessCachePortion, _, TIMER_REPEAT);
}

public Action ProcessCachePortion(Handle timer)
{
	char ip[24];
	StringMapSnapshot snap = processCache.Snapshot();
	int len = (snap.Length <= 15) ? snap.Length : 15;
	for (int i = 0; i < len; i++)
	{
		if (numRequestsPerMin >= 15)
		{
			return Plugin_Continue; // continue again when requests allow for it
		}
		snap.GetKey(i, ip, sizeof(ip));
		DataPack pack;
		if (processCache.GetValue(ip, pack))
		{
			pack.Reset();
			if (GetClientOfUserId(pack.ReadCell()) == 0)
			{
				pack.ReadString(ip, sizeof(ip));
				delete pack;
				pack = new DataPack();
				pack.WriteCell(0); // userid to 0
				pack.WriteString(ip);
			}
			processCache.Remove(ip);
			SendGetIPIntelRequest(pack);
		}
		else
		{
			LogError("Error in plugin function, unable to retrieve from processCache when length is %d!", snap.Length);
		}
	}
	if (snap.Length <= 15)
	{
		delete processCache;
		delete snap;
		return Plugin_Stop;
	}
	delete snap;
	return Plugin_Continue;
}

public Action OnRequestPerMinuteTimer(Handle timer)
{
	numRequestsPerMin = 0;
}
