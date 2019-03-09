#pragma semicolon 1

#include <sourcemod>

//Store Includes
#include <store/store-core>
#include <store/store-logging>

#pragma newdecls required

#define PLUGIN_NAME "[Store] Logging Module"
#define PLUGIN_DESCRIPTION "Logging module for the Sourcemod Store."
#define PLUGIN_VERSION_CONVAR "store_logging_version"

enum ELOG_LEVEL
{
	EMERGENCY = 0,
	ALERT,
	CRITICAL,
	ERROR,
	WARNING,
	NOTICE,
	INFORMATIONAL,
	DEBUG
}

char g_sELogLevel[8][32] =
{
	"emergency",
	"alert",
	"critical",
	"error",
	"warning",
	"notice",
	"informational",
	"debug"
};

//Config Globals
char sLoggingPath[PLATFORM_MAX_PATH] = "store";
char sLoggingFilename[64] = "store";
char sDateFormat[12] = "%Y-%m-%d";

bool bLog_Emergency = true;
bool bLog_Alert = true;
bool bLog_Critical = true;
bool bLog_Error = true;
bool bLog_Warning = true;
bool bLog_Notice = true;
bool bLog_Informational = true;
bool bLog_Debug = true;

bool bFolder_Emergency = false;
bool bFolder_Alert = false;
bool bFolder_Critical = false;
bool bFolder_Error = false;
bool bFolder_Warning = false;
bool bFolder_Notice = false;
bool bFolder_Informational = false;
bool bFolder_Debug = false;

bool bSQLLogging;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = STORE_AUTHORS,
	description = PLUGIN_DESCRIPTION,
	version = STORE_VERSION,
	url = STORE_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Store_LogEmergency", Native_Store_LogEmergency);
	CreateNative("Store_LogAlert", Native_Store_LogAlert);
	CreateNative("Store_LogCritical", Native_Store_LogCritical);
	CreateNative("Store_LogError", Native_Store_LogError);
	CreateNative("Store_LogWarning", Native_Store_LogWarning);
	CreateNative("Store_LogNotice", Native_Store_LogNotice);
	CreateNative("Store_LogInformational", Native_Store_LogInformational);
	CreateNative("Store_LogDebug", Native_Store_LogDebug);

	RegPluginLibrary("store-logging");
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar(PLUGIN_VERSION_CONVAR, STORE_VERSION, PLUGIN_NAME, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);

	LoadConfig("Logging", "configs/store/logging.cfg");
}

public void Store_OnDatabaseInitialized()
{
	Store_RegisterPluginModule(PLUGIN_NAME, PLUGIN_DESCRIPTION, PLUGIN_VERSION_CONVAR, STORE_VERSION);
}

void LoadConfig(const char[] sName, const char[] sFile)
{
	Handle hKV = CreateKeyValues(sName);

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), sFile);

	if (!FileToKeyValues(hKV, sPath))
	{
		CloseHandle(hKV);
		SetFailState("Can't read config file %s", sPath);
	}

	KvGetString(hKV, "logging_path", sLoggingPath, sizeof(sLoggingPath), "store");
	KvGetString(hKV, "logging_filename", sLoggingFilename, sizeof(sLoggingFilename), "store");
	KvGetString(hKV, "date_format", sDateFormat, sizeof(sDateFormat), "%Y-%m-%d");

	if (KvJumpToKey(hKV, "Logging_types"))
	{
		bLog_Emergency = view_as<bool>(KvGetNum(hKV, "emergency", 1));
		bLog_Alert = view_as<bool>(KvGetNum(hKV, "alert", 1));
		bLog_Critical = view_as<bool>(KvGetNum(hKV, "critical", 1));
		bLog_Error = view_as<bool>(KvGetNum(hKV, "error", 1));
		bLog_Warning = view_as<bool>(KvGetNum(hKV, "warning", 1));
		bLog_Notice = view_as<bool>(KvGetNum(hKV, "notice", 1));
		bLog_Informational = view_as<bool>(KvGetNum(hKV, "informational", 1));
		bLog_Debug = view_as<bool>(KvGetNum(hKV, "debug", 1));

		KvGoBack(hKV);
	}

	bool bSubDirectories = view_as<bool>(KvGetNum(hKV, "log_subfolders", 0));

	if (bSubDirectories && KvJumpToKey(hKV, "Logging_subfolders"))
	{
		bFolder_Emergency = view_as<bool>(KvGetNum(hKV, "emergency", 0));
		bFolder_Alert = view_as<bool>(KvGetNum(hKV, "alert", 0));
		bFolder_Critical = view_as<bool>(KvGetNum(hKV, "critical", 0));
		bFolder_Error = view_as<bool>(KvGetNum(hKV, "error", 0));
		bFolder_Warning = view_as<bool>(KvGetNum(hKV, "warning", 0));
		bFolder_Notice = view_as<bool>(KvGetNum(hKV, "notice", 0));
		bFolder_Informational = view_as<bool>(KvGetNum(hKV, "informational", 0));
		bFolder_Debug = view_as<bool>(KvGetNum(hKV, "debug", 0));

		KvGoBack(hKV);
	}

	bSQLLogging = view_as<bool>(KvGetNum(hKV, "log_sql_data", 1));

	CloseHandle(hKV);

	Store_LogInformational("Store Config '%s' Loaded: %s", sName, sFile);
}

