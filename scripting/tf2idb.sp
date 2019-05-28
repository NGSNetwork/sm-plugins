/**
* TheXeon
* tf2idb.sp
*
* Files:
* addons/sourcemod/plugins/tf2idb.smx
* addons/sourcemod/data/sqlite/tf2idb.sq3
*
* Dependencies:
* tf2.inc, tf2idb.inc, ngsutils.inc, ngsupdater.inc
*/
#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo = {
    name        = "[NGS] TF2IDB",
    author          = "Bottiger, FlaminSarge / TheXeon",
    description = "TF2 Item Schema Database",
    version         = "1.0.0",
    url             = "https://www.neogenesisnetwork.net"
};

#include <tf2>
#include <tf2idb>
#include <ngsutils>
#include <ngsupdater>

public APLRes AskPluginLoad2(Handle hPlugin, bool bLateLoad, char[] sError, int iErrorSize) {
    CreateNative("TF2IDB_IsValidItemID", Native_IsValidItemID);
    CreateNative("TF2IDB_GetItemName", Native_GetItemName);
    CreateNative("TF2IDB_GetItemClass", Native_GetItemClass);
    CreateNative("TF2IDB_GetItemSlotName", Native_GetItemSlotName);
    CreateNative("TF2IDB_GetItemSlot", Native_GetItemSlot);
    CreateNative("TF2IDB_GetItemQualityName", Native_GetItemQualityName);
    CreateNative("TF2IDB_GetItemQuality", Native_GetItemQuality);
    CreateNative("TF2IDB_GetItemLevels", Native_GetItemLevels);
    CreateNative("TF2IDB_GetItemAttributes", Native_GetItemAttributes);
    CreateNative("TF2IDB_GetItemEquipRegions", Native_GetItemEquipRegions);
    CreateNative("TF2IDB_DoRegionsConflict", Native_DoRegionsConflict);
    CreateNative("TF2IDB_ListParticles", Native_ListParticles);
    CreateNative("TF2IDB_FindItemCustom", Native_FindItemCustom);
    CreateNative("TF2IDB_ItemHasAttribute", Native_ItemHasAttribute);
    CreateNative("TF2IDB_UsedByClasses", Native_UsedByClasses);

    CreateNative("TF2IDB_CustomQuery", Native_CustomQuery);

    CreateNative("TF2IDB_IsValidAttributeID", Native_IsValidAttributeID);
    CreateNative("TF2IDB_GetAttributeName", Native_GetAttributeName);
    CreateNative("TF2IDB_GetAttributeClass", Native_GetAttributeClass);
    CreateNative("TF2IDB_GetAttributeType", Native_GetAttributeType);
    CreateNative("TF2IDB_GetAttributeDescString", Native_GetAttributeDescString);
    CreateNative("TF2IDB_GetAttributeDescFormat", Native_GetAttributeDescFormat);
    CreateNative("TF2IDB_GetAttributeEffectType", Native_GetAttributeEffectType);
    CreateNative("TF2IDB_GetAttributeArmoryDesc", Native_GetAttributeArmoryDesc);
    CreateNative("TF2IDB_GetAttributeItemTag", Native_GetAttributeItemTag);
    CreateNative("TF2IDB_GetAttributeProperties", Native_GetAttributeProperties);

    CreateNative("TF2IDB_GetQualityName", Native_GetQualityName);
    CreateNative("TF2IDB_GetQualityByName", Native_GetQualityByName);

    RegPluginLibrary("tf2idb");
    return APLRes_Success;
}

Database g_db;

//DBStatement g_statement_IsValidItemID;
DBStatement g_statement_GetItemClass;
DBStatement g_statement_GetItemName;
DBStatement g_statement_GetItemSlotName;
DBStatement g_statement_GetItemQualityName;
DBStatement g_statement_GetItemLevels;
DBStatement g_statement_GetItemAttributes;
DBStatement g_statement_GetItemEquipRegions;
DBStatement g_statement_ListParticles;
DBStatement g_statement_DoRegionsConflict;
DBStatement g_statement_ItemHasAttribute;
DBStatement g_statement_GetItemSlotNameByClass;
DBStatement g_statement_UsedByClasses;

//DBStatement g_statement_IsValidAttributeID;
DBStatement g_statement_GetAttributeName;
DBStatement g_statement_GetAttributeClass;
DBStatement g_statement_GetAttributeType;
DBStatement g_statement_GetAttributeDescString;
DBStatement g_statement_GetAttributeDescFormat;
DBStatement g_statement_GetAttributeEffectType;
DBStatement g_statement_GetAttributeArmoryDesc;
DBStatement g_statement_GetAttributeItemTag;

