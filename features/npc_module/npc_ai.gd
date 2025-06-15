# NPCAI.gd
# The central orchestrating "brain" for an individual NPC.
class_name NPCAI
extends Node

var definition: NPCEntityDefinition
var EntitySvc: Node
var TimeSvc: Node
var AISvc: Node
var ActionHandlerSvc: Node #<-- ADD THIS

var _granular_needs_state: Dictionary = {}
var _personality_traits: Dictionary = {}
var _active_tags: Dictionary = {}
var _memory: NPCMemory
var _current_goal: GOAPGoalDefinition = null
var _current_plan: Array = []
var _current_action = null
var _action_timer: float = 0.0

func _ready() -> void:
	var parent_node = get_parent()
	if not parent_node is NPC:
		push_error("NPCAI: Parent node is not of type 'NPC'.")
		set_process(false)
		return

	self.definition = parent_node.definition
	if not definition:
		push_error("NPCAI: Parent node's 'definition' property is null!")
		set_process(false)
		return

	# Get all manager references
	EntitySvc = get_node("/root/EntitySvc")
	TimeSvc = get_node("/root/TimeSvc")
	AISvc = get_node("/root/AISvc")
	ActionHandlerSvc = get_node("/root/ActionHandlerSvc") #<-- ADD THIS
	
	_memory = NPCMemory.new(self)
	AISvc.register_npc_ai(self)
	_initialize_from_definition()
	print("NPCAI for '%s' initialized." % definition.entity_name)


func _process(delta: float) -> void:
	var minutes_passed = delta * TimeSvc.minutes_per_real_second
	_tick_needs(minutes_passed)
	_memory.tick_memory_decay(minutes_passed)
	if not is_idle():
		_execute_plan_step(delta)


func _initialize_from_definition() -> void:
	_granular_needs_state = definition.initial_granular_needs.duplicate(true)
	_personality_traits = definition.initial_personality_traits.duplicate(true)
	for tag_id in definition.initial_tags:
		add_tag(tag_id)
	
	var self_id = get_instance_id()
	var starting_location_id = get_parent().start_location_id
	if starting_location_id != 0:
		_memory.add_fact(KnownFact.new("NPC_STATE", self_id, "is_at_location", starting_location_id))


func _tick_needs(minutes_passed: float) -> void:
	if minutes_passed <= 0: return
	for need_id in _granular_needs_state.keys():
		var need_def: GranularNeedDefinition = EntitySvc.get_need_definition(need_id)
		if not need_def: continue
		_granular_needs_state[need_id] -= need_def.base_decay_rate * minutes_passed
		_granular_needs_state[need_id] = clampf(_granular_needs_state[need_id], 0.0, 1.0)
	_apply_or_remove_need_based_tags()


func _execute_plan_step(delta: float) -> void:
	_action_timer += delta
	if _action_timer >= 1.0:
		_action_timer = 0.0
		
		# Execute the action's real-world effect FIRST.
		_execute_primitive_action(_current_action)

		# Then, update internal beliefs about the consequences.
		_apply_action_effects_to_memory(_current_action)
		
		_current_plan.pop_front()
		if not _current_plan.is_empty():
			_current_action = _current_plan.front()
		else:
			_on_plan_finished()


## Calls the appropriate handler in the ActionHandlerSvc to modify world state.
func _execute_primitive_action(action) -> void: # action is InstantiatedGOAPAction
	print("%s executes action: %s" % [definition.entity_name, action.action_id])
	var generic_id = action.generic_action.action_id
	
	if generic_id == "PickupItem":
		ActionHandlerSvc.execute_pickup_item(self, action.target_id)
	elif generic_id == "EAT":
		ActionHandlerSvc.execute_eat(self, action.target_id)
	# Other actions like "MOVE", "DROP", "GIVE" would be handled here.


## Updates the NPC's internal memory to reflect the consequences of an action.
func _apply_action_effects_to_memory(action) -> void:
	for key in action.effects:
		var value = action.effects[key]
		if key.begins_with("npc_has_item_"):
			if value == true:
				_memory.add_fact(KnownFact.new("ITEM_IN_INVENTORY", get_instance_id(), "has", action.target_id))
			else:
				_memory.remove_fact("ITEM_IN_INVENTORY", get_instance_id(), "has")
		elif key.begins_with("state_npc_"):
			var state_key = key.trim_prefix("state_npc_")
			_memory.add_fact(KnownFact.new("NPC_STATE", get_instance_id(), state_key, value))
		elif key.begins_with("location_"):
			# This effect is now handled by the ActionHandlerSvc, but the NPC
			# still needs to update its own memory to know the item is gone.
			_memory.remove_fact("ENTITY_LOCATION", action.target_id, "is_at")


func _on_plan_finished() -> void:
	print("%s finished plan to achieve goal: %s" % [definition.entity_name, _current_goal.goal_id])
	if _current_goal.goal_id == "EatFood":
		_granular_needs_state["HUNGER"] = 1.0
		_memory.add_fact(KnownFact.new("NPC_STATE", get_instance_id(), "has_eaten", false))
		print("%s is no longer hungry." % definition.entity_name)
	clear_plan()


func _apply_or_remove_need_based_tags() -> void:
	if _granular_needs_state.get("HUNGER", 1.0) < 0.3:
		if not has_tag("TAG_HUNGRY"): add_tag("TAG_HUNGRY")
	else:
		if has_tag("TAG_HUNGRY"): remove_tag("TAG_HUNGRY")

func is_idle() -> bool: return _current_goal == null
func get_memory() -> NPCMemory: return _memory
func get_world_state_knowledge() -> Dictionary: return _memory.get_memory_based_world_state()

func set_new_plan(goal: GOAPGoalDefinition, plan: Array) -> void:
	_current_goal = goal
	_current_plan = plan
	_current_action = plan.front() if not plan.is_empty() else null

func clear_plan() -> void:
	_current_goal = null
	_current_plan.clear()
	_current_action = null

func add_tag(tag_id: String):
	if has_tag(tag_id): return
	var tag_def = EntitySvc.get_tag_definition(tag_id)
	if tag_def: _active_tags[tag_id] = tag_def

func remove_tag(tag_id: String): _active_tags.erase(tag_id)
func has_tag(tag_id: String) -> bool: return _active_tags.has(tag_id)
