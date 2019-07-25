/*
*****************************************************************************************************
 * [ANY] NGS Earn Adverts
 * Displays In-Game NGS Earn Adverts.
 *
 * Copyright (C)2014-2018 Very Poor People LLC. All rights reserved.
 * Copyright (C)2019 Neogenesis Network. All rights reserved.
 
*****************************************************************************************************
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <https://www.gnu.org/licenses/#GPL>.
 
*****************************************************************************************************


****************************************************************************************************
    ETIQUETTE.
*****************************************************************************************************/
#pragma newdecls required
#pragma semicolon 1
#pragma dynamic 131072


/****************************************************************************************************
    DEFINES
*****************************************************************************************************/
#define CONTENT_URL "https://github.com/NGSNetwork/sm-plugins/raw/master/"
#define RELOAD_ON_UPDATE 1
#define LoopValidClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsValidClient(%1))

/*****************************************************************************************************
    INCLUDES
*****************************************************************************************************/
#include <autoexecconfig>
#include <multicolors>
#include <SteamWorks>
#include <ngs_earn_adverts>
#include <zephstocks>
#include <ngsutils>
#include <ngsupdater>

/****************************************************************************************************
    PLUGIN INFO.
*****************************************************************************************************/
public Plugin myinfo = 
{
    name = "NGS Earn Advertisement Plugin", 
    author = "TheXeon", 
    description = "Plugin for NGS Network Earn", 
    version = "0.0.1", 
    url = "https://earn.neogenesisnetwork.net/"
}

/****************************************************************************************************
    HANDLES.
*****************************************************************************************************/
ConVar g_hNGSUrl = null;
ConVar g_hCvarJoinGame = null;
ConVar g_hCvarAdvertPeriod = null;
ConVar g_hCvarImmunityEnabled = null;
ConVar g_hCvarAdvertTotal = null;
ConVar g_hCvarPhaseAds = null;
ConVar g_hCvarMotdCheck = null;
ConVar g_hCvarSpecAdvertPeriod = null;
ConVar g_hCvarMessages = null;
ConVar g_hCvarWaitUntilDead = null;
ConVar g_hCvarDisableMotd = null;
ConVar g_hCvarUnloadOnDismissal = null;

Handle g_hQueueTimer[MAXPLAYERS + 1];
Handle g_hFinishedTimer[MAXPLAYERS + 1];
Handle g_hSpecTimer[MAXPLAYERS + 1];
Handle g_hPeriodicTimer[MAXPLAYERS + 1];
Handle g_hOnAdvertStarted = null;
Handle g_hOnAdvertFinished = null;

Menu g_mMenuWarning = null;

EngineVersion g_eVersion = Engine_Unknown;

DataPack g_dCache[MAXPLAYERS + 1];

/****************************************************************************************************
    STRINGS.
*****************************************************************************************************/
char g_szNGSUrl[256];
char g_szGameName[256];

char g_szResumeUrl[MAXPLAYERS + 1][256];
char g_szServerIP[64];

/****************************************************************************************************
    BOOLS.
*****************************************************************************************************/
bool g_bJoinAdverts = false;
bool g_bProtoBuf = false;
bool g_bPhaseAds = false;
bool g_bPhase = false;
bool g_bForceJoinGame = false;
bool g_bImmunityEnabled = false;
bool g_bMessages = false;
bool g_bWaitUntilDead = false;
bool g_bHasClasses = false;
bool g_bFirstMotd[MAXPLAYERS + 1] =  { true, ... };
bool g_bAdvertPlaying[MAXPLAYERS + 1];
bool g_bMotdDisabled[MAXPLAYERS + 1];
bool g_bAdRequeue[MAXPLAYERS + 1];
bool g_bGameJoined[MAXPLAYERS + 1];
bool g_bAdvertCleared[MAXPLAYERS + 1] =  { true, ... };

/****************************************************************************************************
    INTS.
*****************************************************************************************************/
int g_iAdvertTotal = -1;
int g_iAdvertRequests[MAXPLAYERS + 1];
int g_iLastAdvertTime[MAXPLAYERS + 1];
int g_iMotdOccurence[MAXPLAYERS + 1];
int g_iMotdAction = 0;
int g_iPort = -1;

/****************************************************************************************************
    FLOATS.
*****************************************************************************************************/
float g_fAdvertPeriod;
float g_fSpecAdvertPeriod;

#include <ngsearn/motdgd>

