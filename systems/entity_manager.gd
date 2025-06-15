## entity_manager.gd
## Central repository for all game definition resources and the primary factory
## for creating entity instances. This autoload loads all .tres definitions
## at startup and provides lookup methods for them.
class_name EntityManager extends Node

## Dictionaries to store loaded definitions, keyed by their unique IDs.
var _entity_definitions: Dictionary = {}
var _goap_goals: Dictionary = {}
var _goap_actions: Dictionary = {}
var _granular_needs: Dictionary = {}
var _item_definitions: Dictionary = {}
var _npc_entity_definitions: Dictionary = {}
var _personality_traits: Dictionary = {}
var _tag_definitions: Dictionary = {}
var _mood_types: Dictionary = {} # Future: For MoodType.gd
var _skill_definitions: Dictionary = {} # Future: For Skill.gd
var _job_postings: Dictionary = {} # Future: For JobPosting.gd
var _world_events: Dictionary = {} # Future: For WorldEvent.gd
var _pricing_strategies: Dictionary = {} # Future: For PricingStrategy.gd
var _cognitive_biases: Dictionary = {} # Future: For CognitiveBias.gd
var _world_entity_states: Dictionary = {} # Future: For WorldEntityState.gd
var _social_actions: Dictionary = {} # Future: For SocialAction.gd
var _crime_types: Dictionary = {} # Future: For CrimeType.gd
var _environmental_parameters: Dictionary = {} # Future: For EnvironmentalParameter.gd
var _political_offices: Dictionary = {} # Future: For PoliticalOffice.gd
var _laws: Dictionary = {} # Future: For Law.gd
var _genes: Dictionary = {} # Future: For Gene.gd
var _belief_systems: Dictionary = {} # Future: For BeliefSystem.gd

## Mapping for JSON-defined utility evaluators to their GDScript class paths.
## This allows dynamic instantiation of evaluators from data.
const _UTILITY_EVALUATOR_CLASS_MAP: Dictionary = {
	"NeedLevel": "res://features/npc_module/components/utility_evaluators/need_level_evaluator.gd",
	"TagPresence": "res://features/npc_module/components/utility_evaluators/tag_presence_evaluator.gd",
	"PersonalityTrait": "res://features/npc_module/components/utility_evaluators/personality_trait_evaluator.gd"
	# Add other evaluator types here as they are created
}

## Called when the node enters the scene tree for the first time.
func _ready():
	print("EntityManager: Loading all definitions...")
	_load_all_definitions()
	print("EntityManager: Loading complete.")
	# Count loaded definitions for debugging
	var loaded_counts = {
		"Needs": _granular_needs.size(),
		"Tags": _tag_definitions.size(),
		"Traits": _personality_traits.size(),
		"Goals": _goap_goals.size(),
		"Actions": _goap_actions.size(),
		"NPCs": _npc_entity_definitions.size(),
		"Items": _item_definitions.size()
	}
	print(" > Loaded %d Needs, %d Tags, %d Traits, %d Goals, %d Actions, %d NPCs, %d Items" % \
	[loaded_counts.Needs, loaded_counts.Tags, loaded_counts.Traits, loaded_counts.Goals, \
	loaded_counts.Actions, loaded_counts.NPCs, loaded_counts.Items])

## Recursively loads all definition resources from predefined directories.
func _load_all_definitions():
	_load_resources("res://definitions/ai/goals/", "GOAPGoalDefinition", _goap_goals)
	_load_resources("res://definitions/ai/actions/", "GOAPActionDefinition", _goap_actions)
	_load_resources("res://definitions/needs/", "GranularNeedDefinition", _granular_needs)
	_load_resources("res://definitions/items/", "ItemDefinition", _item_definitions)
	_load_resources("res://definitions/npcs/", "NPCEntityDefinition", _npc_entity_definitions)
	_load_resources("res://definitions/tags/", "TagDefinition", _tag_definitions)
	_load_resources("res://definitions/traits/", "PersonalityTraitDefinition", _personality_traits)
	# TODO: Add calls for other definition types as their folders and base resources are implemented.

