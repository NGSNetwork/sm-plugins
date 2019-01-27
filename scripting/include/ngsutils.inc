/*******************************
* NGS Utils
* For use in NGS plugins. Provides common functions as well as checks.
* Released under Unlicense License.
*/

#if defined _ngsutil_included
 #endinput
#endif
#define _ngsutil_included

#tryinclude <adt_array>
#tryinclude <adt_trie>
#tryinclude <autoexecconfig>
#tryinclude <clientprefs>
#tryinclude <timber>
#tryinclude <timers>

/**
 * Checks if a client is valid. From another include whose author I can't find
 *
 * @param index				A client index.
 * @param aliveTest			If true, tests if a client is alive.
 * @param botTest			If true, bots will always return FALSE.
 * @param rangeTest			If true, clients out of range will return FALSE.
 * @param ingameTest		If true, clients not in-game will return FALSE.
 * @param afkTest			RELIES ON AFK MANAGER: If true, checks if client is afk.
 * @return					TRUE or FALSE, based on checks.
 */
stock bool IsValidClient(int client, bool aliveTest=false, bool botTest=true,
	bool rangeTest=true, bool ingameTest=true, bool afkTest=false)
{
	if (client > 4096) client = EntRefToEntIndex(client);
	if (rangeTest && (client < 1 || client > MaxClients)) return false;
	if (ingameTest && !IsClientInGame(client)) return false;
	if (botTest && IsFakeClient(client)) return false;
	if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	if (aliveTest && !IsPlayerAlive(client)) return false;
	#if defined _afkmanager_included
		bool afkavailable = (GetFeatureStatus(FeatureType_Native, "AFKM_IsClientAFK") ==
				FeatureStatus_Available);
		if (afkTest)
		{
			if (afkavailable)
			{
				if (AFKM_IsClientAFK(client))
				{
					return false;
				}
			}
			else
			{
				LogError("AFKManager is not available, but was used!");
			}
		}
	#else
		if (afkTest) ThrowError("AFKManager was not included!");
	#endif
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

/**
 * Shows a HUD message to all valid clients on the given channel.
 *
 * As of this writing, only TF, HL2MP, and SourceForts support HUD Text.
 *
 * @param channel		A channel number.
 *						If -1, then a channel will automatically be selected
 *						based on the least-recently-used channel.  If the
 *						channel is any other number, it will be modulo'd with
 *						the channel count to get a final channel number.
 * @param message		Message text or formatting rules.
 * @param ...			Message formatting parameters.
 * @return				-1 on failure (or lack of mod support).
 *						Any other return value is the channel number that was
 *						used to render the text.
 */
stock int ShowHudTextAll(int channel, const char[] message, any ...)
{
	if (channel == -1)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
			{
				channel = ShowHudText(i, -1, "");
				break;
			}
		}
		if (channel == -1)
		{
			return -1;
		}
	}

	char buffer[255];
	VFormat(buffer, sizeof(buffer), message, 3);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			ShowHudText(i, channel, buffer);
		}
	}
	return channel;
}

/**
 * Shows a synchronized HUD message to all clients.
 *
 * As of this writing, only TF, HL2MP, and SourceForts support HUD Text.
 *
 * @param sync			Synchronization object.
 * @param message		Message text or formatting rules.
 * @param ...			Message formatting parameters.
 * @return				-1 on failure, anything else on success.
 *						This function fails if the mod does not support it.
 * @error				Sync object not valid.
 */
stock int ShowSyncHudTextAll(Handle sync, const char[] message, any ...)
{
	int result = -1;
	char buffer[255];
	VFormat(buffer, sizeof(buffer), message, 3);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			result = ShowSyncHudText(i, sync, buffer);
			if (result == -1) return -1;
		}
	}
	return result;
}

/**
 * Shows a synchronized HUD message to all clients.
 *
 * @param index				A client index.
 * @param aliveTest			If true, tests if a client is alive.
 * @param botTest			If true, bots will always return FALSE.
 * @param rangeTest			If true, clients out of range will return FALSE.
 * @param ingameTest		If true, clients not in-game will return FALSE.
 * @param afkTest			RELIES ON AFK MANAGER: If true, checks if client is afk.
 * @return					TRUE or FALSE, based on checks.
 */
stock bool IsServerPopulated(bool checkAFK=false)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i, _, _, _, _, checkAFK))
		{
			return true;
		}
	}
	return false;
}

