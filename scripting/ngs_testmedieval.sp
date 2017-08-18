#include <sourcemod>
#include <sdktools>

public Plugin myinfo = {
    name        = "[NGS] Test Medieval",
    author      = "TheXeon",
    description = "Testing Medieval mode",
    version     = "1.0.0",
    url         = "https://neogenesisnetwork.net/"
}


public void OnPluginStart()
{
	GameRules_SetProp("m_bPlayingMedieval", 1);
}