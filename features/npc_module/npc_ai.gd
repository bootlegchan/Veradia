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
## Granular needs state, e.g., {"HUNGER": 0.5, "SLEEP": 0.2}
var _granular_needs_state: Dictionary = {}
## Overall Maslow needs satisfaction derived from granular needs. (Future use)
var _maslow_satisfaction_levels: Dictionary = {}
## Current mood state, e.g., {"Happy": 0.8, "Stressed": 0.2} (Future use)
var _current_mood_state: Dictionary = {}
## Skill levels, e.g., {"Cooking": 5, "Social": 3}
var _skill_levels: Dictionary = {}
var _current_job_id: String = ""
## Items possessed by the NPC, e.g., {"apple": 3, "money": 100.0}
var _possessed_items: Dictionary = {}
var _money: float = 0.0
var _owned_properties: Dictionary = {}
var _reputation_score: float = 0.0
## Active tags influencing NPC, e.g., {"tag_hungry": 0.8, "tag_injured": 0.5}
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
## Personality traits state, e.g., {"trait_gluttonous": 0.7}
var _personality_state: Dictionary = {}

## AI Components (RefCounted, owned by NPCAI)
var _npc_blackboard: NPCBlackboardRef
var _npc_memory: NPCMemoryRef
var _daily_schedule: DailyScheduleRef

var _current_goal_id: String = ""
var _current_plan: Array = [] # Array of GOAPActionDefinition IDs
var _current_action_index: int = -1
var _is_planning: bool = false

## Global System References (Autoloads)
@onready var _ai_manager: AIManager = get_node("/root/AIManager")
@onready var _entity_manager: EntityManager = get_node("/root/EntityManager")
@onready var _world_manager: WorldManager = get_node("/root/WorldManager")
@onready var _action_primitive_handler: ActionPrimitiveHandler = get_node("/root/ActionPrimitiveHandler")
@onready var _time_manager: GlobalTimeManager = get_node("/root/GlobalTimeManager")

## Timers for state updates
var _last_need_tick_minutes: int = 0
var _last_tag_tick_minutes: int = 0
var _last_memory_tick_minutes: int = 0

## Called when the node enters the scene tree for the first time.
func _ready():
	# Instantiate RefCounted components.
	# NPCMemory needs a reference to this NPCAI for its internal logic
	# that depends on NPCAI's personality and biases.
	_npc_blackboard = NPCBlackboardRef.new()
	_npc_memory = NPCMemoryRef.new(self)
	_daily_schedule = DailyScheduleRef.new() # DailySchedule currently requires no args, adjust if needed

	_ai_manager.npc_plan_generated.connect(receive_plan)
	_ai_manager.npc_plan_failed.connect(plan_failed)
	_ai_manager.npc_goal_selected.connect(func(instance_id, goal_id):
		if instance_id == get_instance_id():
			goal_selected.emit(get_instance_id(), goal_id)
	)

## Initializes the NPC AI with its definition and registers with global managers.
## This method is called *after* _ready() by EntityManager.
##
## Parameters:
## - definition: The NPCEntityDefinition resource for this NPC.
func initialize(definition: NPCEntityDefinition):
	_definition = definition
	name = _definition.entity_name # Set node name for easier debugging in scene tree
	_current_hp = _definition.initial_physiological_level
	_skill_levels = _definition.initial_skills.duplicate()
	_current_job_id = _definition.initial_job_id
	_possessed_items = _definition.initial_inventory.duplicate()
	_money = _definition.initial_money
	_personality_state = _definition.initial_personality_traits.duplicate()

	_initialize_granular_needs()
	_initialize_tags()
	_initialize_cognitive_biases()
	# No need to call _npc_memory._init() again; it was handled by .new(self) in _ready().
	# The _npc_memory can now access updated _personality_state and _active_cognitive_biases
	# directly via its _parent_npc_ai reference whenever it needs them.

	_ai_manager.register_npc_ai(self)

## Initializes the NPC's granular needs based on definitions.
func _initialize_granular_needs():
	var all_granular_needs = _entity_manager.get_all_granular_needs()
	for need_id in all_granular_needs:
		# Initially, needs are at 0 (satisfied)
		_granular_needs_state[need_id] = 0.0
	_last_need_tick_minutes = _time_manager.get_current_total_minutes()