## Helper function to load resources from a given path.
## Supports both .tres (Godot Resource) and .json files.
##
## Parameters:
## - path: The directory path to scan for resources.
## - expected_class_name: The expected `class_name` of the GDScript resource.
##                        Used to validate .tres files or determine target for .json.
## - target_dict: The dictionary to store the loaded resources.
func _load_resources(path: String, expected_class_name: String, target_dict: Dictionary):
	var dir = DirAccess.open(path)
	if not dir:
		push_error("EntityManager: Could not open directory: %s" % path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res_path = path + file_name
			_load_tres_resource_file(res_path, expected_class_name, target_dict)
		elif file_name.ends_with(".json"):
			var json_path = path + file_name
			_load_json_resource_file(json_path, expected_class_name, target_dict)
		file_name = dir.get_next()
	dir.list_dir_end()

## Loads a Godot .tres resource file.
##
## Parameters:
## - res_path: The full path to the .tres file.
## - expected_class_name: The expected `class_name` of the resource.
## - target_dict: The dictionary to store the loaded resource.
func _load_tres_resource_file(res_path: String, expected_class_name: String, target_dict: Dictionary):
	if not ResourceLoader.exists(res_path):
		push_warning("EntityManager: Resource file does not exist: %s" % res_path)
		return

	var resource: Resource = ResourceLoader.load(res_path)
	if resource == null:
		push_error("EntityManager: Failed to load resource: %s" % res_path)
		return

	# Use 'is' operator for type checking with class_name
	if not (resource is Resource and resource.get_script() != null and resource.get_script().get_instance_base_type() == expected_class_name):
		push_warning("EntityManager: Resource %s is not of expected type %s. Actual type: %s" % [res_path, expected_class_name, resource.get_class()])
		return

	var resource_id: String = ""
	if expected_class_name == "GOAPGoalDefinition":
		resource_id = (resource as GOAPGoalDefinition).goal_id
	elif expected_class_name == "GOAPActionDefinition":
		resource_id = (resource as GOAPActionDefinition).action_id
	elif expected_class_name == "GranularNeedDefinition":
		resource_id = (resource as GranularNeedDefinition).need_id
	elif expected_class_name == "ItemDefinition":
		resource_id = (resource as ItemDefinition).item_id
	elif expected_class_name == "NPCEntityDefinition":
		resource_id = (resource as NPCEntityDefinition).entity_id
	elif expected_class_name == "PersonalityTraitDefinition":
		resource_id = (resource as PersonalityTraitDefinition).trait_id
	elif expected_class_name == "TagDefinition":
		resource_id = (resource as TagDefinition).tag_id
	else:
		push_warning("EntityManager: No ID field defined for resource type '%s' from path '%s'. Using filename." % [expected_class_name, res_path])
		resource_id = file_path_to_id(res_path)

	if resource_id.is_empty():
		push_error("EntityManager: Resource %s has empty ID." % res_path)
		return

	if target_dict.has(resource_id):
		push_warning("EntityManager: Duplicate ID '%s' found for resource %s. Overwriting existing." % [resource_id, res_path])

	target_dict[resource_id] = resource

## Loads a JSON file and attempts to convert it into a Godot Resource.
##
## Parameters:
## - json_path: The full path to the .json file.
## - target_class_name: The `class_name` of the GDScript resource to instantiate.
## - target_dict: The dictionary to store the loaded resource.
func _load_json_resource_file(json_path: String, target_class_name: String, target_dict: Dictionary):
	var file = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("EntityManager: Could not open JSON file: %s" % json_path)
		return

	var json_string = file.get_as_text()
	file.close()

	var parse_result = JSON.parse_string(json_string)
	if not parse_result is Dictionary:
		push_error("EntityManager: Failed to parse JSON or it's not a dictionary: %s" % json_path)
		return

	var data: Dictionary = parse_result

	var script_path = "res://definitions/base_definitions/%s.gd" % target_class_name.to_snake_case()
	var script = load(script_path)
	if not script or not script is GDScript:
		push_error("EntityManager: Could not load script for class '%s' at path '%s'." % [target_class_name, script_path])
		return

	var resource: Resource = script.new()
	if not resource:
		push_error("EntityManager: Failed to instantiate resource of type '%s' from script '%s'." % [target_class_name, script_path])
		return

	# Populate resource properties from dictionary data
	for key in data:
		# Use 'in' operator to check if property exists. It's the idiomatic GDScript way.
		if key in resource:
			var value = data[key]
			if key == "utility_evaluators" and value is Array:
				resource.set(key, _parse_utility_evaluators(value))
			else:
				resource.set(key, value)
		else:
			push_warning("EntityManager: Resource '%s' (from %s) does not have property '%s'." % [target_class_name, json_path, key])

	var resource_id: String = ""
	if target_class_name == "GOAPGoalDefinition":
		resource_id = (resource as GOAPGoalDefinition).goal_id
	elif target_class_name == "GOAPActionDefinition":
		resource_id = (resource as GOAPActionDefinition).action_id
	elif target_class_name == "GranularNeedDefinition":
		resource_id = (resource as GranularNeedDefinition).need_id
	elif target_class_name == "ItemDefinition":
		resource_id = (resource as ItemDefinition).item_id
	elif target_class_name == "NPCEntityDefinition":
		resource_id = (resource as NPCEntityDefinition).entity_id
	elif target_class_name == "PersonalityTraitDefinition":
		resource_id = (resource as PersonalityTraitDefinition).trait_id
	elif target_class_name == "TagDefinition":
		resource_id = (resource as TagDefinition).tag_id
	else:
		push_warning("EntityManager: No ID field defined for resource type '%s' from path '%s'. Using filename." % [target_class_name, json_path])
		resource_id = file_path_to_id(json_path)


	if resource_id.is_empty():
		push_error("EntityManager: JSON resource %s has empty ID." % json_path)
		return

	if target_dict.has(resource_id):
		push_warning("EntityManager: Duplicate ID '%s' found for JSON resource %s. Overwriting existing." % [resource_id, json_path])

	target_dict[resource_id] = resource


## Parses an array of utility evaluator data dictionaries into actual UtilityEvaluator instances.
## Arrays parsed from JSON are generic, so this function must accept a generic Array.
##
## Parameters:
## - evaluators_data: A generic Array of Dictionaries, each defining a utility evaluator.
## Returns:
## - Array[UtilityEvaluator]: An array of instantiated and configured UtilityEvaluator objects.
func _parse_utility_evaluators(evaluators_data: Array) -> Array[UtilityEvaluator]:
	var parsed_evaluators: Array[UtilityEvaluator] = []
	for evaluator_dict in evaluators_data:
		if not evaluator_dict is Dictionary:
			push_warning("EntityManager: Item in utility_evaluators array is not a dictionary. Skipping.")
			continue

		var evaluator_type = evaluator_dict.get("evaluator_type", "")
		if evaluator_type.is_empty():
			push_warning("EntityManager: Utility evaluator data missing 'evaluator_type'. Skipping.")
			continue

		var class_path = _UTILITY_EVALUATOR_CLASS_MAP.get(evaluator_type)
		if not class_path:
			push_warning("EntityManager: Unknown utility evaluator type: '%s'. Skipping." % evaluator_type)
			continue

		var script = load(class_path)
		if not script or not script is GDScript:
			push_error("EntityManager: Could not load script for evaluator type '%s' at path '%s'." % [evaluator_type, class_path])
			continue

		var evaluator_instance: UtilityEvaluator = script.new()
		if not evaluator_instance:
			push_error("EntityManager: Failed to instantiate utility evaluator of type '%s'." % evaluator_type)
			continue

		# Populate the evaluator instance's properties from the dictionary
		for key in evaluator_dict:
			# Use 'in' operator to check if property exists.
			if key in evaluator_instance:
				if key == "evaluation_curve" and evaluator_dict[key] is String:
					# Assuming curve path is stored as string in JSON
					var curve_path = evaluator_dict[key]
					var curve_res = ResourceLoader.load(curve_path)
					if curve_res is Curve:
						evaluator_instance.set(key, curve_res)
					else:
						push_warning("EntityManager: Failed to load Curve resource from path '%s' for evaluator '%s'." % [curve_path, evaluator_type])
				else:
					evaluator_instance.set(key, evaluator_dict[key])
			else:
				push_warning("EntityManager: UtilityEvaluator '%s' does not have property '%s'." % [evaluator_type, key])

		parsed_evaluators.append(evaluator_instance)
	return parsed_evaluators

## Helper to convert a file path into a potential ID (strips extension and path).
func file_path_to_id(path: String) -> String:
	var file_name = path.get_file().get_basename()
	return file_name.split(".", true, 1)[0] # Get part before first dot for potential double extensions like .gd.uid

## --- Public API for retrieving definitions ---

func get_entity_definition(id: String) -> EntityDefinition:
	return _entity_definitions.get(id)

func get_goap_goal(id: String) -> GOAPGoalDefinition:
	return _goap_goals.get(id)

func get_goap_action(id: String) -> GOAPActionDefinition:
	return _goap_actions.get(id)

func get_granular_need(id: String) -> GranularNeedDefinition:
	return _granular_needs.get(id)

func get_item_definition(id: String) -> ItemDefinition:
	return _item_definitions.get(id)

func get_npc_entity_definition(id: String) -> NPCEntityDefinition:
	return _npc_entity_definitions.get(id)

func get_personality_trait_definition(id: String) -> PersonalityTraitDefinition:
	return _personality_traits.get(id)

func get_tag_definition(id: String) -> TagDefinition:
	return _tag_definitions.get(id)

# TODO: Add getters for other definition types as needed

func get_all_entity_definitions() -> Dictionary:
	return _entity_definitions.duplicate()

func get_all_goap_goals() -> Dictionary:
	return _goap_goals.duplicate()

func get_all_goap_actions() -> Dictionary:
	return _goap_actions.duplicate()

func get_all_granular_needs() -> Dictionary:
	return _granular_needs.duplicate()

func get_all_item_definitions() -> Dictionary:
	return _item_definitions.duplicate()

func get_all_npc_entity_definitions() -> Dictionary:
	return _npc_entity_definitions.duplicate()

func get_all_personality_traits() -> Dictionary:
	return _personality_traits.duplicate()

func get_all_tag_definitions() -> Dictionary:
	return _tag_definitions.duplicate()

func get_cognitive_bias(id: String): # Placeholder until CognitiveBiasDefinition is implemented
	# return _cognitive_biases.get(id)
	return null

## Spawns an entity based on its definition ID.
## This function is a factory that creates a Node3D scene and initializes its components.
##
## Parameters:
## - entity_id: The ID of the EntityDefinition to spawn.
## - parent_node: The Node to parent the new entity to.
## - global_position: The global position for the new entity.
## - global_rotation: The global rotation for the new entity.
## - extra_data: Optional dictionary for additional initialization data (e.g., genetics for NPC).
## Returns:
## - Node3D: The spawned entity node, or null if spawning failed.
func spawn_entity(entity_id: String, parent_node: Node, global_position: Vector3 = Vector3.ZERO, global_rotation: Vector3 = Vector3.ZERO, extra_data: Dictionary = {}) -> Node3D:
	var entity_def: EntityDefinition = get_entity_definition(entity_id)
	if not entity_def:
		entity_def = get_npc_entity_definition(entity_id) # Check NPC definitions if not generic
	if not entity_def:
		entity_def = get_item_definition(entity_id) # Check Item definitions if not generic
	# Add checks for other specific entity types here as they get separate definitions

	if not entity_def:
		push_error("EntityManager: Entity definition not found for ID: %s" % entity_id)
		return null

	var scene_path = "res://scenes/%s/%s.tscn" % [entity_def.entity_type.to_lower(), entity_id.to_lower()]
	if not ResourceLoader.exists(scene_path):
		push_error("EntityManager: Scene file does not exist for entity '%s' at path: %s" % [entity_id, scene_path])
		return null

	var packed_scene = ResourceLoader.load(scene_path)
	if not packed_scene is PackedScene:
		push_error("EntityManager: Failed to load PackedScene for entity '%s' at path: %s" % [entity_id, scene_path])
		return null

	var entity_node = packed_scene.instantiate() as Node3D
	if not entity_node:
		push_error("EntityManager: Failed to instantiate entity node for '%s'." % entity_id)
		return null

	entity_node.global_position = global_position
	entity_node.global_rotation = global_rotation
	parent_node.add_child(entity_node)

	# Basic initialization based on EntityDefinition
	entity_node.entity_id_name = entity_def.entity_id
	entity_node.entity_name_display = entity_def.entity_name
	entity_node.entity_type = entity_def.entity_type

	# Initialize NPCAI component if it's an NPC
	if entity_def is NPCEntityDefinition:
		var npc_ai_component = entity_node.find_child("NPCAI")
		if not npc_ai_component:
			# If NPCAI is not a child of the root scene, add it directly as an autonomous component.
			# Or, ideally, the NPC scene itself should have NPCAI attached.
			# For this project, NPCAI is a Node attached to the NPC Scene Root
			push_error("EntityManager: NPCAI component not found on NPC scene root for '%s'. Ensure it's a direct child named 'NPCAI'." % entity_id)
			entity_node.queue_free()
			return null
		npc_ai_component.initialize(entity_def)
		# TODO: Pass extra_data (like genetics) to npc_ai_component if applicable

	# TODO: Initialize other components based on entity_def.entity_type (e.g., Item components, Building components)

	return entity_node
