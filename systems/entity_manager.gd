# EntityManager.gd

# A central repository for all game definition resources.
# As an Autoload (singleton), this manager is responsible for recursively scanning
# the `definitions/` directory, parsing all `.json` files, and loading them into
# memory as strongly-typed Godot Resource objects. It provides a simple and
# efficient API for any other system to retrieve these definitions by their unique ID.
class_name EntityManager
extends Node

@export var definitions_path: String = "res://definitions"

var _need_definitions: Dictionary = {}
var _tag_definitions: Dictionary = {}
var _trait_definitions: Dictionary = {}
var _goal_definitions: Dictionary = {}
var _action_definitions: Dictionary = {}
var _npc_entity_definitions: Dictionary = {}
var _item_definitions: Dictionary = {}


func _ready() -> void:
	print("EntityManager: Loading all definitions...")
	_load_all_definitions()
	print("EntityManager: Loading complete.")
	print(" > Loaded %d Needs, %d Tags, %d Traits, %d Goals, %d Actions, %d NPCs, %d Items" % [
			_need_definitions.size(), _tag_definitions.size(), _trait_definitions.size(),
			_goal_definitions.size(), _action_definitions.size(), _npc_entity_definitions.size(),
			_item_definitions.size()
	])


func _load_all_definitions() -> void:
	var dir = DirAccess.open(definitions_path)
	if not dir:
		push_error("EntityManager: Failed to open definitions directory at path: %s" % definitions_path)
		return
	
	_load_definitions_from_directory(dir, definitions_path)


func _load_definitions_from_directory(dir: DirAccess, current_path: String) -> void:
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = "%s/%s" % [current_path, file_name]
		if dir.current_is_dir() and file_name != "." and file_name != "..":
			var sub_dir = DirAccess.open(full_path)
			if sub_dir:
				_load_definitions_from_directory(sub_dir, full_path)
		elif file_name.ends_with(".json"):
			_load_definition_file(full_path)
		
		file_name = dir.get_next()


func _load_definition_file(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("EntityManager: Failed to open definition file: %s" % file_path)
		return

	var content = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(content)
	if error != OK:
		push_error("EntityManager: Failed to parse JSON in file: %s. Error: %s" % [file_path, json.get_error_message()])
		return

	var data: Dictionary = json.get_data()
	var id_key_found = false
	for key in ["entity_id", "need_id", "tag_id", "trait_id", "goal_id", "action_id"]:
		if data.has(key):
			id_key_found = true
			break
	if not id_key_found:
		push_warning("EntityManager: Skipping file. No valid ID key found in: %s" % file_path)
		return
		
	if file_path.begins_with("res://definitions/needs/"):
		var def = GranularNeedDefinition.from_json(data)
		if def: _need_definitions[def.need_id] = def
	elif file_path.begins_with("res://definitions/tags/"):
		var def = TagDefinition.from_json(data)
		if def: _tag_definitions[def.tag_id] = def
	elif file_path.begins_with("res://definitions/traits/"):
		var def = PersonalityTraitDefinition.from_json(data)
		if def: _trait_definitions[def.trait_id] = def
	elif file_path.begins_with("res://definitions/ai/goals/"):
		var def = GOAPGoalDefinition.from_json(data)
		if def: _goal_definitions[def.goal_id] = def
	elif file_path.begins_with("res://definitions/ai/actions/"):
		var def = GOAPActionDefinition.from_json(data)
		if def: _action_definitions[def.action_id] = def
	elif file_path.begins_with("res://definitions/items/"):
		var def = ItemDefinition.from_json(data)
		if def: _item_definitions[def.entity_id] = def
	elif file_path.begins_with("res://definitions/npcs/"):
		var def = NPCEntityDefinition.from_json(data)
		if def: _npc_entity_definitions[def.entity_id] = def
	else:
		push_warning("EntityManager: Unrecognized definition category for file: %s" % file_path)


# --- Public API ---
func get_need_definition(id: String) -> GranularNeedDefinition:
	return _need_definitions.get(id, null)

func get_tag_definition(id: String) -> TagDefinition:
	return _tag_definitions.get(id, null)

func get_trait_definition(id: String) -> PersonalityTraitDefinition:
	return _trait_definitions.get(id, null)
	
func get_goal_definition(id: String) -> GOAPGoalDefinition:
	return _goal_definitions.get(id, null)

func get_action_definition(id: String) -> GOAPActionDefinition:
	return _action_definitions.get(id, null)

func get_npc_entity_definition(id: String) -> NPCEntityDefinition:
	return _npc_entity_definitions.get(id, null)

func get_item_definition(id: String) -> ItemDefinition:
	return _item_definitions.get(id, null)

func get_all_action_definitions() -> Dictionary:
	return _action_definitions
