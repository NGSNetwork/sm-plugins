/**
* TheXeon
* ngs_proxychecker.sp
*
* Files:
* addons/sourcemod/plugins/ngs_proxychecker.smx
* addons/sourcemod/configs/proxychecker.cfg
* cfg/sourcemod/proxychecker.cfg
*
* Dependencies:
* SteamWorks.inc, autoexecconfig.inc, json.inc, ngsutils.inc, ngsupdater.inc
*
*
* Install by configuring api key for proxycheck.io in config/proxychecker.cfg
* and email in cfg/sourcemod/proxychecker.cfg
*/
#pragma dynamic 16384
#pragma newdecls required
#pragma semicolon 1

#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1

//#define DEBUG

#include <SteamWorks>
#include <autoexecconfig>
#include <json>
#include <ngsutils>
#include <ngsupdater>

ConVar cvarContactEmail, cvarLowestTolerableTime;

float getIpIntelProbability;
SMQueue processQueue;
SMTimer processQueueTimer;
KeyValues config;
ArrayList vpnList;
StringMap requestCache;
int vpnToUse; // an index of vpnList
int twentyFourHourTimeStamp;

char getIPIntelURL[1024], proxyCheckIOURL[1024];

// VPN METHODMAP
methodmap VPN < StringMap
{
	public VPN(const char[] type, const char[] url, int requestsPerMin, int requestsPerDay, float probability=-1.0)
	{
		StringMap coolBean = new StringMap();
		coolBean.SetString("type", type);
		coolBean.SetString("url", url);
		coolBean.SetValue("perDaySoFar", 0);
		coolBean.SetValue("perMin", requestsPerMin);
		coolBean.SetValue("perDay", requestsPerDay);
		coolBean.SetValue("probability", probability);
		return view_as<VPN>(coolBean);
	}
}

public Plugin myinfo = {
	name        = "[NGS] Proxy Checker",
	author      = "TheXeon",
	description = "Simple checker against API for proxies/VPNs.",
	version     = "1.3.3",
	url         = "https://www.neogenesisnetwork.net"
}

public void OnPluginStart()
{
	AutoExecConfig_SetCreateDirectory(true);
	AutoExecConfig_SetCreateFile(true);
	AutoExecConfig_SetFile("proxychecker");
	bool appended;
	cvarContactEmail = AutoExecConfig_CreateConVarCheckAppend(appended, "proxychecker_email", "dummy@dummy.dummy", "Contact email for free APIs to use.");
	cvarLowestTolerableTime = AutoExecConfig_CreateConVarCheckAppend(appended, "proxychecker_lowest_time", "45.0", "Lowest possible time for the processing timer to be.");
	AutoExecConfig_ExecAndClean(appended);

	#if defined DEBUG
	RegAdminCmd("sm_triggerproxytimer", CommandTriggerTimer, ADMFLAG_ROOT);
	RegAdminCmd("sm_clearproxycache", CommandClearProxyCache, ADMFLAG_ROOT);
	#endif
	RegAdminCmd("sm_reloadproxyconfig", CommandReloadProxyConfig, ADMFLAG_GENERIC, "Reloads all proxy services from config file.");

	requestCache = new StringMap();
}

public void OnPluginEnd()
{
	KeyValues kv = new KeyValues("Cache");
	kv.SetNum("cachedTime", twentyFourHourTimeStamp);
	char buffer[256];
	int perDaySoFar;
	for (int i = 0; i < vpnList.Length; i++)
	{
		VPN vpn = vpnList.Get(i);
		vpn.GetString("type", buffer, sizeof(buffer));
		vpn.GetValue("perDaySoFar", perDaySoFar);
		kv.JumpToKey(buffer, true);
		kv.SetNum("perDaySoFar", perDaySoFar);
		kv.GoBack();
	}
	kv.Rewind();
	char cachePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, cachePath, sizeof(cachePath), "data/proxycheckercache.cfg");
	kv.ExportToFile(cachePath);
	delete kv;
}

