## npc_blackboard.gd
## Provides a centralized, thread-safe, snapshot-able interface for an NPC's
## current internal state data. It is essentially a managed dictionary.
class_name NPCBlackboard extends RefCounted

## The underlying dictionary holding the NPC's state data.
var _data: Dictionary = {}

## Initializes the blackboard from a given snapshot.
## This is useful for restoring a state.
##
## Parameters:
## - snapshot: A dictionary containing the initial state data.
func initialize_from_snapshot(snapshot: Dictionary):
	_data = snapshot.duplicate(true)

## Returns a deep copy of the blackboard's data, ensuring thread safety.
## This snapshot can be passed to other threads (like AIWorkerThread) without
## risking race conditions.
##
## Returns:
## - Dictionary: A deep copy of the internal data dictionary.
func get_snapshot() -> Dictionary:
	return _data.duplicate(true)

## Checks if the blackboard's current state satisfies a given set of conditions.
##
## Parameters:
## - state: A dictionary of key-value pairs representing the conditions to check.
## Returns:
## - bool: True if all conditions are met, false otherwise.
func check_state(state: Dictionary) -> bool:
	for key in state:
		if not _data.has(key) or _data[key] != state[key]:
			return false
	return true

## Retrieves a single piece of data from the blackboard.
##
## Parameters:
## - key: The key of the data to retrieve.
## Returns:
## - Variant: The data associated with the key, or null if not found.
func get_data(key: String):
	return _data.get(key)

## Sets or updates a single piece of data on the blackboard.
##
## Parameters:
## - key: The key of the data to set or update.
## - value: The new value for the given key.
func set_data(key: String, value):
	_data[key] = value
