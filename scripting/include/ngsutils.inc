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

/**
* Check if a translation file exists. This is intended to be run before
* loading the file in. BuildPath is not needed beforehand. 
*
* @param file			Translation file to check for existence.
* @param loadFile		Load Translation if exists.
* @param failPlugin		If true, SetFailState to pause plugin.
* @return				True if file exists, else false.
*/
stock bool TranslationFileExists(char[] file, bool loadFile=true, bool failPlugin=false)
{
	char path[PLATFORM_MAX_PATH];
	int checkindex = strlen(file) - 4;
	BuildPath(Path_SM, path, sizeof(path), "translations/%s%s", file,
		(StrContains(file, ".txt") == checkindex || 
			StrContains(file, ".cfg") == checkindex) ? "" : ".txt");
	if(FileExists(path))
	{
		if (loadFile)
		{
			LoadTranslations(file);
		}
		return true;
	}
	else if (failPlugin)
	{
		SetFailState("Missing translation file at %s!", path);
	}
	return false;
}

// TIMER METHODMAPS
methodmap SMTimer < Handle
{
	/**
	 * Creates a basic timer.  Calling .Kill() on a timer will kill the timer. Do not .Kill(), .Close(),
	 * or delete in a callback! Make sure to null timer in callback if global!
	 *
	 * @param interval			Interval from the current game time to execute the given function.
	 * @param func				Function to execute once the given interval has elapsed.
	 * @param data				Handle or value to pass through to the timer callback function.
	 * @param flags				Flags to set (such as repeatability or auto-Handle closing).
	 * @return					Handle to the timer object.  You do not need to call CloseHandle().
	 *							If the timer could not be created, null will be returned.
	 */
	public SMTimer(float interval, Timer func, any data=INVALID_HANDLE, int flags=0)
	{
		return view_as<SMTimer>(CreateTimer(interval, func, data, flags));
	}

	/**
	 * Creates a SMTimer in a static fashion. Useful if the Handle isn't meant to be saved.
	 *
	 * @param interval			Interval from the current game time to execute the given function.
	 * @param func				Function to execute once the given interval has elapsed.
	 * @param data				Handle or value to pass through to the timer callback function.
	 * @param flags				Flags to set (such as repeatability or auto-Handle closing).
	 * @return					Handle to the timer object.  You do not need to call CloseHandle().
	 *							If the timer could not be created, null will be returned.
	 */
	public static SMTimer Make(float interval, Timer func, any data=INVALID_HANDLE, int flags=0)
	{
		return new SMTimer(interval, func, data, flags);
	}

	/**
	 * Kills a timer.  Use this instead of delete if you need more options. Do not use in a timer's callback!
	 *
	 * @param autoClose			If autoClose is true, the data that was passed to CreateTimer() will
	 *							be closed as a handle if TIMER_DATA_HNDL_CLOSE was not specified.
	 * @error					Invalid handles will cause a run time error.
	 */
	public void Kill(bool autoClose=false)
	{
		KillTimer(this, autoClose);
		delete this;
	}

	/**
	 * Closes a timer. A clone of .Kill() if autoClose is true. Do not use in a timer's callback!
	 *
	 * @param autoClose			If autoClose is true, the data that was passed to new SMTimer() will
	 *							be deleted as a handle if TIMER_DATA_HNDL_CLOSE was not specified.
	 * @error					Invalid handles will cause a run time error.
	 */
	public void Close(bool autoClose=false)
	{
		if (autoClose)
			this.Kill(autoClose);
		else
			delete this;
	}

	/**
	 * Manually triggers a timer so its function will be called.
	 *
	 * @param reset				If reset is true, the elapsed time counter is reset
	 *							so the full interval must pass again.
	 */
	public void Trigger(bool reset=false)
	{
		TriggerTimer(this, reset);
	}
}

methodmap SMDataTimer < SMTimer
{
	/**
	 * Creates a timer associated with a new datapack if needed.
	 * @note The datapack is automatically freed when the timer ends.
	 * @note The position of the datapack is not reset or changed for the timer function.
	 *
	 * @param interval			Interval from the current game time to execute the given function.
	 * @param func				Function to execute once the given interval has elapsed.
	 * @param datapack			The newly created datapack is passed through this by-reference
	 *							parameter to the timer callback function.
	 * @param flags				Timer flags.
	 * @return					Handle to the timer object.  You do not need to call CloseHandle().
	 */
	public SMDataTimer(float interval, Timer func, DataPack &datapack, int flags=0)
	{
		if (datapack == null)
		{
			datapack = new DataPack();
		}
		flags |= TIMER_DATA_HNDL_CLOSE;
		return view_as<SMDataTimer>(new SMTimer(interval, func, datapack, flags));
	}

	/**
	 * Creates a SMDataTimer in a static fashion. Useful if the Handle isn't meant to be saved.
	 * @note The datapack is automatically freed when the timer ends.
	 * @note The position of the datapack is not reset or changed for the timer function.
	 *
	 * @param interval			Interval from the current game time to execute the given function.
	 * @param func				Function to execute once the given interval has elapsed.
	 * @param datapack			The newly created datapack is passed through this by-reference
	 *							parameter to the timer callback function.
	 * @param flags				Timer flags.
	 * @return					Handle to the timer object.  You do not need to call CloseHandle().
	 */
	public static SMDataTimer Make(float interval, Timer func, DataPack &datapack, int flags=0)
	{
		return new SMDataTimer(interval, func, datapack, flags);
	}
}