StringMap g_slot_mappings;
ArrayList g_quality_mappings;

StringMap g_id_cache;
StringMap g_class_cache;
StringMap g_slot_cache;
StringMap g_minlevel_cache;
StringMap g_maxlevel_cache;

#define NUM_ATT_CACHE_FIELDS 5
StringMap g_attribute_cache;

char g_class_mappings[][] = {
    "unknown", "scout", "sniper", "soldier", "demoman", "medic", "heavy", "pyro", "spy", "engineer"
};

public void OnPluginStart() {
    char error[255];
    g_db = SQLite_UseDatabase("tf2idb", error, sizeof(error));
    if(g_db == null)
        SetFailState(error);

    #define PREPARE_STATEMENT(%1,%2) %1 = SQL_PrepareQuery(g_db, %2, error, sizeof(error)); if(%1 == null) SetFailState(error);

//    PREPARE_STATEMENT(g_statement_IsValidItemID, "SELECT id FROM tf2idb_item WHERE id=?")
    PREPARE_STATEMENT(g_statement_GetItemClass, "SELECT class FROM tf2idb_item WHERE id=?")
    PREPARE_STATEMENT(g_statement_GetItemName, "SELECT name FROM tf2idb_item WHERE id=?")
    PREPARE_STATEMENT(g_statement_GetItemSlotName, "SELECT slot FROM tf2idb_item WHERE id=?")
    PREPARE_STATEMENT(g_statement_GetItemQualityName, "SELECT quality FROM tf2idb_item WHERE id=?")
    PREPARE_STATEMENT(g_statement_GetItemLevels, "SELECT min_ilevel,max_ilevel FROM tf2idb_item WHERE id=?")
    PREPARE_STATEMENT(g_statement_GetItemAttributes, "SELECT attribute,value FROM tf2idb_item_attributes WHERE id=?")
    PREPARE_STATEMENT(g_statement_GetItemEquipRegions, "SELECT region FROM tf2idb_equip_regions WHERE id=?")
    PREPARE_STATEMENT(g_statement_ListParticles, "SELECT id FROM tf2idb_particles")
    PREPARE_STATEMENT(g_statement_DoRegionsConflict, "SELECT a.name FROM tf2idb_equip_conflicts a JOIN tf2idb_equip_conflicts b ON a.name=b.name WHERE a.region=? AND b.region=?")
    PREPARE_STATEMENT(g_statement_ItemHasAttribute, "SELECT attribute FROM tf2idb_item a JOIN tf2idb_item_attributes b ON a.id=b.id WHERE a.id=? AND attribute=?")
    PREPARE_STATEMENT(g_statement_GetItemSlotNameByClass, "SELECT slot FROM tf2idb_class WHERE id=? AND class=?")
    PREPARE_STATEMENT(g_statement_UsedByClasses, "SELECT class FROM tf2idb_class WHERE id=?")

//    PREPARE_STATEMENT(g_statement_IsValidAttributeID, "SELECT id FROM tf2idb_attributes WHERE id=?")
    PREPARE_STATEMENT(g_statement_GetAttributeName, "SELECT name FROM tf2idb_attributes WHERE id=?")
    PREPARE_STATEMENT(g_statement_GetAttributeClass, "SELECT attribute_class FROM tf2idb_attributes WHERE id=?")
    PREPARE_STATEMENT(g_statement_GetAttributeType, "SELECT attribute_type FROM tf2idb_attributes WHERE id=?")
    PREPARE_STATEMENT(g_statement_GetAttributeDescString, "SELECT description_string FROM tf2idb_attributes WHERE id=?")
    PREPARE_STATEMENT(g_statement_GetAttributeDescFormat, "SELECT description_format FROM tf2idb_attributes WHERE id=?")
    PREPARE_STATEMENT(g_statement_GetAttributeEffectType, "SELECT effect_type FROM tf2idb_attributes WHERE id=?")
    PREPARE_STATEMENT(g_statement_GetAttributeArmoryDesc, "SELECT armory_desc FROM tf2idb_attributes WHERE id=?")
    PREPARE_STATEMENT(g_statement_GetAttributeItemTag, "SELECT apply_tag_to_item_definition FROM tf2idb_attributes WHERE id=?")

    g_slot_mappings = new StringMap();
    g_slot_mappings.SetValue("primary", TF2ItemSlot_Primary);
    g_slot_mappings.SetValue("secondary", TF2ItemSlot_Secondary);
    g_slot_mappings.SetValue("melee", TF2ItemSlot_Melee);
    g_slot_mappings.SetValue("pda", TF2ItemSlot_PDA1);
    g_slot_mappings.SetValue("pda2", TF2ItemSlot_PDA2);
    g_slot_mappings.SetValue("building", TF2ItemSlot_Building);
    g_slot_mappings.SetValue("head", TF2ItemSlot_Head);
    g_slot_mappings.SetValue("misc", TF2ItemSlot_Misc);
    g_slot_mappings.SetValue("taunt", TF2ItemSlot_Taunt);
    g_slot_mappings.SetValue("action", TF2ItemSlot_Action);

    g_id_cache = new StringMap();
    g_class_cache = new StringMap();
    g_slot_cache = new StringMap();
    g_minlevel_cache = new StringMap();
    g_maxlevel_cache = new StringMap();

    g_attribute_cache = new StringMap();

    //g_quality_mappings is initialized inside PrepareCache
    PrepareCache();
}

