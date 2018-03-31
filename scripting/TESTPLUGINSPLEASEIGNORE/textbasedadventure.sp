#pragma semicolon 1
#pragma newdecls required

#define DEBUG

#define PLUGIN_NAME           "Text Based Adventure (CYOA)"
#define PLUGIN_AUTHOR         "TheXeon"
#define PLUGIN_DESCRIPTION    "A cool adventure from online!"
#define PLUGIN_VERSION        "1.0.0"
#define PLUGIN_URL            "http://www.fantasy-magazine.com/new/new-fiction/choose-your-own-adventure/"

// http://www.fantasy-magazine.com/new/new-fiction/choose-your-own-adventure/

#include <sourcemod>
#include <sdktools>

Menu adventurePromptMenu; // Empty until filled

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	// === In Chat ===
	// !startadventure
	// /startadventure
	// !sm_startadventure
	// /sm_startadventure
	// === In Console ===
	// sm_startadventure
	RegConsoleCmd("sm_startadventure", CommandStartAdventure, "Start your adventure.");
}

public Action CommandStartAdventure(int client, int args)
{
	// Arguments: sm_bamboozle <name>, <name> is the argument
	if (!IsValidClient(client)) return Plugin_Handled;
	Menu adventureMenu = new Menu(AdventureMenuHandler);
	adventureMenu.SetTitle("=== CYOA ===");
	adventureMenu.AddItem("startadventure", "Start your adventure.");
	adventureMenu.AddItem("endadventure", "End your adventure.");
	adventureMenu.Display(client, 20);
	return Plugin_Handled;
}

public int AdventureMenuHandler(Menu menu, MenuAction action, int clientChoosing, int numberChosen)
{
	// clientChoosing = param1: the client that chose that option
	// numberChosen = param2: number for the option they chose, starting at 0
	if (action == MenuAction_Select)
	{
		// Array of characters (how we represent strings in Pawn)
		// This:
		// {'a', 'b', 'c', 'd', 'A', 'B', 'C', 'A', '\0'}
		// Is the same as this:
		// "abcdABCA";
		// char[] info => indeterminant length of array, usually used in callback of parameters of functions
		// char info[24] => determinant length (24), usually used within functions or as a global variable
		char info[24];
		if (menu.GetItem(numberChosen, info, sizeof(info)))
		{
			if (StrEqual(info, "startadventure"))
			{
				PrintToChat(clientChoosing, "You find yourself standing in a beautiful garden.");
				PrintToChat(clientChoosing, "It teems with all the birds of the air, and all of the creatures of the Earth, and every good thing that grows.");
				PrintToChat(clientChoosing, "As you explore, you feel an incredible sense of peace and rightness, as if the garden had been created just for you.");
				PrintToChat(clientChoosing, "This is the place you belong. Still, you are restless and lonely. You begin to explore your surroundings. At the western edge of the garden, there is a gate.");
				PrintToChat(clientChoosing, "Do you walk through?");
				
				if (adventurePromptMenu == null)
				{
					adventurePromptMenu = new Menu(AdventureChoiceHandler);
				}
				adventurePromptMenu.RemoveAllItems();
				adventurePromptMenu.AddItem("37", "Yes?");
				adventurePromptMenu.AddItem("19", "No?");
				adventurePromptMenu.Display(clientChoosing, MENU_TIME_FOREVER);
			}
			else if (StrEqual(info, "endadventure"))
			{
				PrintToChat(clientChoosing, "You chose end adventure.");
			}
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int AdventureChoiceHandler(Menu menu, MenuAction action, int clientChoosing, int numberChosen)
{
	if (action == MenuAction_Select)
	{
		char info[24];
		if (menu.GetItem(numberChosen, info, sizeof(info)))
		{
			if (adventurePromptMenu == null)
			{
				adventurePromptMenu = new Menu(AdventureChoiceHandler);
			}
			adventurePromptMenu.RemoveAllItems();
			
			if (StrEqual(info, "37"))
			{
				PrintToChat(clientChoosing, "Gates, like books, are meant to be opened, and you would never be truly content if you did not know what lay on the other side.");
				PrintToChat(clientChoosing, "You pass through the gate and enter into a dark forest.");
				PrintToChat(clientChoosing, "You hesitate for a moment, look back, but the forest stretches behind you as if the garden had never been.");
				PrintToChat(clientChoosing, "You continue on. Shadows deepen. An owl calls. Something cries out at a distance and is silenced.");
				PrintToChat(clientChoosing, "You grow chilled, and your feet develop a talent for finding uneven spots of ground, tree roots, and rocks.");
				PrintToChat(clientChoosing, "After the third time you fall, you lean against the very tree whose roots last tangled your feet.");
				PrintToChat(clientChoosing, "The bark prickles and rubs against your back, but it is a welcome distraction from your bruised knees and skinned palms.");
				PrintToChat(clientChoosing, "Your bones are weary and your muscles ache. You crave sleep. A brief rest to fortify yourself for your journey.");
				PrintToChat(clientChoosing, "Do you close your eyes?");
				
				adventurePromptMenu.AddItem("3", "Yes.");
				adventurePromptMenu.AddItem("25", "No.");
				adventurePromptMenu.Display(clientChoosing, MENU_TIME_FOREVER);
			}
			else if (StrEqual(info, "endadventure")) // TODO: Continue from here
			{
				PrintToChat(clientChoosing, "You chose end adventure.");
			}
		}
	}
}

public bool IsValidClient(int client)
{
	if(client > 4096) client = EntRefToEntIndex(client);
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsFakeClient(client)) return false;
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}