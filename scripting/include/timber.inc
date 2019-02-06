#if defined _timber_included
#endinput
#endif
#define _timber_included

// Name from the wonderful Timber library by JakeWharton

#tryinclude <autoexecconfig>

enum TimberLogLevel {
	Log_Error = 0,
    Log_Warning,
	Log_Info,
	Log_Debug,
    Log_Verbose
}

ConVar timber__cvarLogThroughTimber;
ConVar timber__cvarLogToFile;

methodmap Timber
{
    // From DrMckay's LogItem stock, modified for Timber :)
    public static void log(TimberLogLevel level, const char[] log)
    {
        if (timber__cvarLogThroughTimber == null)
        {
            return;
        }

        int logLevel = timber__cvarLogThroughTimber.IntValue;
        if(logLevel < view_as<int>(level))
        {
            return;
        }

        char pluginName[128];
        GetPluginFilename(null, pluginName, sizeof(pluginName));
        ReplaceString(pluginName, sizeof(pluginName), ".smx", "");
        char logPrefixes[][] = {"[ERROR]", "[WARNING]", "[INFO]", "[DEBUG]", "[VERBOSE]"};
        if (timber__cvarLogToFile != null && timber__cvarLogToFile.BoolValue)
        {
            char file[PLATFORM_MAX_PATH];
            BuildPath(Path_SM, file, sizeof(file), "logs/%s.log", pluginName);
            LogToFileEx(file, "%s %s", logPrefixes[view_as<int>(level)], log);
        }
        else
        {
            LogMessage("%s %s", logPrefixes[view_as<int>(level)], log);
        }
    }

    public static void v(const char[] log, any ...)
    {
        if (timber__cvarLogThroughTimber != null)
        {
            char logLine[8192];
            VFormat(logLine, sizeof(logLine), log, 2);
            this.log(Log_Verbose, logLine);
        }
    }

    public static void d(const char[] log, any ...)
    {
        if (timber__cvarLogThroughTimber != null)
        {
            char logLine[8192];
            VFormat(logLine, sizeof(logLine), log, 2);
            Timber.log(Log_Debug, logLine);
        }
    }

    public static void e(const char[] log, any ...)
    {
        if (timber__cvarLogThroughTimber != null)
        {
            char logLine[8192];
            VFormat(logLine, sizeof(logLine), log, 2);
            Timber.log(Log_Error, logLine);
        }
    }

    public static void w(const char[] log, any ...)
    {
        if (timber__cvarLogThroughTimber != null)
        {
            char logLine[8192];
            VFormat(logLine, sizeof(logLine), log, 2);
            Timber.log(Log_Warning, logLine);
        }
    }

    public static void i(const char[] log, any ...)
    {
        if (timber__cvarLogThroughTimber != null)
        {
            char logLine[8192];
            VFormat(logLine, sizeof(logLine), log, 2);
            Timber.log(Log_Verbose, logLine);
        }
    }

    public static void plant(bool &appended = false)
    {
        char pluginName[128], cvarName[256];
        GetPluginFilename(null, pluginName, sizeof(pluginName));
        ReplaceString(pluginName, sizeof(pluginName), ".smx", "");
        Format(cvarName, sizeof(cvarName), "%s_log_level", pluginName);
        #if defined _autoexecconfig_included
        timber__cvarLogThroughTimber = AutoExecConfig_CreateConVarCheckAppend(appended, cvarName, "0", "-1: None\n0: Errors\n1: Warnings\n2: Info\n3: Debug\n4: Verbose");
        #else
        timber__cvarLogThroughTimber = CreateConVar(cvarName, "0", "-1: None\n0: Errors\n1: Warnings\n2: Info\n3: Debug\n4: Verbose");
        #endif
    }
    
    public static void plantToFile(bool &appended = false)
    {
        char pluginName[128], cvarName[256];
        GetPluginFilename(null, pluginName, sizeof(pluginName));
        ReplaceString(pluginName, sizeof(pluginName), ".smx", "");
        Format(cvarName, sizeof(cvarName), "%s_log_file", pluginName);
        #if defined _autoexecconfig_included
        timber__cvarLogToFile = AutoExecConfig_CreateConVarCheckAppend(appended, cvarName, "0", "0: Don't log to file.\n1: Log to file.");
        #else
        timber__cvarLogToFile = CreateConVar(cvarName, "0", "0: Don't log to file.\n1: Log to file.");
        #endif
        Timber.plant(appended);
    }
}