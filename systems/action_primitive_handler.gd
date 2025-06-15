# ActionPrimitiveHandler.gd

# This service translates abstract GOAP actions into concrete changes in the
# simulation's "ground truth" (the WorldManager). When an NPCAI executes a
# step in its plan, it calls the appropriate function here to make the change happen.
# This separates the AI's decision-making (planning) from the mechanics of
# action execution.
class_name ActionPrimitiveHandler
extends Node

# --- Manager References ---
var WorldSvc: Node

func _ready() -> void:
	# Use call_deferred to ensure all other autoloads have finished their _ready().
	call_deferred("_initialize")

func _initialize() -> void:
	WorldSvc = get_node("/root/WorldSvc")
	if not WorldSvc:
		push_error("ActionPrimitiveHandler: WorldSvc not found.")
		set_process(false)
		return
	print("ActionPrimitiveHandler initialized.")


## Executes the logic for an NPC picking up an item.
func execute_pickup_item(npc_ai: NPCAI, target_item_id: int) -> void:
	if not is_instance_valid(npc_ai): return
	
	# To pick something up, it must be removed from its container in the world.
	# We update the "ground truth" in the WorldManager by setting its location to null.
	WorldSvc.set_entity_state(target_item_id, "is_at", null)
	
	print("ActionPrimitiveHandler: Item %d removed from world location." % target_item_id)
	
	# The NPCAI will handle adding the item to its internal inventory belief.


## Executes the logic for an NPC eating an item.
func execute_eat(npc_ai: NPCAI, target_item_id: int) -> void:
	if not is_instance_valid(npc_ai): return
	
	# When an item is eaten, it is permanently removed from the simulation.
	var item_node = WorldSvc.get_entity_by_id(target_item_id)
	if is_instance_valid(item_node):
		# Unregister it from the world state first.
		WorldSvc.unregister_entity(item_node)
		# Then, remove it from the scene tree.
		item_node.queue_free()
		print("ActionPrimitiveHandler: Item %d consumed and removed from simulation." % target_item_id)
	
	# The NPCAI will handle updating its needs and internal beliefs.
