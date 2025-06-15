# NPCEntityDefinition.gd

# Defines the specific properties for an NPC entity, inheriting from the base
# EntityDefinition. This resource holds all the initial, static data required
# to spawn a new NPC into the simulation.
class_name NPCEntityDefinition
extends EntityDefinition

# --- NPC-Specific Properties ---
@export var initial_granular_needs: Dictionary = {}
@export var initial_personality_traits: Dictionary = {}
@export var initial_skills: Dictionary = {}
@export var home_entity_id: String = ""
@export var initial_job_id: String = ""

# The maximum distance from which this NPC can visually perceive entities.
@export var perception_range: float = 10.0


# --- Static Factory Method ---

## Creates and populates a new NPCEntityDefinition from a dictionary.
static func from_json(data: Dictionary) -> NPCEntityDefinition:
	var base_definition = EntityDefinition.from_json(data)
	if not base_definition:
		return null

	var definition = NPCEntityDefinition.new()

	definition.entity_id = base_definition.entity_id
	definition.entity_name = base_definition.entity_name
	definition.entity_type = base_definition.entity_type
	definition.initial_tags = base_definition.initial_tags

	definition.initial_granular_needs = data.get("initial_granular_needs", {})
	definition.initial_personality_traits = data.get("initial_personality_traits", {})
	definition.initial_skills = data.get("initial_skills", {})
	definition.home_entity_id = data.get("home_entity_id", "")
	definition.initial_job_id = data.get("initial_job_id", "")
	definition.perception_range = data.get("perception_range", 10.0)

	return definition
