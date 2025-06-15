# GranularNeedDefinition.gd

# Defines a single, specific physiological or psychological need for an NPC.
# This resource encapsulates the properties of a need like "Hunger", "Thirst",
# or "Social". The values of these needs are tracked dynamically by the NPCAI
# node, and their decay over time is a primary driver of NPC motivation.
class_name GranularNeedDefinition
extends Resource

# --- Need Properties ---

# The unique identifier for this need (e.g., "HUNGER", "ENERGY", "SOCIAL").
@export var need_id: String = ""

# The rate at which this need's value decreases per in-game minute.
# For example, a value of 0.01 means the need drops by 1% every minute.
# This decay can be modified by active Tags on the NPC.
@export var base_decay_rate: float = 0.0

# The level of Maslow's hierarchy this need belongs to (e.g., "Physiological").
# While not used in the initial implementation, this allows for more complex
# motivation modeling later, where satisfying lower-level needs takes priority.
@export var linked_maslow_level: String = ""

# A multiplier that affects how much this need contributes to the utility score
# of associated goals. A higher value makes satisfying this need more important.
@export var importance_modifier: float = 1.0

# --- Static Factory Method ---

## Creates and populates a new GranularNeedDefinition from a dictionary.
## This enables loading need definitions from external JSON files.
##
## @param data: A Dictionary containing the need's properties.
## @return A GranularNeedDefinition instance, or null if parsing fails.
static func from_json(data: Dictionary) -> GranularNeedDefinition:
	# A need must have an ID to be referenced by NPCs and Tags.
	if not data.has("need_id"):
		push_error("GranularNeedDefinition: Failed to parse. Missing 'need_id'.")
		return null

	var definition = GranularNeedDefinition.new()

	# Populate the resource's properties from the dictionary.
	definition.need_id = data.get("need_id", "")
	definition.base_decay_rate = data.get("base_decay_rate", 0.0)
	definition.linked_maslow_level = data.get("linked_maslow_level", "")
	definition.importance_modifier = data.get("importance_modifier", 1.0)

	# Validate that the ID is not empty.
	if definition.need_id.is_empty():
		push_error("GranularNeedDefinition: 'need_id' cannot be empty.")
		return null

	return definition
