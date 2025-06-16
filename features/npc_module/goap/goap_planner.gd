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
	func _init(state_dict: Dictionary, p_action_id: String = "", parent_node: PlannerNode = null, g: float = 0.0, h: float = 0.0):
		state = state_dict.duplicate(true) # Deep copy the state dictionary
		action_id = p_action_id
		parent = parent_node
		g_cost = g
		h_cost = h
		f_cost = g_cost + h_cost

## Finds a plan (a sequence of action IDs) to achieve a desired goal from an initial world state.
func find_plan(initial_world_state: Dictionary, goal_preconditions: Dictionary, all_actions: Dictionary) -> Array:
	if _check_preconditions_met(initial_world_state, goal_preconditions):
		return []

	var open_set: Array[PlannerNode] = [] 
	var closed_set: Dictionary = {} 

	var start_node = PlannerNode.new(initial_world_state, "", null, 0.0, _calculate_heuristic(initial_world_state, goal_preconditions))
	_add_to_open_set(open_set, start_node)

	var final_node: PlannerNode = null

	while not open_set.is_empty():
		var current_node: PlannerNode = _pop_from_open_set(open_set)

		if _check_preconditions_met(current_node.state, goal_preconditions):
			final_node = current_node
			break

		closed_set[_hash_state(current_node.state)] = current_node

		for action_id in all_actions:
			var action_def: GOAPActionDefinition = all_actions[action_id]
			if _check_preconditions_met(current_node.state, action_def.preconditions):
				var next_state = _apply_action_effects(current_node.state, action_def.effects)
				var next_state_hash = _hash_state(next_state)

				if closed_set.has(next_state_hash):
					continue

				var tentative_g_cost = current_node.g_cost + action_def.cost
				var existing_node_in_open_set: PlannerNode = _get_node_from_open_set(open_set, next_state_hash)

				if existing_node_in_open_set != null:
					if tentative_g_cost < existing_node_in_open_set.g_cost:
						existing_node_in_open_set.g_cost = tentative_g_cost
						existing_node_in_open_set.f_cost = existing_node_in_open_set.g_cost + existing_node_in_open_set.h_cost
						existing_node_in_open_set.action_id = action_def.id
						existing_node_in_open_set.parent = current_node
						_resort_open_set(open_set)
				else:
					var next_node = PlannerNode.new(next_state, action_def.id, current_node,
												tentative_g_cost, _calculate_heuristic(next_state, goal_preconditions))
					_add_to_open_set(open_set, next_node)

	if final_node != null:
		return _reconstruct_path(final_node)
	else:
		return []

## Checks if all preconditions in 'required_state' are met in 'current_state'.
func _check_preconditions_met(current_state: Dictionary, required_state: Dictionary) -> bool:
	for key in required_state:
		if not current_state.has(key) or current_state[key] != required_state[key]:
			return false
	return true

## Applies the effects of an action to a given state to produce a new state.
func _apply_action_effects(current_state: Dictionary, effects: Dictionary) -> Dictionary:
	var new_state = current_state.duplicate(true)
	for key in effects:
		new_state[key] = effects[key]
	return new_state

## Calculates a heuristic cost (estimated cost to reach the goal) for a given state.
func _calculate_heuristic(state: Dictionary, goal_preconditions: Dictionary) -> float:
	var unmet_conditions = 0.0
	for key in goal_preconditions:
		if not state.has(key) or state[key] != goal_preconditions[key]:
			unmet_conditions += 1.0
	return unmet_conditions

## Reconstructs the path (sequence of actions) from the final node back to the start.
func _reconstruct_path(final_node: PlannerNode) -> Array:
	var path: Array = []
	var current = final_node
	while current != null and not current.action_id.is_empty():
		path.insert(0, current.action_id)
		current = current.parent
	return path

## Hashes a dictionary state to use as a key in the closed set.
func _hash_state(state_dict: Dictionary) -> String:
	var sorted_keys = state_dict.keys()
	sorted_keys.sort()
	var sorted_dict = {}
	for key in sorted_keys:
		sorted_dict[key] = state_dict[key]
	return JSON.stringify(sorted_dict)

## Adds a node to the open set (min-heap), maintaining sorted order by f_cost.
func _add_to_open_set(open_set: Array, node: PlannerNode):
	var inserted = false
	for i in range(open_set.size()):
		if node.f_cost < open_set[i].f_cost:
			open_set.insert(i, node)
			inserted = true
			break
	if not inserted:
		open_set.append(node)

## Removes and returns the node with the lowest f_cost from the open set.
func _pop_from_open_set(open_set: Array) -> PlannerNode:
	if open_set.is_empty(): return null
	return open_set.pop_front()

## Retrieves a node from the open set by its state hash.
func _get_node_from_open_set(open_set: Array, state_hash: String) -> PlannerNode:
	for node in open_set:
		if _hash_state(node.state) == state_hash:
			return node
	return null

## Re-sorts the open set. Called if a node's cost is updated.
func _resort_open_set(open_set: Array):
	open_set.sort_custom(func(a, b): return a.f_cost < b.f_cost)
