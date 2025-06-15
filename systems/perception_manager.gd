# PerceptionManager.gd
# Simulates NPCs' sensory input.
class_name PerceptionManager
extends Node

var WorldSvc: Node
var AISvc: Node
var _perception_timer: Timer
const PERCEPTION_INTERVAL_SECONDS: float = 2.0

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	WorldSvc = get_node("/root/WorldSvc")
	AISvc = get_node("/root/AISvc")
	if not WorldSvc or not AISvc:
		push_error("PerceptionManager: Required services (WorldSvc, AISvc) not found.")
		set_process(false)
		return
	_perception_timer = Timer.new()
	add_child(_perception_timer)
	_perception_timer.wait_time = PERCEPTION_INTERVAL_SECONDS
	_perception_timer.timeout.connect(_on_perception_timer_timeout)
	_perception_timer.start()
	print("PerceptionManager initialized.")

func _on_perception_timer_timeout() -> void:
	if not AISvc.has_method("get_all_npc_ai_instances"): return
	var all_npcs = AISvc.get_all_npc_ai_instances()
	for npc_ai in all_npcs.values():
		if is_instance_valid(npc_ai):
			_scan_for_npc(npc_ai)

## Simulates what a single NPC can perceive from its current state and location.
func _scan_for_npc(npc_ai: NPCAI) -> void:
	var npc_node = npc_ai.get_parent()
	if not is_instance_valid(npc_node) or not npc_node is Node3D:
		return

	var npc_position = npc_node.global_position
	var perception_range = npc_ai.definition.perception_range
	var perceived_entities = WorldSvc.get_entities_in_range(npc_position, perception_range)
	
	if perceived_entities.is_empty(): return
		
	var perception_count = 0
	for entity_node in perceived_entities:
		if not is_instance_valid(entity_node): continue
		var entity_id = entity_node.get_instance_id()
		if entity_id == npc_node.get_instance_id(): continue
		
		var memory = npc_ai.get_memory()

		if entity_node is Item:
			var item_def = entity_node.definition
			if is_instance_valid(item_def):
				memory.add_fact(KnownFact.new("ENTITY_INFO", entity_id, "entity_type", item_def.entity_type))
				perception_count += 1
		
		var entity_states = WorldSvc.get_all_entity_states(entity_id)
		for state_key in entity_states:
			var state_value = entity_states[state_key]
			
			# DEFINITIVE FIX: When perceiving an "is_at" state, create the correct
			# "ENTITY_LOCATION" fact type that the GOAPPlanner expects.
			if state_key == "is_at":
				memory.add_fact(KnownFact.new("ENTITY_LOCATION", entity_id, "is_at", state_value))
			else:
				# For all other states, create a generic ENTITY_STATE fact.
				memory.add_fact(KnownFact.new("ENTITY_STATE", entity_id, state_key, state_value))
			
			perception_count += 1
	
	if perception_count > 0:
		print("PerceptionSvc: '%s' learned %d new facts about the world." % [npc_ai.definition.entity_name, perception_count])