## Initializes the NPC's active tags based on its definition.
func _initialize_tags():
	for tag_id in _definition.initial_tags:
		var tag_def = _entity_manager.get_tag_definition(tag_id)
		if tag_def:
			_active_tags[tag_id] = 1.0 # Initial strength (can be defined in TagDef later)
			tag_changed.emit(get_instance_id(), tag_id, 1.0)
	_last_tag_tick_minutes = _time_manager.get_current_total_minutes()

## Initializes the NPC's cognitive biases.
func _initialize_cognitive_biases():
	for bias_id in _definition.initial_cognitive_biases:
		# This assumes CognitiveBiasDefinition exists and can be retrieved by EntityManager
		# For now, just add the ID. Actual bias application will be in utility eval.
		_active_cognitive_biases[bias_id] = true # Or initial strength
		# TODO: Consider if biases have strength or are just boolean active/inactive.

## The main entry point for the NPC's AI update cycle.
## Called by AIManager at a controlled frequency.
##
## Parameters:
## - current_total_minutes: The current total minutes in game time.
func execute_plan_step(current_total_minutes: int):
	if _is_dead:
		return

	_tick_internal_states(current_total_minutes)
	_update_blackboard() # Always update blackboard before any decision or planning request

	if _is_planning:
		# Already waiting for a plan, do nothing.
		return

	if _current_plan.is_empty():
		request_new_plan()
	else:
		_execute_current_action()

## Ticks all internal states of the NPC that change over time.
## This includes granular needs, tags, mood, health, and memory decay.
##
## Parameters:
## - current_total_minutes: The current total minutes in game time.
func _tick_internal_states(current_total_minutes: int):
	_tick_granular_needs(current_total_minutes)
	_tick_tags(current_total_minutes)
	_tick_memory(current_total_minutes)
	# TODO: _tick_mood, _tick_health, etc.

## Updates the NPC's granular needs based on decay rates.
## Also applies related tags like 'tag_hungry'.
##
## Parameters:
## - current_total_minutes: The current total minutes in game time.
func _tick_granular_needs(current_total_minutes: int):
	var minutes_passed = current_total_minutes - _last_need_tick_minutes
	if minutes_passed <= 0:
		return

	for need_id in _granular_needs_state:
		var need_def: GranularNeedDefinition = _entity_manager.get_granular_need(need_id)
		if not need_def:
			push_warning("NPCAI %d: Granular need definition for ID '%s' not found." % [get_instance_id(), need_id])
			continue

		var current_value = _granular_needs_state[need_id]
		var decay_amount = need_def.base_decay_rate * minutes_passed
		var new_value = min(current_value + decay_amount, need_def.max_value)

		if new_value != current_value:
			_granular_needs_state[need_id] = new_value
			need_changed.emit(get_instance_id(), need_id, new_value)
			print("DEBUG: NPCAI %d - Need '%s' changed to %f" % [get_instance_id(), need_id, new_value])

			# Apply/remove associated tags based on need level
			if need_id == "HUNGER": # Example for HUNGER, extend for other needs
				var hungry_tag_id = "tag_hungry"
				var hunger_satisfied_now = new_value <= need_def.satisfaction_threshold
				var tag_was_active = _active_tags.has(hungry_tag_id)

				if not hunger_satisfied_now and not tag_was_active: # Hunger increased above threshold, add tag
					_active_tags[hungry_tag_id] = new_value # Strength can be need value
					tag_changed.emit(get_instance_id(), hungry_tag_id, new_value)
					print("DEBUG: NPCAI %d - Tag '%s' activated with strength %f" % [get_instance_id(), hungry_tag_id, new_value])
				elif hunger_satisfied_now and tag_was_active: # Hunger satisfied, remove tag
					_active_tags.erase(hungry_tag_id)
					tag_changed.emit(get_instance_id(), hungry_tag_id, 0.0) # Strength 0.0 means removed
					print("DEBUG: NPCAI %d - Tag '%s' deactivated." % [get_instance_id(), hungry_tag_id])


	_last_need_tick_minutes = current_total_minutes