void PrepareCache() {
    g_db.Query(OnPrepareItemCache, "SELECT id,class,slot,min_ilevel,max_ilevel FROM tf2idb_item");
    g_db.Query(OnPrepareAttribCache, "SELECT id,hidden,stored_as_integer,is_set_bonus,is_user_generated,can_affect_recipe_component_name FROM tf2idb_attributes");
    g_db.Query(OnPrepareQualitySize, "SELECT MAX(value) FROM tf2idb_qualities");
}

void OnPrepareItemCache(Database db, DBResultSet results, const char[] error, any data) {
    while(results.FetchRow()) {
        char slot[TF2IDB_ITEMSLOT_LENGTH], class[TF2IDB_ITEMCLASS_LENGTH], id[16];
        results.FetchString(0, id, sizeof(id));
        results.FetchString(1, class, sizeof(class));
        results.FetchString(2, slot, sizeof(slot));
        int min_level = SQL_FetchInt(results, 3);
        int max_level = SQL_FetchInt(results, 4);

        g_id_cache.SetValue(id, 1);
        g_class_cache.SetString(id, class);
        g_slot_cache.SetString(id, slot);
        g_minlevel_cache.SetValue(id, min_level);
        g_maxlevel_cache.SetValue(id, max_level);
    }
    delete results;
}

void OnPrepareAttribCache(Database db, DBResultSet results, const char[] error, any data) {
    while(results.FetchRow()) {
        char id[16];
        int values[NUM_ATT_CACHE_FIELDS] = { -1, ... };
        results.FetchString(0, id, sizeof(id));
        for (int i = 0; i < NUM_ATT_CACHE_FIELDS; i++) {
            if(!results.IsFieldNull(i)) {
                values[i] = results.FetchInt(i + 1);
            }
        }
        g_attribute_cache.SetArray(id, values, NUM_ATT_CACHE_FIELDS);
    }
    delete results;
}

void OnPrepareQualitySize(Database db, DBResultSet results, const char[] error, any data) {
    if (results != null && results.FetchRow()) {
        int size = results.FetchInt(0);
        delete results;
        g_quality_mappings = new ArrayList(ByteCountToCells(TF2IDB_ITEMQUALITY_LENGTH), size + 1);
        g_db.Query(OnPrepareQualityCache, "SELECT name,value FROM tf2idb_qualities");
    } else {
        delete results;
        //backup strats
        g_quality_mappings = new ArrayList(ByteCountToCells(TF2IDB_ITEMQUALITY_LENGTH), view_as<int>(TF2ItemQuality));    //size of the quality enum
        g_quality_mappings.SetString(view_as<int>(TF2ItemQuality_Normal), "normal");
        g_quality_mappings.SetString(view_as<int>(TF2ItemQuality_Rarity4), "rarity4");
        g_quality_mappings.SetString(view_as<int>(TF2ItemQuality_Strange), "strange");
        g_quality_mappings.SetString(view_as<int>(TF2ItemQuality_Unique), "unique");
    }
}

void OnPrepareQualityCache(Database db, DBResultSet results, const char[] error, any data) {
    while(results.FetchRow()) {
        char name[TF2IDB_ITEMQUALITY_LENGTH];
        results.FetchString(0, name, sizeof(name));
        int value = results.FetchInt(1);
        g_quality_mappings.SetString(value, name);
    }
    delete results;
}

