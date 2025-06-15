## ai_manager.gd
## The central controller for all NPC AI simulations.
## Manages multithreading for AI computation and controls the synchronized tick rates for NPCs.
class_name AIManager extends Node

## Signal emitted when an NPC has selected a new goal.
signal npc_goal_selected(npc_instance_id: int, goal_id: String)
## Signal emitted when an NPC has a new plan generated.
signal npc_plan_generated(npc_instance_id: int, goal_id: String, plan: Array)
## Signal emitted when plan generation fails for an NPC.
signal npc_plan_failed(npc_instance_id: int, goal_id: String, reason: String)

## Reference to the GlobalTimeManager for synchronized ticking (accessed via Autoload name).
@onready var _time_manager: GlobalTimeManager = get_node("/root/TimeSvc")
## Reference to the EntityManager for accessing AI definitions (accessed via Autoload name).
@onready var _entity_manager: EntityManager = get_node("/root/EntitySvc")

## Dictionary to store all active NPCAI instances, keyed by their instance ID.
var _npc_ai_instances: Dictionary = {}
## Array of available AIWorkerThread instances.
var _worker_threads: Array[AIWorkerThread] = []
## Queue for NPCAI instances that need a new plan calculated.
var _planning_queue: Array[int] = []
## A map to track which NPC (by instance ID) is currently being processed by which worker.
var _npc_processing_map: Dictionary = {}

## The number of worker threads to spawn.
@export var num_worker_threads: int = 2
## The base tick rate for AI updates in seconds.
## Each NPC will attempt to update its AI state at this interval if not otherwise throttled.
@export var ai_tick_interval: float = 0.5 # Default to 2 updates per second

## Accumulator for tracking elapsed time for AI ticks.
var _tick_accumulator: float = 0.0

## Called when the node enters the scene tree for the first time.
func _ready():
	_time_manager.time_ticked.connect(_on_time_ticked)
	_initialize_worker_threads()
	print("AIManager initialized.")

## Called every frame.
## Manages the tick rate for AI updates and dispatches planning requests.
func _process(delta: float):
	_tick_accumulator += delta

	# Check if it's time for an AI tick based on the global interval.
	if _tick_accumulator >= ai_tick_interval:
		_tick_accumulator = fmod(_tick_accumulator, ai_tick_interval) # Use fmod for accuracy over long runs
		_perform_ai_tick()

	# Continuously try to assign tasks from the planning queue to available workers.
	_dispatch_planning_tasks()

## Initializes and starts the pool of AI worker threads.
func _initialize_worker_threads():
	for i in range(num_worker_threads):
		var worker = AIWorkerThread.new(i, _entity_manager)
		worker.plan_generated.connect(_on_plan_generated.bind(i))
		worker.plan_failed.connect(_on_plan_failed.bind(i))
		worker.goal_selected.connect(_on_goal_selected.bind(i))
		worker.processing_complete.connect(_on_worker_processing_complete.bind(i))
		_worker_threads.append(worker)
		worker.start_thread()
		print("AIManager: Spawned AIWorkerThread %d." % i)

## Registers an NPCAI instance with the AIManager.
##
## Parameters:
## - npc_ai: The NPCAI instance to register.
func register_npc_ai(npc_ai: NPCAI):
	var instance_id = npc_ai.get_instance_id()
	if _npc_ai_instances.has(instance_id):
		push_warning("AIManager: NPCAI with instance ID %d already registered." % instance_id)
		return

	_npc_ai_instances[instance_id] = npc_ai
	print("AIManager: Registered NPC '%s' (ID: %d)." % [npc_ai.name, instance_id])

## Unregisters an NPCAI instance from the AIManager.
##
## Parameters:
## - npc_ai: The NPCAI instance to unregister.
func unregister_npc_ai(npc_ai: NPCAI):
	var instance_id = npc_ai.get_instance_id()
	if not _npc_ai_instances.has(instance_id):
		push_warning("AIManager: NPCAI with instance ID %d not registered." % instance_id)
		return

	_npc_ai_instances.erase(instance_id)
	_planning_queue.erase(instance_id) # Remove from planning queue if present
	if _npc_processing_map.has(instance_id):
		var worker_id = _npc_processing_map[instance_id]
		# Potentially interrupt worker if it's processing this NPC, or just let it finish and clean up.
		# For simplicity, we assume the worker will finish its current task.
		_npc_processing_map.erase(instance_id)
	print("AIManager: Unregistered NPC '%s' (ID: %d)." % [npc_ai.name, instance_id])