## Updates the strength of active tags based on their decay/regeneration rules.
## (Currently, only need-based tag management is implemented. General tag decay/influence is future.)
##
## Parameters:
## - current_total_minutes: The current total minutes in game time.
func _tick_tags(current_total_minutes: int):
	var minutes_passed = current_total_minutes - _last_tag_tick_minutes
	if minutes_passed <= 0:
		return

	# Iterate over a copy to allow modification during iteration
	var tags_to_update = _active_tags.duplicate()
	for tag_id in tags_to_update:
		var tag_def: TagDefinition = _entity_manager.get_tag_definition(tag_id)
		if not tag_def:
			push_warning("NPCAI %d: Tag definition for ID '%s' not found during tick." % [get_instance_id(), tag_id])
			continue

		# Example: simple decay for temporary tags (placeholder for Tag.gd logic)
		# This should use Tag.dynamic_strength_modifiers for complex rules.
		if tag_def.effect_type == "TEMPORARY":
			var current_strength = _active_tags[tag_id]
			var decay_rate = 0.005 # Example decay rate, should come from TagDef
			var new_strength = max(0.0, current_strength - (decay_rate * minutes_passed))
			if new_strength <= 0.01: # Consider tag removed if strength is very low
				_active_tags.erase(tag_id)
				tag_changed.emit(get_instance_id(), tag_id, 0.0)
			else:
				_active_tags[tag_id] = new_strength
				tag_changed.emit(get_instance_id(), tag_id, new_strength)

	_last_tag_tick_minutes = current_total_minutes

## Ticks the NPC's memory, applying fact and relationship decay.
##
## Parameters:
## - current_total_minutes: The current total minutes in game time.
func _tick_memory(current_total_minutes: int):
	var minutes_passed = current_total_minutes - _last_memory_tick_minutes
	if minutes_passed <= 0:
		return
	_npc_memory.tick(minutes_passed, _active_tags) # NPCMemory needs access to active tags for decay modifiers
	_last_memory_tick_minutes = current_total_minutes

## Requests a new plan from the AIManager.
func request_new_plan():
	_is_planning = true
	_current_goal_id = ""
	_current_plan.clear()
	_current_action_index = -1
	print("DEBUG: NPCAI %d - Requesting new plan." % get_instance_id())
	_ai_manager.request_plan_for_npc(get_instance_id())

## Receives a new plan from the AIManager.
## This method is called via `call_deferred` from AIManager on the main thread.
##
## Parameters:
## - npc_instance_id: The instance ID of the NPC for which the plan was generated.
## - goal_id: The ID of the goal the plan is for.
## - plan: An array of GOAPActionDefinition IDs representing the plan.
func receive_plan(npc_instance_id: int, goal_id: String, plan: Array):
	if npc_instance_id != get_instance_id():
		return # Not for this NPC

	_is_planning = false
	_current_goal_id = goal_id
	_current_plan = plan
	_current_action_index = 0
	print("NPC '%s' received plan for goal '%s'. Plan length: %d" % [name, _current_goal_id, _current_plan.size()])

## Handles the failure of plan generation.
## This method is called via `call_deferred` from AIManager on the main thread.
##
## Parameters:
## - npc_instance_id: The instance ID of the NPC for which planning failed.
## - goal_id: The ID of the goal that failed to plan for.
## - reason: The reason for the planning failure.
func plan_failed(npc_instance_id: int, goal_id: String, reason: String):
	if npc_instance_id != get_instance_id():
		return # Not for this NPC

	_is_planning = false
	_current_goal_id = "" # Clear current goal if plan failed
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
		push_error("NPC '%s': Failed to execute action '%s', definition not found." % [name, action_id])
		_fail_current_goal("Action definition missing.")
		return

	print("%s executes action: %s" % [name, action_id])
	action_completed.emit(get_instance_id(), action_id)

	# Execute all primitive operations for the current action
	var primitive_success: bool = true
	var combined_outcome_data: Dictionary = {}

	for primitive_data in action_def.primitive_operations:
		var result = _action_primitive_handler.execute_primitive(self, primitive_data)
		if not result["success"]:
			primitive_success = false
			push_warning("NPC '%s': Primitive '%s' failed for action '%s'." % [name, primitive_data.get("type", ""), action_id])
			break
		# Merge outcome data from primitives
		for key in result["outcome_data"]:
			combined_outcome_data[key] = result["outcome_data"][key]

	if primitive_success:
		_apply_action_effects(action_def, combined_outcome_data)
		_current_action_index += 1
		# After applying effects and before moving to the next action,
		# update the blackboard and re-check if the overall goal is satisfied.
		# This handles cases where a goal might be achieved mid-plan.
		_update_blackboard()
		var goal_def = _entity_manager.get_goap_goal(_current_goal_id)
		if goal_def and _npc_blackboard.check_state(goal_def.preconditions):
			print("NPC '%s': Goal '%s' satisfied mid-plan." % [name, _current_goal_id])
			_finish_current_goal()
	else:
		_apply_action_failure_effects(action_def)
		_fail_current_goal("Primitive operation failed.")

