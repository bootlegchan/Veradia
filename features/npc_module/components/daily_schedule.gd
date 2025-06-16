## daily_schedule.gd
## Manages an NPC's predefined daily routine of activities.
## This component holds a schedule and provides methods for NPCAI to determine
## the current scheduled activity.
class_name DailySchedule extends RefCounted

## An array of ScheduleEntry.gd resources defining the daily routine.
var _schedule_entries: Array[ScheduleEntry] = []

## Initializes the DailySchedule.
func _init():
	pass

## Initializes the schedule with a set of entries from an NPCEntityDefinition.
##
## Parameters:
## - schedule_entries: The array of ScheduleEntry resources defining the routine.
func initialize(schedule_entries: Array[ScheduleEntry]):
	_schedule_entries = schedule_entries
	# Sort entries by start hour to ensure correct lookup.
	_schedule_entries.sort_custom(func(a, b): return a.start_hour < b.start_hour)


## Selects the next scheduled activity based on the current game time.
## It iterates through the sorted schedule to find the entry for the current hour.
##
## Parameters:
## - current_game_hour: The current hour of the game day (0-23).
## Returns:
## - Dictionary: A dictionary containing the "goal_id" and "location_id_key"
##               from the current schedule entry, or an empty dictionary if no
##               activity is scheduled for the current hour.
func get_scheduled_activity(current_game_hour: int) -> Dictionary:
	for entry in _schedule_entries:
		# Check if the current hour falls within the entry's time block.
		# This handles overnight schedules correctly (e.g., start 22, end 6).
		if entry.start_hour <= entry.end_hour: # Standard day block
			if current_game_hour >= entry.start_hour and current_game_hour < entry.end_hour:
				return {
					"goal_id": entry.associated_goal_id,
					"location_id_key": entry.location_id_key
				}
		else: # Overnight block (e.g., 22:00 to 06:00)
			if current_game_hour >= entry.start_hour or current_game_hour < entry.end_hour:
				return {
					"goal_id": entry.associated_goal_id,
					"location_id_key": entry.location_id_key
				}
				
	return {} # No scheduled activity for this hour


## Allows the NPCAI to override the current schedule if a critical need arises.
## This function will be more complex in the future, determining if the current
## need's urgency outweighs the importance of the scheduled activity.
##
## Parameters:
## - _critical_need_goal_id: The ID of the goal to address a critical need.
## Returns:
## - bool: True if the schedule can be overridden, false otherwise.
func can_override_for_critical_need(_critical_need_goal_id: String) -> bool:
	# For now, always allow overriding for critical needs.
	# Future logic could prevent overriding "Must Attend" events.
	return true