## Adds an NPC's instance ID to the planning queue if it's not already in progress.
##
## Parameters:
## - npc_instance_id: The instance ID of the NPC requiring a new plan.
func request_plan_for_npc(npc_instance_id: int):
	# Only add to queue if not already in queue or being processed
	if not _planning_queue.has(npc_instance_id) and not _npc_processing_map.has(npc_instance_id):
		_planning_queue.append(npc_instance_id)
		#print("AIManager: NPC %d added to planning queue." % npc_instance_id)

## Called by GlobalTimeManager at a regular interval.
## This triggers the main AI tick for all registered NPCs.
##
## Parameters:
## - current_total_minutes: The current total minutes in game time.
func _on_time_ticked(current_total_minutes: int):
	for npc_instance_id in _npc_ai_instances.keys():
		var npc_ai: NPCAI = _npc_ai_instances[npc_instance_id]
		if is_instance_valid(npc_ai): # Ensure NPC still exists
			npc_ai.execute_plan_step(current_total_minutes)
		else:
			# Clean up invalid instances
			_npc_ai_instances.erase(npc_instance_id)
			_planning_queue.erase(npc_instance_id)
			if _npc_processing_map.has(npc_instance_id):
				_npc_processing_map.erase(npc_instance_id)

## Performs the AI tick for all active NPCs, prompting them to update their states
## and potentially request new plans.
func _perform_ai_tick():
	for npc_instance_id in _npc_ai_instances.keys():
		var npc_ai: NPCAI = _npc_ai_instances[npc_instance_id]
		if is_instance_valid(npc_ai):
			# NPC's internal states are ticked here
			# (e.g., needs decay, mood changes, tag updates)
			# The decision to request a plan is made by NPCAI.execute_plan_step()
			pass # Actual state ticking is handled in NPCAI._tick_all_internal_states

## Dispatches planning tasks from the queue to available worker threads.
func _dispatch_planning_tasks():
	if _planning_queue.is_empty():
		return

	for worker in _worker_threads:
		if not worker.is_processing(): # Check if worker is idle
			if not _planning_queue.is_empty():
				var npc_instance_id = _planning_queue.pop_front()
				var npc_ai: NPCAI = _npc_ai_instances.get(npc_instance_id)

				if is_instance_valid(npc_ai):
					# Get a deep copy (snapshot) of the NPC's blackboard data for the worker thread.
					# This is crucial for thread safety, ensuring the worker operates on immutable data.
					var blackboard_snapshot: Dictionary = npc_ai.get_blackboard_snapshot().get_snapshot()
					var task_data = {
						"npc_instance_id": npc_instance_id,
						"blackboard_snapshot": blackboard_snapshot,
						"ongoing_goals": npc_ai.get_ongoing_goal_ids() # Pass relevant data for goal selection
					}
					worker.add_task(task_data)
					_npc_processing_map[npc_instance_id] = worker._worker_id
					#print("AIManager: Dispatched plan request for NPC %d to worker %d." % [npc_instance_id, worker._worker_id])
				else:
					push_warning("AIManager: Attempted to dispatch plan for invalid NPC instance: %d" % npc_instance_id)
					# If NPC is invalid, remove it from processing map if it somehow got there
					if _npc_processing_map.has(npc_instance_id):
						_npc_processing_map.erase(npc_instance_id)
			else:
				break # No more NPCs in queue

