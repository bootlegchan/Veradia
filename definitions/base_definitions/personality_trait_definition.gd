# PersonalityTraitDefinition.gd

# Defines a single personality trait that can be part of an NPC's character.
# Traits like "Agreeableness" or "Extroversion" are defined as resources and then
# assigned a numeric value in the NPCEntityDefinition. These traits are intended
# to influence an NPC's behavior by affecting the utility of goals and actions,
# social interactions, and their susceptibility to certain moods or biases.
class_name PersonalityTraitDefinition
extends Resource

# --- Trait Properties ---

# The unique identifier for this trait (e.g., "AGREEABLENESS", "GLUTTONOUS").
@export var trait_id: String = ""

# The human-readable name for the trait (e.g., "Agreeableness", "Gluttonous").
@export var trait_name: String = ""

# --- Static Factory Method ---

## Creates and populates a new PersonalityTraitDefinition from a dictionary.
## This function allows personality traits to be defined in external JSON files,
## making it easy to add or modify traits without changing game code.
##
## @param data: A Dictionary containing the trait's properties.
## @return A PersonalityTraitDefinition instance, or null if parsing fails.
static func from_json(data: Dictionary) -> PersonalityTraitDefinition:
	# A trait must have an ID to be referenced by the system.
	if not data.has("trait_id"):
		push_error("PersonalityTraitDefinition: Failed to parse. Missing 'trait_id'.")
		return null

	var definition = PersonalityTraitDefinition.new()

	# Populate the resource's properties.
	definition.trait_id = data.get("trait_id", "")
	definition.trait_name = data.get("trait_name", definition.trait_id) # Default name to ID.

	# Validate that the ID is not empty.
	if definition.trait_id.is_empty():
		push_error("PersonalityTraitDefinition: 'trait_id' cannot be empty.")
		return null

	return definition 
