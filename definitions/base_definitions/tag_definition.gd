# TagDefinition.gd

# Defines the properties of a Tag, which is a universal dynamic modifier.
# Tags are status effects that can be applied to any entity (NPCs, items, etc.)
# to influence their state and behavior. For example, a "Hungry" tag could
# increase the decay rate of a "Stamina" need and increase the utility of any
# goal related to eating. This data-driven approach allows for complex emergent
# interactions without writing custom code for every status effect.
class_name TagDefinition
extends Resource

# --- Tag Properties ---

# The unique identifier for this tag (e.g., "TAG_HUNGRY", "TAG_INJURED").
@export var tag_id: String = ""

# The human-readable name for display purposes (e.g., "Hungry", "Injured").
@export var tag_name: String = ""

# Defines how the tag is removed.
# "PERMANENT": Never removed automatically.
# "TEMPORARY": Removed after a specific duration (to be implemented).
# "ELASTIC": Strength changes over time and may be removed at a threshold (to be implemented).
@export var effect_type: String = "PERMANENT"

# A dictionary defining how this tag influences granular needs.
# The structure allows for multipliers or additive modifiers.
# Example: {"HUNGER": {"decay_multiplier": 1.5}, "ENERGY": {"decay_multiplier": 1.2}}
@export var influence_on_needs: Dictionary = {}

# A dictionary defining how this tag influences personality traits.
# Example: {"AGREEABLENESS": {"add_modifier": -0.2}}
@export var influence_on_personality: Dictionary = {}

# A dictionary defining how this tag influences the utility of GOAP goals.
# Example: {"EatFood": {"utility_multiplier": 1.5}}
@export var influence_on_goal_utility: Dictionary = {}

# --- Static Factory Method ---

## Creates and populates a new TagDefinition from a dictionary.
## This enables loading tag definitions from external JSON files.
##
## @param data: A Dictionary containing the tag's properties.
## @return A TagDefinition instance, or null if parsing fails.
static func from_json(data: Dictionary) -> TagDefinition:
	# A tag must have a unique ID to be identifiable.
	if not data.has("tag_id"):
		push_error("TagDefinition: Failed to parse. Missing 'tag_id'.")
		return null

	var definition = TagDefinition.new()

	# Populate the resource's properties from the dictionary.
	definition.tag_id = data.get("tag_id", "")
	definition.tag_name = data.get("tag_name", definition.tag_id) # Default name to ID
	definition.effect_type = data.get("effect_type", "PERMANENT")
	definition.influence_on_needs = data.get("influence_on_needs", {})
	definition.influence_on_personality = data.get("influence_on_personality", {})
	definition.influence_on_goal_utility = data.get("influence_on_goal_utility", {})

	# Validate that the ID is not empty.
	if definition.tag_id.is_empty():
		push_error("TagDefinition: 'tag_id' cannot be empty.")
		return null

	return definition
