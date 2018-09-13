#if defined _truedemocracy_included
  #endinput
#endif
#define _truedemocracy_included

#pragma dynamic 16384
#include <json>

methodmap Vote < JSON_Object
{
	public Vote()
	{
		return view_as<Vote>(new JSON_Object());
	}
	
	public static Vote fromJSON(char[] json)
	{
		return view_as<Vote>(json_decode(json));
	}
	
	public bool setKeyFromArray(char[] key, ArrayList array, bool replace=true, bool cleanup=true)
	{
		JSON_Object jsonArray = new JSON_Object(true);
		char option[48];
		for (int i = 0; i < array.Length; i++)
		{
			array.GetString(i, option, sizeof(option));
			jsonArray.PushString(option);
		}
		
		if (cleanup)
		{
			delete array;
		}
		
		return this.SetObject(key, jsonArray, replace);
	}
	
	public bool setOptionsFromObject(JSON_Object jsonOptions, bool replace=true)
	{
		return this.SetObject("options", jsonOptions, replace);
	}
	
	public bool setOptionsFromArray(ArrayList array, bool replace=true, bool cleanup=true)
	{
		if (array == null || array.Length < 2)
		{
			return false;
		}
		
		return this.setKeyFromArray("options", array, replace, cleanup);
	}
	
	public JSON_Object getOptions()
	{
		return this.GetObject("options");
	}
	
	public bool getId(char[] id, int len)
	{
		return this.GetString("id", id, len);
	}
	
	public bool setId(char[] id)
	{
		return this.SetString("id", id);
	}
	
	public bool getQuestion(char[] buffer, int len)
	{
		return this.GetString("question", buffer, len);
	}
	
	public bool setQuestion(char[] buffer)
	{
		return this.SetString("question", buffer);
	}
	
	public JSON_Object getTypes()
	{
		return this.GetObject("types");
	}
	
	public bool setTypesFromObject(JSON_Object jsonOptions, bool replace=true)
	{
		return this.SetObject("types", jsonOptions, replace);
	}
	
	public bool setTypesFromArray(ArrayList array, bool replace=true, bool cleanup=true)
	{
		return this.setKeyFromArray("types", array, replace, cleanup);
	}
	
	public JSON_Object getShow()
	{
		return this.GetObject("show");
	}
	
	public bool setShowFromObject(JSON_Object jsonOptions, bool replace=true)
	{
		return this.SetObject("show", jsonOptions, replace);
	}
	
	public bool setShowFromArray(ArrayList array, bool replace=true, bool cleanup=true)
	{
		return this.setKeyFromArray("show", array, replace, cleanup);
	}
	
	property int hold
	{
		public get() { return this.GetInt("hold"); }
		public set(int holdTime) { this.SetInt("hold", holdTime); }
	}
	
	property bool anonymous
	{
		public get() { return this.GetBool("anonymous"); }
		public set(bool anon) { this.SetBool("anonymous", anon); }
	}
	
	public JSON_Object getRewards()
	{
		return this.GetObject("rewards");
	}
	
	public bool setRewards(JSON_Object obj)
	{
		return this.SetObject("rewards", obj);
	}
}

native void TrueDemocracy_StartVote(Vote vote);

public SharedPlugin __pl_ngs_truedemocracy = {
	name = "[NGS] True Democracy",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
}