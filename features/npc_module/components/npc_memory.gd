# npc_memory.gd

# Manages an NPC's subjective knowledge of the world through a collection of
# KnownFact objects. This component is the sole source of "beliefs" for the NPC,
# forming the basis for all its decisions. The GOAP planner will query this memory
# to understand what the NPC *thinks* is true about the world.
class_name NPCMemory
extends RefCounted

const MIN_CERTAINTY_THRESHOLD = 0.2

var _known_facts: Dictionary = {}
var _owner_npc: NPCAI

func _init(owner: NPCAI) -> void:
	self._owner_npc = owner

func add_fact(new_fact: KnownFact) -> void:
	var fact_key = _generate_fact_key(new_fact)
	_known_facts[fact_key] = new_fact

func remove_fact(fact_type: String, subject_id: int, key: String) -> void:
	var fact_key = "%s_%s_%s" % [fact_type, subject_id, key]
	if _known_facts.has(fact_key):
		_known_facts.erase(fact_key)

func _generate_fact_key(fact: KnownFact) -> String:
	return "%s_%s_%s" % [fact.fact_type, fact.subject_entity_id, fact.key]

func get_fact(fact_type: String, subject_id: int, key: String) -> KnownFact:
	var fact_key = "%s_%s_%s" % [fact_type, subject_id, key]
	var fact: KnownFact = _known_facts.get(fact_key)
	if fact and fact.certainty >= MIN_CERTAINTY_THRESHOLD:
		return fact
	return null

func find_entities_matching_criteria(criteria: Dictionary) -> Array[int]:
	var potential_entities: Dictionary = {}
	for fact in _known_facts.values():
		if fact.certainty < MIN_CERTAINTY_THRESHOLD: continue
		potential_entities[fact.subject_entity_id] = true

	var final_matches: Array[int] = []
	for entity_id in potential_entities.keys():
		if _does_entity_match(entity_id, criteria):
			final_matches.append(entity_id)
	return final_matches

func _does_entity_match(entity_id: int, criteria: Dictionary) -> bool:
	if criteria.has("tags"):
		for required_tag in criteria.get("tags", []):
			var fact = get_fact("ENTITY_STATE", entity_id, "has_tag_%s" % required_tag)
			if not fact or not fact.value: return false
	if criteria.has("entity_type"):
		var fact = get_fact("ENTITY_INFO", entity_id, "entity_type")
		if not fact or fact.value != criteria.get("entity_type"): return false
	if criteria.has("has_state"):
		for key in criteria.get("has_state", {}):
			var fact = get_fact("ENTITY_STATE", entity_id, key)
			if not fact or fact.value != criteria["has_state"][key]: return false
	return true

## Generates a world state dictionary for the GOAP planner based on memory.
func get_memory_based_world_state() -> Dictionary:
	var world_state: Dictionary = {}
	if not is_instance_valid(_owner_npc): return world_state

	var self_id = _owner_npc.get_instance_id()

	# Process all facts to build the state
	for fact in _known_facts.values():
		if fact.certainty < MIN_CERTAINTY_THRESHOLD: continue

		match fact.fact_type:
			"ENTITY_STATE":
				# Generic state: state_1001_is_on = true
				world_state["state_%s_%s" % [fact.subject_entity_id, fact.key]] = fact.value
			"NPC_STATE":
				if fact.subject_entity_id == self_id:
					# Own state: state_npc_is_at_home = true
					# Own location: location_npc = 2001
					if fact.key == "is_at_location":
						world_state["location_npc"] = fact.value
					else:
						world_state["state_npc_%s" % fact.key] = fact.value
			"ITEM_IN_INVENTORY":
				# Inventory state: npc_has_item_1001 = true
				if fact.subject_entity_id == self_id:
					world_state["npc_has_item_%s" % fact.value] = true
			"ENTITY_LOCATION":
				# Location of other entities: location_1001 = 2001
				world_state["location_%s" % fact.subject_entity_id] = fact.value

	# Add active tags
	for tag_id in _owner_npc._active_tags:
		world_state["has_tag_%s" % tag_id] = true

	return world_state

func tick_memory_decay(minutes_passed: float) -> void:
	if minutes_passed <= 0: return
	# Future implementation.