stock void ParseWhiteListBlackList()
{
	bool whiteListMode = true;
	char path[PLATFORM_MAX_PATH], line[128];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/proxywhitelist.cfg");
	if (!FileExists(path))
	{
		LogMessage("No whitelist/blacklist file exists at %s! If you would" ...
		" like to whitelist or blacklist IPs, please get it from the" ...
		" repo or create it!", path);
		return;
	}
	else
	{
		LogMessage("Successfully enabled whitelist/blacklist file!");
	}
	File whiteListFile = OpenFile(path, "r");
	while (!whiteListFile.EndOfFile() && whiteListFile.ReadLine(line, 
		sizeof(line)))
	{
		TrimString(line);
		if (strlen(line) < 1 || line[0] == '#' || line[0] == '/') {
			continue;
		} else if (line[0] == 'w') {
			whiteListMode = true;
		} else if (line[0] == 'b') {
			whiteListMode = false;
		} else {
			PrintToServerDebug("%s %s!", whiteListMode ? "Whitelisting" : "Blacklisting", line);
			requestCache.SetValue(line, whiteListMode);
		}
	}
	delete whiteListFile;
}

public void OnConfigsExecuted()
{
	#if defined DEBUG
	char cvarValue[256];
	cvarContactEmail.GetString(cvarValue, sizeof(cvarValue));
	PrintToServer("After AutoExecConfig is all run, email is %s", cvarValue);
	cvarLowestTolerableTime.GetString(cvarValue, sizeof(cvarValue));
	PrintToServer("After AutoExecConfig is all run, lowest tolerable time is %s", cvarValue);
	#endif
	char configPath[PLATFORM_MAX_PATH], cachePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, configPath, sizeof(configPath), "configs/proxychecker.cfg");
	BuildPath(Path_SM, cachePath, sizeof(cachePath), "data/proxycheckercache.cfg");
	if (FileExists(configPath))
	{
		ReadProxyConfigFile(configPath, cachePath, true);
	}
	else
	{
		SetFailState("Required configuration file at %s is not there! Get it from the repo!", configPath);
	}

	ParseWhiteListBlackList();
}