public void OnPluginStart()
{		
    UserMsg umVGUIMenu = GetUserMessageId("VGUIMenu");
    
    if (umVGUIMenu == INVALID_MESSAGE_ID) {
        SetFailState("This game does not support VGUI menu's, please contact us and let us know what game it is!");
    }
    
    HookUserMessage(umVGUIMenu, OnVGUIMenu, true);
    
    g_bProtoBuf = (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf);
    
    if (GetGameFolderName(g_szGameName, sizeof(g_szGameName)) <= 0) {
        SetFailState("Unable to retrieve game directory name, please contact us for support!");
    }
    
    AutoExecConfig_SetFile("plugin.ngs_adverts");
    
    g_hCvarJoinGame = AutoExecConfig_CreateConVar("sm_ngs_onjoin", "1", "Should advertisement be displayed to players on first team join?, 0 = Disabled.", _, true, 0.0, true, 1.0);
    g_hCvarJoinGame.AddChangeHook(OnCvarChanged);
    
    g_hCvarAdvertPeriod = AutoExecConfig_CreateConVar("sm_ngs_ad_period", "5", "How often the periodic adverts should be played (In Minutes), 0 = Disabled.", _, true, 0.0);
    g_hCvarAdvertPeriod.AddChangeHook(OnCvarChanged);
    
    g_hCvarSpecAdvertPeriod = AutoExecConfig_CreateConVar("sm_ngs_spec_ad_period", "5", "How often should ads be played to spectators (In Minutes), 0 = Disabled.", _, true, 0.0);
    g_hCvarSpecAdvertPeriod.AddChangeHook(OnCvarChanged);
    
    g_hCvarPhaseAds = AutoExecConfig_CreateConVar("sm_ngs_onphase", "1", "Should advertisement attempt to be displayed on game phases? (HalfTime, OverTime, MapEnd, WinPanels etc) (This will supersede sm_ngs_wait_until_dead) 0 = Disabled.", _, true, 0.0, true, 1.0);
    g_hCvarPhaseAds.AddChangeHook(OnCvarChanged);
    
    g_hCvarAdvertTotal = AutoExecConfig_CreateConVar("sm_ngs_ad_total", "0", "How many adverts should be played in total (excluding join adverts)? 0 = Unlimited, -1 = Disabled.", _, true, -1.0);
    g_hCvarAdvertTotal.AddChangeHook(OnCvarChanged);
    
    g_hCvarImmunityEnabled = AutoExecConfig_CreateConVar("sm_ngs_immunity_enabled", "0", "Prevent displaying ads to users with access to 'advertisement_immunity', 0 = Disabled. (Default: Reservartion flag)", _, true, 0.0, true, 1.0);
    g_hCvarImmunityEnabled.AddChangeHook(OnCvarChanged);
    
    g_hCvarMotdCheck = AutoExecConfig_CreateConVar("sm_ngs_kickmotd", "0", "Action for player with html motd disabled, 0 = Disabled, 1 = Kick Player, 2 = Display notifications.", _, true, 0.0, true, 2.0);
    g_hCvarMotdCheck.AddChangeHook(OnCvarChanged);
    
    g_hCvarMessages = AutoExecConfig_CreateConVar("sm_ngs_messages", "1", "Show messages to clients, 0 = Disabled.", _, true, 0.0, true, 1.0);
    g_hCvarMessages.AddChangeHook(OnCvarChanged);
    
    g_hCvarWaitUntilDead = AutoExecConfig_CreateConVar("sm_ngs_wait_until_dead", "0", "Wait until player is dead (Except first join) 0 = Disabled.", _, true, 0.0, true, 1.0);
    g_hCvarWaitUntilDead.AddChangeHook(OnCvarChanged);
    
    HookEventEx("game_win", Phase_Hooks, EventHookMode_Pre);
    HookEventEx("game_end", Phase_Hooks, EventHookMode_Pre);
    HookEventEx("round_win", Phase_Hooks, EventHookMode_Pre);
    HookEventEx("tf_game_over", Phase_Hooks, EventHookMode_Pre);
    HookEventEx("teamplay_win_panel", Phase_Hooks, EventHookMode_Pre);
    HookEventEx("teamplay_round_win", Phase_Hooks, EventHookMode_Pre);
    HookEventEx("arena_win_panel", Phase_Hooks, EventHookMode_Pre);
    HookEventEx("announce_phase_end", Phase_Hooks, EventHookMode_Pre);
    HookEventEx("cs_win_panel_match", Phase_Hooks, EventHookMode_Pre);
    HookEventEx("wave_complete", Phase_Hooks, EventHookMode_Pre);
    HookEventEx("dod_game_over", Phase_Hooks, EventHookMode_Pre);
    HookEventEx("dod_win_panel", Phase_Hooks, EventHookMode_Pre);
    HookEventEx("round_start", Event_RoundStart, EventHookMode_Post);
    HookEventEx("teamplay_round_start", Event_RoundStart, EventHookMode_Post);
    HookEventEx("player_team", Event_PlayerTeam, EventHookMode_Post);
    HookEventEx("player_class", Event_Requeue, EventHookMode_Post);
    HookEventEx("player_spawn", Event_Requeue, EventHookMode_Post);
    HookEventEx("player_death", Event_Requeue, EventHookMode_Post);
    
    LoadTranslations("ngs_earn_adverts.phrases.txt");
    
    AutoExecConfig_ExecuteFile();
    
    g_hOnAdvertStarted = CreateGlobalForward("NGS_OnAdvertStarted", ET_Ignore, Param_Cell, Param_String);
    g_hOnAdvertFinished = CreateGlobalForward("NGS_OnAdvertFinished", ET_Ignore, Param_Cell, Param_String);
        
    CreateMotdMenu();
    
    AddCommandListener(JoinGame_Listener, "joingame");

    LoopValidClients(iClient) {
        OnClientPutInServer(iClient);
    }

    connectMOTDgdHub(null);
}

// public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] szError, int iErrMax)
// {
//     CreateNative("NGS_PlayAdvert", Native_PlayAdvert);
//     CreateNative("NGS_IsAdvertPlaying", Native_IsAdvertPlaying);
    
//     RegPluginLibrary("NGSAdverts");
//     return APLRes_Success;
// }

