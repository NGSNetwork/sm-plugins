/**
 * MOTD stocks with VGUI URL Cache Buster (VUCB)-specific extensions
 * 
 * KeyValue entries prefixed with "x-vgui-" are values handled by VUCB.
 */

#if defined _vgui_motd_stocks_included
	#endinput
#endif

#define _vgui_motd_stocks_included

// TODO register cache buster as a shared plugin?
// have to figure out some way to ensure these extended features are discoverable

// if 0 cache buster will not pass dimensions to proxy page and assume default
#define CSGO_POPUP_FULL 0
#define POPUP_FULL_SIZE 0

/**
 * Displays an MOTD panel with CS:GO-specific options.
 */
stock void CSGO_ShowMOTDPanel(int client, const char[] title, const char[] url,
		bool show = false, int width = POPUP_FULL_SIZE, int height = POPUP_FULL_SIZE) {
	KeyValues kv = new KeyValues("data");
	
	kv.SetString("title", title);
	kv.SetNum("type", MOTDPANEL_TYPE_URL);
	kv.SetString("msg", url);
	
	// x-vgui-popup is implicitly true in the core plugin and will remain true
	// as long as normal MOTDs are broken
	
	if (show) {
		// extended options handled by cache buster
		kv.SetNum("x-vgui-width", width);
		kv.SetNum("x-vgui-height", height);
	}
	
	ShowVGUIPanel(client, "info", kv, show);
	
	delete kv;
}

/**
 * Displays an MOTD panel with TF2-specific options.
 * All these options are native to TF2.
 */
stock void TF2_ShowMOTDPanel(int client, const char[] title, const char[] url, bool show = true,
		bool big = false) {
	KeyValues kv = new KeyValues("data");
	
	kv.SetString("title", title);
	kv.SetNum("type", MOTDPANEL_TYPE_URL);
	kv.SetString("msg", url);
	
	if (big) {
		kv.SetNum("customsvr", 1);
	}
	
	ShowVGUIPanel(client, "info", kv, show);
	
	delete kv;
}

/**
 * Displays a popup web panel using VUCB extensions.
 */
stock void ShowMOTDPopupPanel(int client, const char[] title, const char[] url,
		int width = POPUP_FULL_SIZE, int height = POPUP_FULL_SIZE) {
	KeyValues kv = new KeyValues("data");
	
	kv.SetString("title", title);
	kv.SetNum("type", MOTDPANEL_TYPE_URL);
	kv.SetString("msg", url);
	
	kv.SetNum("x-vgui-popup", true);
	
	if (width || height) {
		kv.SetNum("x-vgui-width", width);
		kv.SetNum("x-vgui-height", height);
	}
	
	ShowVGUIPanel(client, "info", kv, false);
	
	delete kv;
}
