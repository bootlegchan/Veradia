## npc_entity_definition.gd
## Defines the blueprint for an Non-Player Character (NPC) entity.
## This resource extends EntityDefinition with NPC-specific attributes
## and initial states.
class_name NPCEntityDefinition extends EntityDefinition

## The initial health/physiological level of the NPC when spawned (0.0-1.0).
@export var initial_physiological_level: float = 1.0
## The initial mood state of the NPC as a dictionary (e.g., {"Happy": 0.8, "Stressed": 0.2}).
@export var initial_mood_state: Dictionary = {}
## The initial skill levels of the NPC as a dictionary (e.g., {"Cooking": 5, "Social": 3}).
@export var initial_skills: Dictionary = {}
## The ID of the NPC's initial job, if any.
@export var initial_job_id: String = ""
## The initial items the NPC possesses in their inventory as a dictionary
## (e.g., {"item_apple": 2, "item_money": 50}).
@export var initial_inventory: Dictionary = {}
## The initial amount of money the NPC has.
@export var initial_money: float = 0.0
## The initial personality trait values of the NPC as a dictionary, mapping trait_id to value (0.0-1.0).
## Example: {"trait_gluttonous": 0.7, "trait_brave": 0.3}
@export var initial_personality_traits: Dictionary = {}

## An array of ScheduleEntry resources defining the NPC's default daily routine.
@export var schedule_entries: Array[ScheduleEntry] = []

## An array of GOAPGoalDefinition IDs that the NPC will try to pursue from the start,
## or which are considered inherent desires.
@export var initial_ongoing_goal_ids: Array[String] = []
## A pool of GOAPGoalDefinition IDs that this NPC type is capable of pursuing as long-term goals.
@export var potential_ongoing_goal_ids: Array[String] = []
## The maximum number of long-term goals an NPC can be actively pursuing simultaneously.
@export var max_active_ongoing_goals: int = 1
## An array of CognitiveBiasDefinition IDs that are initially active for this NPC.
@export var initial_cognitive_biases: Array[String] = []
## The entity ID of the NPC's initial home or primary residence.
@export var home_entity_id: String = ""