stock void PrintItem(int id) {
    bool valid = TF2IDB_IsValidItemID(id);
    if(!valid) {
        PrintToServer("Invalid Item %i", id);
        return;
    }

    char name[64];
    TF2IDB_GetItemName(43, name, sizeof(name));

    PrintToServer("%i - %s", id, name);
    PrintToServer("slot %i - quality %i", TF2IDB_GetItemSlot(id), TF2IDB_GetItemQuality(id));

    int min,max;
    TF2IDB_GetItemLevels(id, min, max);
    PrintToServer("Level %i - %i", min, max);
}

public int Native_IsValidItemID(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    char strId[16];
    IntToString(id, strId, sizeof(strId));
    int junk;
    return g_id_cache.GetValue(strId, junk);
}

public int Native_GetItemClass(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    int size = GetNativeCell(3);

    char strId[16];
    IntToString(id, strId, sizeof(strId));
    char[] class = new char[size];

    if(g_class_cache.GetString(strId, class, size)) {
        SetNativeString(2, class, size);
        return true;
    }
    return false;
}

public int Native_GetItemName(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    int size = GetNativeCell(3);
    g_statement_GetItemName.BindInt(0, id);
    SQL_Execute(g_statement_GetItemName);
    if(SQL_FetchRow(g_statement_GetItemName)) {
        char[] buffer = new char[size];
        SQL_FetchString(g_statement_GetItemName, 0, buffer, size);
        SetNativeString(2, buffer, size);
        return true;
    } else {
        return false;
    }
}

public int Native_GetItemSlotName(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    int size = GetNativeCell(3);
    TFClassType classType = (nParams >= 4) ? GetNativeCell(4) : TFClass_Unknown;

    char[] slot = new char[size];

    if(classType != TFClass_Unknown) {
        g_statement_GetItemSlotNameByClass.BindInt(0, id);
        g_statement_GetItemSlotNameByClass.BindString(1, g_class_mappings[classType], false);

        SQL_Execute(g_statement_GetItemSlotNameByClass);

        while(SQL_FetchRow(g_statement_GetItemSlotNameByClass)) {
            if(!SQL_IsFieldNull(g_statement_GetItemSlotNameByClass, 0)) {
                SQL_FetchString(g_statement_GetItemSlotNameByClass, 0, slot, size);
                SetNativeString(2, slot, size);
                return true;
            }
        }
    }

    char strId[16];
    IntToString(id, strId, sizeof(strId));

    if(g_slot_cache.GetString(strId, slot, size)) {
        SetNativeString(2, slot, size);
        return true;
    }
    return false;
}

public int Native_GetItemSlot(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    char slotString[16];
    TFClassType classType = (nParams >= 2) ? GetNativeCell(2) : TFClass_Unknown;

    if(TF2IDB_GetItemSlotName(id, slotString, sizeof(slotString), classType)) {
        TF2ItemSlot slot;
        if(g_slot_mappings.GetValue(slotString, slot)) {
            return view_as<int>(slot);
        }
    }
    return -1;
}

public int Native_GetItemQualityName(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    int size = GetNativeCell(3);
    g_statement_GetItemQualityName.BindInt(0, id);
    SQL_Execute(g_statement_GetItemQualityName);
    if(SQL_FetchRow(g_statement_GetItemQualityName)) {
        char[] buffer = new char[size];
        SQL_FetchString(g_statement_GetItemQualityName, 0, buffer, size);
        SetNativeString(2, buffer, size);
        return true;
    } else {
        return false;
    }
}

public int Native_GetItemQuality(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    char qualityString[16];
    TF2ItemQuality quality = TF2ItemQuality_Normal;
    if(TF2IDB_GetItemSlotName(id, qualityString, sizeof(qualityString))) {
        quality = GetQualityByName(qualityString);
    }
    return view_as<int>(quality > TF2ItemQuality_Normal ? quality : TF2ItemQuality_Normal);
}

public int Native_GetItemLevels(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    char strId[16];
    IntToString(id, strId, sizeof(strId));
    int min,max;
    bool exists = g_minlevel_cache.GetValue(strId, min);
    g_maxlevel_cache.GetValue(strId, max);
    if(exists) {
        SetNativeCellRef(2, min);
        SetNativeCellRef(3, max);
    }
    return exists;
}

