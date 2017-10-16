#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <chat-processor>

#define PLUGIN_VERSION "1.0.0"

public Plugin myinfo = 
{
	name = "[NGS] Test Chat Color and codes",
	author = "TheXeon",
	description = "Test Chat Color and codes",
	version = PLUGIN_VERSION,
	url = "https://www.neogenesisnetwork.net/"
}

public void CP_OnChatMessagePost(int author, ArrayList recipients, const char[] flagstring, const char[] formatstring, const char[] name, const char[] message, bool processcolors, bool removecolors)
{
	PrintToServer("[TCPC] NAME: %s", name);
	PrintToServer("[TCPC] MESSAGE: %s", message);
	PrintToServer("[TCPC] process/remove = %b/%b", processcolors, removecolors);
}