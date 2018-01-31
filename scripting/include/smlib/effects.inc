#if defined _smlib_effects_included
	#endinput
#endif
#define _smlib_effects_included

#include <sourcemod>
#include <sdktools_entinput>
#include <sdktools_tempents>
#include <sdktools_tempents_stocks>
#include <smlib/clients>
#include <smlib/effects>
#include <smlib/entities>
#include <smlib/math>

// Entity Dissolve types
enum DissolveType
{
	DISSOLVE_NORMAL = 0,
	DISSOLVE_ELECTRICAL,
	DISSOLVE_ELECTRICAL_LIGHT,
	DISSOLVE_CORE
};

/**
 * Dissolves a player
 *
 * @param client		Client Index.
 * @param dissolveType	Dissolve Type, use the DissolveType enum.
 * @return				True on success, otherwise false.
 */
stock bool Effect_DissolveEntity(int entity, DissolveType dissolveType=DISSOLVE_NORMAL)
{
	int env_entity_dissolver = CreateEntityByName("env_entity_dissolver");

	if (env_entity_dissolver == -1) {
		return false;
	}

	Entity_PointAtTarget(env_entity_dissolver, entity);
	SetEntProp(env_entity_dissolver, Prop_Send, "m_nDissolveType", _:dissolveType);
	AcceptEntityInput(env_entity_dissolver,	"Dissolve");
	Entity_Kill(env_entity_dissolver);

	return true;
}

/**
 * Dissolves a player's Ragdoll
 *
 * @param client		Client Index.
 * @param dissolveType	Dissolve Type, use the DissolveType enum.
 * @return				True on success, otherwise false.
 */
stock bool Effect_DissolvePlayerRagDoll(int client, DissolveType dissolveType=DISSOLVE_NORMAL)
{
	int m_hRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");

	if (m_hRagdoll == -1) {
		return false;
	}
	
	return Effect_DissolveEntity(m_hRagdoll, dissolveType);
}

typedef EffectCallback = function void(int entity, any data);

/**
 * Fades an entity in our out.
 * You can specifiy a callback function which will get called
 * when the fade is finished.
 * Important: The callback will be called if it is passed,
 * no matter if the entity is still valid or not. That means you
 * have to check if the entity is valid yourself.
 *
 * @param entity		Entity Index.
 * @param fadeOut		Optional: Fade the entity out (true) or in (false).
 * @param kill			Optional: If to kill the entity when the fade is finished.
 * @param fast			Optional: Fade the entity fast (~0.7 secs) or slow (~3 secs)
 * @param callback		Optional: You can specify a callback Function that will get called when the fade is finished.
 * @param data			Optional: You can pass any data to the callback.
 * @noreturn
 */