public int Native_GetItemAttributes(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    int aids[TF2IDB_MAX_ATTRIBUTES];
    float values[TF2IDB_MAX_ATTRIBUTES];
    g_statement_GetItemAttributes.BindInt(0, id);
    SQL_Execute(g_statement_GetItemAttributes);

    int index;
    while(SQL_FetchRow(g_statement_GetItemAttributes)) {
        int aid = SQL_FetchInt(g_statement_GetItemAttributes, 0);
        float value = SQL_FetchFloat(g_statement_GetItemAttributes, 1);
        aids[index] = aid;
        values[index] = value;
        index++;
    }

    if(index) {
        SetNativeArray(2, aids, index);
        SetNativeArray(3, values, index);
    }

    return index;
}

public int Native_GetItemEquipRegions(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    g_statement_GetItemEquipRegions.BindInt(0, id);
    ArrayList list = new ArrayList(ByteCountToCells(16));
    SQL_Execute(g_statement_GetItemEquipRegions);
    while(SQL_FetchRow(g_statement_GetItemEquipRegions)) {
        char buffer[16];
        SQL_FetchString(g_statement_GetItemEquipRegions, 0, buffer, sizeof(buffer));
        list.PushString(buffer);
    }
    Handle output = CloneHandle(list, hPlugin);
    delete list;
    return view_as<int>(output);
}

public int Native_ListParticles(Handle hPlugin, int nParams) {
    ArrayList list = new ArrayList();
    SQL_Execute(g_statement_ListParticles);
    while(SQL_FetchRow(g_statement_ListParticles)) {
        int effect = SQL_FetchInt(g_statement_ListParticles, 0);
        if(effect > 5 && effect < 2000 && effect != 20 && effect != 28)
            list.Push(effect);
    }
    Handle output = CloneHandle(list, hPlugin);
    delete list;
    return view_as<int>(output);
}

public int Native_DoRegionsConflict(Handle hPlugin, int nParams) {
    char region1[16];
    char region2[16];
    GetNativeString(1, region1, sizeof(region1));
    GetNativeString(2, region2, sizeof(region2));
    g_statement_DoRegionsConflict.BindString(0, region1, false);
    g_statement_DoRegionsConflict.BindString(1, region2, false);
    SQL_Execute(g_statement_DoRegionsConflict);
    return SQL_GetRowCount(g_statement_DoRegionsConflict) > 0;
}

public int Native_FindItemCustom(Handle hPlugin, int nParams) {
    int length;
    GetNativeStringLength(1, length);
    char[] query = new char[length+1];
    GetNativeString(1, query, length+1);

    DBResultSet queryHandle = SQL_Query(g_db, query);
    if(queryHandle == null)
        return 0;
    ArrayList list = new ArrayList();
    while(queryHandle.FetchRow()) {
        int id = queryHandle.FetchInt(0);
        list.Push(id);
    }
    delete queryHandle;
    Handle output = CloneHandle(list, hPlugin);
    delete list;
    return view_as<int>(output);
}

public int Native_CustomQuery(Handle hPlugin, int nParams) {
    int length;
    GetNativeStringLength(1, length);
    char[] query = new char[length+1];
    GetNativeString(1, query, length+1);
    char error[256];
    DBStatement queryHandle = SQL_PrepareQuery(g_db, query, error, sizeof(error));
    ArrayList arguments = view_as<ArrayList>(GetNativeCell(2));
    if (arguments != null) {
        int argSize = arguments.Length;
        int maxlen = GetNativeCell(3);
        char[] buf = new char[maxlen];
        for(int i = 0; i < argSize; i++) {
            arguments.GetString(i, buf, maxlen);
            queryHandle.BindString(i, buf, true);
        }
    }
    
    if(!SQL_Execute(queryHandle)) {
        delete queryHandle;
    }
    return view_as<int>(queryHandle);
}

public int Native_ItemHasAttribute(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    int aid = GetNativeCell(2);

    g_statement_ItemHasAttribute.BindInt(0, id);
    g_statement_ItemHasAttribute.BindInt(1, aid);
    SQL_Execute(g_statement_ItemHasAttribute);

    if(SQL_FetchRow(g_statement_ItemHasAttribute)) {
        return SQL_GetRowCount(g_statement_ItemHasAttribute) > 0;
    }
    return false;
}

public int Native_UsedByClasses(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    char class[16];
    int result = 0;
    
    g_statement_UsedByClasses.BindInt(0, id);
    SQL_Execute(g_statement_UsedByClasses);
    
    while (SQL_FetchRow(g_statement_UsedByClasses)) {
        if (SQL_FetchString(g_statement_UsedByClasses, 0, class, sizeof(class)) > 0) {
            result |= (1 << view_as<int>(TF2_GetClass(class)));
        }
    }
    return result;
}

