## npc_memory.gd
## Manages an NPC's dynamic, limited, and elastic knowledge of the world.
## This is the sole source of "beliefs" about the external world for the NPC.
## It relies on the parent NPCAI for access to personality traits and cognitive biases.
class_name NPCMemory extends RefCounted

## Dictionary of known facts, keyed by unique fact identifiers (e.g., entity ID + fact type).
var _known_facts: Dictionary = {}
## Dictionary of known relationships with other NPCs, keyed by their instance IDs.
var _known_relationships: Dictionary = {}
## Dictionary to track trust levels for different information sources, keyed by source ID.
var _source_trust: Dictionary = {}

## Reference to the parent NPCAI instance. Used to query personality traits and cognitive biases.
var _parent_npc_ai: NPCAI

## Fact decay rates, can be influenced by personality or tags.
var _fact_decay_rates: Dictionary = {
	"default": 0.001, # Default decay rate per minute
	"LOW_IMPORTANCE": 0.005
}

## Initializes the NPC's memory system.
##
## Parameters:
## - parent_npc_ai: The NPCAI instance that owns this memory. Used to query dynamic NPC properties.
func _init(parent_npc_ai: NPCAI):
	_parent_npc_ai = parent_npc_ai
	if not _parent_npc_ai:
		push_error("NPCMemory: Parent NPCAI reference is null during initialization.")

## Stores a new fact or updates an existing one in memory.
## Handles conflict resolution, certainty calculation, and emotional impact.
##
## Parameters:
## - fact: The KnownFact.gd object to add or update.
func add_fact(fact: KnownFact):
	if not fact or fact.fact_id.is_empty():
		push_warning("NPCMemory: Attempted to add an invalid or empty fact.")
		return

	var existing_fact: KnownFact = _known_facts.get(fact.fact_id)

	if existing_fact:
		# Conflict resolution: Combine or override based on certainty, source, etc.
		# For now, a simple update, potentially averaging certainty or taking the higher.
		# This is where _calculate_incoming_fact_certainty would be used.
		# For simplicity, we'll just update for now.
		existing_fact.certainty = max(existing_fact.certainty, fact.certainty) # Take higher certainty
		existing_fact.timestamp = Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system()) # Update timestamp
		# TODO: Implement more sophisticated conflict resolution based on source trust and biases
		print("NPCMemory: Fact '%s' updated. New certainty: %f" % [fact.fact_id, existing_fact.certainty])
	else:
		_known_facts[fact.fact_id] = fact
		# Initial certainty can be influenced by biases right at perception/addition
		fact.certainty = _calculate_incoming_fact_certainty(fact)
		print("NPCMemory: Fact '%s' added. Certainty: %f" % [fact.fact_id, fact.certainty])

	# TODO: Trigger emotional impact based on fact
	# TODO: Update dynamic source trust based on accuracy of past information from source

## Calculates the actual certainty of an incoming fact, influenced by NPC's cognitive biases and personality.
##
## Parameters:
## - fact: The incoming KnownFact to evaluate.
## Returns:
## - float: The final certainty score (0.0-1.0) after applying internal modifiers.
func _calculate_incoming_fact_certainty(fact: KnownFact) -> float:
	var base_certainty = fact.certainty # Starting from the initial certainty provided by PerceptionManager

	if not _parent_npc_ai:
		return base_certainty # Cannot apply biases if parent is null or not fully initialized.

	var personality_state: Dictionary = _parent_npc_ai._personality_state
	var active_cognitive_biases: Dictionary = _parent_npc_ai._active_cognitive_biases
	# Access EntityManager through the parent NPCAI's reference
	var entity_manager: EntityManager = _parent_npc_ai._entity_manager 

	# Apply influence from cognitive biases
	for bias_id in active_cognitive_biases:
		var bias_def = entity_manager.get_cognitive_bias(bias_id)
		if bias_def and bias_def.has_method("get_influence_on_fact_certainty"):
			var influence_map = bias_def.get_influence_on_fact_certainty()
			if influence_map.has(fact.fact_type): # Check for bias specific to fact type
				base_certainty += influence_map[fact.fact_type]
			elif influence_map.has("default"): # Apply default bias if no specific match
				base_certainty += influence_map["default"]

	# Apply influence from personality traits (e.g., skeptical trait reduces certainty)
	# This requires PersonalityTraitDefinition to have an influence_on_fact_certainty.
	# Placeholder for future implementation.
	# for trait_id in personality_state:
	#	var trait_def = entity_manager.get_personality_trait_definition(trait_id)
	#	if trait_def and trait_def.has_method("get_influence_on_fact_certainty"):
	#		var influence_map = trait_def.get_influence_on_fact_certainty()
	#		if influence_map.has(fact.fact_type):
	#			base_certainty += influence_map[fact.fact_type] * personality_state[trait_id]

	return clamp(base_certainty, 0.0, 1.0)