public int Native_Store_LogEmergency(Handle hPlugin, int iParams)
{
	if (!bLog_Emergency)return;

	char sFormat[1024];
	FormatNativeString(0, 1, 2, sizeof(sFormat), _, sFormat);

	char sDate[24];
	FormatTime(sDate, sizeof(sDate), sDateFormat, GetTime());

	Log_File(hPlugin, sLoggingPath, sLoggingFilename, sDate, EMERGENCY, bFolder_Emergency, sFormat);
}

public int Native_Store_LogAlert(Handle hPlugin, int iParams)
{
	if (!bLog_Alert)return;

	char sFormat[1024];
	FormatNativeString(0, 1, 2, sizeof(sFormat), _, sFormat);

	char sDate[24];
	FormatTime(sDate, sizeof(sDate), sDateFormat, GetTime());

	Log_File(hPlugin, sLoggingPath, sLoggingFilename, sDate, ALERT, bFolder_Alert, sFormat);
}

public int Native_Store_LogCritical(Handle hPlugin, int iParams)
{
	if (!bLog_Critical)return;

	char sFormat[1024];
	FormatNativeString(0, 1, 2, sizeof(sFormat), _, sFormat);

	char sDate[24];
	FormatTime(sDate, sizeof(sDate), sDateFormat, GetTime());

	Log_File(hPlugin, sLoggingPath, sLoggingFilename, sDate, CRITICAL, bFolder_Critical, sFormat);
}

public int Native_Store_LogError(Handle hPlugin, int iParams)
{
	if (!bLog_Error)return;

	char sFormat[1024];
	FormatNativeString(0, 1, 2, sizeof(sFormat), _, sFormat);

	char sDate[24];
	FormatTime(sDate, sizeof(sDate), sDateFormat, GetTime());

	Log_File(hPlugin, sLoggingPath, sLoggingFilename, sDate, ERROR, bFolder_Error, sFormat);
}

public int Native_Store_LogWarning(Handle hPlugin, int iParams)
{
	if (!bLog_Warning)return;

	char sFormat[1024];
	FormatNativeString(0, 1, 2, sizeof(sFormat), _, sFormat);

	char sDate[24];
	FormatTime(sDate, sizeof(sDate), sDateFormat, GetTime());

	Log_File(hPlugin, sLoggingPath, sLoggingFilename, sDate, WARNING, bFolder_Warning, sFormat);
}

public int Native_Store_LogNotice(Handle hPlugin, int iParams)
{
	if (!bLog_Notice)return;

	char sFormat[1024];
	FormatNativeString(0, 1, 2, sizeof(sFormat), _, sFormat);

	char sDate[24];
	FormatTime(sDate, sizeof(sDate), sDateFormat, GetTime());

	Log_File(hPlugin, sLoggingPath, sLoggingFilename, sDate, NOTICE, bFolder_Notice, sFormat);
}

public int Native_Store_LogInformational(Handle hPlugin, int iParams)
{
	if (!bLog_Informational)return;

	char sFormat[1024];
	FormatNativeString(0, 1, 2, sizeof(sFormat), _, sFormat);

	char sDate[24];
	FormatTime(sDate, sizeof(sDate), sDateFormat, GetTime());

	Log_File(hPlugin, sLoggingPath, sLoggingFilename, sDate, INFORMATIONAL, bFolder_Informational, sFormat);
}

public int Native_Store_LogDebug(Handle hPlugin, int iParams)
{
	if (!bLog_Debug)return;

	char sFormat[1024];
	FormatNativeString(0, 1, 2, sizeof(sFormat), _, sFormat);

	char sDate[24];
	FormatTime(sDate, sizeof(sDate), sDateFormat, GetTime());

	Log_File(hPlugin, sLoggingPath, sLoggingFilename, sDate, DEBUG, bFolder_Debug, sFormat);
}

void Log_File(Handle hPlugin, const char[] sPath = "", const char[] sFile = "store", const char[] sDate = "", ELOG_LEVEL eLevel, bool bLogToFolder, const char[] format, any...)
{
	char sPath_Build[PLATFORM_MAX_PATH];
	if (strlen(sPath) != 0)
	{
		BuildPath(Path_SM, sPath_Build, sizeof(sPath_Build), "logs/%s", sPath);

		if (!DirExists(sPath_Build))
		{
			CreateDirectory(sPath_Build, 511);
		}
	}
	else
	{
		BuildPath(Path_SM, sPath_Build, sizeof(sPath_Build), "logs");
	}

	char sLevelPath[PLATFORM_MAX_PATH];
	if (bLogToFolder)
	{
		Format(sLevelPath, sizeof(sLevelPath), "%s/%s", sPath_Build, g_sELogLevel[eLevel]);
	}
	else
	{
		Format(sLevelPath, sizeof(sLevelPath), "%s", sPath_Build);
	}


	if (!DirExists(sLevelPath))
	{
		CreateDirectory(sLevelPath, 511);
	}

	char sFile_Build[PLATFORM_MAX_PATH];

	if (strlen(sDate) != 0)
	{
		Format(sFile_Build, sizeof(sFile_Build), "%s/%s_%s.log", sLevelPath, sFile, sDate);
	}
	else
	{
		Format(sFile_Build, sizeof(sFile_Build), "%s/%s.log", sLevelPath, sFile);
	}

	char sMessage[1024];
	VFormat(sMessage, sizeof(sMessage), format, 8);

	if (bSQLLogging)
	{
		char sPluginName[128];
		GetPluginInfo(hPlugin, PlInfo_Name, sPluginName, sizeof(sPluginName));
		Store_SQLLogQuery(g_sELogLevel[eLevel], sPluginName, sMessage);
	}

	Format(sMessage, sizeof(sMessage), "[Store] %s", sMessage);
	LogToFileEx(sFile_Build, sMessage);
}