public void OnClientPutInServer(int iClient)
{
    if (!IsValidClient(iClient)) {
        return;
    }
    
    DataPack dPack = new DataPack();
    dPack.WriteCell(GetClientUserId(iClient));
    dPack.WriteCell(false);
    
    QueryClientConVar(iClient, "cl_disablehtmlmotd", Query_MotdPlayAd, dPack);
    
    ClearTimers(iClient, null, true, true);
    
    if (g_fAdvertPeriod > 0.0 && g_fAdvertPeriod < 3.0) {
        g_fAdvertPeriod = 3.0;
        g_hCvarAdvertPeriod.IntValue = 3;
    }
    
    if (g_fAdvertPeriod > 0.0) {
        g_hPeriodicTimer[iClient] = CreateTimer(g_fAdvertPeriod * 60.0, Timer_IntervalAd, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
    }
    
    if (!g_bHasClasses) {
        g_bHasClasses = HasEntProp(iClient, Prop_Send, "m_iClass");
    }
    
    strcopy(g_szResumeUrl[iClient], 128, "about:blank");
    
    g_bFirstMotd[iClient] = true;
    g_bAdvertCleared[iClient] = true;
    g_iMotdOccurence[iClient] = 0;
}

public void OnClientDisconnect(int iClient)
{
    g_iAdvertRequests[iClient] = 0;
    g_iLastAdvertTime[iClient] = 0;
    g_iMotdOccurence[iClient] = 0;
    g_bFirstMotd[iClient] = true;
    g_bAdvertPlaying[iClient] = false;
    g_bMotdDisabled[iClient] = false;
    g_bAdRequeue[iClient] = false;
    g_bGameJoined[iClient] = false;
    g_bAdvertCleared[iClient] = true;
    
    ClearTimers(iClient, null, true, true);
    
    strcopy(g_szResumeUrl[iClient], 128, "about:blank");
}

public void OnMapStart() {
    g_bPhase = false;
}

public void OnConfigsExecuted()
{
    UpdateConVars();
    GetServerIP();
}

public void OnMapEnd()
{
    g_bPhase = false;
}

public void Event_RoundStart(Event eEvent, char[] szEvent, bool bDontBroadcast) {
    g_bPhase = false;
}

public void Phase_Hooks(Event eEvent, char[] szEvent, bool bDontBroadcast)
{
    if (!g_bPhaseAds) {
        return;
    }
    
    g_bPhase = true;
    
    LoopValidClients(iClient) {
        SendAdvert(iClient);
    }
}

public Action Event_PlayerEvents(Event eEvent, char[] szEvent, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    
    if (!IsValidClient(iClient)) {
        return Plugin_Continue;
    }
    
    SendAdvert(iClient);
    return Plugin_Continue;
}

public Action Event_Requeue(Event eEvent, char[] szEvent, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    
    if (!g_bAdRequeue[iClient]) {
        return;
    }
    
    SendAdvert(iClient);
}

public Action Event_PlayerTeam(Event eEvent, char[] szEvent, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    int iTeam = eEvent.GetInt("team");
    bool bDisconnect = eEvent.GetBool("disconnect");
    
    if (!IsValidClient(iClient) || bDisconnect) {
        return Plugin_Continue;
    }
    
    if (iTeam != 1 || g_fSpecAdvertPeriod <= 0.0) {
        NullifyTimer(iClient, g_hSpecTimer[iClient], true);
    }
    
    if (!g_bAdRequeue[iClient] && iTeam != 1) {
        return Plugin_Continue;
    }
    
    SendAdvert(iClient);
    return Plugin_Continue;
}

public Action OnVGUIMenu(UserMsg umId, Handle hMsg, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit)
{
    int iClient = iPlayers[0];
    
    if (!SteamWorks_IsConnected()) {
        return Plugin_Continue;
    }

    if (!IsValidClient(iClient)) {
        return Plugin_Continue;
    }

    char szUrl[256]; char szTitle[256]; char szKey[256];
    bool bShow; bool bCustomSvr; int iWidth; int iHeight;
    bool bGotURL = GetVGUIInfo(iClient, hMsg, szKey, szUrl, szTitle, iWidth, iHeight, bShow, bCustomSvr);
    bool bMotd; bool bNGS; bool bAboutBlank; bool bMotdClear;
    
    if (StrEqual(szTitle, "Clear Motd", false)) {
        bMotdClear = true;
    } else if (StrEqual(szUrl, "motd", false) || StrEqual(szUrl, "motd_text", false)) {
        bMotd = true;
    } else if (StrContains(szUrl, g_szNGSUrl, false) != -1) {
        bNGS = true;
    } else if (StrEqual(szUrl, "about:blank", false)) {
        bAboutBlank = true;
    }
    
    if (GetClientTeam(iClient) < 1 && g_bProtoBuf && !bMotd && !StrEqual(szKey, "team") && !bMotdClear) {
        return Plugin_Handled;
    }
    
    if (!bGotURL) {
        return Plugin_Continue;
    }
    
    if (g_bJoinAdverts && g_bFirstMotd[iClient] && !bMotd && !bNGS && !bMotdClear) {
        return Plugin_Handled;
    }
    
    if (!bMotd && !bNGS && !bMotdClear) {
        strcopy(g_szResumeUrl[iClient], sizeof(szUrl), "about:blank");
    }
    
    if (bNGS && AdShouldWait(iClient)) {
        return Plugin_Handled;
    }
    
    int iUserId = GetClientUserId(iClient);
    
    if (g_bAdvertPlaying[iClient]) {
        if (bAboutBlank || bMotd || bNGS || bMotdClear) {
            return Plugin_Handled;
        }
        
        RequestFrame(PrintMiscMessage, iUserId);
        
        return Plugin_Handled;
    }
    
    if (bMotdClear) {		
        g_bAdvertCleared[iClient] = true;
        
        return Plugin_Continue;
    }
    
    if (!bAboutBlank && !bMotd && !bMotdClear && (!g_bFirstMotd[iClient] || !g_bJoinAdverts)) {
        if (g_dCache[iClient] == null) {
            g_dCache[iClient] = new DataPack();
        }
        
        g_dCache[iClient].Reset();
        g_dCache[iClient].WriteString(szTitle);
        g_dCache[iClient].WriteString(szUrl);
        g_dCache[iClient].WriteCell(iWidth);
        g_dCache[iClient].WriteCell(iHeight);
        g_dCache[iClient].WriteCell(bShow);
        g_dCache[iClient].WriteCell((bReliable ? USERMSG_RELIABLE : 0) | (bInit ? USERMSG_INITMSG : 0));
        g_dCache[iClient].WriteCell(bNGS);
        g_dCache[iClient].WriteCell(bCustomSvr);
        
        DataPack dPack = new DataPack();
        dPack.WriteCell(iUserId);
        dPack.WriteCell(true);
        dPack.Reset();
        
        RequestFrame(ClearMotd, dPack);
        
        return Plugin_Handled;
    }
    
    if (bNGS) {
        RequestFrame(Frame_AdvertStartedForward, iUserId);
        
        g_bAdvertPlaying[iClient] = true;
        g_hFinishedTimer[iClient] = CreateTimer(60.0, Timer_AdvertFinished, iUserId, TIMER_FLAG_NO_MAPCHANGE);
        
        g_bAdRequeue[iClient] = false;
        g_bAdvertCleared[iClient] = false;
        
        g_iLastAdvertTime[iClient] = GetTime();
        g_iAdvertRequests[iClient]++;
        
        return Plugin_Continue;
    }
    
    if (bMotd) {
        if (IsClientImmune(iClient)) {
            g_bFirstMotd[iClient] = false;
            return Plugin_Continue;
        }
        
        // if (++g_iMotdOccurence[iClient] != g_iExpectedMotdOccurence) {
        //     g_bAdvertCleared[iClient] = false;
            
        //     DataPack dPack = new DataPack();
        //     dPack.WriteCell(iUserId);
        //     dPack.WriteCell(false);
        //     dPack.Reset();
            
        //     RequestFrame(ClearMotd, dPack);
        //     return Plugin_Handled;
        // }
        
        if (!g_bJoinAdverts || g_bMotdDisabled[iClient]) {
            g_bFirstMotd[iClient] = false;
            g_bAdRequeue[iClient] = true;
            return Plugin_Continue;
        }
        
        if (!g_bProtoBuf) {
            RequestFrame(Frame_BfMotdOverride, iUserId);
            return Plugin_Handled;
        }
        
        if (!FormatAdvertUrl(iClient, g_szNGSUrl, szUrl) || !ShowVGUIPanelEx(iClient, "NGS Network Advertisement MOTD", szUrl, _, _, _, hMsg)) {
            g_bAdRequeue[iClient] = true;
            g_bAdvertCleared[iClient] = false;
            
            DataPack dPack = new DataPack();
            dPack.WriteCell(iUserId);
            dPack.WriteCell(false);
            dPack.Reset();
            
            RequestFrame(ClearMotd, dPack);
            g_bFirstMotd[iClient] = false;
            return Plugin_Changed;
        }
        
        RequestFrame(Frame_AdvertStartedForward, iUserId);
        
        g_bAdvertPlaying[iClient] = true;
        g_iAdvertRequests[iClient]++;
        g_hFinishedTimer[iClient] = CreateTimer(60.0, Timer_AdvertFinished, iUserId, TIMER_FLAG_NO_MAPCHANGE);
        
        g_bAdvertCleared[iClient] = false;
        g_bFirstMotd[iClient] = false;
        
        return Plugin_Changed;
    }
    
    if (bAboutBlank) {
        g_bAdvertCleared[iClient] = false;
        
        DataPack dPack = new DataPack();
        dPack.WriteCell(iUserId);
        dPack.WriteCell(false);
        dPack.Reset();
        
        RequestFrame(ClearMotd, dPack);
    }
    
    if (!g_bJoinAdverts) {
        g_bAdRequeue[iClient] = true;
    }
    
    if (!bNGS) {
        g_bAdvertCleared[iClient] = true;
    }

    return Plugin_Continue;
}

public void Frame_BfMotdOverride(int iUserId)
{
    int iClient = GetClientOfUserId(iUserId);
    
    if (!IsValidClient(iClient)) {
        return;
    }
    
    char szUrl[256];
    bool bFailed = false;
    bFailed = !FormatAdvertUrl(iClient, g_szNGSUrl, szUrl);
    
    if (!bFailed) {
        bFailed = !ShowVGUIPanelEx(iClient, "NGS Network Advertisement MOTD", szUrl);
    }
    
    if (bFailed) {
        ShowMOTDPanel(iClient, "Motd", "motd", MOTDPANEL_TYPE_URL);
    }
    
    g_bFirstMotd[iClient] = false;
}

public void Query_MotdPlayAd(QueryCookie qCookie, int iClient, ConVarQueryResult cqResult, const char[] szCvarName, const char[] szCvarValue, DataPack dPack)
{
    if (!IsValidClient(iClient)) {
        delete dPack;
        return;
    }
    
    if (IsClientImmune(iClient)) {
        delete dPack;
        return;
    }
    
    dPack.Reset();
    
    int iUserId = dPack.ReadCell();
    bool bPlayAd = view_as<bool>(dPack.ReadCell());
    delete dPack;
    
    if (iClient != GetClientOfUserId(iUserId)) {
        return;
    }
    
    if (StringToInt(szCvarValue) != 0) {
        g_bMotdDisabled[iClient] = true;
        
        if (g_iMotdAction == 1) {
            KickClient(iClient, "%t", "Kick Message");
        } else if (g_iMotdAction == 2) {
            PrintHintText(iClient, "%t", "Menu_Title");
            g_mMenuWarning.Display(iClient, 10);
            g_bAdRequeue[iClient] = true;
        }
        
        return;
    }
    
    if (bPlayAd && g_hQueueTimer[iClient] == null) {
        g_bAdvertCleared[iClient] = false;
        g_hQueueTimer[iClient] = CreateTimer(1.0, Timer_PlayAdvert, iUserId, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
    }
    
    g_bMotdDisabled[iClient] = false;
}

public void Frame_AdvertStartedForward(int iUserId)
{
    int iClient = GetClientOfUserId(iUserId);
    
    if (!IsValidClient(iClient)) {
        return;
    }
    
    Call_StartForward(g_hOnAdvertStarted);
    Call_PushCell(iClient);
    Call_PushString(g_szResumeUrl[iClient]);
    Call_Finish();
}

public void Frame_AdvertFinishedForward(int iUserId)
{
    int iClient = GetClientOfUserId(iUserId);
    
    if (!IsValidClient(iClient)) {
        return;
    }
    
    Call_StartForward(g_hOnAdvertFinished);
    Call_PushCell(iClient);
    Call_PushString(g_szResumeUrl[iClient]);
    Call_Finish();
}

public void PrintMiscMessage(int iUserId)
{
    int iClient = GetClientOfUserId(iUserId);
    
    if (!IsValidClient(iClient)) {
        return;
    }
    
    if (!g_bMessages) {
        return;
    }
    
    CPrintToChat(iClient, "%s%t", "[NGS]", "Misc Message");
}

public Action Timer_IntervalAd(Handle hTimer, int iUserId)
{
    int iClient = GetClientOfUserId(iUserId);
    
    if (!IsValidClient(iClient)) {
        return Plugin_Stop;
    }
    
    SendAdvert(iClient);
    return Plugin_Continue;
}

public Action Timer_PlayAdvert(Handle hTimer, int iUserId)
{
    int iClient = GetClientOfUserId(iUserId);
    
    if (!IsValidClient(iClient)) {
        return Plugin_Stop;
    }
    
    if (HasClientFinishedAds(iClient)) {
        ClearTimers(iClient, hTimer, true, false);
        NullifyTimer(iClient, hTimer, false);
        return Plugin_Stop;
    }
    
    if (g_bAdvertPlaying[iClient] || g_hFinishedTimer[iClient] != null) {
        if (hTimer == g_hSpecTimer[iClient] || hTimer == g_hPeriodicTimer[iClient] || hTimer == g_hQueueTimer[iClient]) {
            return Plugin_Continue;
        }
        
        return Plugin_Stop;
    }
    
    if (AdShouldWait(iClient)) {
        return Plugin_Continue;
    }
    
    if (IsClientImmune(iClient)) {
        ClearTimers(iClient, hTimer, true, true);
        NullifyTimer(iClient, hTimer, false);
        return Plugin_Stop;
    }
    
    char szUrl[256];
    
    if (!FormatAdvertUrl(iClient, g_szNGSUrl, szUrl)) {
        return Plugin_Continue;
    }
    
    ShowVGUIPanelEx(iClient, "NGS Network Advertisement MOTD", szUrl);
    
    NullifyTimer(iClient, hTimer, false);
    
    int iTeam = GetClientTeam(iClient);
    
    if (hTimer == g_hPeriodicTimer[iClient]) {
        return Plugin_Continue;
    } else if (iTeam == 1 && g_fSpecAdvertPeriod > 0.0) {
        if (g_hSpecTimer[iClient] == null) {
            g_hSpecTimer[iClient] = CreateTimer(g_fSpecAdvertPeriod * 60.0, Timer_PlayAdvert, iUserId, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
        }
        
        return Plugin_Continue;
        
    } else if (iTeam != 1 && hTimer != g_hSpecTimer[iClient]) {
        NullifyTimer(iClient, g_hSpecTimer[iClient], true);
    }
    
    if (hTimer == g_hSpecTimer[iClient] || hTimer == g_hPeriodicTimer[iClient]) {
        return Plugin_Continue;
    }
    
    NullifyTimer(iClient, hTimer, false);
    return Plugin_Stop;
}

public Action Timer_AdvertFinished(Handle hTimer, int iUserId)
{
    int iClient = GetClientOfUserId(iUserId);
    
    if (!IsValidClient(iClient)) {
        return Plugin_Stop;
    }
    
    if (!g_bAdvertPlaying[iClient]) {
        ShowVGUIPanelEx(iClient, "Adverts Finished", "about:blank", _, _, false, _, false);
        NullifyTimer(iClient, g_hFinishedTimer[iClient], g_hFinishedTimer[iClient] != hTimer);
        return Plugin_Stop;
    }
    
    g_bAdvertPlaying[iClient] = false;
    
    if (g_bMessages) {
        CPrintToChat(iClient, "%s%t", "[NGS]", "Advert Finished");
    }
    
    strcopy(g_szResumeUrl[iClient], 128, "about:blank");
    
    RequestFrame(Frame_AdvertFinishedForward, iUserId);
    NullifyTimer(iClient, g_hFinishedTimer[iClient], false);
    
    return Plugin_Stop;
}

public void OnCvarChanged(ConVar hConVar, const char[] szOldValue, const char[] szNewValue)
{
    if (hConVar == g_hNGSUrl) {
        strcopy(g_szNGSUrl, sizeof(g_szNGSUrl), szNewValue);
        TrimString(g_szNGSUrl); StripQuotes(g_szNGSUrl);
    } else if (hConVar == g_hCvarJoinGame) {
        g_bJoinAdverts = view_as<bool>(StringToInt(szNewValue));
    } else if (hConVar == g_hCvarPhaseAds) {
        g_bPhaseAds = view_as<bool>(StringToInt(szNewValue));
    } else if (hConVar == g_hCvarAdvertPeriod) {
        g_fAdvertPeriod = StringToFloat(szNewValue);
        
        if (g_fAdvertPeriod > 0.0 && g_fAdvertPeriod < 3.0) {
            g_fAdvertPeriod = 3.0;
            g_hCvarAdvertPeriod.IntValue = 3;
        }
    }
    else if (hConVar == g_hCvarAdvertTotal) {
        g_iAdvertTotal = StringToInt(szNewValue);
    } else if (hConVar == g_hCvarImmunityEnabled) {
        g_bImmunityEnabled = view_as<bool>(StringToInt(szNewValue));
    } else if (hConVar == g_hCvarSpecAdvertPeriod) {
        g_fSpecAdvertPeriod = StringToFloat(szNewValue);
        
        if (g_fSpecAdvertPeriod < 3.0 && g_fSpecAdvertPeriod > 0.0) {
            g_fSpecAdvertPeriod = 3.0;
            g_hCvarSpecAdvertPeriod.IntValue = 3;
        }
    } else if (hConVar == g_hCvarWaitUntilDead) {
        g_bWaitUntilDead = view_as<bool>(StringToInt(szNewValue));
    } else if (hConVar == g_hCvarMessages) {
        g_bMessages = view_as<bool>(StringToInt(szNewValue));
    } else if (hConVar == g_hCvarMotdCheck) {
        g_iMotdAction = StringToInt(szNewValue);
    } else if (hConVar == g_hCvarDisableMotd) {
        if (StringToInt(szNewValue) != 0) {
            g_hCvarDisableMotd.IntValue = 0;
        }
    } else if (hConVar == g_hCvarUnloadOnDismissal) {
        if (StringToInt(szNewValue) != 0) {
            g_hCvarUnloadOnDismissal.IntValue = 0;
        }
    }
}

public void UpdateConVars()
{
    g_bJoinAdverts = g_hCvarJoinGame.BoolValue;
    g_bPhaseAds = g_hCvarPhaseAds.BoolValue;
    g_bImmunityEnabled = g_hCvarImmunityEnabled.BoolValue;
    g_bWaitUntilDead = g_hCvarWaitUntilDead.BoolValue;
    g_bMessages = g_hCvarMessages.BoolValue;
    g_iMotdAction = g_hCvarMotdCheck.IntValue;
    
    g_fAdvertPeriod = g_hCvarAdvertPeriod.FloatValue;
    g_fSpecAdvertPeriod = g_hCvarSpecAdvertPeriod.FloatValue;
    
    if (g_fAdvertPeriod > 0.0 && g_fAdvertPeriod < 3.0) {
        g_fAdvertPeriod = 3.0;
        g_hCvarAdvertPeriod.IntValue = 3;
    }
    
    if (g_fSpecAdvertPeriod < 3.0 && g_fSpecAdvertPeriod > 0.0) {
        g_fSpecAdvertPeriod = 3.0;
        g_hCvarSpecAdvertPeriod.IntValue = 3;
    }
    
    g_iAdvertTotal = g_hCvarAdvertTotal.IntValue;
    
    g_hNGSUrl.GetString(g_szNGSUrl, sizeof(g_szNGSUrl));
    TrimString(g_szNGSUrl); StripQuotes(g_szNGSUrl);
    
    if (g_hCvarDisableMotd == null) {
        g_hCvarDisableMotd = FindConVar("sv_disable_motd");
    }
    
    if (g_hCvarDisableMotd != null) {
        g_hCvarDisableMotd.AddChangeHook(OnCvarChanged);
        g_hCvarDisableMotd.IntValue = 0;
    }
    
    if (g_hCvarUnloadOnDismissal == null) {
        g_hCvarUnloadOnDismissal = FindConVar("sv_motd_unload_on_dismissal");
    }
    
    if (g_hCvarUnloadOnDismissal != null) {
        g_hCvarUnloadOnDismissal.AddChangeHook(OnCvarChanged);
        g_hCvarUnloadOnDismissal.IntValue = 0;
    }
}

public Action JoinGame_Listener(int iClient, const char[] szCommand, int iArgs)
{
    g_bGameJoined[iClient] = true;
    
    if (!g_bAdRequeue[iClient]) {
        return;
    }
    
    SendAdvert(iClient);
}

public void CreateMotdMenu()
{
    if (g_mMenuWarning != null) {
        return;
    }
    
    char szBuffer[128];
    
    g_mMenuWarning = new Menu(MenuHandler);
    
    Format(szBuffer, sizeof(szBuffer), "%t", "Menu_Title");
    
    g_mMenuWarning.SetTitle(szBuffer);
    g_mMenuWarning.Pagination = MENU_NO_PAGINATION;
    g_mMenuWarning.ExitBackButton = false;
    g_mMenuWarning.ExitButton = false;
    
    Format(szBuffer, sizeof(szBuffer), "%t", "Menu_Phrase_0");
    g_mMenuWarning.AddItem("", szBuffer, ITEMDRAW_DISABLED);
    
    Format(szBuffer, sizeof(szBuffer), "%t", "Menu_Phrase_1");
    g_mMenuWarning.AddItem("", szBuffer, ITEMDRAW_DISABLED);
    
    Format(szBuffer, sizeof(szBuffer), "%t", "Menu_Phrase_2");
    g_mMenuWarning.AddItem("", szBuffer, ITEMDRAW_DISABLED);
    
    Format(szBuffer, sizeof(szBuffer), "%t", "Menu_Phrase_Exit");
    g_mMenuWarning.AddItem("0", szBuffer);
}

// public int Native_IsAdvertPlaying(Handle hPlugin, int iNumParams)
// {
//     int iClient = GetNativeCell(1);
    
//     return g_bAdvertPlaying[iClient];
// }

// public int Native_PlayAdvert(Handle hPlugin, int iNumParams)
// {
//     int iClient = GetNativeCell(1);
    
//     return SendAdvert(iClient);
// }

stock bool GetVGUIInfo(int iClient, Handle hMsg, char szKey[256], char szUrl[256], char szTitle[256], int & iWidth, int & iHeight, bool & bShow, bool & bCustomSvr)
{
    if (g_bProtoBuf) {
        PbReadString(hMsg, "name", szKey, sizeof(szKey));
    } else {
        BfReadString(hMsg, szKey, sizeof(szKey));
    }
    
    if (g_iMotdOccurence[iClient] == 2 && g_bProtoBuf && StrEqual(szKey, "team") && g_bAdvertPlaying[iClient] && g_bJoinAdverts) {
        g_bAdvertPlaying[iClient] = false;
        
        NullifyTimer(iClient, g_hFinishedTimer[iClient], true);
        return false;
    }
    
    if (!StrEqual(szKey, "info")) {
        return false;
    }
    
    bool bUrlFound = false;
    
    bShow = g_bProtoBuf ? PbReadBool(hMsg, "show") : view_as<bool>(BfReadByte(hMsg));
    
    Handle hSubKey = null;
    
    int iKeyCount = g_bProtoBuf ? PbGetRepeatedFieldCount(hMsg, "subkeys") : BfGetNumBytesLeft(hMsg);
    
    for (int i = 0; i < iKeyCount; i++) {
        if (g_bProtoBuf) {
            hSubKey = PbReadRepeatedMessage(hMsg, "subkeys", i);
            PbReadString(hSubKey, "name", szKey, sizeof(szKey));
        } else {
            BfReadString(hMsg, szKey, sizeof(szKey));
        }
        
        if (StrContains(szKey, "msg", false) != -1) {
            if (g_bProtoBuf) {
                PbReadString(hSubKey, "str", szUrl, sizeof(szUrl));
            } else {
                BfReadString(hMsg, szUrl, sizeof(szUrl));
            }
            
            bUrlFound = true;
        } else if (StrContains(szKey, "title", false) != -1) {
            if (g_bProtoBuf) {
                PbReadString(hSubKey, "str", szTitle, sizeof(szTitle));
            } else {
                BfReadString(hMsg, szTitle, sizeof(szTitle));
            }
        } else if (StrContains(szKey, "x-vgui-width", false) != -1) {
            char szResult[10];
            
            if (g_bProtoBuf) {
                PbReadString(hSubKey, "str", szResult, sizeof(szResult));
            } else {
                BfReadString(hMsg, szResult, sizeof(szResult));
            }
            
            iWidth = StringToInt(szResult);
        } else if (StrContains(szKey, "x-vgui-height", false) != -1) {
            char szResult[10];
            
            if (g_bProtoBuf) {
                PbReadString(hSubKey, "str", szResult, sizeof(szResult));
            } else {
                BfReadString(hMsg, szResult, sizeof(szResult));
            }
            
            iHeight = StringToInt(szResult);
        } else if (StrContains(szKey, "customsvr", false) != -1) {
            char szResult[10];
            
            if (g_bProtoBuf) {
                PbReadString(hSubKey, "str", szResult, sizeof(szResult));
            } else {
                BfReadString(hMsg, szResult, sizeof(szResult));
            }
            
            bCustomSvr = view_as<bool>(StringToInt(szResult));
        }
    }
    
    return bUrlFound;
}

stock void ClearTimers(int iClient, Handle hCurrentTimer, bool bDelete = true, bool bFinishedTimer = false)
{
    if (hCurrentTimer != g_hSpecTimer[iClient]) {
        NullifyTimer(iClient, g_hSpecTimer[iClient], bDelete);
    }
    
    if (hCurrentTimer != g_hPeriodicTimer[iClient]) {
        NullifyTimer(iClient, g_hPeriodicTimer[iClient], bDelete);
    }
    
    if (hCurrentTimer != g_hQueueTimer[iClient]) {
        NullifyTimer(iClient, g_hQueueTimer[iClient], bDelete);
    }
    
    if (hCurrentTimer != g_hFinishedTimer[iClient] && bFinishedTimer) {
        NullifyTimer(iClient, g_hFinishedTimer[iClient], bDelete);
    }
}

stock void NullifyTimer(int iClient, Handle hTimer, bool bDelete)
{
    if (bDelete && hTimer != null) {
        bDelete = false;
    }
    
    if (hTimer == g_hSpecTimer[iClient]) {
        if (bDelete) {
            delete g_hSpecTimer[iClient];
        }
        
        g_hSpecTimer[iClient] = null;
    } else if (hTimer == g_hPeriodicTimer[iClient]) {
        if (bDelete) {
            delete g_hPeriodicTimer[iClient];
        }
        
        g_hPeriodicTimer[iClient] = null;
    } else if (hTimer == g_hQueueTimer[iClient]) {
        if (bDelete) {
            delete g_hQueueTimer[iClient];
        }
        
        g_hQueueTimer[iClient] = null;
    } else if (hTimer == g_hFinishedTimer[iClient]) {
        if (bDelete) {
            delete g_hFinishedTimer[iClient];
        }
        
        g_hFinishedTimer[iClient] = null;
    }
}

stock bool ShowVGUIPanelEx(int iClient, const char[] szTitle, char szUrl[256], int iType = MOTDPANEL_TYPE_URL, int iFlags = 0, bool bShow = true, Handle hMsg = null, bool bAdvert = true, int iWidth = 0, int iHeight = 0, bool bCustomSvr = false)
{
    if (g_bMotdDisabled[iClient]) {
        return false;
    }
    
    bool bOverride = hMsg != null && g_bProtoBuf;
    int iTeam = GetClientTeam(iClient);
    int iClass = 0;
    
    bool bMotd; bool bAboutBlank;
    
    if (StrEqual(szUrl, "motd") || StrEqual(szUrl, "motd_text")) {
        bMotd = true;
    } else if (StrContains(szUrl, g_szNGSUrl, false) != -1) {
        bAdvert = true;
    } else if (StrEqual(szUrl, "about:blank", false)) {
        bAboutBlank = true;
    }
    
    if (bMotd || bAboutBlank) {
        bAdvert = false;
    }
    
    if (g_bHasClasses) {
        iClass = GetEntProp(iClient, Prop_Send, "m_iClass");
    }
    
    if ((iTeam < 1 || (g_bHasClasses && iClass <= 0 && iTeam > 1))) {
        if (!g_bFirstMotd[iClient] || (g_bFirstMotd[iClient] && !g_bJoinAdverts)) {
            return false;
        }
        
        if (g_bProtoBuf && !bOverride) {
            return false;
        }
    }
    
    if (bAdvert) {
        if (AdShouldWait(iClient) || HasClientFinishedAds(iClient) || IsClientImmune(iClient)) {
            return false;
        }
        
        if (g_bAdRequeue[iClient] && IsPlayerAlive(iClient)) {
            bShow = false;
        }
    }
    
    if (g_bFirstMotd[iClient] && g_bForceJoinGame && !g_bGameJoined[iClient]) {
        FakeClientCommandEx(iClient, "joingame");
    }
    
    if (bOverride || bAboutBlank) {
        bShow = false;
    }
    
    KeyValues hKv = new KeyValues("data");
    
    hKv.SetString("title", szTitle);
    hKv.SetNum("type", iType);
    hKv.SetString("msg", szUrl);
    
    EngineVersion ver = GetEngineVersion();

    if (ver == Engine_CSGO || ver == Engine_Unknown) {
        hKv.SetString("cmd", "1");
    } else {
        hKv.SetNum("cmd", 5);
    }
    
    hKv.SetNum("x-vgui-width", iWidth);
    hKv.SetNum("x-vgui-height", iHeight);
    hKv.SetNum("customsvr", bCustomSvr);
    
    hKv.GotoFirstSubKey(false);
    iFlags &= ~USERMSG_BLOCKHOOKS;
    
    if (!bOverride) {
        hMsg = StartMessageOne("VGUIMenu", iClient, iFlags);
    }
    
    char szKey[256]; char szValue[256];
    
    if (g_bProtoBuf) {
        if (!bOverride) {
            PbSetString(hMsg, "name", "info");
            PbSetBool(hMsg, "show", bShow);
        }
        
        Handle hSubKey;
        
        do {
            hKv.GetSectionName(szKey, sizeof(szKey));
            hKv.GetString(NULL_STRING, szValue, sizeof(szValue), "");
            
            hSubKey = PbAddMessage(hMsg, "subkeys");
            
            PbSetString(hSubKey, "name", szKey);
            PbSetString(hSubKey, "str", szValue);
            
        } while (hKv.GotoNextKey(false));
        
    } else {
        BfWriteString(hMsg, "info");
        BfWriteByte(hMsg, bShow);
        
        int iKeyCount = 0;
        
        do {
            ++iKeyCount;
        } while (hKv.GotoNextKey(false));
        
        BfWriteByte(hMsg, iKeyCount);
        
        if (iKeyCount > 0) {
            hKv.GoBack(); hKv.GotoFirstSubKey(false);
            do {
                hKv.GetSectionName(szKey, sizeof(szKey));
                hKv.GetString(NULL_STRING, szValue, sizeof(szValue), "");
                
                BfWriteString(hMsg, szKey);
                BfWriteString(hMsg, szValue);
            } while (hKv.GotoNextKey(false));
        }
    }
    
    if (!bOverride) {
        EndMessage();
    }
    
    delete hKv;
    
    if (!bMotd) {
        g_bFirstMotd[iClient] = false;
    }
    
    return true;
}

stock bool IsClientImmune(int iClient)
{
    if (!IsValidClient(iClient)) {
        return true;
    }
    
    if (!g_bImmunityEnabled) {
        return false;
    }
    
    return CheckCommandAccess(iClient, "advertisement_immunity", ADMFLAG_RESERVATION);
}

stock bool CheckGameSpecificConditions()
{
    if (g_eVersion == Engine_CSGO) {
        if (GameRules_GetProp("m_bWarmupPeriod") == 1) {
            return true;
        }
    }
    
    return false;
}

stock bool AdShouldWait(int iClient)
{
    char szAuthId[64];
    
    if (!IsClientAuthorized(iClient) || !GetClientAuthId(iClient, AuthId_Steam2, szAuthId, sizeof(szAuthId), true) || StrContains(szAuthId, ":", false) == -1) {
        return true;
    }
    
    if (g_hFinishedTimer[iClient] != null) {
        return true;
    }
    
    int iTeam = GetClientTeam(iClient);
    int iClass = 0;
    
    if (g_bHasClasses) {
        iClass = GetEntProp(iClient, Prop_Send, "m_iClass");
    }
    
    if ((iTeam < 1 || (g_bHasClasses && iClass <= 0 && iTeam > 1))) {
        if (!g_bFirstMotd[iClient] || (g_bFirstMotd[iClient] && !g_bJoinAdverts)) {
            return true;
        }
    }
    
    if (g_bAdvertPlaying[iClient] || g_hFinishedTimer[iClient] != null || (g_iLastAdvertTime[iClient] > 0 && GetTime() - g_iLastAdvertTime[iClient] < 180)) {
        return true;
    }
    
    if (g_bWaitUntilDead && IsPlayerAlive(iClient) && (iTeam > 1) && (!g_bPhase && !g_bFirstMotd[iClient] && !g_bAdRequeue[iClient] && !CheckGameSpecificConditions())) {
        return true;
    }
    
    return false;
}

stock bool HasClientFinishedAds(int iClient)
{
    if (g_iAdvertTotal > 0 && !g_bFirstMotd[iClient] && g_iAdvertRequests[iClient] >= g_iAdvertTotal) {
        return true;
    }
    
    if (g_iAdvertTotal <= -1 && !g_bFirstMotd[iClient]) {
        return true;
    }
    
    if (!g_bFirstMotd[iClient] && g_fAdvertPeriod <= 0.0) {
        return true;
    }
    
    return false;
}

stock void GetServerIP()
{
    bool bGotIP = false;
    
    int iSIP[4];
    SteamWorks_GetPublicIP(iSIP);
        
    Format(g_szServerIP, sizeof(g_szServerIP), "%d.%d.%d.%d", iSIP[0], iSIP[1], iSIP[2], iSIP[3]);
    
    if (!IsIPLocal(IPToLong(g_szServerIP))) {
        bGotIP = true;
    } else {
        strcopy(g_szServerIP, sizeof(g_szServerIP), "");
        bGotIP = false;
    }
    
    if (!bGotIP) {
        ConVar hCvarIP = FindConVar("hostip");
        
        if (hCvarIP != null) {
            int iServerIP = hCvarIP.IntValue; bGotIP = !IsIPLocal(iServerIP);
            
            if (bGotIP) {
                Format(g_szServerIP, sizeof(g_szServerIP), "%d.%d.%d.%d", iServerIP >>> 24 & 255, iServerIP >>> 16 & 255, iServerIP >>> 8 & 255, iServerIP & 255);
            }
        }
    }
    
    if (!bGotIP) {
        SetFailState("There was an error fetching your server IP, the plugin has been disabled, please contact us for support!");
    }
    
    ConVar hCvarPort = FindConVar("hostport");
    
    if (hCvarPort != null) {
        g_iPort = hCvarPort.IntValue;
    }
}

stock bool FormatAdvertUrl(int iClient, char[] szInput, char[] szOutput)
{
    if (StrEqual(g_szNGSUrl, "", false)) {
        return false;
    }
    
    TrimString(g_szNGSUrl); StripQuotes(g_szNGSUrl);
    
    return strcopy(szOutput, 256, szInput) > 0;
}

stock int IPToLong(const char[] szIP)
{
    char szPieces[4][4];
    
    if (ExplodeString(szIP, ".", szPieces, sizeof(szPieces), sizeof(szPieces[])) != 4) {
        return 0;
    }
    
    return (StringToInt(szPieces[0]) << 24 | StringToInt(szPieces[1]) << 16 | StringToInt(szPieces[2]) << 8 | StringToInt(szPieces[3]));
}

stock bool IsIPLocal(int iIP)
{
    if (167772160 <= iIP <= 184549375 || 2886729728 <= iIP <= 2887778303 || 3232235520 <= iIP <= 3232301055) {
        return true;
    }
    
    return false;
}

stock bool SendAdvert(int iClient)
{
    if (HasClientFinishedAds(iClient) || g_hQueueTimer[iClient] != null) {
        return false;
    }
    
    DataPack dPack = new DataPack();
    dPack.WriteCell(GetClientUserId(iClient));
    dPack.WriteCell(true);
    
    if (QueryClientConVar(iClient, "cl_disablehtmlmotd", Query_MotdPlayAd, dPack) == QUERYCOOKIE_FAILED) {
        g_bAdRequeue[iClient] = true;
        delete dPack;
        return false;
    }
    
    return !g_bMotdDisabled[iClient];
}

// Credits https://forums.alliedmods.net/showpost.php?p=2112007&postcount=9
stock void ClearMotd(DataPack dPack)
{
    if (dPack == null) {
        return;
    }
    
    dPack.Reset();
    
    int iUserId = dPack.ReadCell();
    int iClient = GetClientOfUserId(iUserId);
    delete dPack;
    
    if (!IsValidClient(iClient)) {
        return;
    }
    
    if (g_bAdvertPlaying[iClient]) {
        return;
    }
    
    Handle hMsg = StartMessageOne("VGUIMenu", iClient);
    
    if (hMsg == null) {
        return;
    }
    
    if (g_bProtoBuf) {
        PbSetString(hMsg, "name", "info");
        PbSetBool(hMsg, "show", false);
        
        Handle hSubKey;
        
        hSubKey = PbAddMessage(hMsg, "subkeys");
        
        PbSetString(hSubKey, "name", "title");
        PbSetString(hSubKey, "str", "Clear Motd");
        
        hSubKey = PbAddMessage(hMsg, "subkeys");
        
        PbSetString(hSubKey, "name", "type");
        PbSetString(hSubKey, "str", "0");
        
        hSubKey = PbAddMessage(hMsg, "subkeys");
        
        PbSetString(hSubKey, "name", "msg");
        PbSetString(hSubKey, "str", "");
        
        hSubKey = PbAddMessage(hMsg, "subkeys");
    } else {
        BfWriteString(hMsg, "info");
        BfWriteByte(hMsg, false);
        BfWriteByte(hMsg, 4);
        
        BfWriteString(hMsg, "title");
        BfWriteString(hMsg, "Clear Motd");
        
        BfWriteString(hMsg, "type");
        BfWriteString(hMsg, "");
        
        BfWriteString(hMsg, "msg");
        BfWriteString(hMsg, "");
    }
    
    EndMessage();
}

public int MenuHandler(Menu mMenu, MenuAction maAction, int iParam1, int iParam2) {  } 