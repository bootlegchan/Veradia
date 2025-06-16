## entity_manager.gd
## Central repository for all game definition resources and the primary factory
## for creating entity instances. This autoload loads all .tres definitions
## at startup and provides lookup methods for them.
class_name EntityManager extends Node

## Dictionaries to store loaded definitions, keyed by their unique IDs.
var _goap_goals: Dictionary = {}
var _goap_actions: Dictionary = {}
var _granular_needs: Dictionary = {}
var _item_definitions: Dictionary = {}
var _npc_entity_definitions: Dictionary = {}
var _personality_traits: Dictionary = {}
var _tag_definitions: Dictionary = {}
var _schedule_entries: Dictionary = {}
var _mood_types: Dictionary = {}
var _skill_definitions: Dictionary = {}
var _job_postings: Dictionary = {}
var _world_events: Dictionary = {}
var _pricing_strategies: Dictionary = {}
var _cognitive_biases: Dictionary = {}
var _world_entity_states: Dictionary = {}
var _social_actions: Dictionary = {}
var _crime_types: Dictionary = {}
var _environmental_parameters: Dictionary = {}
var _political_offices: Dictionary = {}
var _laws: Dictionary = {}
var _genes: Dictionary = {}
var _belief_systems: Dictionary = {}

## Mapping for JSON-defined utility evaluators to their GDScript class paths.
const _UTILITY_EVALUATOR_CLASS_MAP: Dictionary = {
	"NeedLevel": "res://features/npc_module/components/utility_evaluators/need_level_evaluator.gd",
	"TagPresence": "res://features/npc_module/components/utility_evaluators/tag_presence_evaluator.gd",
	"PersonalityTrait": "res://features/npc_module/components/utility_evaluators/personality_trait_evaluator.gd",
	"UtilityEvaluator": "res://definitions/base_definitions/utility_evaluator.gd"
}

## Called when the node enters the scene tree for the first time.
func _ready():
	print("EntityManager: Loading all definitions...")
	_load_all_definitions()
	print("EntityManager: Loading complete.")
	var loaded_counts = {
		"Needs": _granular_needs.size(), "Tags": _tag_definitions.size(), "Traits": _personality_traits.size(),
		"Goals": _goap_goals.size(), "Actions": _goap_actions.size(), "NPCs": _npc_entity_definitions.size(),
		"Items": _item_definitions.size(), "Schedules": _schedule_entries.size()
	}
	print(" > Loaded %d Needs, %d Tags, %d Traits, %d Goals, %d Actions, %d NPCs, %d Items, %d Schedules" % \
	[loaded_counts.Needs, loaded_counts.Tags, loaded_counts.Traits, loaded_counts.Goals, \
	loaded_counts.Actions, loaded_counts.NPCs, loaded_counts.Items, loaded_counts.Schedules])

## Recursively loads all definition resources from predefined directories.
func _load_all_definitions():
	_load_resources("res://definitions/ai/goals/", "GOAPGoalDefinition", _goap_goals)
	_load_resources("res://definitions/ai/actions/", "GOAPActionDefinition", _goap_actions)
	_load_resources("res://definitions/needs/", "GranularNeedDefinition", _granular_needs)
	_load_resources("res://definitions/items/", "ItemDefinition", _item_definitions)
	_load_resources("res://definitions/npcs/schedules/", "ScheduleEntry", _schedule_entries)
	_load_resources("res://definitions/npcs/", "NPCEntityDefinition", _npc_entity_definitions)
	_load_resources("res://definitions/tags/", "TagDefinition", _tag_definitions)
	_load_resources("res://definitions/traits/", "PersonalityTraitDefinition", _personality_traits)

## Helper function to load resources from a given path.
func _load_resources(path: String, expected_class_name: String, target_dict: Dictionary):
	var dir = DirAccess.open(path)
	if not dir:
		push_error("EntityManager: Could not open directory: %s" % path)
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			_load_tres_resource_file(path + file_name, expected_class_name, target_dict)
		elif file_name.ends_with(".json"):
			_load_json_resource_file(path + file_name, expected_class_name, target_dict)
		file_name = dir.get_next()
	dir.list_dir_end()

## Loads a Godot .tres resource file.
func _load_tres_resource_file(res_path: String, expected_class_name: String, target_dict: Dictionary):
	if not ResourceLoader.exists(res_path):
		push_warning("EntityManager: Resource file does not exist: %s" % res_path)
		return
	var resource: Resource = ResourceLoader.load(res_path)
	if resource == null:
		push_error("EntityManager: Failed to load resource: %s" % res_path)
		return
	if not (resource is Resource and resource.get_script() != null and resource.get_script().get_instance_base_type() == expected_class_name):
		push_warning("EntityManager: Resource %s is not of expected type %s. Actual type: %s" % [res_path, expected_class_name, resource.get_class()])
		return
	var resource_id: String = (resource as DefinitionBase).id
	if resource_id.is_empty():
		push_error("EntityManager: Resource %s has an empty ID." % res_path)
		return
	if target_dict.has(resource_id):
		push_warning("EntityManager: Duplicate ID '%s' found for resource %s. Overwriting existing." % [resource_id, res_path])
	target_dict[resource_id] = resource

## Loads a JSON file and converts it into a Godot Resource.
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
	var resource = _create_resource_from_data(data, target_class_name, json_path)
	if not resource: return
	var resource_id: String = (resource as DefinitionBase).id
	if target_class_name == "ScheduleEntry":
		resource_id = json_path.get_file()
		(resource as DefinitionBase).id = resource_id
	if resource_id.is_empty():
		push_error("EntityManager: JSON resource %s has an empty ID." % json_path)
		return
	if target_dict.has(resource_id):
		push_warning("EntityManager: Duplicate ID '%s' found for JSON resource %s. Overwriting existing." % [resource_id, json_path])
	target_dict[resource_id] = resource

