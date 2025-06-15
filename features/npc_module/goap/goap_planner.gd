## goap_planner.gd
## Implements the Goal-Oriented Action Planning (GOAP) algorithm.
## This class is responsible for finding a sequence of GOAP actions that can transform
## an initial world state into a desired goal state using a variation of A* search.
class_name GOAPPlanner extends RefCounted

## Represents a node in the A* search graph.
## Contains the current world state, the action taken to reach this state,
## the parent node, and cost metrics (g_cost, h_cost, f_cost).
class PlannerNode extends RefCounted:
	var state: Dictionary         # The world state at this node.
	var action_id: String         # The ID of the action taken to reach this state from parent.
	var parent: PlannerNode       # Reference to the parent node.
	var g_cost: float             # Cost from the start node to this node.
	var h_cost: float             # Heuristic cost from this node to the goal.
	var f_cost: float             # g_cost + h_cost (total estimated cost).

	## Constructor for PlannerNode.
	func _init(state_dict: Dictionary, action_id_str: String = "", parent_node: PlannerNode = null, g: float = 0.0, h: float = 0.0):
		state = state_dict.duplicate(true) # Deep copy the state dictionary
		action_id = action_id_str
		parent = parent_node
		g_cost = g
		h_cost = h
		f_cost = g_cost + h_cost

## Finds a plan (a sequence of action IDs) to achieve a desired goal from an initial world state.
##
## Parameters:
## - initial_world_state: A Dictionary representing the current known state of the world (from NPCBlackboard snapshot).
## - goal_preconditions: A Dictionary representing the desired conditions for the goal to be achieved.
## - all_actions: A Dictionary of GOAPActionDefinition resources, keyed by their action_id.
##                This allows efficient lookup of actions during planning. The planner operates
##                solely on this provided data, adhering to the principle of thread-safe snapshots.
## Returns:
## - Array[String]: An array of GOAPActionDefinition IDs representing the plan, or an empty array if no plan is found.
func find_plan(initial_world_state: Dictionary, goal_preconditions: Dictionary, all_actions: Dictionary) -> Array:
	if _check_preconditions_met(initial_world_state, goal_preconditions):
		# Goal already achieved, no plan needed.
		return []

	var open_set: Array[PlannerNode] = [] # Nodes to be evaluated. Implemented as a min-heap for efficiency.
	var closed_set: Dictionary = {} # Nodes already evaluated. Key: state hash, Value: PlannerNode.

	var start_node = PlannerNode.new(initial_world_state, "", null, 0.0, _calculate_heuristic(initial_world_state, goal_preconditions))
	_add_to_open_set(open_set, start_node)

	# came_from is not strictly needed if parent is stored in PlannerNode, but can be useful for debugging path reconstruction.
	# var came_from: Dictionary = {} # Key: node, Value: parent node. Used to reconstruct path.
	var final_node: PlannerNode = null

	while not open_set.is_empty():
		var current_node: PlannerNode = _pop_from_open_set(open_set)

		# If the current state meets the goal preconditions, we found a plan.
		if _check_preconditions_met(current_node.state, goal_preconditions):
			final_node = current_node
			break

		# Add current node to closed set.
		closed_set[_hash_state(current_node.state)] = current_node

		# Explore neighbors (possible actions)
		for action_id in all_actions:
			var action_def: GOAPActionDefinition = all_actions[action_id]
			# Check if the action's preconditions are met in the current_node's state
			if _check_preconditions_met(current_node.state, action_def.preconditions):
				var next_state = _apply_action_effects(current_node.state, action_def.effects)
				var next_state_hash = _hash_state(next_state)

				if closed_set.has(next_state_hash):
					continue # This state has already been evaluated

				var tentative_g_cost = current_node.g_cost + action_def.cost

				var next_node: PlannerNode = null
				# Check if this state is already in the open set with a higher cost
				var existing_node_in_open_set: PlannerNode = _get_node_from_open_set(open_set, next_state_hash)

				if existing_node_in_open_set != null:
					if tentative_g_cost < existing_node_in_open_set.g_cost:
						# Found a shorter path to an already discovered state
						next_node = existing_node_in_open_set
						next_node.g_cost = tentative_g_cost
						next_node.f_cost = next_node.g_cost + next_node.h_cost
						next_node.action_id = action_def.action_id
						next_node.parent = current_node
						# Re-sort open set to reflect updated cost
						_resort_open_set(open_set)
				else:
					# New state, create a new node
					next_node = PlannerNode.new(next_state, action_def.action_id, current_node,
												tentative_g_cost, _calculate_heuristic(next_state, goal_preconditions))
					_add_to_open_set(open_set, next_node)

				# if next_node != null: # came_from not used for path reconstruction in this version
				#	came_from[next_node] = current_node # Store path for reconstruction

	if final_node != null:
		return _reconstruct_path(final_node)
	else:
		return [] # No plan found

