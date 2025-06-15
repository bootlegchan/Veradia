# GOAPPlanner.gd

# Implements a dynamic, memory-driven GOAP planner.
class_name GOAPPlanner
extends RefCounted

class InstantiatedGOAPAction extends GOAPActionDefinition:
	var target_id: int = 0
	var target_location_id: int = 0
	var generic_action: GOAPActionDefinition = null

class AStarNode extends RefCounted:
	var state: Dictionary
	var parent: AStarNode = null
	var action: InstantiatedGOAPAction = null
	var g_score: float = 0.0
	var h_score: float = 0.0
	func get_f_score() -> float: return g_score + h_score

func find_plan(start_state: Dictionary, goal_state: Dictionary, available_actions: Array, memory: NPCMemory) -> Array:
	var open_set: Array[AStarNode] = []
	var closed_set: Array[Dictionary] = []

	var start_node := AStarNode.new()
	start_node.state = start_state
	start_node.h_score = _calculate_heuristic(start_state, goal_state)
	open_set.append(start_node)

	# Generate the list of all possible actions ONCE, before the loop.
	var possible_next_actions = _get_possible_instantiated_actions(available_actions, memory)

	while not open_set.is_empty():
		open_set.sort_custom(func(a, b): return a.get_f_score() < b.get_f_score())
		var current_node: AStarNode = open_set.pop_front()

		if _are_conditions_met(current_node.state, goal_state):
			return _reconstruct_plan(current_node)

		closed_set.append(current_node.state)
		
		for action in possible_next_actions:
			if not _are_conditions_met(current_node.state, action.preconditions):
				continue

			var new_state = _apply_effects(current_node.state, action.effects)
			if new_state in closed_set: continue
				
			var neighbor_node := AStarNode.new()
			neighbor_node.state = new_state
			neighbor_node.parent = current_node
			neighbor_node.action = action
			neighbor_node.g_score = current_node.g_score + action.cost
			neighbor_node.h_score = _calculate_heuristic(new_state, goal_state)
			open_set.append(neighbor_node)
			
	print("GOAPPlanner: No plan found.")
	return []

func _get_possible_instantiated_actions(generic_actions: Array, memory: NPCMemory) -> Array[InstantiatedGOAPAction]:
	var possible_actions: Array[InstantiatedGOAPAction] = []
	for generic_action in generic_actions:
		if not generic_action.target_criteria:
			var simple_action = InstantiatedGOAPAction.new()
			simple_action.preconditions = generic_action.preconditions
			simple_action.effects = generic_action.effects
			simple_action.action_id = generic_action.action_id
			simple_action.cost = generic_action.cost
			simple_action.generic_action = generic_action
			possible_actions.append(simple_action)
			continue

		var potential_target_ids = memory.find_entities_matching_criteria(generic_action.target_criteria)
		for target_id in potential_target_ids:
			var instantiated_action = _resolve_placeholders(generic_action, target_id, memory)
			possible_actions.append(instantiated_action)

	return possible_actions

func _resolve_placeholders(generic_action: GOAPActionDefinition, target_id: int, memory: NPCMemory) -> InstantiatedGOAPAction:
	var inst = InstantiatedGOAPAction.new()
	inst.generic_action = generic_action
	inst.target_id = target_id
	inst.action_id = "%s (target: %s)" % [generic_action.action_id, target_id]
	inst.cost = generic_action.cost

	var location_fact = memory.get_fact("ENTITY_LOCATION", target_id, "is_at")
	
	# DEFINITIVE FIX: Check if the fact and its value are valid before assigning.
	# If the fact exists but its value is null, treat it as 0 (no location).
	inst.target_location_id = location_fact.value if (location_fact and location_fact.value != null) else 0

	inst.preconditions = _replace_dict_placeholders(generic_action.preconditions, inst)
	inst.effects = _replace_dict_placeholders(generic_action.effects, inst)
	
	return inst

func _replace_dict_placeholders(dict: Dictionary, inst_action: InstantiatedGOAPAction) -> Dictionary:
	var new_dict = {}
	for key in dict:
		var new_key = str(key).replace("$target_id", str(inst_action.target_id))
		new_key = new_key.replace("$target_location_id", str(inst_action.target_location_id))

		var value = dict[key]
		var new_value = value
		if value is String:
			new_value = str(value).replace("$target_id", str(inst_action.target_id))
			new_value = new_value.replace("$target_location_id", str(inst_action.target_location_id))
		
		new_dict[new_key] = new_value
	return new_dict

func _reconstruct_plan(goal_node: AStarNode) -> Array:
	var plan: Array[InstantiatedGOAPAction] = []
	var current_node = goal_node
	while current_node.parent != null:
		plan.push_front(current_node.action)
		current_node = current_node.parent
	return plan

func _calculate_heuristic(state: Dictionary, goal: Dictionary) -> float:
	var h: float = 0.0
	for key in goal:
		if not state.has(key) or str(state[key]) != str(goal[key]):
			h += 1.0
	return h

func _are_conditions_met(state: Dictionary, conditions: Dictionary) -> bool:
	for key in conditions:
		if not state.has(key) or str(state[key]) != str(conditions[key]):
			return false
	return true

func _apply_effects(state: Dictionary, effects: Dictionary) -> Dictionary:
	var new_state = state.duplicate(true)
	for key in effects: new_state[key] = effects[key]
	return new_state
