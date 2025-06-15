# ItemDefinition.gd

# Defines the properties for an Item entity, inheriting from EntityDefinition.
class_name ItemDefinition
extends EntityDefinition

# --- Item-Specific Properties ---
@export var base_value: float = 0.0
@export var stackable: bool = false
@export var is_illegal: bool = false

# --- Static Factory Method ---
static func from_json(data: Dictionary) -> ItemDefinition:
	var base_definition = EntityDefinition.from_json(data)
	if not base_definition:
		return null

	var definition = ItemDefinition.new()
	definition.entity_id = base_definition.entity_id
	definition.entity_name = base_definition.entity_name
	definition.entity_type = base_definition.entity_type
	definition.initial_tags = base_definition.initial_tags

	definition.base_value = data.get("base_value", 0.0)
	definition.stackable = data.get("stackable", false)
	definition.is_illegal = data.get("is_illegal", false)
	
	return definition
