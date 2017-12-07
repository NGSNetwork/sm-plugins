#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <morecolors>

#define PLUGIN_VERSION "2.1.0"
#define MAX_MENU_DISPLAY_TIME 10
#define MAX_DATE_LENGTH 12
#define MAX_ID_LENGTH 32
#define MAX_MSG_LENGTH 64
#define MAX_ERROR_LENGTH 255
#define DATE_FORMAT "%d.%m.%Y"

Handle weddings_db;
Handle forward_proposal;
Handle forward_wedding;
Handle forward_divorce;
ConVar cvar_couples;
ConVar cvar_database;
ConVar cvar_delay;
ConVar cvar_disallow;
ConVar cvar_kick_msg;
Handle usage_cache;

int proposal_checked[MAXPLAYERS + 1];
int proposal_beingChecked[MAXPLAYERS + 1];
int proposal_slots[MAXPLAYERS + 1];
char proposal_names[MAXPLAYERS + 1][MAX_NAME_LENGTH];
char proposal_ids[MAXPLAYERS + 1][MAX_ID_LENGTH];

bool marriage_checked[MAXPLAYERS + 1];
int marriage_beingChecked[MAXPLAYERS + 1];
int marriage_slots[MAXPLAYERS + 1];
char marriage_names[MAXPLAYERS + 1][MAX_NAME_LENGTH];
char marriage_ids[MAXPLAYERS + 1][MAX_ID_LENGTH];
int marriage_scores[MAXPLAYERS + 1];
int marriage_times[MAXPLAYERS + 1];

#include <weddings/sql_queries>
#include <weddings/functions_general>
#include <weddings/functions_proposals>
#include <weddings/functions_marriages>
#include <weddings/functions_natives>
#include <weddings/menu_handlers>

public Plugin myinfo = {
	name = "[NGS] Weddings",
	author = "Dr. O/ TheXeon",
	description = "Get married! Propose to other players, browse, accept and revoke proposals or get divorced again. Top couples will be chosen according to their combined score.",
	version = PLUGIN_VERSION,
	url = "https://neogenesisnetwork.net/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("GetPartnerSlot", Native_GetPartnerSlot);
	CreateNative("GetPartnerName", Native_GetPartnerName);
	CreateNative("GetPartnerID", Native_GetPartnerID);
	CreateNative("GetMarriageScore", Native_GetMarriageScore);
	CreateNative("GetWeddingTime", Native_GetWeddingTime);
	CreateNative("GetProposals", Native_GetProposals);
	CreateNative("GetMarriages", Native_GetMarriages);
	return APLRes_Success;
}

