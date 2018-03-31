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
	// Variables!
	/*
		int iTypeFour = 0; // integers (negative numbers, 0, positive numbers)
		float fType = 1.2; // decimal point numbers
		char cType = 'B'; // single characters
		bool bType = true; // boolean types (true or false)
		
		These variables are the cornerstone of programming. Without a method of saving data,
		we'd have to redo computations many many many many times.
		
		If I've already declared a variable (like fType up above), I can reassign it to
		a different value with:
		
		fType = 1.3; // notice I didnt put `float` there, only the variable name.
	*/

	int iType = 0; // stores integers
	int iTypeTwo = 1;
	int iTypeThree = -1;

	int iTypeFour = 0; // integers (negative numbers, 0, positive numbers)
	float fType = 1.2; // decimal point numbers
	char cType = 'a'; // single characters
	bool bType = true; // boolean types (true or false)

	char[] sType = "Yeseroni"; // This is a string (array of characters)

	int playerCredits = 0; // camelcasing & descriptive name (YES!!!)
	int amountofstuff = 0; // no camelcasing, no descriptive name (NO)

	int mathSub = iType + iTypeTwo; // usage of other two variables

	PrintToServer("%d", iTypeFour); // Will be 0
	iTypeFour = 1; // Notice no int
	PrintToServer("%d", iTypeFour); // Will be 1

	int randInt = GetRandomInt(0, 1);
	float randFloat = GetRandomFloat();

	// This is a single lined comment. Comments can be used to say what a piece of code 
	// does, or more commonly to leave a comment for you when you come back after a night
	// of coding.

	// <-- This makes it a comment.

	/*
		This is a block comment.
		I dont have to keep typing // in front of every line, thank goodness.
	*/

	// Concept: Block Coding! You can group programs into blocks and limit their visibility.
	// Scopes!
	/*
	{
		this;
		is;
		code;
	}
	*/


	// Arrays
	/*
		Arrays are how we store a lot of data in an indexed way. This means that we can
		simply store a list of data in exactly that, a list! They store multiple pieces
		of info in one variable, so are useful.
		
		int players[32];
		float position[3];
		
		By default, they are initialized to 0. The size can be left out of you are
		preassigning data.
		
		int numbers[] = {1, 2, 3, 4, 5, 6}; // There is no size specified.
		
		Using arrays is different than using regular variables, as you need to specify an
		index. Indexes start at 0, not 1.
		
		numbers[0] = 3; // turns numbers[] into {3, 2, 3, 4, 5, 6}
				^								 ^
			Index								changed
	*/

	// Strings
	/*
		They are just arrays mang. Char arrays. They have a special character on the end
		called the null terminator '\0'. Without the null terminator, sourcepawn wouldn't
		know where to stop reading strings.
	*/

	Menu menu = new Menu(MainMenuHandler);
	menu.AddItem("option1", "This is option 1");
	menu.AddItem("option2", "This is option 2");
	// menu.Display(/*clientnumber*/);
}

public int MainMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	// param1: the client that chose that option
	// param2: number for the option they chose, starting at 0
	char info[18];
	if (menu.GetItem(param2, info, sizeof(info)))
	{
		if (StrEqual(info, "option1"))
		{
			PrintToChat(param1, "You chose option 1.");
		}
	}
}

