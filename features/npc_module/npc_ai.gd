## npc_ai.gd
## The central AI controller for an individual NPC.
## Manages all core internal states and orchestrates RefCounted AI components.
class_name NPCAI extends Node

## Preload component scripts to ensure their class names are recognized.
const DailyScheduleRef = preload("res://features/npc_module/components/daily_schedule.gd")
const NPCMemoryRef = preload("res://features/npc_module/components/npc_memory.gd")
const NPCBlackboardRef = preload("res://features/npc_module/components/npc_blackboard.gd")

## Signals for observability and integration with global systems.
signal died(npc_instance_id: int)
signal goal_selected(npc_instance_id: int, goal_id: String)
signal action_completed(npc_instance_id: int, action_id: String)
signal need_changed(npc_instance_id: int, need_id: String, new_value: float)
signal tag_changed(npc_instance_id: int, tag_id: String, new_strength: float)
signal inventory_changed(npc_instance_id: int, item_id: String, quantity: int)
signal money_changed(npc_instance_id: int, new_amount: float)

## Immutable reference to this NPC's definition blueprint.
var _definition: NPCEntityDefinition

## Core Internal States (managed directly by NPCAI)
var _current_hp: float = 1.0
var _is_dead: bool = false
var _cause_of_death: String = ""
var _active_injuries: Dictionary = {}
var _active_diseases: Dictionary = {}
var _granular_needs_state: Dictionary = {}
var _maslow_satisfaction_levels: Dictionary = {}
var _current_mood_state: Dictionary = {}
var _skill_levels: Dictionary = {}
var _current_job_id: String = ""
var _possessed_items: Dictionary = {}
var _money: float = 0.0
var _owned_properties: Dictionary = {}
var _reputation_score: float = 0.0
var _active_tags: Dictionary = {}
var _active_cognitive_biases: Dictionary = {}
var _belief_adherence: Dictionary = {}
var _political_office_id: String = ""
var _political_campaign_progress: float = 0.0
var _political_opinion_alignment: Dictionary = {}
var _criminal_record: Dictionary = {}
var _is_under_arrest: bool = false
var _is_incarcerated: bool = false
var _incarceration_release_time: float = 0.0
var _mother_id: String = ""
var _father_id: String = ""
var _genetic_profile: Dictionary = {}
var _personality_state: Dictionary = {}

## AI Components (RefCounted, owned by NPCAI)
var _npc_blackboard: NPCBlackboardRef
var _npc_memory: NPCMemoryRef
var _daily_schedule: DailyScheduleRef

var _current_goal_id: String = ""
var _current_plan: Array = [] # Array of GOAPActionDefinition IDs
var _current_action_index: int = -1
var _is_planning: bool = false
var _action_in_progress: bool = false
var _action_finish_time: float = 0.0

## Global System References (Autoloads)
@onready var _ai_manager: AIManager = get_node("/root/AISvc")
@onready var _entity_manager: EntityManager = get_node("/root/EntitySvc")
@onready var _action_primitive_handler: ActionPrimitiveHandler = get_node("/root/ActionHandlerSvc")
@onready var _time_manager: GlobalTimeManager = get_node("/root/TimeSvc")

## Timers for state updates
var _last_need_tick_minutes: int = 0
var _last_tag_tick_minutes: int = 0
var _last_memory_tick_minutes: int = 0

## Called when the node enters the scene tree for the first time.
func _ready():
	_npc_blackboard = NPCBlackboardRef.new()
	_npc_memory = NPCMemoryRef.new(self)
	_daily_schedule = DailyScheduleRef.new()

	_ai_manager.npc_plan_generated.connect(receive_plan)
	_ai_manager.npc_plan_failed.connect(plan_failed)
	_ai_manager.npc_goal_selected.connect(func(instance_id, goal_id):
		if instance_id == get_instance_id():
			goal_selected.emit(get_instance_id(), goal_id)
	)

## Initializes the NPC AI with its definition and registers with global managers.
func initialize(definition: NPCEntityDefinition):
	print("DEBUG: NPCAI.initialize() called for '%s'." % definition.entity_name)
	_definition = definition
	name = _definition.entity_name
	_current_hp = _definition.initial_physiological_level
	_skill_levels = _definition.initial_skills.duplicate()
	_current_job_id = _definition.initial_job_id
	_possessed_items = _definition.initial_inventory.duplicate()
	_money = _definition.initial_money
	_personality_state = _definition.initial_personality_traits.duplicate()
	_npc_blackboard.set_data("home_entity_id", _definition.home_entity_id)
	_initialize_granular_needs()
	_initialize_tags()
	_initialize_cognitive_biases()
	_daily_schedule.initialize(_definition.schedule_entries)
	_ai_manager.register_npc_ai(self)