#if defined _clientprefs_included
// Cookie Methodmaps!
methodmap Cookie < Handle
{
	/**
	 * Creates a new Client preference cookie.
	 *
	 * Cookies can be closed via delete when
	 * no longer needed.
	 *
	 * @param name			Name of the new preference cookie.
	 * @param description	Optional description of the preference cookie.
	 * @param access		What CookieAccess level to assign to this cookie.
	 * @return				A handle to the newly created cookie. If the cookie already
	 *                      exists, a handle to it will still be returned.
	 * @error				Cookie name is blank.
	 */
	public Cookie(const char[] name, const char[] description, CookieAccess access)
	{
		return view_as<Cookie>(RegClientCookie(name, description, access));
	}

	/**
	 * Searches for a Client preference cookie. Use as Cookie.Find().
	 *
	 * Cookies can be closed via delete when
	 * no longer needed.
	 *
	 * @param name			Name of cookie to find.
	 * @return				A cookie if it is found. null otherwise.
	 */
	public static Cookie Find(const char[] name)
	{
		return view_as<Cookie>(FindClientCookie(name));
	}

	/**
	 * Set the value of a Client preference cookie.
	 *
	 * @param client		Client index.
	 * @param value			String value to set.
	 * @error				Invalid cookie handle or invalid client index.
	 */
	public void SetValue(int client, const char[] value)
	{
		SetClientCookie(client, this, value);
	}

	/**
	 * Retrieve the value of a Client preference cookie.
	 *
	 * @param client		Client index.
	 * @param buffer		Copyback buffer for value.
	 * @param maxlen		Maximum length of the buffer.
	 * @error				Invalid cookie handle or invalid client index.
	 */
	public void GetValue(int client, char[] buffer, int maxlen)
	{
		GetClientCookie(client, this, buffer, maxlen);
	}

	/**
	 * Sets the value of a Client preference cookie based on an authID string.
	 *
	 * @param authID		String Auth/STEAM ID of player to set.
	 * @param value			String value to set.
	 * @error			Invalid cookie handle.
	 */
	public void SetByAuth(const char[] authID, const char[] value)
	{
		SetAuthIdCookie(authID, this, value);
	}

	/**
	 * Add a new prefab item to the client cookie settings menu.
	 *
	 * Note: This handles everything automatically and does not require a callback
	 *
	 * @param type			A CookieMenu prefab menu type.
	 * @param display		Text to show on the menu.
	 * @param handler		Optional handler callback for translations and output on selection
	 * @param info			Info data to pass to the callback.
	 * @error				Invalid cookie handle.
	 */
	public void SetMenu(CookieMenu type, const char[] display, CookieMenuHandler handler=INVALID_FUNCTION, any info=0)
	{
		SetCookiePrefabMenu(this, type, display, handler, info);
	}

	/**
	 * Returns the access level of a cookie
	 *
	 * @return				CookieAccess access level.
	 * @error				Invalid cookie handle.
	 */
	property CookieAccess Access
	{
		public get() {return GetCookieAccess(this);}
	}

	/**
	 * Returns the last updated timestamp for a client cookie
	 *
	 * @param client		Client index.
	 * @return			Last updated timestamp.
	 */
	public int GetTime(int client)
	{
		return GetClientCookieTime(client, this);
	}
}

methodmap CookieIterator < Handle
{
	/**
	 * Gets a cookie iterator.  Must be freed with delete.
	 *
	 * @return				A new cookie iterator.
	 */
	 public CookieIterator()
	 {
	 	return view_as<CookieIterator>(GetCookieIterator());
	 }

	 /**
	 * Reads a cookie iterator, then advances to the next cookie if any.
	 *
	 * @param name			Name buffer.
	 * @param nameLen		Name buffer size.
	 * @param access		Access level of the cookie.
	 * @param desc			Cookie description buffer.
	 * @param descLen		Cookie description buffer size.
	 * @return				True on success, false if there are no more commands.
	 */
	 public bool Read(char[] name, int nameLen, CookieAccess &access, char[] desc="", int descLen=0)
	 {
	 	return ReadCookieIterator(this, name, nameLen, access, desc, descLen);
	 }
}
#endif

#if defined _dbi_included
// Thanks to Shaders Allen (Drixevel) for the idea and code! sourcemod-misc.inc -> methodmaps
methodmap SmartDB < Database
{
	public void QueryF(SQLQueryCallback callback, any data, DBPriority priority = DBPrio_Normal, const char[] format, any ...)
	{
		char query[8192];
		VFormat(query, sizeof(query), format, 5);
		this.Query(callback, query, data, priority);
	}

	public void VoidQuery(const char[] query, DBPriority prio = DBPrio_Normal)
	{
		DataPack pack = new DataPack();
		pack.WriteString(query);
		this.Query(TQuery_Void, query, pack, prio);
	}

	public void VoidQueryF(DBPriority priority = DBPrio_Normal, const char[] format, any ...)
	{
		char query[8192];
		VFormat(query, sizeof(query), format, 3);
		this.VoidQuery(query, priority);
	}

	public void FetchClientName(int client, char[] buffer, int size)
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		int size2 = 2 * strlen(sName) + 1;
		char[] sEscapedName = new char[size2 + 1];
		this.Escape(sName, sEscapedName, size2 + 1);
		strcopy(buffer, size, sEscapedName);
	}
}

public void TQuery_Void(Database owner, DBResultSet hndl, const char[] error, DataPack data)
{
	if (hndl == null)
	{
		data.Reset();
		char sQuery[8192];
		data.ReadString(sQuery, sizeof(sQuery));
		LogError("Error executing void query: %s", error);
		LogError("Query Output: %s", sQuery);
	}
	delete data;
}
#endif