## Checks if all preconditions in 'required_state' are met in 'current_state'.
## This method is publicly accessible because AIWorkerThread also uses it for goal selection validation.
##
## Parameters:
## - current_state: The current world state as a Dictionary.
## - required_state: The preconditions to check, as a Dictionary.
## Returns:
## - bool: True if all required conditions are met, false otherwise.
func _check_preconditions_met(current_state: Dictionary, required_state: Dictionary) -> bool:
	for key in required_state:
		# If the key is not in the current state, or the value doesn't match, preconditions are not met.
		if not current_state.has(key) or current_state[key] != required_state[key]:
			return false
	return true

## Applies the effects of an action to a given state to produce a new state.
##
## Parameters:
## - current_state: The state before the action.
## - effects: The effects of the action as a Dictionary.
## Returns:
## - Dictionary: The new state after applying the effects.
func _apply_action_effects(current_state: Dictionary, effects: Dictionary) -> Dictionary:
	var new_state = current_state.duplicate(true) # Deep copy to avoid modifying original
	for key in effects:
		new_state[key] = effects[key]
	return new_state

## Calculates a heuristic cost (estimated cost to reach the goal) for a given state.
## This is a simple count of unmet preconditions.
##
## Parameters:
## - state: The current world state.
## - goal_preconditions: The desired goal state.
## Returns:
## - float: The heuristic cost.
func _calculate_heuristic(state: Dictionary, goal_preconditions: Dictionary) -> float:
	var unmet_conditions = 0.0
	for key in goal_preconditions:
		if not state.has(key) or state[key] != goal_preconditions[key]:
			unmet_conditions += 1.0
	return unmet_conditions

## Reconstructs the path (sequence of actions) from the final node back to the start.
##
## Parameters:
## - final_node: The PlannerNode that reached the goal.
## Returns:
## - Array[String]: The ordered list of action IDs.
func _reconstruct_path(final_node: PlannerNode) -> Array:
	var path: Array = []
	var current = final_node
	while current != null and not current.action_id.is_empty(): # Stop at the start node (which has no action_id)
		path.insert(0, current.action_id)
		current = current.parent
	return path

## Hashes a dictionary state to use as a key in the closed set.
## Note: This simple hashing might cause collisions for complex states.
## For robust production, consider a more sophisticated deep hash or
## custom comparison for PlannerNode objects if dictionaries contain complex nested structures.
## For now, converting to JSON string is a straightforward way to hash dictionary content.
##
## Parameters:
## - state_dict: The dictionary state to hash.
## Returns:
## - String: A string representation of the state.
func _hash_state(state_dict: Dictionary) -> String:
	# Convert dictionary to a sorted JSON string for consistent hashing.
	# Sort keys to ensure consistent order regardless of dictionary iteration order.
	var sorted_keys = state_dict.keys()
	sorted_keys.sort()
	var sorted_dict = {}
	for key in sorted_keys:
		sorted_dict[key] = state_dict[key]
	return JSON.stringify(sorted_dict)

## Adds a node to the open set (min-heap), maintaining sorted order by f_cost.
##
## Parameters:
## - open_set: The array representing the min-heap.
## - node: The PlannerNode to add.
func _add_to_open_set(open_set: Array, node: PlannerNode):
	# Simple insertion sort for now, for larger sets a proper heap implementation would be faster.
	var inserted = false
	for i in range(open_set.size()):
		if node.f_cost < open_set[i].f_cost:
			open_set.insert(i, node)
			inserted = true
			break
	if not inserted:
		open_set.append(node)

## Removes and returns the node with the lowest f_cost from the open set.
##
## Parameters:
## - open_set: The array representing the min-heap.
## Returns:
## - PlannerNode: The node with the lowest f_cost.
func _pop_from_open_set(open_set: Array) -> PlannerNode:
	if open_set.is_empty():
		return null
	return open_set.pop_front() # Assumes open_set is always sorted, so front is lowest f_cost

## Retrieves a node from the open set by its state hash.
##
## Parameters:
## - open_set: The array representing the min-heap.
## - state_hash: The hash of the state to find.
## Returns:
## - PlannerNode: The found node, or null if not present.
func _get_node_from_open_set(open_set: Array, state_hash: String) -> PlannerNode:
	for node in open_set:
		if _hash_state(node.state) == state_hash:
			return node
	return null

## Re-sorts the open set. Called if a node's cost is updated.
## In a proper heap, this would involve a "decrease-key" operation.
## For a simple sorted array, a full sort is easiest.
##
## Parameters:
## - open_set: The array representing the min-heap.
func _resort_open_set(open_set: Array):
	open_set.sort_custom(func(a, b): return a.f_cost < b.f_cost)
