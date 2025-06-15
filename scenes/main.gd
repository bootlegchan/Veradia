## main.gd
## The main scene script responsible for initializing the game world,
## spawning initial entities like NPCs and items, and starting the simulation.
extends Node

# Autoloads
@onready var entity_manager: EntityManager = get_node("/root/EntitySvc")
@onready var world_manager: WorldManager = get_node("/root/WorldSvc")

# Scene node references will be assigned in _ready()
var item_spawn_points_parent: Node3D
var npc_spawn_points_parent: Node3D


## Called when the node enters the scene tree for the first time.
func _ready():
	# Assign scene node references and check for their existence
	item_spawn_points_parent = get_node_or_null("ItemSpawnPoints")
	npc_spawn_points_parent = get_node_or_null("NPCSpawnPoints")

	if not npc_spawn_points_parent:
		push_error("Main: 'NPCSpawnPoints' node not found as a child of Main. Cannot spawn NPC.")
		return
	if not item_spawn_points_parent:
		push_error("Main: 'ItemSpawnPoints' node not found as a child of Main. Cannot spawn items.")

	# Wait for global systems to be ready before starting simulation.
	# This ensures all autoloads have completed their own _ready() functions.
	await get_tree().process_frame
	_spawn_npc()
	_spawn_world_items()
	print("\n--- Simulation Starting ---")

## Spawns the initial test NPC into the world.
func _spawn_npc():
	var npc_spawn_points = npc_spawn_points_parent.get_children()
	if npc_spawn_points.is_empty():
		push_error("Main: No NPC spawn points (Marker3D children) found under NPCSpawnPoints node.")
		return

	# For now, spawn one test NPC using its full, correct entity_id.
	var npc_def_id = "npc_human_base"
	var npc_def = entity_manager.get_npc_entity_definition(npc_def_id)
	if not npc_def:
		push_error("Main: Failed to get '%s' definition. Aborting." % npc_def_id)
		return

	var spawn_point = npc_spawn_points[0]
	var npc_node = entity_manager.spawn_entity(npc_def.entity_id, self, spawn_point.global_position)
	if not npc_node:
		push_error("Main: Failed to spawn NPC '%s'." % npc_def_id)
	else:
		world_manager.register_entity(npc_node)
		print("Main: Spawning test NPC...")


## Spawns initial items into the world at designated spawn points.
func _spawn_world_items():
	if not item_spawn_points_parent:
		return # Error was already reported in _ready

	var item_spawn_points = item_spawn_points_parent.get_children()
	if item_spawn_points.is_empty():
		push_warning("Main: No item spawn points (Marker3D children) found under ItemSpawnPoints node.")
		return
	
	print("Main: Spawning world items...")

	var items_to_spawn = [
		{"def_id": "item_apple", "quantity": 3},
		# Add more items here as needed
	]

	for item_data in items_to_spawn:
		# Use the full, correct entity_id.
		var item_def_id = item_data["def_id"]
		var item_def = entity_manager.get_item_definition(item_def_id)
		if not item_def:
			push_error("Main: Failed to get '%s' definition." % item_def_id)
			continue
		
		for i in range(item_data["quantity"]):
			if item_spawn_points.is_empty():
				push_warning("Main: Ran out of item spawn points.")
				break
			
			var spawn_point = item_spawn_points.pick_random()
			var item_node = entity_manager.spawn_entity(item_def.entity_id, self, spawn_point.global_position)
			
			if not item_node:
				push_error("Main: Failed to spawn item '%s'." % item_def_id)
			else:
				world_manager.register_entity(item_node)
				# Remove spawn point to avoid spawning multiple items at the same spot
				item_spawn_points.erase(spawn_point)