/**
 * Returns an absolute value.
 *
 * @param value			Input value.
 * @return				Absolute value of the input.
 */
stock int abs(int value)
{
	return RoundToNearest(FloatAbs(float(value)));
}

/**
 * Prints to server console only if DEBUG flag is defined.
 *
 * @param buffer			String to print to console.
 * @param ...				Optional format parameters.
 * @noreturn
 */
stock void PrintToServerDebug(const char[] buffer, any ...)
{
	#if defined DEBUG
	char format[8192];
	VFormat(format, sizeof(format), buffer, 2);
	PrintToServer(format);
	#endif
}

#if defined _tf2_stocks_included
#define TF_MAX_CLASS_NAME_LENGTH 12
stock int TF2_ClassEnumToString(TFClassType i_class, char s_class[TF_MAX_CLASS_NAME_LENGTH])
{
	switch (i_class)
	{
			case TFClass_Scout: 	return Format(s_class, TF_MAX_CLASS_NAME_LENGTH, "scout");
			case TFClass_Soldier: 	return Format(s_class, TF_MAX_CLASS_NAME_LENGTH, "soldier");
			case TFClass_Pyro: 		return Format(s_class, TF_MAX_CLASS_NAME_LENGTH, "pyro");
			case TFClass_DemoMan: 	return Format(s_class, TF_MAX_CLASS_NAME_LENGTH, "demoman");
			case TFClass_Heavy: 	return Format(s_class, TF_MAX_CLASS_NAME_LENGTH, "heavy");
			case TFClass_Medic: 	return Format(s_class, TF_MAX_CLASS_NAME_LENGTH, "medic");
			case TFClass_Sniper: 	return Format(s_class, TF_MAX_CLASS_NAME_LENGTH, "sniper");
			case TFClass_Spy: 		return Format(s_class, TF_MAX_CLASS_NAME_LENGTH, "spy");
			case TFClass_Engineer: 	return Format(s_class, TF_MAX_CLASS_NAME_LENGTH, "engineer");
	}
	return 0;
}
#endif

#if defined _timers_included
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
#endif

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

