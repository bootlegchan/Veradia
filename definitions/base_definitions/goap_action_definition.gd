# GOAPActionDefinition.gd

# Represents a generic, parameterizable action that an NPC can perform.
# This refactored definition now includes the concept of a target. An action is
# defined generically (e.g., "PickupItem"), and the planner's job is to find a
# suitable target from memory (e.g., an apple) to "instantiate" the action with.
# The preconditions and effects use placeholders like `$target_id` to refer to
# the specific object the action is being performed on.
class_name GOAPActionDefinition
extends Resource

# --- Action Properties ---
@export var action_id: String = ""
@export var cost: float = 1.0

# --- Target Properties ---
# Describes the kind of target this action is looking for.
# "entity_type": The general type, e.g., "Item", "NPC".
# "tags": An array of tags the target must have, e.g., ["Food", "Drinkable"].
# "has_state": A dictionary of states the target must have, e.g., {"is_on": false}.
@export var target_criteria: Dictionary = {}

# --- State Dictionaries ---
# The preconditions and effects now support placeholders that will be replaced
# by the planner at runtime with the actual target's information.
# - `$target_id`: Replaced with the instance ID of the action's target.
# - `$target_location_id`: Replaced with the instance ID of the target's container/location.
@export var preconditions: Dictionary = {}
@export var effects: Dictionary = {}


# --- Static Factory Method ---

## Creates and populates a new GOAPActionDefinition from a dictionary.
static func from_json(data: Dictionary) -> GOAPActionDefinition:
	if not data.has("action_id"):
		push_error("GOAPActionDefinition: Failed to parse. Missing 'action_id'.")
		return null

	var definition = GOAPActionDefinition.new()

	definition.action_id = data.get("action_id", "")
	definition.cost = data.get("cost", 1.0)
	definition.target_criteria = data.get("target_criteria", {})
	definition.preconditions = data.get("preconditions", {})
	definition.effects = data.get("effects", {})

	if definition.action_id.is_empty():
		push_error("GOAPActionDefinition: 'action_id' cannot be empty.")
		return null
		
	if definition.effects.is_empty():
		push_error("GOAPActionDefinition: Action '%s' must have at least one effect." % definition.action_id)
		return null

	return definition
