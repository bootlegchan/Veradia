## tag_definition.gd
## Defines a dynamic modifier tag that can be applied to NPCs or other entities.
## Tags can influence behavior, stats, and relationships.
## These resources are loaded by EntityManager.
class_name TagDefinition extends DefinitionBase

## A human-readable name for the tag.
@export var tag_name: String = ""
## The category of the tag (e.g., "STATE", "RELATIONSHIP", "TEMPORARY_EFFECT").
@export var type: String = ""
## The effect type of the tag, which determines its lifespan.
## PERMANENT: Lasts forever unless removed by a specific action.
## TEMPORARY: Decays over time.
## ELASTIC: Strength changes based on game conditions.
@export var effect_type: String = "" # PERMANENT, TEMPORARY, ELASTIC
