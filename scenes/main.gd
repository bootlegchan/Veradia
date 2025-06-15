# main.gd
extends Node

const NPCScene = preload("res://scenes/npcs/npc.tscn")
const ItemScene = preload("res://scenes/items/item.tscn")

var EntitySvc: Node
var WorldSvc: Node

func _ready() -> void:
	await get_tree().physics_frame
	EntitySvc = get_node("/root/EntitySvc")
	WorldSvc = get_node("/root/WorldSvc")
	if not WorldSvc or not EntitySvc:
		push_error("Main: A required Service is null. Check Autoloads.")
		return
	# We need to spawn the items FIRST so we can get the fridge's ID.
	var fridge_id = _spawn_world_items()
	_spawn_npc(fridge_id)
	
	print("\n--- Simulation Starting ---")

## Spawns the NPC and tells it where it is starting.
func _spawn_npc(p_start_location_id: int) -> void:
	print("Main: Spawning test NPC...")
	var npc_definition = EntitySvc.get_npc_entity_definition("human_base")
	if not npc_definition:
		push_error("Main: Failed to get 'human_base' definition. Aborting.")
		return
		
	var npc_instance = NPCScene.instantiate()
	if npc_instance is NPC:
		npc_instance.definition = npc_definition
		npc_instance.name = npc_definition.entity_name
		npc_instance.position = Vector3(0, 0, 10)
		# FINAL FIX: Pass the fridge's actual instance ID to the NPC.
		npc_instance.start_location_id = p_start_location_id
	else:
		push_error("Main: Instanced NPC scene root does not have 'npc.gd' script or is not Node3D!")
		return
	add_child(npc_instance)

## Spawns world items and returns the ID of the container.
func _spawn_world_items() -> int:
	print("Main: Spawning world items...")
	
	var fridge = Node3D.new()
	fridge.name = "Fridge"
	fridge.position = Vector3(0, 0, 0)
	add_child(fridge)
	WorldSvc.register_entity(fridge)
	
	var apple_def = EntitySvc.get_item_definition("apple")
	if not apple_def:
		push_error("Main: Failed to get 'apple' definition.")
		return 0
	
	var apple_instance = ItemScene.instantiate()
	if apple_instance is Item:
		apple_instance.definition = apple_def
		apple_instance.name = apple_def.entity_name
		apple_instance.position = Vector3(0, 0, 1)
	else:
		push_error("Main: Instanced Item scene root does not have 'item.gd' script or is not Node3D!")
		return 0
		
	add_child(apple_instance)
	
	var initial_apple_states = {
		"has_tag_Food": true,
		"is_at": fridge.get_instance_id()
	}
	WorldSvc.register_entity(apple_instance, initial_apple_states)
	
	# Return the fridge's ID so the spawner can use it.
	return fridge.get_instance_id()