#if defined _adt_array_included
// SMQueue Methodmap, because this doesn't exist?
methodmap SMQueue < ArrayList
{
	/**
	 * Returns a Queue "object". This is just an ArrayList with
	 * queue-like access and manipulation methods.
	 *
	 * @param blocksize		The number of cells each member of the array can
	 * 						hold.  For example, 32 cells is equivalent to:
	 * 						new Array[X][32]
	 * @param startsize		Initial size of the array.  Note that data will
	 * 						NOT be auto-initialized.
	 * @return 				A new SMQueue object.
	 */
	public SMQueue(int blocksize = 1, int startsize = 0)
	{
		return view_as<SMQueue>(new ArrayList(blocksize, startsize));
	}

	/**
	 * Checks if a Queue is empty.
	 *
	 * @return			True if Queue is empty, false otherwise.
	 */
	public bool isEmpty()
	{
		return this.Length == 0;
	}

	/**
	 * Retrieves the front element in the Queue.
	 *
	 * @param block					Optionally specify which block to read (useful if the blocksize > 0).
	 * @param asChar				Optionally read as a byte instead of a cell.
	 * @return							Contents of first element.
	 * @error								Empty queue.
	 */
	public any GetFront(int block = 0, bool asChar=false)
	{
		if (this.isEmpty())
		{
			ThrowError("Error: GetFront() called on empty Queue!");
		}
		return this.Get(0, block, asChar);
	}

	/**
	 * Retrieves a string value from the front of a Queue.
	 *
	 * @param buffer        Buffer to copy to.
	 * @param maxlength     Maximum size of the buffer.
	 * @return              Number of characters copied.
	 * @error               Invalid index.
	 */
	public int GetFrontString(char[] buffer, int maxlength)
	{
		if (this.isEmpty())
		{
			ThrowError("Error: GetFrontString() called on empty Queue!");
		}
		return this.GetString(0, buffer, maxlength);
	}

	/**
	 * Retrieves an array from the front of a Queue.
	 *
	 * @param buffer        Buffer to copy to.
	 * @param maxlength     Maximum size of the buffer.
	 * @param size          Size given, otherwise blocksize.
	 * @return              Number of characters copied.
	 * @error               Invalid index.
	 */
	public int GetFrontArray(any[] buffer, int size = -1)
	{
		if (this.isEmpty())
		{
			ThrowError("Error: GetFrontArray() called on empty Queue!");
		}
		return this.GetArray(0, buffer, size);
	}

	/**
	 * Places new data element at the end of Queue
	 *
	 * @param data         Item to put at rear.
	 * @noreturn
	 */
	public void Enqueue(any data)
	{
		this.Push(data);
	}

	/**
	 * Enqueues at a given index. If the index is greater than the Length, this
	 * will optionally just append. Useful if you want to prioritize elements.
	 *
	 * @param index                Index to place item at.
	 * @param data                 Item to put at index.
	 * @param appendOutBounds      Optionally set to append if index is greater
	 *                             than queue size.
	 * @noreturn
	 */
	public void EnqueueAt(int index, any data, bool appendOutBounds = true)
	{
		int queueLen = this.Length;
		if (index < 0 || (!appendOutBounds && queueLen <= index))
		{
			ThrowError("SMQueue Error: Attempted to add item at %d to queue of size %d!", index, queueLen);
		}
		if (queueLen > index)
		{
			this.ShiftUp(index);
			this.Set(index, data);
		}
		else if (appendOutBounds)
		{
			this.Enqueue(data);
		}
	}

	/**
	 * Places a string at the end of a Queue, truncating it if it is too big.
	 *
	 * @param value         String to push.
	 * @noreturn
	 */
	public void EnqueueString(const char[] value)
	{
		this.PushString(value);
	}

	/**
	 * Enqueues at a given index. If the index is greater than the Length, this
	 * will optionally just append. Useful if you want to prioritize elements.
	 *
	 * @param index                Index to place item at.
	 * @param value                String to put at index.
	 * @param appendOutBounds      Optionally set to append if index is greater
	 *                             than queue size.
	 * @noreturn
	 */
	public void EnqueueStringAt(int index, const char[] value, bool appendOutBounds = true)
	{
		int queueLen = this.Length;
		if (index < 0 || (!appendOutBounds && queueLen <= index))
		{
			ThrowError("SMQueue Error: Attempted to add string at %d to queue of size %d!", index, queueLen);
		}
		if (queueLen > index)
		{
			this.ShiftUp(index);
			this.SetString(index, value);
		}
		else if (appendOutBounds)
		{
			this.EnqueueString(value);
		}
	}

	/**
	 * Places an array at the end of a Queue.
	 *
	 * @param values        Block of values to copy.
	 * @param size          If not set, the number of elements copied from the array
	 *                      will be equal to the blocksize.  If set higher than the
	 *                      blocksize, the operation will be truncated.
	 * @noreturn
	 */
	public void EnqueueArray(const any[] values, int size = -1)
	{
		this.PushArray(values, size);
	}

	/**
	 * Enqueues at a given index. If the index is greater than the Length, this
	 * will optionally just append. Useful if you want to prioritize elements.
	 *
	 * @param index                Index to place item at.
	 * @param value                String to put at index.
	 * @param appendOutBounds      Optionally set to append if index is greater
	 *                             than queue size.
	 * @noreturn
	 */
	public void EnqueueArrayAt(int index, const any[] value, bool appendOutBounds = true)
	{
		int queueLen = this.Length;
		if (index < 0 || (!appendOutBounds && queueLen <= index))
		{
			ThrowError("SMQueue Error: Attempted to add array at %d to queue of size %d!", index, queueLen);
		}
		if (queueLen > index)
		{
			this.ShiftUp(index);
			this.SetArray(index, value);
		}
		else if (appendOutBounds)
		{
			this.EnqueueArray(value);
		}
	}

	/**
	 * Retrieves and remove a cell value from front of Queue.
	 *
	 * @param block         Optionally specify which block to read from
	 *                      (useful if the blocksize > 0).
	 * @param asChar        Optionally read as a byte instead of a cell.
	 * @return              Value read.
	 * @error               Queue is empty.
	 */
	public any Dequeue(int block = 0, bool asChar = false)
	{
		if (this.isEmpty())
		{
			ThrowError("Error: Dequeue() called on empty Queue!");
		}
		any item = this.Get(0, block, asChar);
		this.Erase(0);
		return item;
	}

	/**
	 * Retrieves and remove a string value from front of Queue.
	 *
	 * @param buffer        Buffer to copy to.
	 * @param maxlength     Maximum size of the buffer.
	 * @return              Number of characters copied.
	 * @error               Queue is empty.
	 */
	public int DequeueString(char[] buffer, int maxlength)
	{
		if (this.isEmpty())
		{
			ThrowError("Error: DequeueString() called on empty Queue!");
		}

		int val = this.GetString(0, buffer, maxlength);
		this.Erase(0);
		return val;
	}

	/**
	 * Retrieves an array of cells from an array.
	 *
	 * @param buffer        Buffer to store the array in.
	 * @param size          If not set, assumes the buffer size is equal to the
	 *                      blocksize.  Otherwise, the size passed is used.
	 * @return              Number of cells copied.
	 * @error               Queue is empty.
	 */
	 public int DequeueArray(any[] buffer, int size = -1)
 	{
 		if (this.isEmpty())
 		{
 			ThrowError("Error: DequeueArray() called on empty Queue!");
 		}

 		int val = this.GetArray(0, buffer, size);
 		this.Erase(0);
 		return val;
 	}
}
#endif