## Applies the effects of a successfully completed action to the NPC's internal state.
##
## Parameters:
## - action_def: The GOAPActionDefinition that was executed.
## - outcome_data: Any additional data returned by primitive operations (e.g., consumption effects).
func _apply_action_effects(action_def: GOAPActionDefinition, outcome_data: Dictionary):
	# Apply general effects defined in the action definition
	for key in action_def.effects:
		var value = action_def.effects[key]
		_apply_generic_effect(key, value)

	# Apply success-specific effects
	for key in action_def.success_effects:
		var value = action_def.success_effects[key]
		_apply_generic_effect(key, value)

	# Apply effects from primitive outcomes (e.g., item consumption)
	if outcome_data.has("consumption_effects"):
		var consumption_effects: Dictionary = outcome_data["consumption_effects"]
		for need_id in consumption_effects:
			var change_amount = consumption_effects[need_id]
			_adjust_granular_need(need_id, change_amount)

## Applies effects based on a key-value pair, modifying internal NPC states.
## This function centralizes how action effects update the NPC's state properties.
##
## Parameters:
## - key: The string identifier for the state to modify (e.g., "hunger_satisfied", "has_item_apple").
## - value: The new value or change amount for the state.
func _apply_generic_effect(key: String, value):
	match key:
		"hunger_satisfied":
			# This is a GOAP state flag, needs to map to actual granular need adjustment
			if value == true:
				_adjust_granular_need("HUNGER", -_granular_needs_state.get("HUNGER", 0.0)) # Set hunger to 0
				print("NPC '%s' is no longer hungry." % name)
		"has_item_apple": # Example: for removing item from inventory when consumed
			if value == false: # Assuming 'has_item_X: false' means item was consumed/removed
				remove_item_from_inventory("item_apple", 1)
		# TODO: Add more generic effect handlers as actions are defined
		# "money_gain":
		# 	_money += value
		# 	money_changed.emit(get_instance_id(), _money)
		# "add_tag":
		# 	if value is String:
		# 		_active_tags[value] = 1.0 # Or specific strength
		# 		tag_changed.emit(get_instance_id(), value, 1.0)
		# "remove_tag":
		# 	if value is String and _active_tags.has(value):
		# 		_active_tags.erase(value)
		# 		tag_changed.emit(get_instance_id(), value, 0.0)
		# Default case for direct state manipulation if needed:
		# _:
		# 	if has_node(key): # For properties on the NPCAI itself
		# 		set(key, value)
		pass

## Applies effects defined for action failure.
##
## Parameters:
## - action_def: The GOAPActionDefinition that failed.
func _apply_action_failure_effects(action_def: GOAPActionDefinition):
	for key in action_def.failure_effects:
		var value = action_def.failure_effects[key]
		# Apply failure-specific effects, e.g., reduce mood, add stress tag
		# _apply_generic_effect(key, value) # Re-use generic effect applier

## Called when the current goal is successfully completed.
func _finish_current_goal():
	print("NPC '%s' finished plan to achieve goal: %s" % [name, _current_goal_id])
	_current_goal_id = ""
	_current_plan.clear()
	_current_action_index = -1

## Called when the current goal cannot be achieved due to action failure or other issues.
##
## Parameters:
## - reason: A string explaining why the goal failed.
func _fail_current_goal(reason: String):
	push_warning("NPC '%s': Goal '%s' failed. Reason: %s" % [name, _current_goal_id, reason])
	_current_goal_id = ""
	_current_plan.clear()
	_current_action_index = -1
	_is_planning = false # Allow new planning cycle

