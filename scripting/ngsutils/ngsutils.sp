/*******************************
* NGS Utils
* For use in NGS plugins. Provides common functions as well as checks.
* Released under Unlicense License.
*/	


/**
* Checks if a client is valid. From another include whose author I can't find
*
* @param index				A client index.
* @param aliveTest			If true, tests if a client is alive.
* @param botTest			If true, bots will always return FALSE.
* @param rangeTest			If true, clients out of range will return FALSE.
* @param ingameTest			If true, clients not in-game will return FALSE.
* @return					TRUE or FALSE, based on checks.
*/
stock bool IsValidClient(int client, bool aliveTest=false, bool botTest=true, bool rangeTest=true, 
	bool ingameTest=true)
{
	if (client > 4096) client = EntRefToEntIndex(client);
	if (rangeTest && (client < 1 || client > MaxClients)) return false;
	if (ingameTest && !IsClientInGame(client)) return false;
	if (botTest && IsFakeClient(client)) return false;
	if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	if (aliveTest && !IsPlayerAlive(client)) return false;
	return true;
}