# GOAPGoalDefinition.gd

# Represents a single, high-level goal that an NPC can pursue.
# In Goal-Oriented Action Planning (GOAP), a goal defines the desired state
# of the world. The GOAP planner's job is to find a sequence of actions to
# achieve this state. This resource encapsulates the conditions that define the
# goal and its intrinsic importance to the NPC.
class_name GOAPGoalDefinition
extends Resource

# --- Goal Properties ---

# The unique identifier for this goal definition (e.g., "EatFood", "FindShelter").
@export var goal_id: String = ""

# The conditions that must be true for this goal to be considered satisfied.
# This is a dictionary representing the desired world state. The GOAP planner
# will work to create a plan that makes the active world state match these
# conditions.
# Example: {"has_eaten": true}
@export var preconditions: Dictionary = {}

# The base importance of this goal. The Utility AI system will use this value,
# combined with dynamic factors (like needs, mood, personality), to decide which
# goal is the most urgent to pursue at any given moment.
@export var base_importance: float = 0.0

# If the goal is directly tied to satisfying a specific need, this specifies the
# need's ID (e.g., "HUNGER"). This allows the Utility AI to directly link the
# urgency of a need to the importance of this goal.
@export var linked_granular_need_type: String = ""

# --- Static Factory Method ---

## Creates and populates a new GOAPGoalDefinition from a dictionary.
## This enables loading goal definitions from external JSON files, adhering
## to the data-driven design principle.
##
## @param data: A Dictionary containing the goal's properties.
## @return A GOAPGoalDefinition instance, or null if parsing fails.
static func from_json(data: Dictionary) -> GOAPGoalDefinition:
	# Validate that the essential 'goal_id' field exists.
	if not data.has("goal_id"):
		push_error("GOAPGoalDefinition: Failed to parse. Missing 'goal_id'.")
		return null

	var definition = GOAPGoalDefinition.new()

	# Populate the resource's properties from the dictionary.
	definition.goal_id = data.get("goal_id", "")
	definition.preconditions = data.get("preconditions", {})
	definition.base_importance = data.get("base_importance", 0.0)
	definition.linked_granular_need_type = data.get("linked_granular_need_type", "")

	# A goal must have an ID and at least one precondition to be valid.
	if definition.goal_id.is_empty():
		push_error("GOAPGoalDefinition: 'goal_id' cannot be empty.")
		return null
	if definition.preconditions.is_empty():
		push_error("GOAPGoalDefinition: Goal '%s' must have at least one precondition." % definition.goal_id)
		return null

	return definition
