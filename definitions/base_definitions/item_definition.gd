## item_definition.gd
## Defines the properties for various items in the game world.
## These resources are loaded by EntityManager.
class_name ItemDefinition extends EntityDefinition

## The category of the item (e.g., "Food", "Tool", "Currency").
@export var item_category: String = ""
## The base monetary value of the item.
@export var base_value: float = 0.0
## True if multiple instances of this item can be stacked in inventory.
@export var stackable: bool = true
## True if owning or using this item is considered illegal.
@export var is_illegal: bool = false
## A dictionary defining the effects on an NPC's granular needs upon consumption.
## Keys are granular need IDs (e.g., "HUNGER", "THIRST"), values are the change in need level.
## Example: {"HUNGER": -0.8, "THIRST": -0.1} would reduce hunger by 0.8 and thirst by 0.1.
@export var consumption_effects: Dictionary = {}
## True if this item is a natural resource that can regenerate over time.
@export var is_renewable: bool = false
## The time in minutes for a renewable item to regenerate at its source.
@export var regeneration_time_minutes: float = 0.0