## Updates the NPC's blackboard with its current internal state.
## This snapshot is used for goal selection and planning by the AIWorkerThread.
func _update_blackboard():
	# Always ensure these are deep copies for thread safety
	_npc_blackboard.set_data("current_hp", _current_hp)
	_npc_blackboard.set_data("granular_needs_state", _granular_needs_state.duplicate(true))
	_npc_blackboard.set_data("active_tags", _active_tags.duplicate(true))
	_npc_blackboard.set_data("personality_state", _personality_state.duplicate(true))
	_npc_blackboard.set_data("possessed_items", _possessed_items.duplicate(true))
	_npc_blackboard.set_data("money", _money)
	_npc_blackboard.set_data("is_dead", _is_dead)
	_npc_blackboard.set_data("current_job_id", _current_job_id)
	_npc_blackboard.set_data("npc_instance_id", get_instance_id()) # Add instance ID to blackboard for debug

	# Derived states for GOAP planning (e.g., is hunger satisfied?)
	var hunger_satisfied = false
	var hunger_def = _entity_manager.get_granular_need("HUNGER")
	if hunger_def and _granular_needs_state.has("HUNGER"):
		hunger_satisfied = _granular_needs_state["HUNGER"] <= hunger_def.satisfaction_threshold
	_npc_blackboard.set_data("hunger_satisfied", hunger_satisfied)
	print("DEBUG: NPCAI %d - Blackboard updated. hunger_satisfied: %s (from hunger %f <= threshold %f)" % [get_instance_id(), hunger_satisfied, _granular_needs_state.get("HUNGER", -1.0), hunger_def.satisfaction_threshold])
	
	# Example: check if NPC has a specific item
	_npc_blackboard.set_data("has_item_apple", _possessed_items.has("item_apple") and _possessed_items["item_apple"] > 0)
	
	# Add any other derived states needed for planning preconditions/effects

## Returns a snapshot of the NPC's blackboard for external systems (e.g., AIManager).
func get_blackboard_snapshot() -> NPCBlackboard:
	return _npc_blackboard

## Returns the list of ongoing goal IDs for this NPC.
## (Currently, this is only initial_ongoing_goal_ids from definition, but can become dynamic.)
func get_ongoing_goal_ids() -> Array[String]:
	return _definition.initial_ongoing_goal_ids.duplicate()

## Adds an item to the NPC's inventory.
##
## Parameters:
## - item_id: The ID of the item to add.
## - quantity: The amount of the item to add.
func add_item_to_inventory(item_id: String, quantity: int):
	var current_quantity = _possessed_items.get(item_id, 0)
	_possessed_items[item_id] = current_quantity + quantity
	inventory_changed.emit(get_instance_id(), item_id, _possessed_items[item_id])

## Removes an item from the NPC's inventory.
##
## Parameters:
## - item_id: The ID of the item to remove.
## - quantity: The amount of the item to remove.
## Returns:
## - bool: True if items were successfully removed, false if not enough quantity.
func remove_item_from_inventory(item_id: String, quantity: int) -> bool:
	var current_quantity = _possessed_items.get(item_id, 0)
	if current_quantity >= quantity:
		_possessed_items[item_id] = current_quantity - quantity
		if _possessed_items[item_id] <= 0:
			_possessed_items.erase(item_id)
		inventory_changed.emit(get_instance_id(), item_id, _possessed_items.get(item_id, 0))
		return true
	return false

## Adjusts a granular need's value.
##
## Parameters:
## - need_id: The ID of the granular need (e.g., "HUNGER").
## - adjustment: The amount to add or subtract (negative to reduce need/satisfy, positive to increase need/deplete).
func _adjust_granular_need(need_id: String, adjustment: float):
	if not _granular_needs_state.has(need_id):
		push_warning("NPCAI: Attempted to adjust unknown granular need: %s" % need_id)
		return

	var need_def: GranularNeedDefinition = _entity_manager.get_granular_need(need_id)
	if not need_def:
		push_warning("NPCAI: Granular need definition for ID '%s' not found during adjustment." % need_id)
		return

	var current_value = _granular_needs_state[need_id]
	var new_value = clamp(current_value + adjustment, 0.0, need_def.max_value)
	if new_value != current_value:
		_granular_needs_state[need_id] = new_value
		need_changed.emit(get_instance_id(), need_id, new_value)
		# Re-evaluate tags immediately after adjustment (e.g., tag_hungry)
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
	if _ai_manager:
		_ai_manager.unregister_npc_ai(self)
	print("NPC '%s' (ID: %d) exited tree." % [name, get_instance_id()])
