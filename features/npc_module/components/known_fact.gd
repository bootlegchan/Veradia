# known_fact.gd

# Represents a single, atomic piece of information that an NPC holds in its memory.
# A fact describes a property or state of a specific entity in the world. This
# is the fundamental building block of an NPC's belief system. All AI decisions
# will be derived from a collection of these facts.
class_name KnownFact
extends RefCounted

# --- Fact Properties ---

# The category or type of fact. This helps organize and query memory.
# Examples: "ENTITY_LOCATION", "ENTITY_STATE", "RELATIONSHIP_STATUS".
var fact_type: String

# The unique instance ID of the entity this fact is about.
var subject_entity_id: int

# The specific property or aspect of the subject this fact describes.
# For an "ENTITY_STATE" fact, this might be "is_locked".
# For an "ENTITY_LOCATION" fact, this might be the location's entity ID.
var key: String

# The value of the fact. This can be any data type.
# For "is_locked", it would be a bool (true/false).
# For location, it could be a Vector3 or an entity ID of the container.
var value: Variant

# The in-game time (in total minutes) when this fact was last updated or confirmed.
# Used to calculate fact decay.
var timestamp: float = 0.0

# The NPC's confidence in the truth of this fact (0.0 to 1.0).
# A fact learned directly (observation) will have high certainty, while a fact
# learned from gossip will have lower certainty. This value decays over time.
var certainty: float = 1.0


## Constructor for creating a new KnownFact instance.
func _init(p_fact_type: String, p_subject_id: int, p_key: String, p_value: Variant, p_certainty: float = 1.0) -> void:
	self.fact_type = p_fact_type
	self.subject_entity_id = p_subject_id
	self.key = p_key
	self.value = p_value
	self.certainty = p_certainty
	
	# If the TimeSvc exists, grab the current time for the timestamp.
	if Engine.has_singleton("TimeSvc"):
		var time_svc = Engine.get_singleton("TimeSvc")
		# We need to get the actual method from the node.
		if time_svc.has_method("get_total_minutes_elapsed"):
			self.timestamp = time_svc.get_total_minutes_elapsed()


## Overrides the base _to_string method to provide a custom, readable output
## for debugging purposes. This is the idiomatic Godot way to make objects
## printable.
func _to_string() -> String:
	return "Fact(Subject: %s, Key: %s, Value: %s, Certainty: %.2f)" % [subject_entity_id, key, str(value), certainty]
