#if defined _tf2idb_included
	#endinput
#endif
#define _tf2idb_included

#define TF2IDB_MAX_ATTRIBUTES 			15
#define TF2IDB_ITEMCLASS_LENGTH			64
#define TF2IDB_ITEMSLOT_LENGTH			16

enum TF2ItemSlot {
	TF2ItemSlot_Primary = 0,
	TF2ItemSlot_Secondary = 1,
	TF2ItemSlot_Sapper = 1,
	TF2ItemSlot_Melee = 2,
	TF2ItemSlot_PDA = 3,
	TF2ItemSlot_PDA1 = 3,
	TF2ItemSlot_PDA2 = 4,
	TF2ItemSlot_Building = 5,
	TF2ItemSlot_Hat = 5,
	TF2ItemSlot_Head = 5,
	TF2ItemSlot_Misc = 6,
	TF2ItemSlot_Action = 7,
	TF2ItemSlot_Taunt,
};

enum TF2ItemQuality {
	TF2ItemQuality_Normal = 0, // 0
	TF2ItemQuality_Rarity1,
	TF2ItemQuality_Genuine = 1,
	TF2ItemQuality_Rarity2,
	TF2ItemQuality_Vintage,
	TF2ItemQuality_Rarity3,
	TF2ItemQuality_Rarity4,
	TF2ItemQuality_Unusual = 5,
	TF2ItemQuality_Unique,
	TF2ItemQuality_Community,
	TF2ItemQuality_Developer,
	TF2ItemQuality_Selfmade,
	TF2ItemQuality_Customized, // 10
	TF2ItemQuality_Strange,
	TF2ItemQuality_Completed,
	TF2ItemQuality_Haunted,
	TF2ItemQuality_ToborA
};

native bool TF2IDB_IsValidItemID(int id);
native bool TF2IDB_GetItemName(int id, char[] string, int length);
native bool TF2IDB_GetItemClass(int id, char[] string, int length);
native bool TF2IDB_GetItemSlotName(int id, char[] string, int length);
native TF2ItemSlot TF2IDB_GetItemSlot(int id);
native bool TF2IDB_GetItemQualityName(int id, char[] string, int length);
native TF2ItemQuality TF2IDB_GetItemQuality(int id);
native bool TF2IDB_GetItemLevels(int id, int &min, int &max);
native int TF2IDB_GetItemAttributes(int id, int aid[TF2IDB_MAX_ATTRIBUTES], float values[TF2IDB_MAX_ATTRIBUTES]);
native Handle TF2IDB_GetItemEquipRegions(int id);
native bool TF2IDB_DoRegionsConflict(const char[] region1, const char[] region2);
native Handle TF2IDB_ListParticles();
native Handle TF2IDB_FindItemCustom(const char[] query);
native bool TF2IDB_ItemHasAttribute(int id, int aid);

public SharedPlugin __pl_tf2idb = {
	name = "tf2idb",
	file = "tf2idb.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#if !defined REQUIRE_PLUGIN
public void __pl_tf2idb_SetNTVOptional() {
	MarkNativeAsOptional("TF2IDB_IsValidItemID");
	MarkNativeAsOptional("TF2IDB_GetItemName");
	MarkNativeAsOptional("TF2IDB_GetItemClass");
	MarkNativeAsOptional("TF2IDB_GetItemSlotName");
	MarkNativeAsOptional("TF2IDB_GetItemSlot");
	MarkNativeAsOptional("TF2IDB_GetItemQualityName");
	MarkNativeAsOptional("TF2IDB_GetItemQuality");
	MarkNativeAsOptional("TF2IDB_GetItemLevels");
	MarkNativeAsOptional("TF2IDB_GetItemAttributes");
	MarkNativeAsOptional("TF2IDB_GetItemEquipRegions");
	MarkNativeAsOptional("TF2IDB_DoRegionsConflict");
	MarkNativeAsOptional("TF2IDB_ListParticles");
	MarkNativeAsOptional("TF2IDB_FindItemCustom");	
	MarkNativeAsOptional("TF2IDB_ItemHasAttribute");
}

#endif