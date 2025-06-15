# EntityDefinition.gd

# The foundational data structure for any object that can exist in the simulation.
# This resource defines the most basic, shared properties of all entities, such
# as their unique ID, name, and type. It serves as the base class for more
# specific definitions like NPCEntityDefinition or ItemDefinition.
# The `from_json` static method is crucial for our data-driven architecture,
# allowing us to create instances of this resource by parsing external JSON files.
class_name EntityDefinition
extends Resource

# --- Core Properties ---
@export var entity_id: String = ""
@export var entity_name: String = ""
@export var entity_type: String = ""
@export var initial_tags: Array[String] = []

# --- Static Factory Method ---

## Creates and populates a new EntityDefinition resource from a dictionary.
static func from_json(data: Dictionary) -> EntityDefinition:
	# Basic validation.
	if not data.has("entity_id") or not data.has("entity_type"):
		push_error("EntityDefinition: Failed to parse. Missing 'entity_id' or 'entity_type'.")
		return null

	# Create a new instance of this resource.
	var definition = EntityDefinition.new()

	# Populate the resource's properties.
	definition.entity_id = data.get("entity_id", "")
	definition.entity_name = data.get("entity_name", definition.entity_id)
	definition.entity_type = data.get("entity_type", "")
	
	# FINAL CORRECTION:
	# The property `definition.initial_tags` is a TypedArray[String].
	# We must populate it from the generic array loaded from JSON.
	var tags_from_json = data.get("initial_tags", [])
	if tags_from_json is Array:
		# Iterate and append each item. The append() method will enforce the
		# String type, preventing incorrect data from being loaded.
		for tag_id in tags_from_json:
			definition.initial_tags.append(tag_id)

	# Perform a final check to ensure the ID is not empty.
	if definition.entity_id.is_empty():
		push_error("EntityDefinition: 'entity_id' cannot be empty.")
		return null
		
	return definition
