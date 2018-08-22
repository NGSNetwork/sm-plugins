#if defined _nodecomm_included
  #endinput
#endif
#define _nodecomm_included

#include <json>

/**
 * Sends a request to a listening Node application to do processing.
 *
 * @param json			JSON to send in Post Body. Is essentially your data.
 */
native bool NodeComm_SendRequest(char[] json);

/**
 * Upon receiving a response, fires this.
 *
 * @param handler			The handler of the request.
 * @param response			The response as a JSON encoded string.
 * @return					True if the response was successful, false otherwise.
 */
forward Action NodeComm_ReceiveResponse(JSON_Object &response);

public SharedPlugin __pl_ngs_nodecomm =
{
	name = "ngs_nodecomm",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_nodecomm_SetNTVOptional()
{
	MarkNativeAsOptional("NodeComm_SendRequest");
}
#endif