void ReadProxyConfigFile(const char[] configPath, const char[] cachePath, bool stopNotNull=false)
{
	if (stopNotNull && vpnList != null)
	{
		return;
	}
	delete config;
	delete processQueueTimer;
	if (vpnList != null && vpnList.Length > 0)
	{
		for (int i = 0; i < vpnList.Length; i++)
		{
			VPN removeVPN = vpnList.Get(i);
			delete removeVPN;
		}
	}
	delete vpnList;
	vpnList = new ArrayList();
	config = new KeyValues("Checkers");
	if (!config.ImportFromFile(configPath))
	{
		SetFailState("Could not read from required config at %s, please get it from the repo!", configPath);
	}

	if (!config.GotoFirstSubKey())
	{
		delete config;
		SetFailState("Malformed config at %s, please correct it from the repo!", configPath);
	}

	// Iterate over subsections at the same nesting level
	char buffer[256], url[1024], email[256];
	float probability, lowestPerMin;
	int perMin, perDay, totalPerDay;
	cvarContactEmail.GetString(email, sizeof(email));
	if (StrEqual(email, "dummy@dummy.dummy"))
	{
		SetFailState("Please set a valid email in the config and reload the plugin, currently %s!", email);
	}

	do
	{
		config.GetSectionName(buffer, sizeof(buffer));
		config.GetString("url", url, sizeof(url));
		ReplaceString(url, sizeof(url), "{CONTACTEMAIL}", email);
		perMin = config.GetNum("requestspermin");
		perDay = config.GetNum("requestsperday");
		probability = config.GetFloat("probability", -1.0);
		vpnList.Push(new VPN(buffer, url, perMin, perDay, probability));
		if (StrEqual(buffer, "getipintel"))
		{
			strcopy(getIPIntelURL, sizeof(getIPIntelURL), url);
			getIpIntelProbability = probability;
		}
		else if (StrEqual(buffer, "proxycheck.io"))
		{
			strcopy(proxyCheckIOURL, sizeof(proxyCheckIOURL), url);
		}
		if (!lowestPerMin || lowestPerMin > perMin)
		{
			lowestPerMin = float(perMin);
		}
		totalPerDay += perDay;
	}
	while (config.GotoNextKey());

	float possibleTotal = float(RoundToCeil(84600.0 / totalPerDay) + 5);
	lowestPerMin = 60.0 / lowestPerMin; // stretch over seconds.

	float lowestTolerableTime = cvarLowestTolerableTime.FloatValue;
	float time = (possibleTotal > lowestTolerableTime && possibleTotal > lowestPerMin) ?
		possibleTotal : (lowestPerMin > lowestTolerableTime) ? lowestPerMin : lowestTolerableTime;

	if (FileExists(cachePath) && vpnList.Length > 0)
	{
		KeyValues kv = new KeyValues("Cache");
		if (kv.ImportFromFile(cachePath))
		{
			kv.Rewind();
			twentyFourHourTimeStamp = kv.GetNum("cachedTime");
			int offsetTime = GetTime() - twentyFourHourTimeStamp;
			if (offsetTime < 86400)
			{
				vpnToUse = 0;
				for (int i = 0; i < vpnList.Length; i++)
				{
					VPN vpn = vpnList.Get(i);
					vpn.GetString("type", buffer, sizeof(buffer));
					if (kv.JumpToKey(buffer))
					{
						int perDaySoFar = kv.GetNum("perDaySoFar");
						vpn.GetValue("perDay", perDay);
						vpn.SetValue("perDaySoFar", perDaySoFar);
						if (perDaySoFar >= perDay)
						{
							vpnToUse++;
							PrintToServerDebug("Rolling vpnList to %d as perDaySoFar of %d is >= %s\'s perDay of %d", vpnToUse, perDaySoFar, buffer, perDay);
							if (vpnToUse == vpnList.Length)
							{
								PrintToServerDebug("Just totally invalidating vpnToUse as all are taken up. List length is %d", vpnList.Length);
								vpnToUse = -1;
							}
						}
						PrintToServerDebug("Setting %s perDaySoFar to %d!", buffer, kv.GetNum("perDaySoFar"));
					}
					kv.GoBack();
				}
			}
		}
		delete kv;
	}

	if (processQueue == null)
	{
		processQueue = new SMQueue();
	}
	processQueueTimer = new SMTimer(time, OnProcessQueueTimer, _, TIMER_REPEAT); // saved for later delete/reuse if needed
	PrintToServerDebug("Set process queue timer to %0.2f with lowestPerMin at %0.2f and " ...
		"totalPerDay at %d", time, lowestPerMin, totalPerDay);
}

#if defined DEBUG
public Action CommandTriggerTimer(int client, int args)
{
	ReplyToCommand(client, "Triggered proxy check timer!");
	processQueueTimer.Trigger();
	return Plugin_Handled;
}

public Action CommandClearProxyCache(int client, int args)
{
	delete requestCache;
	requestCache = new StringMap();
	ReplyToCommand(client, "Cleared the proxy cache entirely!");
	return Plugin_Handled;
}
#endif

public Action CommandReloadProxyConfig(int client, int args)
{
	char configPath[PLATFORM_MAX_PATH], cachePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, configPath, sizeof(configPath), "configs/proxychecker.cfg");
	BuildPath(Path_SM, cachePath, sizeof(cachePath), "data/proxycheckercache.cfg");
	if (FileExists(configPath))
	{
		ReadProxyConfigFile(configPath, cachePath);
	}
	else
	{
		SetFailState("Required configuration file at %s is not there! Get it from the repo!", configPath);
	}
	ReplyToCommand(client, "Proxies have been reloaded!");
	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	if (!IsFakeClient(client))
	{
		bool isSafe;
		char ip[24];
		GetClientIP(client, ip, sizeof(ip));

		if (requestCache != null && requestCache.GetValue(ip, isSafe) && isSafe)
		{
			PrintToServerDebug("Retrieved notion that client %L is safe", client);
			return;
		}

		DataPack pack = new DataPack();
		if (processQueue != null)
		{
			pack.WriteCell(GetClientUserId(client));
			pack.WriteString(ip);
			processQueue.Enqueue(pack);
		}
	}
}