#if defined _adt_trie_included
methodmap StringObj < StringMap
{
	/**
	 * Creates a new java-like String Object (must be closed or deleted).
	 *
	 * @param buffer        Buffer to store the array in.
	 * @noreturn
	 */
	public StringObj(const char[] buffer)
	{
		StringMap map = new StringMap();
		map.SetString("value", buffer);
		map.SetValue("length", strlen(buffer));
		return view_as<String>(map);
	}

	/**
	 * Gets the cached length of the string.
	 */
	property int length
	{
		public get()
		{
			int length;
			this.GetValue("length", length);
			return length;
		}
	}

	/**
	 * Returns the char value at the specified index.
	 *
	 * @param index			Index to retrieve character from.
	 */
	public char charAt(int index)
	{
		int length = this.length;
		if (index >= length || index < 0)
		{
			ThrowError("StringObj Error: Attempted to access index out of bounds!");
		}
		char[] value = new char[length];
		this.GetString("value", value, length);
		return view_as<char>(value[index]);
	}

	/**
	 * Turn a string into a character array. Implementation of strlcpy.
	 *
	 * @param dest					Character array to copy into.
	 * @param arraySize			Size of array to copy into.
	 * @returns							Number of bytes written to dest buffer.
	 */
	public int toCharArray(char[] dest, int destLen)
	{
		int written;
		this.GetString("value", dest, destLen, written);

		return written;	/* count does not include NUL */
	}

	/**
	 * Compares two strings to each other. From GNU C Library.
	 *
	 * @param anotherString			Right String to compare to.
	 * @param	caseSensitive			If true (default), comparison is case sensitive. If false,
	 *														comparison is case insensitive.
	 * @return 			-1 if str1 < str2 0 if str1 == str2 1 if str1 > str2
	 */
	public int compareTo(StringObj anotherString, bool caseSensitive)
	{
		int length = this.length, otherLength = anotherString.length;

		char[] str1 = new char[length], str2 = new char[otherLength];

		this.toCharArray(str1, length);
		anotherString.toCharArray(str2, otherLength);

		return strcmp(str1, str2, caseSensitive);
	}

	/**
	 * Returns whether a string is empty.
	 *
	 * @return			String is empty?
	 */
	public bool isEmpty()
	{
		return (this.length == 0);
	}
}
// Object METHODMAPS similar to Java, designed to be extended with methodmaps.
methodmap SMObject < StringMap
{
	/**
	 * Create a new object with properties you can set/add to.
	 *
	 * @return							A new Object that is cool.
	 */
	public SMObject()
	{
		StringMap map = new StringMap();
		map.SetValue("any", new StringMap());
		map.SetValue("function", new StringMap());
		map.SetValue("handle", new StringMap());
		map.SetValue("object", new StringMap());
		map.SetValue("string", new StringMap());

		map.SetValue("class", "Object");
		map.SetValue("destroyhandles", new StringMap());
		return view_as<SMObject>(map);
	}

	/**
	 * Returns the memory value of this, might be usable as a hashCode, iunno.
	 *
	 * @return						Memory location of this object.
	 */
	public int hashCode()
	{
		return view_as<int>(this);
	}

	/**
	 * Returns the class of the item.
	 *
	 * @param buffer			Buffer to save class to.
	 * @param buffSize		Size of buffer.
	 * @return						Number of bytes written to buffer.
	 */
	public int getClass(char[] buffer, int buffSize)
	{
		int len;
		this.GetString("class", buffer, buffSize, len);
		return len;
	}

	/**
	 * Returns if two objects are equal.
	 *
	 * @param obj					Object to check for equality.
	 * @return						True if objects are the same, otherwise no.
	 */
	public bool equals(SMObject obj)
	{
		return obj == this;
	}

	/**
	 * Creates and returns a clone of the Object.
	 *
	 * @param plugin			Possible new plugin's ownership handle.
	 * @return						Cloned object that must be disposed of by itself.
	 */
	public SMObject clone(Handle plugin=INVALID_HANDLE)
	{
		return view_as<SMObject>(CloneHandle(this, plugin));
	}

	/**
	 * Saves a string representation of the object to buffer.
	 *
	 * @param buffer			Character buffer to save object to.
	 * @param buffSize		Size of buffer to put it
	 * @return						Number of bytes written to buffer.
	 */
	public int toString(char[] buffer, int buffSize)
	{
		char class[256];
		this.getClass(class, sizeof(class));
		return Format(buffer, buffSize, "%s@%x", class, this.hashCode());
	}

	/////////////////////////
	///				TYPES				///
	/////////////////////////

	public StringMap retrieveMapOfType(const char[] type)
	{
		StringMap typeMap;
		this.GetValue(type, typeMap);
		return typeMap;
	}

	/**
	 * Adds a boolean member to Object.
	 *
	 * @param memberName	New member to add to Object.
	 * @param val					Optional default value to give.
	 * @noreturn
	 */
	public void addBool(char[] memberName, bool val=false)
	{
		StringMap typeMap = this.retrieveMapOfType("any");

		if (!typeMap.SetValue(memberName, val, false))
		{
			ThrowError("Error in AddBool. Attempted to add member %s that already existed!", memberName);
		}
	}

	/**
	 * Adds a character member to Object.
	 *
	 * @param memberName	New member to add to Object.
	 * @param val					Optional default value to give.
	 * @noreturn
	 */
	public void addChar(char[] memberName, any val='\0')
	{
		StringMap typeMap = this.retrieveMapOfType("any");

		if (!typeMap.SetValue(memberName, val, false))
		{
			ThrowError("Error in AddChar. Attempted to add member %s that already existed!", memberName);
		}
	}

	/**
	 * Adds a float member to Object.
	 *
	 * @param memberName	New member to add to Object.
	 * @param val					Optional default value to give.
	 * @return						Cloned object that must be disposed of by itself.
	 */
	public void addFloat(char[] memberName, float val=0.0)
	{
		StringMap typeMap = this.retrieveMapOfType("any");

		if (!typeMap.SetValue(memberName, val, false))
		{
			ThrowError("Error in AddFloat. Attempted to add member %s that already existed!", memberName);
		}
	}

	/**
	 * Adds a float member to Object.
	 *
	 * @param memberName	New member to add to Object.
	 * @param val					Name of function to put in.
	 * @return						Cloned object that must be disposed of by itself.
	 */
	public void addFunction(char[] memberName, const char[] val="")
	{
		StringMap typeMap = this.retrieveMapOfType("function");

		if (!typeMap.SetString(memberName, val, false))
		{
			ThrowError("Error in AddFunction. Attempted to add member %s that already existed!", memberName);
		}
	}

	/**
	 * Adds a Handle member to Object.
	 *
	 * @param memberName	New member to add to Object.
	 * @param val					Name of function to put in.
	 * @return						Cloned object that must be disposed of by itself.
	 */
	public void addHandle(char[] memberName, Handle val = null, bool deleteAtDispose = true)
	{
		StringMap typeMap = this.retrieveMapOfType("handle");

		if (!typeMap.SetValue(memberName, val, false))
		{
			ThrowError("Error in AddHandle. Attempted to add member %s that already existed!", memberName);
		}

		if (deleteAtDispose)
		{
			typeMap = this.retrieveMapOfType("destroyhandles");
			if (!typeMap.SetValue(memberName, val, false))
			{
				ThrowError("Error in AddHandle. Attempt to add %s to delete Map failed!", memberName);
			}
		}
	}

	/**
	 * Adds a integer member to Object.
	 *
	 * @param memberName	New member to add to Object.
	 * @param val					Optional default value to give.
	 * @noreturn
	 */
	public void addInt(char[] memberName, int val=0)
	{
		StringMap typeMap = this.retrieveMapOfType("any");

		if (!typeMap.SetValue(memberName, val, false))
		{
			ThrowError("Error in AddInt. Attempted to add member %s that already existed!", memberName);
		}
	}

	/**
	 * Adds a integer member to Object.
	 *
	 * @param memberName	New member to add to Object.
	 * @param val					Optional default value to give.
	 * @noreturn
	 */
	public void addObject(char[] memberName, SMObject val=null)
	{
		StringMap typeMap = this.retrieveMapOfType("object");

		if (!typeMap.SetValue(memberName, val, false))
		{
			ThrowError("Error in AddObject. Attempted to add member %s that already existed!", memberName);
		}
	}

	/**
	 * Adds a boolean member to Object.
	 *
	 * @param memberName	New member to add to Object.
	 * @param val					Optional default value to give.
	 * @return						Cloned object that must be disposed of by itself.
	 */
	public void addString(char[] memberName, const char[] val = "") // TODO: finish this with arrays
	{
		StringMap typeMap = this.retrieveMapOfType("string");

		if (!typeMap.SetString(memberName, val, false))
		{
			ThrowError("Error in AddString. Attempted to add member %s that already existed!", memberName);
		}
	}

	/**
	 * Disposes of all members.
	 *
	 * @param deleteThis	Optionally delete this object (set to null)
	 * @noreturn
	 */
	public void dispose(bool deleteThis=true)
	{
		DisposeObj(this, deleteThis);
	}
}