## Ticks the memory, causing facts and relationships to decay over time.
##
## Parameters:
## - minutes_passed: The number of game minutes that have passed since the last tick.
## - active_tags: The dictionary of active tags on the NPC (used to modify decay rates).
func tick(minutes_passed: int, active_tags: Dictionary):
	# Decay facts
	var facts_to_remove: Array = []
	for fact_id in _known_facts:
		var fact: KnownFact = _known_facts[fact_id]
		var decay_rate = _fact_decay_rates.get(fact.importance, _fact_decay_rates["default"])

		# Apply tag influences to decay rate (e.g., "forgetful" tag increases decay)
		for tag_id in active_tags:
			# This would require TagDefinition to have an influence_on_memory_decay property.
			# For now, it's a placeholder.
			# var tag_def = _entity_manager.get_tag_definition(tag_id)
			# if tag_def and tag_def.influence_on_memory_decay.has(fact.fact_type):
			# 	decay_rate += tag_def.influence_on_memory_decay[fact.fact_type] * active_tags[tag_id]
			pass

		fact.certainty = max(0.0, fact.certainty - (decay_rate * minutes_passed))

		if fact.certainty <= 0.05: # Threshold for forgetting a fact
			facts_to_remove.append(fact_id)

	for fact_id in facts_to_remove:
		_known_facts.erase(fact_id)
		print("NPCMemory: Fact '%s' forgotten due to decay." % fact_id)

	# TODO: Decay relationships (MemoryRelation.gd)

## Retrieves a known fact by its ID.
##
## Parameters:
## - fact_id: The unique ID of the fact.
## Returns:
## - KnownFact: The KnownFact object, or null if not found.
func get_fact(fact_id: String) -> KnownFact:
	return _known_facts.get(fact_id)

## Checks if the NPC knows a specific location.
##
## Parameters:
## - location_id: The ID of the location.
## Returns:
## - bool: True if the NPC knows the location, false otherwise.
func knows_location(location_id: String) -> bool:
	# Implement logic to check if a fact about this location exists and has sufficient certainty.
	# Example: check for fact_type "LEARNED_LOCATION" and location_id in its data.
	# This requires a standardized fact_id generation or searching through facts.
	return false # Placeholder

## Retrieves a list of known entities of a specific type.
##
## Parameters:
## - entity_type: The type of entity (e.g., "ITEM", "BUILDING", "NPC").
## Returns:
## - Array[int]: An array of instance IDs of known entities.
func get_known_entities_by_type(entity_type: String) -> Array[int]:
	# This would require facts to store entity instance IDs and types,
	# and be queryable by these properties.
	return [] # Placeholder

## Retrieves the best known entity of a specific type (e.g., closest, highest quality).
## This would require more sophisticated fact data and sorting logic.
func get_best_known_entity_of_type(entity_type: String) -> int:
	return 0 # Placeholder instance ID

## Retrieves the relationship data with another NPC.
func get_relationship_with(target_npc_id: int):
	return _known_relationships.get(target_npc_id)

## Retrieves relationships of a specific type (e.g., "FRIEND", "ENEMY").
func get_relationship_by_type(relation_type: String) -> Array:
	return [] # Placeholder

## Generates a GOAP-compatible world_state dictionary based only on sufficiently certain known facts.
## This is the NPC's subjective view of the world.
##
## Returns:
## - Dictionary: The NPC's current world state for GOAP planning.
func get_memory_based_world_state() -> Dictionary:
	var world_state: Dictionary = {}

	# Example: Populate 'has_item_apple' based on memory
	# This assumes there's a specific fact type or ID for item presence in inventory.
	# For initial integration, we defer this to NPCAI's direct state for simplicity
	# as per current design (_update_blackboard already handles it).
	# This function would be more critical if memory was the *only* source for all blackboard data.
	# Given _update_blackboard already pulls from NPCAI's direct internal states,
	# this function might be adapted to *filter* that data based on certainty, or
	# add derived facts from memory that aren't direct internal states (e.g., "kitchen_is_clean").

	return world_state