public void OnPluginStart() {
	LoadTranslations("weddings.phrases");
	RegConsoleCmd("sm_marry", Marry, "List connected singles.");
	RegConsoleCmd("sm_revoke", Revoke, "Revoke proposal.");
	RegConsoleCmd("sm_proposals", Proposals, "List incoming proposals.");
	RegConsoleCmd("sm_divorce", Divorce, "End marriage.");
	RegConsoleCmd("sm_couples", Couples, "List top couples.");
	RegAdminCmd("sm_weddings_reset", Reset, ADMFLAG_BAN, "Reset database tables of the weddings plugin.");
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	forward_proposal = CreateGlobalForward("OnProposal", ET_Event, Param_Cell, Param_Cell);
	forward_wedding = CreateGlobalForward("OnWedding", ET_Event, Param_Cell, Param_Cell);
	forward_divorce = CreateGlobalForward("OnDivorce", ET_Event, Param_Cell, Param_Cell);
	CreateConVar("sm_weddings_version", PLUGIN_VERSION, "Version of the weddings plugin.", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_REPLICATED);
	cvar_couples = CreateConVar("sm_weddings_show_couples", "10", "How many couples to show in the !couples menu.", FCVAR_NOTIFY, true, 3.0, true, 100.0);
	cvar_database = CreateConVar("sm_weddings_database", "0", "What database to use. Change takes effect on plugin reload.\n0 = sourcemod-local | 1 = custom\nIf set to 1, a \"weddings\" entry is needed in \"sourcemod\\configs\\databases.cfg\".", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvar_delay = CreateConVar("sm_weddings_command_delay", "0", "How many minutes clients must wait after successful command usage.", FCVAR_NOTIFY, true, 0.0, true, 30.0);
	cvar_disallow = CreateConVar("sm_weddings_disallow_unmarried", "0", "Whether to prevent unmarried clients from joining the server.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvar_kick_msg = CreateConVar("sm_weddings_kick_message", "Unmarried clients currently not allowed", "Message to display to kicked clients.\nOnly applies if sm_weddings_disallow_unmarried is set to 1.", FCVAR_NOTIFY);
	AutoExecConfig(true, "weddings");
	usage_cache = CreateArray(MAX_ID_LENGTH, 0);
	for(int i = 1; i <= MaxClients; i++)
	{
		proposal_checked[i] = false;
		marriage_checked[i] = false;
		proposal_beingChecked[i] = false;
		marriage_beingChecked[i] = false;
	}
}

public void OnConfigsExecuted() {
	initDatabase();
}

public void OnClientAuthorized(int client, const char[] auth) {
	char client_id[MAX_ID_LENGTH];	
	
	if(!IsFakeClient(client) && !IsClientReplay(client) && !proposal_beingChecked[client] && !marriage_beingChecked[client]) {
		strcopy(client_id, sizeof(client_id), auth);
		proposal_beingChecked[client] = true;
		marriage_beingChecked[client] = true;
		checkProposal(client_id);
		checkMarriage(client_id);
	}
}

public void OnClientSettingsChanged(int client) {
	int partner;
	char client_name[MAX_NAME_LENGTH];
	
	if(proposal_checked[client] && marriage_checked[client]) {
		if(IsClientInGame(client) && !IsFakeClient(client) && !IsClientReplay(client) && GetClientName(client, client_name, sizeof(client_name))) {
			partner = marriage_slots[client];
			if(partner != -2) {
				if(partner != -1) {
					marriage_names[partner] = client_name;
				}
			} else {
				for(int i = 1; i <= MaxClients; i++) {
					if(proposal_slots[i] == client) {
						proposal_names[i] = client_name;
					}
				}
			}
		}
	}
}

public void OnClientDisconnect(int client) {
	int partner;
	
	proposal_checked[client] = false;
	marriage_checked[client] = false;
	proposal_beingChecked[client] = false;
	marriage_beingChecked[client] = false;
	for(int i = 1; i <= MaxClients; i++) {
		if(proposal_slots[i] == client) {
			proposal_slots[i] = -1;
		}
	}
	partner = marriage_slots[client];
	if(partner > 0) {
		marriage_slots[partner] = -1;
	}
}

public void Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast) {
	int attacker;
	int partner;
	char attacker_id[MAX_ID_LENGTH];
	
	attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(attacker != 0 && GetClientAuthId(attacker, AuthId_Engine, attacker_id, sizeof(attacker_id))) {
		partner = marriage_slots[attacker];
		if(partner != -2) {
			if(partner != -1) {				
				marriage_scores[partner] = marriage_scores[partner] + 1;
			}
			marriage_scores[attacker] = marriage_scores[attacker] + 1;
			updateMarriageScore(attacker_id);	
		}		 	
	}
}

public Action Uncache(Handle timer, Handle data) {
	int entries = GetArraySize(usage_cache);
	char client_id[MAX_ID_LENGTH];
	char client_id_stored[MAX_ID_LENGTH];
	
	ReadPackString(data, client_id, sizeof(client_id));
	CloseHandle(data);
	for(int i = 0; i < entries; i++) {
		GetArrayString(usage_cache, i, client_id_stored, sizeof(client_id_stored));
		if(StrEqual(client_id, client_id_stored)) {
			RemoveFromArray(usage_cache, i);
			break;
		}
	}
	return Plugin_Handled;
}

public Action Marry(int client, int args) {		
	char client_id[MAX_ID_LENGTH];
	
	if(GetClientAuthId(client, AuthId_Engine, client_id, sizeof(client_id))) {
		if(proposal_checked[client] && marriage_checked[client]) {		
			if(checkUsage(client_id)) {
				if(marriage_slots[client] == -2) {
					if(proposal_slots[client] == -2) {
						Handle marry_menu = CreateMenu(MarryMenuHandler, MENU_ACTIONS_DEFAULT);
						SetMenuTitle(marry_menu, "%t", "!marry menu title");
						if(addTargets(marry_menu, client) > 0) {
							DisplayMenu(marry_menu, client, MAX_MENU_DISPLAY_TIME);
						} else {
							PrintToChat(client, "[SM] %t", "no singles on server");
						}
					} else {
						CPrintToChat(client, "[SM] %t", "already proposed", proposal_names[client]);
						PrintToChat(client,  "[SM] %t", "revoke info");
					}					
				} else {
					CPrintToChat(client, "[SM] %t", "already married", marriage_names[client]);
					PrintToChat(client, "[SM] %t", "divorce info");
				}
			} else {
				PrintToChat(client, "[SM] %t", "spam");
				CPrintToChat(client, "[SM] %t", "delay info", GetConVarFloat(cvar_delay));
			}			
		} else {
			PrintToChat(client, "[SM] %t", "status being checked");
		}
	}
	return Plugin_Handled;
}

public Action Revoke(int client, int args) {
	char client_id[MAX_ID_LENGTH];
	
	if(GetClientAuthId(client, AuthId_Engine, client_id, sizeof(client_id))) {
		if(proposal_checked[client] && marriage_checked[client]) {
			if(checkUsage(client_id)) {		
				if(marriage_slots[client] == -2) {
					if(proposal_slots[client] == -2) {
						PrintToChat(client, "[SM] %t", "not proposed");	
					} else {
						revokeProposal(client_id);
						cacheUsage(client_id);						
						CPrintToChat(client, "[SM] %t", "proposal revoked", proposal_names[client]);
						proposal_slots[client] = -2;
						proposal_names[client] = "";
						proposal_ids[client] = "";
					}
				} else {
					CPrintToChat(client, "[SM] %t", "already married", marriage_names[client]);
					PrintToChat(client, "[SM] %t", "divorce info");
				}
			} else {
				PrintToChat(client, "[SM] %t", "spam");
				CPrintToChat(client, "[SM] %t", "delay info", GetConVarFloat(cvar_delay));
			}
		} else {
			PrintToChat(client, "[SM] %t", "status being checked");
		}
	}
	return Plugin_Handled;
}

public Action Proposals(int client, int args)
{
	char client_id[MAX_ID_LENGTH];
	
	if(GetClientAuthId(client, AuthId_Engine, client_id, sizeof(client_id))) {
		if(proposal_checked[client] && marriage_checked[client]) {
			if(checkUsage(client_id)) {
				if(marriage_slots[client] == -2) {
					findProposals(client_id);
				} else {
					CPrintToChat(client, "[SM] %t", "already married", marriage_names[client]);
					PrintToChat(client, "[SM] %t", "divorce info");
				}		
			} else {
				PrintToChat(client, "[SM] %t", "spam");
				CPrintToChat(client, "[SM] %t", "delay info", GetConVarFloat(cvar_delay));
			}
		} else {
			PrintToChat(client, "[SM] %t", "status being checked");
		}
	}
	return Plugin_Handled;
}

public Action Divorce(int client, int args) {
	char client_id[MAX_ID_LENGTH];
	
	if(GetClientAuthId(client, AuthId_Engine, client_id, sizeof(client_id))) {
		if(proposal_checked[client] && marriage_checked[client]) {
			if(checkUsage(client_id)) {
				if(marriage_slots[client] == -2) {
					PrintToChat(client, "[SM] %t", "not married");
					PrintToChat(client, "[SM] %t", "marriage info");
				} else {
					int format;
					int time_spent;
					int partner = marriage_slots[client];
					char client_name[MAX_NAME_LENGTH];				
					
					if(GetClientName(client, client_name, sizeof(client_name))) {
						revokeMarriage(client_id);
						forwardDivorce(client, partner);
						cacheUsage(client_id);				
						computeTimeSpent(marriage_times[client], time_spent, format);						
						switch(format) {
							case 0 : {
								CPrintToChatAll("[SM] %t", "marriage revoked days", client_name, marriage_names[client], time_spent);
							}
							case 1 : {
								CPrintToChatAll("[SM] %t", "marriage revoked months", client_name, marriage_names[client], time_spent);
							}
							case 2 : {
								CPrintToChatAll("[SM] %t", "marriage revoked years", client_name, marriage_names[client], time_spent);
							}
						}
						PrintToChatAll("[SM] %t", "divorce notification");
						marriage_slots[client] = -2;
						marriage_names[client] = "";
						marriage_ids[client] = "";
						marriage_scores[client] = -1;
						marriage_times[client] = -1;
						if(partner != -1) {
							marriage_slots[partner] = -2;
							marriage_names[partner] = "";
							marriage_ids[partner] = "";
							marriage_scores[partner] = -1;
							marriage_times[partner] = -1;						
						}						
					}
				}
			} else {
				PrintToChat(client, "[SM] %t", "spam");
				CPrintToChat(client, "[SM] %t", "delay info", GetConVarFloat(cvar_delay));
			}			
		} else {
			PrintToChat(client, "[SM] %t", "status being checked");
		}
	}
	return Plugin_Handled;
}

public Action Couples(int client, int args)
{
	char client_id[MAX_ID_LENGTH];
	
	if(GetClientAuthId(client, AuthId_Engine, client_id, sizeof(client_id))) {
		findMarriages(client_id);
	}
	return Plugin_Handled;
}

public Action Reset(int client, int args) {
	resetTables(client);
	return Plugin_Handled;
}