## action_primitive_handler.gd
## Manages the execution of low-level "primitive operations" defined within GOAP Actions.
## These primitives interact directly with global systems (WorldManager, EntityManager)
## to enact changes in the game world, and can return data back to the NPCAI for internal state updates.
class_name ActionPrimitiveHandler extends Node

## Reference to the WorldManager singleton (accessed via Autoload name).
@onready var _world_manager: WorldManager = get_node("/root/WorldSvc")
## Reference to the EntityManager singleton (accessed via Autoload name).
@onready var _entity_manager: EntityManager = get_node("/root/EntitySvc")
## Reference to the AIManager singleton (accessed via Autoload name).
@onready var _ai_manager: AIManager = get_node("/root/AISvc")
## Reference to the SimDataRecorder singleton.
# @onready var _sim_data_recorder: SimDataRecorder = get_node("/root/SimDataRecorder") # Uncomment when SimDataRecorder exists

## Called when the node enters the scene tree for the first time.
func _ready():
	print("ActionPrimitiveHandler initialized.")

## Executes a single primitive operation defined within a GOAPAction.
##
## Parameters:
## - npc_ai: The NPCAI instance performing the action.
## - primitive_data: A Dictionary containing the type and parameters for the primitive operation.
## Returns:
## - Dictionary: A dictionary containing the results of the primitive operation,
##               including "success": bool and any "outcome_data" like consumption effects.
func execute_primitive(npc_ai: NPCAI, primitive_data: Dictionary) -> Dictionary:
	var primitive_type: String = primitive_data.get("type", "")
	var success: bool = false
	var outcome_data: Dictionary = {}

	match primitive_type:
		"CONSUME_ITEM":
			var target_item_id_key = primitive_data.get("item_id_key", "")
			if target_item_id_key.is_empty():
				push_warning("ActionPrimitiveHandler: CONSUME_ITEM primitive missing 'item_id_key'.")
				return {"success": false, "outcome_data": {}}

			var target_item_instance_id = npc_ai.get_blackboard_snapshot().get_data(target_item_id_key)
			if target_item_instance_id == null:
				push_warning("ActionPrimitiveHandler: CONSUME_ITEM failed, no item instance ID found for key '%s' in blackboard." % target_item_id_key)
				return {"success": false, "outcome_data": {}}

			var consume_result = _execute_consume_item(npc_ai, target_item_instance_id)
			success = consume_result["success"]
			outcome_data = consume_result["outcome_data"]

		"PICKUP_ITEM":
			var target_entity_id_key = primitive_data.get("target_entity_id_key", "")
			if target_entity_id_key.is_empty():
				push_warning("ActionPrimitiveHandler: PICKUP_ITEM primitive missing 'target_entity_id_key'.")
				return {"success": false, "outcome_data": {}}

			var target_entity_instance_id = npc_ai.get_blackboard_snapshot().get_data(target_entity_id_key)
			if target_entity_instance_id == null:
				push_warning("ActionPrimitiveHandler: PICKUP_ITEM failed, no target entity instance ID found for key '%s' in blackboard." % target_entity_id_key)
				return {"success": false, "outcome_data": {}}

			success = _execute_pickup_item(npc_ai, target_entity_instance_id)

		"MOVE_TO_RANDOM_LOCATION":
			var radius = primitive_data.get("radius", 10.0)
			success = _execute_move_to_random_location(npc_ai, radius)

		"MOVE_TO_LOCATION":
			var target_key = primitive_data.get("target_location_key", "")
			if target_key.is_empty():
				push_warning("ActionPrimitiveHandler: MOVE_TO_LOCATION primitive missing 'target_location_key'.")
				return {"success": false, "outcome_data": {}}
				
			var target_instance_id = npc_ai.get_blackboard_snapshot().get_data(target_key)
			if target_instance_id == null:
				push_warning("ActionPrimitiveHandler: MOVE_TO_LOCATION failed, no target location ID found for key '%s' in blackboard." % target_key)
				return {"success": false, "outcome_data": {}}
				
			success = _execute_move_to_location(npc_ai, target_instance_id)

		"IDLE":
			var duration_seconds = primitive_data.get("duration_seconds", 5.0)
			success = _execute_idle(npc_ai, duration_seconds)

		_:# Default case for unhandled primitives
			push_warning("ActionPrimitiveHandler: Unknown primitive type '%s'." % primitive_type)
			success = false

	return {"success": success, "outcome_data": outcome_data}