stock void Effect_Fade(int entity, bool fadeOut=true, bool kill=false, bool fast=true, EffectCallback callback=INVALID_FUNCTION, any data=0)
{
	float timerTime = 0.0;
	
	if (fast) {
		timerTime = 0.6;

		if (fadeOut) {
			SetEntityRenderFx(entity, RENDERFX_FADE_FAST);
		}
		else {
			SetEntityRenderFx(entity, RENDERFX_SOLID_FAST);
		}
	}
	else {
		timerTime = 3.0;

		if (fadeOut) {
			SetEntityRenderFx(entity, RENDERFX_FADE_SLOW);
		}
		else {
			SetEntityRenderFx(entity, RENDERFX_SOLID_SLOW);
		}
	}

	ChangeEdictState(entity, GetEntSendPropOffs(entity, "m_nRenderFX", true));

	if (kill || callback != INVALID_FUNCTION) {
		DataPack dataPack;
		CreateDataTimer(timerTime, _smlib_Timer_Effect_Fade, dataPack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
		
		dataPack.WriteCell(EntIndexToEntRef(entity));
		dataPack.WriteCell(kill);
		dataPack.WriteFunction(callback);
		dataPack.WriteCell(data);
		dataPack.Reset();
	}
}

/**
 * Fades the entity in.
 *  A wrapper function around Effect_Fade().
 *
 * @param entity		Entity Index.
 * @param fast			Optional: Fade the entity fast (~0.7 secs) or slow (~3 secs)
 * @param callback		Optional: You can specify a callback Function that will get called when the fade is finished.
 * @param data			Optional: You can pass any data to the callback.
 * @noreturn
 */
stock void Effect_FadeIn(int entity, bool fast=true, EffectCallback callback=INVALID_FUNCTION, any data=0)
{
	Effect_Fade(entity, false, false, fast, callback, data);
}
	
/**
 * Fades the entity out.
 * A wrapper function around Effect_Fade().
 *
 * @param entity		Entity Index.
 * @param fadeOut		Optional: Fade the entity out (true) or in (false).
 * @param kill			Optional: If to kill the entity when the fade is finished.
 * @param fast			Optional: Fade the entity fast (~0.7 secs) or slow (~3 secs)
 * @param callback		Optional: You can specify a callback Function that will get called when the fade is finished.
 * @param data			Optional: You can pass any data to the callback.
 * @noreturn
 */
stock void Effect_FadeOut(int entity, bool kill=false, bool fast=true, EffectCallback callback=INVALID_FUNCTION, any data=0)
{
	Effect_Fade(entity, true, kill, fast, callback, data);
}

public Action _smlib_Timer_Effect_Fade(Handle timer, DataPack dataPack)
{
	dataPack.Reset();
	int entity = dataPack.ReadCell();
	int kill = dataPack.ReadCell();
	EffectCallback callback = view_as<EffectCallback>(dataPack.ReadFunction());
	any data = view_as<any>(dataPack.ReadCell());
	
	if (callback != INVALID_FUNCTION) {
		Call_StartFunction(INVALID_HANDLE, callback);
		Call_PushCell(entity);
		Call_PushCell(data);
		Call_Finish();
	}

	if (kill && IsValidEntity(entity)) {
		Entity_Kill(entity);
	}

	return Plugin_Stop;
}

/**
 * Sends a boxed beam effect to one player.
 * 
 * Ported from eventscripts vecmath library.
 *
 * @param client        The client to show the box to.
 * @param bottomCorner	One bottom corner of the box.
 * @param upperCorner	One upper corner of the box.
 * @param modelIndex	Precached model index.
 * @param haloIndex		Precached model index.
 * @param startFrame	Initital frame to render.
 * @param frameRate		Beam frame rate.
 * @param life			Time duration of the beam.
 * @param width			Initial beam width.
 * @param endWidth		Final beam width.
 * @param fadeLength	Beam fade time duration.
 * @param amplitude		Beam amplitude.
 * @param color			Color array (r, g, b, a).
 * @param speed			Speed of the beam.
 * @noreturn
 */
stock void Effect_DrawBeamBoxToClient(
	int client,
	const float bottomCorner[3],
	const float upperCorner[3],
	int modelIndex,
	int haloIndex,
	int startFrame=0,
	int frameRate=30,
	float life=5.0,
	float width=5.0,
	float endWidth=5.0,
	int fadeLength=2,
	float amplitude=1.0,
	const int color[4]={ 255, 0, 0, 255 },
	int speed=0
) {
    int clients[1];
    clients[0] = client;
    Effect_DrawBeamBox(clients, 1, bottomCorner, upperCorner, modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
}

/**
 * Sends a boxed beam effect to all players.
 * 
 * Ported from eventscripts vecmath library.
 *
 * @param bottomCorner	One bottom corner of the box.
 * @param upperCorner	One upper corner of the box.
 * @param modelIndex	Precached model index.
 * @param haloIndex		Precached model index.
 * @param startFrame	Initital frame to render.
 * @param frameRate		Beam frame rate.
 * @param life			Time duration of the beam.
 * @param width			Initial beam width.
 * @param endWidth		Final beam width.
 * @param fadeLength	Beam fade time duration.
 * @param amplitude		Beam amplitude.
 * @param color			Color array (r, g, b, a).
 * @param speed			Speed of the beam.
 * @noreturn
 */
stock void Effect_DrawBeamBoxToAll(
	const float bottomCorner[3],
	const float upperCorner[3],
	int modelIndex,
	int haloIndex,
	int startFrame=0,
	int frameRate=30,
	float life=5.0,
	float width=5.0,
	float endWidth=5.0,
	int fadeLength=2,
	float amplitude=1.0,
	const int color[4]={ 255, 0, 0, 255 },
	int speed=0
)
{
	int clients[MaxClients];
	int numClients = Client_Get(clients, CLIENTFILTER_INGAME);

	Effect_DrawBeamBox(clients, numClients, bottomCorner, upperCorner, modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
}

/**
 * Sends a boxed beam effect to a list of players.
 * 
 * Ported from eventscripts vecmath library.
 *
 * @param clients        An array of clients to show the box to.
 * @param numClients    Number of players in the array.
 * @param bottomCorner	One bottom corner of the box.
 * @param upperCorner	One upper corner of the box.
 * @param modelIndex	Precached model index.
 * @param haloIndex		Precached model index.
 * @param startFrame	Initital frame to render.
 * @param frameRate		Beam frame rate.
 * @param life			Time duration of the beam.
 * @param width			Initial beam width.
 * @param endWidth		Final beam width.
 * @param fadeLength	Beam fade time duration.
 * @param amplitude		Beam amplitude.
 * @param color			Color array (r, g, b, a).
 * @param speed			Speed of the beam.
 * @noreturn
 */
stock void Effect_DrawBeamBox(
	int[] clients,
	int numClients,
	const float bottomCorner[3],
	const float upperCorner[3],
	int modelIndex,
	int haloIndex,
	int startFrame=0,
	int frameRate=30,
	float life=5.0,
	float width=5.0,
	float endWidth=5.0,
	int fadeLength=2,
	float amplitude=1.0,
	const int color[4]={ 255, 0, 0, 255 },
	int speed=0
) {
	// Create the additional corners of the box
	float corners[8][3];

	for (int i=0; i < 4; i++) {
		Array_Copy(bottomCorner,	corners[i],		3);
		Array_Copy(upperCorner,		corners[i+4],	3);
	}

	corners[1][0] = upperCorner[0];
	corners[2][0] = upperCorner[0]; corners[2][1] = upperCorner[1];
	corners[3][1] = upperCorner[1];
	corners[4][0] = bottomCorner[0]; corners[4][1] = bottomCorner[1];
	corners[5][1] = bottomCorner[1];
	corners[7][0] = bottomCorner[0];

    // Draw all the edges

	// Horizontal Lines
	// Bottom
	for (int i=0; i < 4; i++) {
		int j = ( i == 3 ? 0 : i+1 );
		TE_SetupBeamPoints(corners[i], corners[j], modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
		TE_Send(clients, numClients);
	}

	// Top
	for (int i=4; i < 8; i++) {
		int j = ( i == 7 ? 4 : i+1 );
		TE_SetupBeamPoints(corners[i], corners[j], modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
		TE_Send(clients, numClients);
	}

	// All Vertical Lines
	for (int i=0; i < 4; i++) {
		TE_SetupBeamPoints(corners[i], corners[i+4], modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
		TE_Send(clients, numClients);
	}
}
