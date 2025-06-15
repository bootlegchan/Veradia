# AIManager.gd

# The central controller for all NPC AI simulations.
class_name AIManager
extends Node

# --- Manager References ---
var EntitySvc: Node

# --- AI State ---
var _npc_ai_instances: Dictionary = {}
var _goap_planner: GOAPPlanner
var _all_generic_actions: Array = []

# --- Configuration ---
var _replan_timer: Timer
const REPLAN_INTERVAL_SECONDS: float = 1.0


func _ready() -> void:
	EntitySvc = get_node("/root/EntitySvc")
	if not EntitySvc:
		push_error("AIManager: EntitySvc not found! AI cannot function.")
		set_process(false)
		return

	await EntitySvc.ready

	_goap_planner = GOAPPlanner.new()
	_cache_all_actions()

	_replan_timer = Timer.new()
	add_child(_replan_timer)
	_replan_timer.wait_time = REPLAN_INTERVAL_SECONDS
	_replan_timer.timeout.connect(_on_replan_timer_timeout)
	_replan_timer.start()
	
	print("AIManager initialized.")


func _cache_all_actions() -> void:
	if EntitySvc.has_method("get_all_action_definitions"):
		_all_generic_actions = EntitySvc.get_all_action_definitions().values()
		print("AIManager: Cached %d generic actions." % _all_generic_actions.size())
	else:
		push_error("AIManager: EntitySvc is missing 'get_all_action_definitions' method.")


func register_npc_ai(npc_ai: NPCAI) -> void:
	var instance_id = npc_ai.get_instance_id()
	if not _npc_ai_instances.has(instance_id):
		_npc_ai_instances[instance_id] = npc_ai
		print("AIManager: Registered NPC '%s' (ID: %s)." % [npc_ai.definition.entity_name, instance_id])


func unregister_npc_ai(npc_ai: NPCAI) -> void:
	var instance_id = npc_ai.get_instance_id()
	if _npc_ai_instances.has(instance_id):
		_npc_ai_instances.erase(instance_id)


func _on_replan_timer_timeout() -> void:
	for npc_ai in _npc_ai_instances.values():
		if npc_ai.is_idle():
			_find_new_plan_for_npc(npc_ai)


func _find_new_plan_for_npc(npc_ai: NPCAI) -> void:
	var highest_utility_goal: GOAPGoalDefinition = null
	if npc_ai.has_tag("TAG_HUNGRY"):
		highest_utility_goal = EntitySvc.get_goal_definition("EatFood")

	if not highest_utility_goal: return

	print("AIManager: NPC '%s' selected goal: '%s'" % [npc_ai.definition.entity_name, highest_utility_goal.goal_id])
	var current_world_state = npc_ai.get_world_state_knowledge()
	var plan: Array = _goap_planner.find_plan(current_world_state, highest_utility_goal.preconditions, _all_generic_actions, npc_ai.get_memory())

	if not plan.is_empty():
		print("AIManager: Plan found for '%s':" % npc_ai.definition.entity_name)
		for action in plan: print("  - %s" % action.action_id)
		npc_ai.set_new_plan(highest_utility_goal, plan)
	else:
		print("AIManager: Failed to find a plan for '%s' to achieve goal '%s'." % [npc_ai.definition.entity_name, highest_utility_goal.goal_id])
		npc_ai.clear_plan()


## Returns the dictionary of all active NPCAI instances.
## Used by PerceptionManager to iterate through all NPCs that need to perceive.
func get_all_npc_ai_instances() -> Dictionary:
	return _npc_ai_instances