## Initializes the NPC's granular needs based on definitions.
func _initialize_granular_needs():
	var all_granular_needs = _entity_manager.get_all_granular_needs()
	for need_id in all_granular_needs:
		_granular_needs_state[need_id] = 0.0
	_last_need_tick_minutes = _time_manager.get_current_total_minutes()

## Initializes the NPC's active tags based on its definition.
func _initialize_tags():
	for tag_id in _definition.initial_tags:
		var tag_def = _entity_manager.get_tag_definition(tag_id)
		if tag_def:
			_active_tags[tag_id] = 1.0
			tag_changed.emit(get_instance_id(), tag_id, 1.0)
	_last_tag_tick_minutes = _time_manager.get_current_total_minutes()

## Initializes the NPC's cognitive biases.
func _initialize_cognitive_biases():
	for bias_id in _definition.initial_cognitive_biases:
		_active_cognitive_biases[bias_id] = true

## The main entry point for the NPC's AI update cycle.
func execute_plan_step(current_total_minutes: int):
	if _is_dead: return

	_tick_internal_states(current_total_minutes)
	
	if _action_in_progress:
		_check_action_completion()
		return
	
	if _is_planning: return

	if _current_plan.is_empty():
		request_new_plan()
	else:
		_execute_current_action()

## Ticks all internal states of the NPC that change over time.
func _tick_internal_states(current_total_minutes: int):
	_tick_granular_needs(current_total_minutes)
	_tick_tags(current_total_minutes)
	_tick_memory(current_total_minutes)

## Updates the NPC's granular needs based on decay rates.
func _tick_granular_needs(current_total_minutes: int):
	var minutes_passed = current_total_minutes - _last_need_tick_minutes
	if minutes_passed <= 0: return

	for need_id in _granular_needs_state:
		var need_def: GranularNeedDefinition = _entity_manager.get_granular_need(need_id)
		if not need_def: continue
		var current_value = _granular_needs_state[need_id]
		var decay_amount = need_def.base_decay_rate * minutes_passed
		var new_value = min(current_value + decay_amount, need_def.max_value)
		if new_value != current_value:
			_granular_needs_state[need_id] = new_value
			need_changed.emit(get_instance_id(), need_id, new_value)
			if need_id == "HUNGER":
				var hungry_tag_id = "tag_hungry"
				var hunger_satisfied_now = new_value <= need_def.satisfaction_threshold
				var tag_was_active = _active_tags.has(hungry_tag_id)
				if not hunger_satisfied_now and not tag_was_active:
					_active_tags[hungry_tag_id] = new_value
					tag_changed.emit(get_instance_id(), hungry_tag_id, new_value)
				elif hunger_satisfied_now and tag_was_active:
					_active_tags.erase(hungry_tag_id)
					tag_changed.emit(get_instance_id(), hungry_tag_id, 0.0)
	_last_need_tick_minutes = current_total_minutes

## Updates the strength of active tags.
func _tick_tags(current_total_minutes: int):
	var minutes_passed = current_total_minutes - _last_tag_tick_minutes
	if minutes_passed <= 0: return

	var tags_to_update = _active_tags.duplicate()
	for tag_id in tags_to_update:
		var tag_def: TagDefinition = _entity_manager.get_tag_definition(tag_id)
		if not tag_def:
			if tag_id != "tag_hungry":
				push_warning("NPCAI %d: Tag definition for ID '%s' not found during tick." % [get_instance_id(), tag_id])
			continue
		if tag_def.effect_type == "TEMPORARY":
			var current_strength = _active_tags[tag_id]
			var decay_rate = 0.005
			var new_strength = max(0.0, current_strength - (decay_rate * minutes_passed))
			if new_strength <= 0.01:
				_active_tags.erase(tag_id)
				tag_changed.emit(get_instance_id(), tag_id, 0.0)
			else:
				_active_tags[tag_id] = new_strength
				tag_changed.emit(get_instance_id(), tag_id, new_strength)
	_last_tag_tick_minutes = current_total_minutes

## Ticks the NPC's memory, applying fact and relationship decay.
func _tick_memory(current_total_minutes: int):
	var minutes_passed = current_total_minutes - _last_memory_tick_minutes
	if minutes_passed <= 0: return
	_npc_memory.tick(minutes_passed, _active_tags)
	_last_memory_tick_minutes = current_total_minutes
	
## Checks if the current timed action has finished.
func _check_action_completion():
	if Time.get_ticks_msec() >= _action_finish_time:
		_action_in_progress = false
		_action_finish_time = 0.0
		_current_action_index += 1
		# After a timed action, we immediately try to execute the next action in the plan.
		_execute_current_action()

