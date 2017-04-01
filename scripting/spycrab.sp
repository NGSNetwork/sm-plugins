#include <sourcemod>
#include <sdktools>
#include <adminmenu>

Menu spycrabMenu;

public void OnPluginStart()
{
	RegConsoleCmd("sm_crab", Cmd_Crab, "Displays users to spycrab with");
	spycrabMenu = new Menu(SpycrabMenuHandler);
	spycrabMenu.SetTitle("Select a player:");
	SpycrabMenuBuilder();
}

public Action Cmd_Crab(int client, int args)
{
	spycrabMenu.Display(client, MENU_TIME_FOREVER);
}

public int SpycrabMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char target[16], client[16];
		int itarget, iclient;
		spycrabMenu.GetItem(param2, target, sizeof(target));
		itarget = StringToInt(target);
		spycrabMenu.GetItem(param1, client, sizeof(client));
		iclient = StringToInt(client);
		PrintToChatAll("%N has challenged %N to a spycrab showdown!", itarget, iclient);
	}
}

public void SpycrabMenuBuilder()
{
	AddTargetsToMenu(spycrabMenu, 0, true, false);
}