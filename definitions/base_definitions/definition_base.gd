## definition_base.gd
## A foundational base class for all data definition resources in the game.
## It standardizes the presence of a unique identifier ('id') for all definitions,
## enabling generic, polymorphic handling by the EntityManager and other systems.
class_name DefinitionBase extends Resource

## The unique, standardized identifier for this definition.
## All other definitions (GOAPGoal, Item, NPC, etc.) will inherit and use this property.
@export var id: String = ""