## Requests a new plan from the AIManager.
func request_new_plan():
	_is_planning = true
	_current_goal_id = ""
	_current_plan.clear()
	_current_action_index = -1
	_reset_transient_blackboard_state()
	var scheduled_activity = _daily_schedule.get_scheduled_activity(_time_manager.get_current_game_hour())
	var scheduled_goal_id = scheduled_activity.get("goal_id", "")
	var location_key = scheduled_activity.get("location_id_key", "")
	if not location_key.is_empty():
		var location_id = _npc_blackboard.get_data(location_key)
		if location_id: _npc_blackboard.set_data("goal_location", location_id)
		else: push_warning("NPCAI: Scheduled location key '%s' not found on blackboard." % location_key)
	_update_blackboard()
	_ai_manager.request_plan_for_npc(get_instance_id(), scheduled_goal_id)

## Resets temporary GOAP state flags from the blackboard.
func _reset_transient_blackboard_state():
	var transient_keys = ["is_wandering", "is_relaxing", "at_location"]
	for key in transient_keys:
		if _npc_blackboard.get_data(key) != null:
			_npc_blackboard.set_data(key, false)

## Receives a new plan from the AIManager.
func receive_plan(npc_instance_id: int, goal_id: String, plan: Array):
	if npc_instance_id != get_instance_id(): return
	_is_planning = false
	_current_goal_id = goal_id
	_current_plan = plan
	_current_action_index = 0

## Handles the failure of plan generation.
func plan_failed(npc_instance_id: int, goal_id: String, reason: String):
	if npc_instance_id != get_instance_id(): return
	_is_planning = false
	_current_goal_id = ""
	_current_plan.clear()
	_current_action_index = -1
	push_warning("NPC '%s': Plan failed for goal '%s'. Reason: %s" % [name, goal_id, reason])

## Executes the current action in the plan.
func _execute_current_action():
	if _current_action_index >= _current_plan.size():
		_finish_current_goal()
		return
	var action_id: String = _current_plan[_current_action_index]
	var action_def: GOAPActionDefinition = _entity_manager.get_goap_action(action_id)
	if not action_def:
		_fail_current_goal("Action definition missing.")
		return
	print("%s executes action: %s" % [name, action_id])
	action_completed.emit(get_instance_id(), action_id)
	var primitive_success = true
	var combined_outcome_data = {}
	for primitive_data in action_def.primitive_operations:
		var result = _action_primitive_handler.execute_primitive(self, primitive_data)
		if not result["success"]:
			primitive_success = false
			push_warning("NPC '%s': Primitive '%s' failed for action '%s'." % [name, primitive_data.get("type", ""), action_id])
			break
		for key in result["outcome_data"]:
			combined_outcome_data[key] = result["outcome_data"][key]
	if primitive_success:
		_apply_action_effects(action_def, combined_outcome_data)
		if not _action_in_progress:
			_current_action_index += 1
			_update_blackboard()
			var goal_def = _entity_manager.get_goap_goal(_current_goal_id)
			if goal_def and _npc_blackboard.check_state(goal_def.preconditions):
				_finish_current_goal()
	else:
		_apply_action_failure_effects(action_def)
		_fail_current_goal("Primitive operation failed.")

## Applies the effects of a successfully completed action to the NPC's internal state.
func _apply_action_effects(action_def: GOAPActionDefinition, outcome_data: Dictionary):
	for key in action_def.effects: _apply_generic_effect(key, action_def.effects[key])
	for key in action_def.success_effects: _apply_generic_effect(key, action_def.success_effects[key])
	if outcome_data.has("consumption_effects"):
		for need_id in outcome_data["consumption_effects"]:
			_adjust_granular_need(need_id, outcome_data["consumption_effects"][need_id])
	if outcome_data.has("action_duration"):
		var duration_seconds = outcome_data["action_duration"]
		_action_in_progress = true
		_action_finish_time = Time.get_ticks_msec() + (duration_seconds * 1000)

## Applies effects based on a key-value pair, modifying internal and blackboard states.
func _apply_generic_effect(key: String, value):
	_npc_blackboard.set_data(key, value)
	match key:
		"hunger_satisfied":
			if value == true:
				_adjust_granular_need("HUNGER", -_granular_needs_state.get("HUNGER", 0.0))
				print("NPC '%s' is no longer hungry." % name)
		"has_item_apple":
			if value == false: remove_item_from_inventory("item_apple", 1)
		"is_wandering", "is_relaxing", "at_location":
			pass
		_:
			push_warning("NPCAI: Unhandled generic effect key '%s'." % key)

## Applies effects defined for action failure.
func _apply_action_failure_effects(action_def: GOAPActionDefinition):
	for key in action_def.failure_effects: _apply_generic_effect(key, action_def.failure_effects[key])

