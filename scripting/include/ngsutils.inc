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

// TIMER METHODMAPS
methodmap SMTimer < Handle
{
	/**
	 * Creates a basic timer.  Calling CloseHandle() on a timer will end the timer.
	 *
	 * @param interval			Interval from the current game time to execute the given function.
	 * @param func				Function to execute once the given interval has elapsed.
	 * @param data				Handle or value to pass through to the timer callback function.
	 * @param flags				Flags to set (such as repeatability or auto-Handle closing).
	 * @return					Handle to the timer object.  You do not need to call CloseHandle().
	 *							If the timer could not be created, INVALID_HANDLE will be returned.
	 */
	public SMTimer(float interval, Timer func, any data=null, int flags=0)
	{
		return view_as<SMTimer>(CreateTimer(interval, func, data, flags));
	}
	
	/**
	 * Kills a timer.  Use this instead of CloseHandle() if you need more options.
	 *
	 * @param autoClose			If autoClose is true, the data that was passed to CreateTimer() will
	 *							be closed as a handle if TIMER_DATA_HNDL_CLOSE was not specified.
	 * @error				Invalid handles will cause a run time error.
	 */
	public void Kill(bool autoClose=false)
	{
		KillTimer(view_as<Handle>(this));
	}
	
	/**
	 * Manually triggers a timer so its function will be called.
	 *
	 * @param reset				If reset is true, the elapsed time counter is reset
	 *							so the full interval must pass again.
	 */
	public void Trigger(bool reset=false)
	{
		TriggerTimer(view_as<Handle>(this), reset);
	}
}
