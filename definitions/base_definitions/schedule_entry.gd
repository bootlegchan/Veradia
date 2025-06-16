## schedule_entry.gd
## A data resource that defines a single block of time in an NPC's daily schedule.
## It associates a time range with a specific GOAP goal.
class_name ScheduleEntry extends DefinitionBase

## The hour of the day (0-23) when this schedule entry begins.
@export var start_hour: int = 0
## The hour of the day (0-23) when this schedule entry ends.
@export var end_hour: int = 0
## The `id` of the GOAPGoalDefinition that the NPC should pursue during this time block.
@export var associated_goal_id: String = ""
## Optional: The key on the NPC's blackboard that holds the instance ID of the target location
## for this scheduled activity (e.g., "home_entity_id", "workplace_entity_id").
@export var location_id_key: String = ""