## Callback for when an AI worker thread has completed processing a task (either success or failure).
## This frees up the worker for new tasks.
##
## Parameters:
## - worker_id: The ID of the worker that completed processing.
func _on_worker_processing_complete(worker_id: int):
	# Find the NPC that was being processed by this worker and remove it from the map
	var npc_id_to_remove = -1
	for npc_instance_id in _npc_processing_map:
		if _npc_processing_map[npc_instance_id] == worker_id:
			npc_id_to_remove = npc_instance_id
			break
	if npc_id_to_remove != -1:
		_npc_processing_map.erase(npc_id_to_remove)

## Callback for when an AI worker thread successfully generates a plan.
## The plan is then relayed back to the corresponding NPCAI instance on the main thread.
##
## Parameters:
## - worker_id: The ID of the worker thread that generated the plan.
## - npc_instance_id: The instance ID of the NPC for which the plan was generated.
## - goal_id: The ID of the goal for which the plan was generated.
## - plan: The generated sequence of GOAPActionDefinition IDs.
## - blackboard_snapshot: The blackboard snapshot used for planning (can be used for post-plan validation/debugging).
func _on_plan_generated(worker_id: int, npc_instance_id: int, goal_id: String, plan: Array, blackboard_snapshot: Dictionary):
	# All thread results must be processed on the main thread.
	# Using call_deferred ensures this.
	call_deferred("_process_plan_result", npc_instance_id, goal_id, plan, true, "")

## Callback for when an AI worker thread fails to generate a plan.
## The failure is relayed back to the corresponding NPCAI instance on the main thread.
##
## Parameters:
## - worker_id: The ID of the worker thread where planning failed.
## - npc_instance_id: The instance ID of the NPC for which planning failed.
## - goal_id: The ID of the goal for which planning failed (may be empty if no goal was selected).
## - reason: A string explaining why the plan failed.
func _on_plan_failed(worker_id: int, npc_instance_id: int, goal_id: String, reason: String):
	call_deferred("_process_plan_result", npc_instance_id, goal_id, [], false, reason)

## Callback for when an AI worker thread has selected a goal.
##
## Parameters:
## - worker_id: The ID of the worker thread that selected the goal.
## - npc_instance_id: The instance ID of the NPC.
## - goal_id: The ID of the selected goal.
func _on_goal_selected(worker_id: int, npc_instance_id: int, goal_id: String):
	# Emit signal on main thread
	npc_goal_selected.emit(npc_instance_id, goal_id)
	print("AIManager: NPC '%d' selected goal: '%s'" % [npc_instance_id, goal_id])

## Processes the plan generation result (success or failure) on the main thread.
## This function is called via `call_deferred` to ensure thread safety.
##
## Parameters:
## - npc_instance_id: The instance ID of the NPC.
## - goal_id: The ID of the goal.
## - plan: The generated plan (empty array if failed).
## - success: True if plan generation was successful, false otherwise.
## - reason: The reason for failure, if any.
func _process_plan_result(npc_instance_id: int, goal_id: String, plan: Array, success: bool, reason: String):
	var npc_ai: NPCAI = _npc_ai_instances.get(npc_instance_id)
	if is_instance_valid(npc_ai):
		if success:
			npc_ai.receive_plan(npc_instance_id, goal_id, plan) # Pass npc_instance_id as expected by receive_plan
			npc_plan_generated.emit(npc_instance_id, goal_id, plan)
			print("AIManager: Plan found for '%s':" % npc_ai.name)
			for action_id in plan:
				print("  - %s" % _entity_manager.get_goap_action(action_id).action_id) # Print action ID
		else:
			npc_ai.plan_failed(npc_instance_id, goal_id, reason) # Pass npc_instance_id as expected by plan_failed
			npc_plan_failed.emit(npc_instance_id, goal_id, reason)
			print("AIManager: Failed to find a plan for '%s' to achieve goal '%s'. Reason: %s" % [npc_ai.name, goal_id, reason])
	else:
		push_warning("AIManager: Received plan result for invalid NPC instance: %d. Goal: %s" % [npc_instance_id, goal_id])

## Cleans up worker threads when the AIManager is exiting.
func _exit_tree():
	for worker in _worker_threads:
		worker.stop_thread()
	_worker_threads.clear()
	print("AIManager: Exited and stopped all worker threads.")