stock void DisposeObj(SMObject me, bool deleteThis=true)
{
	StringMap map;
	me.GetValue("any", map);
	delete map;
	me.GetValue("function", map);
	delete map;
	me.GetValue("handle", map);
	delete map;
	me.GetValue("string", map);
	delete map;

	char key[24];
	me.GetValue("destroyhandles", map);
	StringMapSnapshot snap = map.Snapshot();
	Handle subHandle;
	for (int i = 0; i < snap.Length; i++)
	{
		snap.GetKey(i, key, sizeof(key));
		map.GetValue(key, subHandle);
		delete subHandle;
	}
	delete snap;
	delete map;

	SMObject objs;
	me.GetValue("object", map);
	snap = map.Snapshot();
	for (int i = 0; i < snap.Length; i++)
	{
		snap.GetKey(i, key, sizeof(key));
		map.GetValue(key, objs);
		objs.dispose(deleteThis);
	}
	delete snap;
	delete map;
	if (deleteThis)
	{
		delete me;
	}
}
#endif

#if defined _autoexecconfig_included
/**
 * Creates a Convar using AutoExecConfig_CreateConVar and sets a reference bool
 * to whether the file was appended to or not.
 *
 * @param wasAppended         Reference variable to set to true if appended.
 * @param name                Name of new convar.
 * @param defaultValue        String containing the default value of new convar.
 * @param description         Optional description of the convar.
 * @param flags               Optional bitstring of flags determining how the convar should be handled. See FCVAR_* constants for more details.
 * @param hasMin              Optional boolean that determines if the convar has a minimum value.
 * @param min                 Minimum floating point value that the convar can have if hasMin is true.
 * @param hasMax              Optional boolean that determines if the convar has a maximum value.
 * @param max                 Maximum floating point value that the convar can have if hasMax is true.
 * @return                    A handle to the newly created convar. If the convar already exists, a handle to it will still be returned.
 * @error                     Convar name is blank or is the same as an existing console command.
 */
stock ConVar AutoExecConfig_CreateConVarCheckAppend(bool &wasAppended, const char[] name, const char[] defaultValue, const char[] description="", int flags=0, bool hasMin=false, float min=0.0, bool hasMax=false, float max=0.0)
{
	ConVar returnCvar = AutoExecConfig_CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);
	if (AutoExecConfig_GetAppendResult() == AUTOEXEC_APPEND_SUCCESS)
	{
		wasAppended = true;
	}
	return returnCvar;
}

/**
 * Executes and cleans if the file was appended to. Can also be used to force a
 * clean and/or execute.
 *
 * @param appended            Variable that indicates whether a convar was
 *                            appended during the creation process. Use
 *                            AutoExecConfig_CreateConVarCheckAppend with this.
 * @param exec                Optional: Should file be executed?
 * @noreturn
 */
stock ConVar AutoExecConfig_ExecAndClean(bool appended, bool exec=true)
{
	if (exec)
	{
		AutoExecConfig_ExecuteFile();
	}
	if (appended)
	{
		AutoExecConfig_CleanFile();
	}
}
#endif