## Called when the current goal is successfully completed.
func _finish_current_goal():
	print("NPC '%s' finished plan to achieve goal: %s" % [name, _current_goal_id])
	_current_goal_id = ""
	_current_plan.clear()
	_current_action_index = -1

## Called when the current goal cannot be achieved.
func _fail_current_goal(reason: String):
	push_warning("NPC '%s': Goal '%s' failed. Reason: %s" % [name, _current_goal_id, reason])
	_current_goal_id = ""
	_current_plan.clear()
	_current_action_index = -1
	_is_planning = false

## Updates the NPC's blackboard with its current internal state.
func _update_blackboard():
	_npc_blackboard.set_data("current_hp", _current_hp)
	_npc_blackboard.set_data("granular_needs_state", _granular_needs_state.duplicate(true))
	_npc_blackboard.set_data("active_tags", _active_tags.duplicate(true))
	_npc_blackboard.set_data("personality_state", _personality_state.duplicate(true))
	_npc_blackboard.set_data("possessed_items", _possessed_items.duplicate(true))
	_npc_blackboard.set_data("money", _money)
	_npc_blackboard.set_data("is_dead", _is_dead)
	_npc_blackboard.set_data("current_job_id", _current_job_id)
	_npc_blackboard.set_data("npc_instance_id", get_instance_id())
	var hunger_def = _entity_manager.get_granular_need("HUNGER")
	if hunger_def and _granular_needs_state.has("HUNGER"):
		_npc_blackboard.set_data("hunger_satisfied", _granular_needs_state["HUNGER"] <= hunger_def.satisfaction_threshold)
	_npc_blackboard.set_data("has_item_apple", _possessed_items.has("item_apple") and _possessed_items["item_apple"] > 0)
	var search_criteria = {"entity_id_name": "item_apple", "sort_by": "NEAREST"}
	var nearest_food_fact: KnownFact = _npc_memory.get_best_known_entity_fact(search_criteria)
	if nearest_food_fact:
		_npc_blackboard.set_data("nearest_food_item", nearest_food_fact.data["instance_id"])
	else:
		if _npc_blackboard.get_data("nearest_food_item") != null:
			_npc_blackboard.set_data("nearest_food_item", null)

## Returns a snapshot of the NPC's blackboard.
func get_blackboard_snapshot() -> NPCBlackboard: return _npc_blackboard
## Returns the list of ongoing goal IDs for this NPC.
func get_ongoing_goal_ids() -> Array[String]: return _definition.initial_ongoing_goal_ids.duplicate()
## Adds an item to the NPC's inventory.
func add_item_to_inventory(item_id: String, quantity: int):
	var current_quantity = _possessed_items.get(item_id, 0)
	_possessed_items[item_id] = current_quantity + quantity
	inventory_changed.emit(get_instance_id(), item_id, _possessed_items[item_id])
## Removes an item from the NPC's inventory.
func remove_item_from_inventory(item_id: String, quantity: int) -> bool:
	var current_quantity = _possessed_items.get(item_id, 0)
	if current_quantity >= quantity:
		_possessed_items[item_id] = current_quantity - quantity
		if _possessed_items[item_id] <= 0: _possessed_items.erase(item_id)
		inventory_changed.emit(get_instance_id(), item_id, _possessed_items.get(item_id, 0))
		return true
	return false
## Adjusts a granular need's value.
func _adjust_granular_need(need_id: String, adjustment: float):
	if not _granular_needs_state.has(need_id): return
	var need_def: GranularNeedDefinition = _entity_manager.get_granular_need(need_id)
	if not need_def: return
	var current_value = _granular_needs_state[need_id]
	var new_value = clamp(current_value + adjustment, 0.0, need_def.max_value)
	if new_value != current_value:
		_granular_needs_state[need_id] = new_value
		need_changed.emit(get_instance_id(), need_id, new_value)
		if need_id == "HUNGER":
			var hungry_tag_id = "tag_hungry"
			var hunger_satisfied_now = new_value <= need_def.satisfaction_threshold
			var tag_was_active = _active_tags.has(hungry_tag_id)
			if not hunger_satisfied_now and not tag_was_active:
				_active_tags[hungry_tag_id] = new_value
				tag_changed.emit(get_instance_id(), hungry_tag_id, new_value)
			elif hunger_satisfied_now and tag_was_active:
				_active_tags.erase(hungry_tag_id)
				tag_changed.emit(get_instance_id(), hungry_tag_id, 0.0)

## Called when the node is about to be removed from the scene tree.
func _exit_tree():
	if _ai_manager: _ai_manager.unregister_npc_ai(self)
	print("NPC '%s' (ID: %d) exited tree." % [name, get_instance_id()])
