#if defined _store_shop_included
  #endinput
#endif
#define _store_shop_included

//Forwards
forward Action Store_OnBuyItem(int client, int itemId);
forward void Store_OnBuyItem_Post(int client, int itemId, bool success);

/**
 * Opens the shop menu for a client.
 *
 * @param client			Client index.
 *
 * @noreturn
 */
native void Store_OpenShop(int client);

/**
 * Opens the shop menu for a client in a specific category.
 *
 * @param client			Client index.
 * @param categoryId		The category that you want to open.
 *
 * @noreturn
 */
native void Store_OpenShopCategory(int client, int categoryId);

public SharedPlugin __pl_store_shop =
{
    name = "store-shop",
    file = "store-shop.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if defined REQUIRE_PLUGIN
public void __pl_store_shop_SetNTVOptional()
{
	MarkNativeAsOptional("Store_OpenShop");  
	MarkNativeAsOptional("Store_OpenShopCategory");  	
}
#endif