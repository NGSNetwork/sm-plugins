#if defined _betherobot_included_
  #endinput
#endif
#define _betherobot_included_

enum RobotStatus {
	RobotStatus_Human = 0, // Client is human
	RobotStatus_WantsToBeRobot, // Client wants to be robot, but can't because of defined rules.
	RobotStatus_Robot // Client is a robot. Beep boop.
}

/**
 * Checks if a client is a robot.
 *
 * @param client			Index of the client to check.
 * @return					RobotStatus value of the client; RobotStatus_Human if they're a human, RobotStatus_Robot if they're a robot, RobotStatus_WantsToBeRobot if they want to be a robot, but can't for some reason.
 */
native RobotStatus:BeTheRobot_GetRobotStatus(client);

/**
 * Sets if a client should be robot or not.
 *
 * @param client			Index of the client to set.
 * @param toggle			True to make the client a robot, false to change them back to a human. Skip this argument to toggle instead.
 * @noreturn
 */
native BeTheRobot_SetRobot(client, bool:toggle = bool:2);

/**
 * Uses Be the Robot's "CheckTheRules()" native to check if a client should be allowed to be a robot or not.
 *
 * @param client			Index of the client to check.
 * @return					True if the client is allowed to be a robot (not dead, allowed class by server, etc.) false otherwise.
 */
native bool:BeTheRobot_CheckRules(client);

public SharedPlugin:__pl_betherobot = 
{
	name = "betherobot",
	file = "betherobot.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_betherobot_SetNTVOptional()
{
	MarkNativeAsOptional("BeTheRobot_GetRobotStatus");
	MarkNativeAsOptional("BeTheRobot_SetRobot");
	MarkNativeAsOptional("BeTheRobot_CheckRules");
}
#endif