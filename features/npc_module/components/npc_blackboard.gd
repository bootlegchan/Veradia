# NPCBlackboard.gd

# A thread-safe data container that provides a snapshot of an NPC's internal state
# and its memory-based view of the world. It is populated by the NPCAI before a
# planning request and provides a deep copy of its data to the AI worker thread.
class_name NPCBlackboard
extends RefCounted

# The internal dictionary holding the NPC's state snapshot.
var _state: Dictionary = {}


## Populates the blackboard with the current state of a given NPCAI node.
## This is the primary way the blackboard is kept up-to-date.
## @param npc_ai: The NPCAI instance to source the data from.
func initialize_from_npc(npc_ai: NPCAI) -> void:
	clear()
	
	if not is_instance_valid(npc_ai):
		push_error("NPCBlackboard: Provided NPCAI instance is not valid.")
		return
	
	# --- Populate from World Knowledge ---
	# This is the most crucial step: the blackboard's world state is now a direct
	# snapshot of the NPC's subjective memory. The planner will see the world
	# exactly as the NPC believes it to be.
	if is_instance_valid(npc_ai._memory):
		self._state = npc_ai._memory.get_memory_based_world_state()
	
	# --- Populate from Internal State ---
	# We still need to add the NPC's internal needs and other non-memory states
	# to the blackboard for the utility system to evaluate.
	
	# Add granular need values.
	for need_id in npc_ai._granular_needs_state:
		var key = "need_%s" % need_id
		var value = npc_ai._granular_needs_state[need_id]
		set_value(key, value)


## Returns a deep copy of the entire state dictionary.
## This is the most critical method for thread safety.
## @return A deep copy of the internal state dictionary.
func get_snapshot() -> Dictionary:
	return _state.duplicate(true)


# --- Helper Methods ---

## Sets a value in the blackboard's state dictionary.
func set_value(key: String, value: Variant) -> void:
	_state[key] = value

## Clears all data from the blackboard.
func clear() -> void:
	_state.clear()
