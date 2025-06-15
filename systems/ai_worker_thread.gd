## ai_worker_thread.gd
## Manages a single AI processing thread for offloading computationally intensive tasks
## like GOAP goal selection and plan generation from the main game thread.
class_name AIWorkerThread extends Thread

signal plan_generated(npc_instance_id: int, goal_id: String, plan: Array, blackboard_snapshot: Dictionary)
signal plan_failed(npc_instance_id: int, goal_id: String, reason: String)
signal goal_selected(npc_instance_id: int, goal_id: String)
signal processing_complete(worker_id: int) # Signaled when a task is finished, making the worker available.

## A unique identifier for this worker thread.
var _worker_id: int = -1
## Reference to the EntityManager singleton for accessing definition resources.
var _entity_manager: EntityManager
## An instance of GOAPPlanner for generating action sequences.
var _goap_planner: GOAPPlanner
## A queue for tasks assigned to this worker.
var _task_queue: Array = []
## A flag to indicate if the thread should continue running.
var _should_run: bool = false
## The current task being processed by this worker.
var _current_task: Dictionary = {}

## Initializes the AI worker thread with necessary dependencies.
##
## Parameters:
## - worker_id: A unique ID for this worker.
## - entity_manager: Reference to the global EntityManager.
func _init(worker_id: int, entity_manager: EntityManager):
	_worker_id = worker_id
	_entity_manager = entity_manager
	_goap_planner = GOAPPlanner.new() # Each thread gets its own planner instance for thread safety.

## Starts the thread.
func start_thread():
	_should_run = true
	start(_thread_loop)
	print("AIWorkerThread %d: Started." % _worker_id)

## Stops the thread.
func stop_thread():
	_should_run = false
	wait_to_finish()
	print("AIWorkerThread %d: Stopped." % _worker_id)

## Adds a task to the worker's queue.
##
## Parameters:
## - task_data: A dictionary containing task details (e.g., npc_instance_id, blackboard_snapshot, ongoing_goals).
func add_task(task_data: Dictionary):
	_task_queue.append(task_data)

## The main loop for the worker thread. Processes tasks from the queue.
func _thread_loop():
	while _should_run:
		if not _task_queue.is_empty():
			_current_task = _task_queue.pop_front()
			_process_task(_current_task)
			_current_task = {} # Clear current task after processing
			processing_complete.emit(_worker_id) # Signal availability
		else:
			# Yield to avoid busy-waiting and allow other threads/processes to run.
			# OS.delay_msec is used for non-main thread delays.
			OS.delay_msec(10)

## Processes a single AI task.
## This involves selecting a goal and then finding a plan to achieve it.
##
## Parameters:
## - task_data: The dictionary containing the NPC's state snapshot and ongoing goals.
func _process_task(task_data: Dictionary):
	var npc_instance_id: int = task_data["npc_instance_id"]
	var blackboard_snapshot: Dictionary = task_data["blackboard_snapshot"]
	var ongoing_goals: Array[String] = task_data["ongoing_goals"]

	# DEBUG: Print the full blackboard snapshot received by the worker
	print("DEBUG: AIWorkerThread %d - Received snapshot for NPC %d: %s" % [_worker_id, npc_instance_id, JSON.stringify(blackboard_snapshot, "  ")])

	# Step 1: Select the highest utility goal
	var selected_goal_id: String = _select_highest_utility_goal(blackboard_snapshot, ongoing_goals)

	if selected_goal_id.is_empty():
		plan_failed.emit(npc_instance_id, "", "No suitable goal found.")
		return

	goal_selected.emit(npc_instance_id, selected_goal_id)

	var goal_definition: GOAPGoalDefinition = _entity_manager.get_goap_goal(selected_goal_id)
	if not goal_definition:
		plan_failed.emit(npc_instance_id, selected_goal_id, "Goal definition not found for ID: %s" % selected_goal_id)
		return

	# Step 2: Find a plan for the selected goal
	# Retrieve all GOAP actions from EntityManager as a dictionary.
	# The GOAPPlanner expects a dictionary for efficient action lookup.
	var all_goap_actions_dict: Dictionary = _entity_manager.get_all_goap_actions()
	# Pass the dictionary directly to find_plan.
	# No need to pass EntityManager or NPCMemory as the planner operates on the provided snapshot and actions.
	var plan: Array = _goap_planner.find_plan(blackboard_snapshot, goal_definition.preconditions, all_goap_actions_dict)

	if plan.is_empty():
		plan_failed.emit(npc_instance_id, selected_goal_id, "No plan found to achieve goal: %s" % selected_goal_id)
	else:
		plan_generated.emit(npc_instance_id, selected_goal_id, plan, blackboard_snapshot)