## Creates and populates a Resource object from a dictionary of data.
func _create_resource_from_data(data: Dictionary, target_class_name: String, source_path: String) -> Resource:
	var script_path: String
	if target_class_name == "UtilityEvaluator":
		var evaluator_type = data.get("evaluator_type", "UtilityEvaluator")
		script_path = _UTILITY_EVALUATOR_CLASS_MAP.get(evaluator_type)
	else:
		script_path = "res://definitions/base_definitions/%s.gd" % target_class_name.to_snake_case()
	if script_path.is_empty() or not ResourceLoader.exists(script_path):
		push_error("EntityManager: Could not find script for class '%s' at path '%s'." % [target_class_name, script_path])
		return null
	var script = load(script_path)
	if not script is GDScript:
		push_error("EntityManager: Failed to load script for class '%s' at path '%s'." % [target_class_name, script_path])
		return null
	var resource: Resource = script.new()
	if not resource:
		push_error("EntityManager: Failed to instantiate resource of type '%s' from script '%s'." % [target_class_name, script_path])
		return null
	for key in data:
		if key in resource:
			var value = data[key]
			if key == "schedule_entries" and value is Array:
				resource.set(key, _parse_schedule_entries(value))
			else:
				resource.set(key, value)
		else:
			push_warning("EntityManager: Resource '%s' (from %s) does not have property '%s'." % [target_class_name, source_path, key])
	return resource

## Parses an array of schedule entry IDs and returns the corresponding resource objects.
func _parse_schedule_entries(schedule_entry_ids: Array) -> Array[ScheduleEntry]:
	var parsed_entries: Array[ScheduleEntry] = []
	for entry_id in schedule_entry_ids:
		if not entry_id is String:
			push_warning("EntityManager: Item in schedule_entries array is not a string ID. Skipping.")
			continue
		var schedule_entry_res = get_schedule_entry(entry_id)
		if schedule_entry_res:
			parsed_entries.append(schedule_entry_res)
		else:
			push_warning("EntityManager: Could not find schedule entry definition for ID '%s'." % entry_id)
	return parsed_entries

## --- Public API for retrieving definitions ---

func get_entity_definition(id: String) -> DefinitionBase:
	if _npc_entity_definitions.has(id):
		return _npc_entity_definitions[id]
	if _item_definitions.has(id):
		return _item_definitions[id]
	return null

func get_schedule_entry(id: String) -> ScheduleEntry: return _schedule_entries.get(id)
func get_goap_goal(id: String) -> GOAPGoalDefinition: return _goap_goals.get(id)
func get_goap_action(id: String) -> GOAPActionDefinition: return _goap_actions.get(id)
func get_granular_need(id: String) -> GranularNeedDefinition: return _granular_needs.get(id)
func get_item_definition(id: String) -> ItemDefinition: return _item_definitions.get(id)
func get_npc_entity_definition(id: String) -> NPCEntityDefinition: return _npc_entity_definitions.get(id)
func get_personality_trait_definition(id: String) -> PersonalityTraitDefinition: return _personality_traits.get(id)
func get_tag_definition(id: String) -> TagDefinition: return _tag_definitions.get(id)
func get_all_goap_goals() -> Dictionary: return _goap_goals.duplicate()
func get_all_goap_actions() -> Dictionary: return _goap_actions.duplicate()
func get_all_granular_needs() -> Dictionary: return _granular_needs.duplicate()
func get_all_item_definitions() -> Dictionary: return _item_definitions.duplicate()
func get_all_npc_entity_definitions() -> Dictionary: return _npc_entity_definitions.duplicate()
func get_all_personality_traits() -> Dictionary: return _personality_traits.duplicate()
func get_all_tag_definitions() -> Dictionary: return _tag_definitions.duplicate()
func get_cognitive_bias(_id: String): return null

## Spawns an entity based on its definition ID.
func spawn_entity(entity_id: String, parent_node: Node, global_position: Vector3 = Vector3.ZERO, global_rotation: Vector3 = Vector3.ZERO, extra_data: Dictionary = {}) -> Node3D:
	var entity_def: DefinitionBase = get_entity_definition(entity_id)
	if not entity_def:
		push_error("EntityManager: Entity definition not found for ID: '%s'" % entity_id)
		return null
	var scene_path = entity_def.scene_path
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_error("EntityManager: Scene path '%s' is invalid or not defined for entity '%s'." % [scene_path, entity_id])
		return null
	var packed_scene = ResourceLoader.load(scene_path)
	if not packed_scene is PackedScene:
		push_error("EntityManager: Failed to load PackedScene for entity '%s' at path: %s" % [entity_id, scene_path])
		return null
	var entity_node = packed_scene.instantiate() as Node3D
	if not entity_node:
		push_error("EntityManager: Failed to instantiate entity node for '%s'." % entity_id)
		return null
	parent_node.add_child(entity_node)
	entity_node.global_position = global_position
	entity_node.global_rotation_degrees = global_rotation
	if "entity_id_name" in entity_node: entity_node.entity_id_name = entity_def.id
	if "entity_name_display" in entity_node: entity_node.entity_name_display = entity_def.entity_name
	if "entity_type" in entity_node: entity_node.entity_type = entity_def.entity_type
	if entity_def is NPCEntityDefinition:
		var npc_ai_component = entity_node.find_child("NPCAI")
		if not npc_ai_component:
			push_error("EntityManager: NPCAI component not found on NPC scene root for '%s'. Ensure it's a direct child named 'NPCAI'." % entity_id)
			entity_node.queue_free()
			return null
		npc_ai_component.initialize(entity_def)
	return entity_node
