## daily_schedule.gd
## Manages an NPC's predefined daily routine of activities.
## This component holds a schedule and provides methods for NPCAI to determine
## the current scheduled activity.
class_name DailySchedule extends RefCounted

## An array of ScheduleEntry.gd resources defining the daily routine.
## (ScheduleEntry.gd is a future resource to be defined).
var _schedule_entries: Array = []
## The current activity based on the schedule.
var _current_activity_id: String = ""
## The remaining time in game minutes for the current activity.
var _remaining_time: float = 0.0

## Initializes the DailySchedule.
func _init():
	pass

## Selects the next scheduled activity based on the current game time.
##
## Parameters:
## - current_game_hour: The current hour of the game day (0-23).
## Returns:
## - String: The ID of the goal associated with the current scheduled activity.
func get_scheduled_goal(current_game_hour: int) -> String:
	# Placeholder logic: a simple work/home schedule.
	# This will be replaced by iterating through _schedule_entries in the future.
	if current_game_hour >= 9 and current_game_hour < 17:
		return "Work" # Example goal
	else:
		return "RelaxAtHome" # Example goal
	
	return "" # Default if no activity is scheduled

## Allows the NPCAI to override the current schedule if a critical need arises.
## This function will be more complex in the future, determining if the current
## need's urgency outweighs the importance of the scheduled activity.
##
## Parameters:
## - critical_need_goal_id: The ID of the goal to address a critical need.
## Returns:
## - bool: True if the schedule can be overridden, false otherwise.
func can_override_for_critical_need(critical_need_goal_id: String) -> bool:
	# For now, always allow overriding for critical needs.
	# Future logic could prevent overriding "Must Attend" events.
	return true
