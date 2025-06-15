## perception_manager.gd
## Simulates NPCs' sensory input, scanning the world and feeding facts about
## the environment into their respective NPCMemory instances.
class_name PerceptionManager extends Node

@onready var _world_manager: WorldManager = get_node("/root/WorldSvc")
@onready var _ai_manager: AIManager = get_node("/root/AISvc")
@onready var _entity_manager: EntityManager = get_node("/root/EntitySvc")

# Preload the KnownFact script to instantiate it.
const KnownFactRef = preload("res://features/npc_module/components/known_fact.gd")

@export var perception_tick_interval: float = 2.0 # How often (in seconds) to run the perception scan
var _tick_accumulator: float = 0.0

## Called when the node enters the scene tree for the first time.
func _ready():
	print("PerceptionManager initialized.")

## Called every frame. Manages the tick rate for perception scans.
func _process(delta: float):
	_tick_accumulator += delta
	if _tick_accumulator >= perception_tick_interval:
		_tick_accumulator = fmod(_tick_accumulator, perception_tick_interval)
		_perform_perception_scan()

## Scans the world from each NPC's perspective and updates their memory with perceived facts.
func _perform_perception_scan():
	var all_npcs = _ai_manager._npc_ai_instances
	if all_npcs.is_empty():
		return

	# This is a global scan for all NPCs. In a large-scale simulation, this would be
	# optimized to only scan for NPCs in active areas (e.g., near the player).
	for npc_instance_id in all_npcs:
		var npc_ai: NPCAI = all_npcs[npc_instance_id]
		if not is_instance_valid(npc_ai):
			continue
		
		var npc_node = npc_ai.get_parent() # Assuming NPCAI is a child of the CharacterBody3D
		if not is_instance_valid(npc_node) or not npc_node is Node3D:
			continue

		var npc_position = npc_node.global_position
		# The perception range should ideally come from the NPC's definition.
		var perception_range = 20.0 

		var entities_in_range = _world_manager.get_entities_in_range(npc_position, perception_range)
		
		if not entities_in_range.is_empty():
			#print("PerceptionSvc: '%s' perceived %d entities." % [npc_ai.name, entities_in_range.size()])
			for entity_node in entities_in_range:
				# Don't perceive self
				if entity_node.get_instance_id() == npc_node.get_instance_id():
					continue
				
				# CRITICAL: Check if the perceived node is a valid game entity with our custom script properties.
				if not ("entity_id_name" in entity_node and "entity_type" in entity_node):
					continue # This is not a game entity we care about (e.g., it's a Marker3D, a light, etc.)

				var fact_id = "entity_loc_%d" % entity_node.get_instance_id()
				var fact_type = "ENTITY_LOCATION"
				var source = "OBSERVATION"
				
				# Populate fact data with relevant information about the perceived entity.
				var entity_data = {
					"instance_id": entity_node.get_instance_id(),
					"entity_id_name": entity_node.entity_id_name,
					"entity_type": entity_node.entity_type,
					"position": entity_node.global_position
				}

				# Create the fact with all required constructor arguments.
				var fact = KnownFactRef.new(fact_id, fact_type, source, entity_data)
				
				npc_ai._npc_memory.add_fact(fact)
