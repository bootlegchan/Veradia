# WorldManager.gd
# Manages the "ground truth" of the physical game world.
class_name WorldManager
extends Node

var _world_entities: Dictionary = {}
var _entity_states: Dictionary = {}

## Registers a new world entity with the manager.
func register_entity(entity_node: Node3D, initial_states: Dictionary = {}) -> bool:
	if not is_instance_valid(entity_node):
		push_error("WorldManager: Attempted to register an invalid Node3D.")
		return false
	var instance_id = entity_node.get_instance_id()
	if _world_entities.has(instance_id):
		push_warning("WorldManager: Entity with ID %s is already registered." % instance_id)
		return false
	_world_entities[instance_id] = entity_node
	_entity_states[instance_id] = initial_states
	return true

## Unregisters a world entity.
func unregister_entity(entity_node: Node3D) -> void:
	if not is_instance_valid(entity_node): return
	var instance_id = entity_node.get_instance_id()
	if _world_entities.has(instance_id):
		_world_entities.erase(instance_id)
		_entity_states.erase(instance_id)

# --- Public API ---
func set_entity_state(entity_instance_id: int, state_key: String, value: Variant) -> void:
	if not _entity_states.has(entity_instance_id): return
	_entity_states[entity_instance_id][state_key] = value

func get_entity_state(entity_instance_id: int, state_key: String, default: Variant = null) -> Variant:
	if not _entity_states.has(entity_instance_id): return default
	return _entity_states[entity_instance_id].get(state_key, default)

func get_all_entity_states(entity_instance_id: int) -> Dictionary:
	return _entity_states.get(entity_instance_id, {}).duplicate()

func get_entity_by_id(entity_instance_id: int) -> Node3D:
	var entity = _world_entities.get(entity_instance_id, null)
	if is_instance_valid(entity): return entity
	return null

## Finds all registered world entities within a given radius of an origin point.
func get_entities_in_range(origin: Vector3, radius: float) -> Array[Node3D]:
	# This is the correct implementation that returns a typed array.
	var found_entities: Array[Node3D] = []
	var radius_squared = radius * radius
	for entity_node in _world_entities.values():
		# This check ensures we only try to calculate distance for Node3D objects.
		if is_instance_valid(entity_node) and entity_node is Node3D:
			if origin.distance_squared_to(entity_node.global_position) <= radius_squared:
				found_entities.append(entity_node)
	return found_entities