## Executes the "CONSUME_ITEM" primitive operation.
func _execute_consume_item(npc_ai: NPCAI, target_item_instance_id: int) -> Dictionary:
	var item_entity: Node3D = _world_manager.get_entity(target_item_instance_id)
	if not is_instance_valid(item_entity):
		push_warning("ActionPrimitiveHandler: CONSUME_ITEM failed, target item ID '%d' is not valid in world." % target_item_instance_id)
		return {"success": false, "outcome_data": {}}

	var item_def: ItemDefinition = _entity_manager.get_item_definition(item_entity.entity_id_name)
	if not item_def:
		push_warning("ActionPrimitiveHandler: CONSUME_ITEM failed, item definition for '%s' not found." % item_entity.entity_id_name)
		return {"success": false, "outcome_data": {}}

	_world_manager.unregister_entity(item_entity)
	item_entity.queue_free()
	print("ActionPrimitiveHandler: Item %d consumed and removed from simulation." % target_item_instance_id)
	return {"success": true, "outcome_data": {"consumption_effects": item_def.consumption_effects}}

## Executes the "PICKUP_ITEM" primitive operation.
func _execute_pickup_item(npc_ai: NPCAI, target_entity_instance_id: int) -> bool:
	var item_entity: Node3D = _world_manager.get_entity(target_entity_instance_id)
	if not is_instance_valid(item_entity):
		push_warning("ActionPrimitiveHandler: PICKUP_ITEM failed, target item ID '%d' is not valid in world." % target_entity_instance_id)
		return false

	var item_def: ItemDefinition = _entity_manager.get_item_definition(item_entity.entity_id_name)
	if not item_def:
		push_warning("ActionPrimitiveHandler: PICKUP_ITEM failed, item definition for '%s' not found." % item_entity.entity_id_name)
		return false

	_world_manager.unregister_entity(item_entity)
	npc_ai.add_item_to_inventory(item_def.entity_id, 1)
	item_entity.queue_free()
	print("ActionPrimitiveHandler: Item %d removed from world location. NPC %d picked up %s." % [target_entity_instance_id, npc_ai.get_instance_id(), item_def.entity_id])
	return true

## Moves the NPC to a random location within a specified radius.
func _execute_move_to_random_location(npc_ai: NPCAI, radius: float) -> bool:
	var npc_node = npc_ai.get_parent()
	var random_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var target_position = npc_node.global_position + random_direction * randf_range(1.0, radius)
	print("ActionPrimitiveHandler: NPC '%s' is wandering towards %s." % [npc_ai.name, target_position])
	return true

## Moves the NPC to a specific target location.
func _execute_move_to_location(npc_ai: NPCAI, target_instance_id: int) -> bool:
	var target_entity = _world_manager.get_entity(target_instance_id)
	if not is_instance_valid(target_entity):
		push_warning("ActionPrimitiveHandler: MOVE_TO_LOCATION failed, target entity ID '%d' is not valid in world." % target_instance_id)
		return false
	
	print("ActionPrimitiveHandler: NPC '%s' is moving towards entity %d (%s)." % [npc_ai.name, target_instance_id, target_entity.name])
	return true

## Makes the NPC wait for a specified duration.
func _execute_idle(npc_ai: NPCAI, duration_seconds: float) -> bool:
	print("ActionPrimitiveHandler: NPC '%s' is relaxing for %.1f seconds." % [npc_ai.name, duration_seconds])
	return true