## Selects the highest utility GOAP goal for an NPC based on its current state.
## A goal is only considered if its preconditions are NOT already met in the current state.
##
## Parameters:
## - npc_blackboard_snapshot: A snapshot of the NPC's current internal state.
## - ongoing_goals: An array of IDs of goals the NPC is currently pursuing or has set as long-term.
## Returns:
## - String: The ID of the selected goal, or an empty string if no suitable goal is found.
func _select_highest_utility_goal(npc_blackboard_snapshot: Dictionary, ongoing_goals: Array[String]) -> String:
	var best_goal_id: String = ""
	var highest_utility: float = -INF # Initialize with negative infinity

	var all_goal_definitions: Dictionary = _entity_manager.get_all_goap_goals()

	for goal_id_str in all_goal_definitions:
		var goal_def: GOAPGoalDefinition = all_goal_definitions[goal_id_str]

		var goal_preconditions_met_in_snapshot = _goap_planner._check_preconditions_met(npc_blackboard_snapshot, goal_def.preconditions)

		# Debugging: Print current state of relevant blackboard property for EatFood
		if goal_def.goal_id == "EatFood":
			print("DEBUG: AIWorkerThread %d - Evaluating EatFood Goal. For NPC %d" % [_worker_id, npc_blackboard_snapshot.get("npc_instance_id", -1)])
			print("DEBUG:   Snapshot hunger_satisfied: %s" % npc_blackboard_snapshot.get("hunger_satisfied"))
			print("DEBUG:   Goal preconditions hunger_satisfied: %s" % goal_def.preconditions.get("hunger_satisfied"))
			print("DEBUG:   Goal preconditions met in snapshot: %s" % goal_preconditions_met_in_snapshot)

		# CRITICAL: If the goal's preconditions are already met, this goal is satisfied
		# and should NOT be pursued. Skip it entirely for selection.
		if goal_preconditions_met_in_snapshot:
			print("DEBUG: AIWorkerThread %d - Skipping goal '%s' because preconditions already met for NPC %d." % [_worker_id, goal_def.goal_id, npc_blackboard_snapshot.get("npc_instance_id", -1)])
			continue # Skip this goal, it's already achieved

		var current_utility: float = _calculate_goal_utility(goal_def, npc_blackboard_snapshot)

		# Apply influence from ongoing goals
		for ongoing_goal_id in ongoing_goals:
			var ongoing_goal_def: GOAPGoalDefinition = _entity_manager.get_goap_goal(ongoing_goal_id)
			if ongoing_goal_def and ongoing_goal_def.influence_on_other_goals.has(goal_def.goal_id):
				current_utility += ongoing_goal_def.influence_on_other_goals[goal_def.goal_id]

		# Apply personality trait bonus
		if npc_blackboard_snapshot.has("personality_state"):
			for trait_id in goal_def.relevant_personality_traits:
				if npc_blackboard_snapshot["personality_state"].has(trait_id) and \
				npc_blackboard_snapshot["personality_state"][trait_id] > 0.0: # Check if trait is present
					current_utility += goal_def.trait_pursuit_bonus_multiplier

		# Debugging utility values (optional)
		#print("Goal '%s' utility: %f" % [goal_def.goal_id, current_utility])

		if current_utility > highest_utility:
			highest_utility = current_utility
			best_goal_id = goal_def.goal_id

	return best_goal_id

## Calculates the total utility for a given GOAPGoalDefinition.
## This method iterates through all associated UtilityEvaluators and sums their contributions.
##
## Parameters:
## - goal_definition: The GOAPGoalDefinition to evaluate.
## - npc_blackboard_snapshot: The current state of the NPC as a snapshot.
## Returns:
## - float: The total calculated utility for the goal.
func _calculate_goal_utility(goal_definition: GOAPGoalDefinition, npc_blackboard_snapshot: Dictionary) -> float:
	var total_utility: float = goal_definition.base_importance

	# Evaluate each UtilityEvaluator defined for this goal
	for evaluator_res in goal_definition.utility_evaluators:
		if evaluator_res is UtilityEvaluator:
			total_utility += evaluator_res._evaluate(npc_blackboard_snapshot)
		else:
			push_warning("AIWorkerThread: Invalid utility evaluator resource found for goal '%s'." % goal_definition.goal_id)

	# Apply cognitive bias influence if present in snapshot (from NPCAI)
	if npc_blackboard_snapshot.has("active_cognitive_biases"):
		var active_biases: Dictionary = npc_blackboard_snapshot["active_cognitive_biases"]
		for bias_id in active_biases:
			# NOTE: This assumes CognitiveBiasDefinition exists and can be retrieved by EntityManager
			# and has an 'influence_on_utility_evaluation' property that's a dictionary mapping goal_ids to multipliers.
			var bias_def = _entity_manager.get_cognitive_bias(bias_id)
			if bias_def and bias_def.has_method("get_influence_on_utility_evaluation"): # Defensive check
				var influence_map = bias_def.get_influence_on_utility_evaluation()
				if influence_map.has(goal_definition.goal_id):
					total_utility *= (1.0 + influence_map[goal_definition.goal_id]) # Apply as a multiplier
				elif influence_map.has("default"): # Apply a default influence if specific not found
					total_utility *= (1.0 + influence_map["default"])


	return total_utility

## Retrieves the current number of tasks in the queue.
func get_queue_size() -> int:
	return _task_queue.size()

## Checks if the worker is currently processing a task.
func is_processing() -> bool:
	return not _current_task.is_empty()
