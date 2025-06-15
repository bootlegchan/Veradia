## entity_definition.gd
## Base definition for all entities (NPCs, items, buildings).
## These resources are loaded by EntityManager.
class_name EntityDefinition extends Resource

## A unique identifier for this entity definition.
@export var entity_id: String = ""
## A human-readable name for the entity.
@export var entity_name: String = ""
## The category of the entity (e.g., "NPC", "ITEM", "BUILDING").
## This helps in classifying and managing entities.
@export var entity_type: String = ""
## The direct path to the scene file (.tscn) that represents this entity.
## This makes spawning entities purely data-driven and removes fragile path construction logic.
@export var scene_path: String = ""
## An array of TagDefinition IDs that are initially applied to this entity when it's spawned.
@export var initial_tags: Array[String] = []
## An array of WorldEntityState resources. (Future use)
# @export var initial_world_entity_states: Array[WorldEntityState]