public Action OnProcessQueueTimer(Handle timer)
{
	char ip[24];
	bool dummy;
	DataPack pack;
	while (!processQueue.isEmpty())
	{
		pack = processQueue.Dequeue();
		pack.Reset();
		pack.ReadCell();
		pack.ReadString(ip, sizeof(ip));
		PrintToServerDebug("ProcessQueue is not empty, processing %s.", ip);
		if (requestCache.GetValue(ip, dummy))
		{
			PrintToServerDebug("Got ip %s from cache, already processed.", ip);
			delete pack; // already cached
		}
		else
		{
			PrintToServerDebug("Ip %s not in cache, sending request.", ip);
			SendCheckRequest(pack);
			break;
		}
	}
}

void SendCheckRequest(DataPack pack)
{
	if (vpnList != null)
	{
		int now = GetTime();
		if (!twentyFourHourTimeStamp)
		{
			twentyFourHourTimeStamp = now;
		}
		else if (now - twentyFourHourTimeStamp >= 86400)
		{
			PrintToServerDebug("now: %d minus priortimestamp: %d is greater than a day, reseting daily values.", now, twentyFourHourTimeStamp);
			for (int i = 0; i < vpnList.Length; i++)
			{
				VPN vpn = vpnList.Get(i);
				vpn.SetValue("perDaySoFar", 0);
			}
			twentyFourHourTimeStamp = now;
			if (vpnList.Length > 0 && vpnToUse < 0)
			{
				vpnToUse = 0; // this should never be needed, but just in case
			}
		}

		if (vpnList.Length > 0 && vpnToUse >= 0)
		{
			char type[256];
			VPN vpn = vpnList.Get(vpnToUse);
			vpn.GetString("type", type, sizeof(type));
			if (StrEqual(type, "getipintel"))
			{
				SendGetIPIntelRequest(pack);
			}
			else if (StrEqual(type, "proxycheck.io"))
			{
				SendProxyCheckIORequest(pack);
			}
			int soFarToday, allowedPerDay;
			vpn.GetValue("perDaySoFar", soFarToday);
			vpn.SetValue("perDaySoFar", soFarToday + 1);
			vpn.GetValue("perDay", allowedPerDay);
			if (soFarToday + 1 == allowedPerDay)
			{
				PrintToServerDebug("soFarToday + 1 == allowedPerDay for service %s!", type);
				if (vpnToUse + 1 == vpnList.Length)
				{
					PrintToServerDebug("vpnToUse runs off the end of the list, invalidating vpnToUse");
					vpnToUse = -1; // wait to cycle back
				}
				else
				{
					PrintToServerDebug("vpnToUse is being iterated by 1 to %d.", vpnToUse + 1);
					vpnToUse++;
				}
			}
		}
		else
		{
			PrintToServerDebug("vpnToUse is -1 requeuing datapack at beginning");
			processQueue.EnqueueAt(0, pack);
		}
	}
}