public int Native_IsValidAttributeID(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    char strId[16];
    IntToString(id, strId, sizeof(strId));
    int junk[NUM_ATT_CACHE_FIELDS];
    return g_attribute_cache.GetArray(strId, junk, NUM_ATT_CACHE_FIELDS);
}

stock bool GetStatementStringForID(DBStatement statement, int id, char[] buf, int size) {
    statement.BindInt(0, id);
    SQL_Execute(statement);
    if(SQL_FetchRow(statement)) {
        SQL_FetchString(statement, 0, buf, size);
        return true;
    }
    return false;
}

public int Native_GetAttributeName(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    int size = GetNativeCell(3);
    char[] buf = new char[size+1];
    if(GetStatementStringForID(g_statement_GetAttributeName, id, buf, size)) {
        SetNativeString(2, buf, size);
        return true;
    }
    return false;
}
public int Native_GetAttributeClass(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    int size = GetNativeCell(3);
    char[] buf = new char[size+1];
    if(GetStatementStringForID(g_statement_GetAttributeClass, id, buf, size)) {
        SetNativeString(2, buf, size);
        return true;
    }
    return false;
}
public int Native_GetAttributeType(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    int size = GetNativeCell(3);
    char[] buf = new char[size+1];
    if(GetStatementStringForID(g_statement_GetAttributeType, id, buf, size)) {
        SetNativeString(2, buf, size);
        return true;
    }
    return false;
}
public int Native_GetAttributeDescString(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    int size = GetNativeCell(3);
    char[] buf = new char[size+1];
    if(GetStatementStringForID(g_statement_GetAttributeDescString, id, buf, size)) {
        SetNativeString(2, buf, size);
        return true;
    }
    return false;
}
public int Native_GetAttributeDescFormat(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    int size = GetNativeCell(3);
    char[] buf = new char[size+1];
    if(GetStatementStringForID(g_statement_GetAttributeDescFormat, id, buf, size)) {
        SetNativeString(2, buf, size);
        return true;
    }
    return false;
}
public int Native_GetAttributeEffectType(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    int size = GetNativeCell(3);
    char[] buf = new char[size+1];
    if(GetStatementStringForID(g_statement_GetAttributeEffectType, id, buf, size)) {
        SetNativeString(2, buf, size);
        return true;
    }
    return false;
}
public int Native_GetAttributeArmoryDesc(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    int size = GetNativeCell(3);
    char[] buf = new char[size+1];
    if(GetStatementStringForID(g_statement_GetAttributeArmoryDesc, id, buf, size)) {
        SetNativeString(2, buf, size);
        return true;
    }
    return false;
}
public int Native_GetAttributeItemTag(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    int size = GetNativeCell(3);
    char[] buf = new char[size+1];
    if(GetStatementStringForID(g_statement_GetAttributeItemTag, id, buf, size)) {
        SetNativeString(2, buf, size);
        return true;
    }
    return false;
}
public int Native_GetAttributeProperties(Handle hPlugin, int nParams) {
    int id = GetNativeCell(1);
    char strId[16];
    IntToString(id, strId, sizeof(strId));
    int values[NUM_ATT_CACHE_FIELDS];
    if(g_attribute_cache.GetArray(strId, values, NUM_ATT_CACHE_FIELDS)) {
        for(int i = 0; i < NUM_ATT_CACHE_FIELDS; i++) {
            SetNativeCellRef(i+2, values[i]);
        }
        return true;
    }
    return false;
}

stock TF2ItemQuality GetQualityByName(char[] strSearch) {
    if(strSearch[0] == '\0') {
        return view_as<TF2ItemQuality>(-1);
    }
    return view_as<TF2ItemQuality>(g_quality_mappings.FindString(strSearch));
}
public int Native_GetQualityByName(Handle hPlugin, int nParams) {
    char strQualityName[TF2IDB_ITEMQUALITY_LENGTH+1];
    GetNativeString(1, strQualityName, TF2IDB_ITEMQUALITY_LENGTH);
    return view_as<int>(GetQualityByName(strQualityName));
}
public int Native_GetQualityName(Handle hPlugin, int nParams) {
    int quality = GetNativeCell(1);
    int length = GetNativeCell(3);
    char[] strQualityName = new char[length+1];
    if(g_quality_mappings.GetString(quality, strQualityName, length) <= 0) {
        return false;
    }
    SetNativeString(2, strQualityName, length);
    return true;
}
