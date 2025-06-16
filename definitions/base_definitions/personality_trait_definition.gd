## personality_trait_definition.gd
## Defines a personality trait for an NPC.
## These resources are loaded by EntityManager.
class_name PersonalityTraitDefinition extends DefinitionBase

## A human-readable name for the trait.
@export var trait_name: String = ""
## A dictionary containing influence multipliers for various game aspects.
## The keys could be things like "goal_utility_anger" or "action_cost_socialize",
## allowing traits to have wide-ranging, data-driven effects on AI behavior.
@export var influence_multipliers: Dictionary = {}