void SendGetIPIntelRequest(DataPack pack)
{
	char contactAddr[256], ip[24], formatURL[1024];
	pack.Reset();
	pack.ReadCell();
	pack.ReadString(ip, sizeof(ip));
	cvarContactEmail.GetString(contactAddr, sizeof(contactAddr));
	if (StrEqual("dummy@dummy.dummy", contactAddr))
	{
		LogError("SPAMMY ERRORS! Please change the email used with the proxy checker to something valid!");
		delete pack;
		return;
	}
	strcopy(formatURL, sizeof(formatURL), getIPIntelURL);
	ReplaceString(formatURL, sizeof(formatURL), "{CLIENTIP}", ip);
	SWHTTPRequest request = new SWHTTPRequest(k_EHTTPMethodGET, formatURL);
	request.SetContextValue(pack);
	request.SetCallbacks(OnGetIPIntelRequestDone);
	request.Send();
	PrintToServerDebug("Sending getipintel request at url %s .", formatURL);
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
			LogError("Get IP Intel request failed for userid %d! There were too many requests, please investigate this!", userid);
			processQueue.Enqueue(pack);
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
	PrintToServerDebug("Probability for proxy is %.2f for ip %s!", probability, ip);
	if (probability >= getIpIntelProbability)
	{
		ServerCommand("sm_banip %s 0 Suspicion of proxy with probability %.2f", ip, probability);
		if (userid != 0 && client != 0) // might be redundant, only client is needed.
		{
			KickClient(client, "%.2f percent suspicion of proxy server.", probability);
		}
		requestCache.SetValue(ip, false); // TODO: Make cache erase after a while
	}
	else
	{
		requestCache.SetValue(ip, true); // TODO: Make cache erase after a while
	}
	PrintToServerDebug("Caching probability %.02f for client %L.", probability, client);
}

void SendProxyCheckIORequest(DataPack pack)
{
	char ip[24], formatURL[1024];
	pack.Reset();
	pack.ReadCell();
	pack.ReadString(ip, sizeof(ip));
	strcopy(formatURL, sizeof(formatURL), proxyCheckIOURL);
	ReplaceString(formatURL, sizeof(formatURL), "{CLIENTIP}", ip);
	SWHTTPRequest request = new SWHTTPRequest(k_EHTTPMethodGET, formatURL);
	request.SetContextValue(pack);
	request.SetCallbacks(OnProxyCheckIORequestDone);
	request.Send();
	PrintToServerDebug("Sending proxycheckio request at url %s .", formatURL);
}

public void OnProxyCheckIORequestDone(SWHTTPRequest hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, DataPack pack)
{
	pack.Reset();
	int userid = pack.ReadCell();
	char ip[24];
	pack.ReadString(ip, sizeof(ip));
	if(eStatusCode != k_EHTTPStatusCode200OK || !bRequestSuccessful)
	{
		LogError("ProxyCheck.io request failed for userid %d! Status code is %d, success was %s.", userid, eStatusCode, (bRequestSuccessful) ? "true" : "false");
		processQueue.Enqueue(pack); // deprioritize this
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

	PrintToServerDebug("ProxyCheck.io request returned %s", buffer);

	JSON_Object reponse = new JSON_Object();
	reponse.Decode(buffer);
	char status[24];
	reponse.GetString("status", status, sizeof(status));
	if (!StrEqual(status, "ok"))
	{
		char message[256];
		reponse.GetString("message", message, sizeof(message));
		if (StrEqual("warning", status))
		{
			LogMessage("ProxyCheck.io error: %s", message);
		}
		else
		{
			LogError("ProxyCheck.io error: %s", message);
		}
	}
	else
	{
		char isProxy[8], proxyType[24];
		JSON_Object ipObj = reponse.GetObject(ip);
		ipObj.GetString("proxy", isProxy, sizeof(isProxy));
		PrintToServerDebug("Result for proxy is %s <%s> for ip %s!", isProxy, (isProxy[0] == 'y') ? proxyType : "none", ip);
		if (StrEqual(isProxy, "yes"))
		{
			ipObj.GetString("type", proxyType, sizeof(proxyType));
			ServerCommand("sm_banip %s 0 Suspicion of proxy with type %s", ip, proxyType);
			if (userid != 0 && client != 0) // might be redundant, only client is needed.
			{
				KickClient(client, "Suspicion of proxy server with type %s.", proxyType);
			}
			requestCache.SetValue(ip, false); // TODO: Make cache erase after a while
		}
		else
		{
			requestCache.SetValue(ip, true); // TODO: Make cache erase after a while
		}
		PrintToServerDebug("Caching suspicion of %s for ip %s.", isProxy, ip);
	}
	reponse.Cleanup();
	delete reponse;
}
