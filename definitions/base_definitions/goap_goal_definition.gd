## goap_goal_definition.gd
## Defines the properties and conditions for a GOAP (Goal-Oriented Action Planning) Goal.
## These resources are loaded by EntityManager and used by the GOAPPlanner and NPCAI
## to determine an NPC's desires and motivations.
class_name GOAPGoalDefinition extends Resource

## A unique identifier for this goal definition.
@export var goal_id: String = ""
## A human-readable name for the goal.
@export var goal_name: String = ""
## A dictionary of key-value pairs representing the desired state for this goal to be considered met.
## Example: {"has_item_apple": true, "hunger_satisfied": true}
@export var preconditions: Dictionary = {}
## The base importance of this goal, influencing its initial utility.
@export var base_importance: float = 0.5
## The Maslow's Hierarchy of Needs level this goal is primarily linked to (e.g., "Physiological", "Safety").
## This helps the NPC's AI prioritize goals based on fundamental needs.
@export var linked_maslow_need: String = ""
## True if this is a long-term goal that an NPC might pursue over extended periods or across multiple plans.
@export var is_long_term_goal: bool = false
## A dictionary mapping other goal IDs to utility modifiers. If this goal is active, it can influence
## the utility of other goals.
## Example: {"MaintainHome": 0.2} means if "BuildNewHome" is active, "MaintainHome" might gain 0.2 utility.
@export var influence_on_other_goals: Dictionary = {}
## The minimum economic status required for an NPC to consider pursuing this goal.
@export var min_economic_status_for_pursuit: String = ""
## The minimum social status required for an NPC to consider pursuing this goal.
@export var social_status_for_pursuit: String = ""
## A list of PersonalityTraitDefinition IDs that are relevant to this goal.
## NPCs with these traits might have a higher inclination to pursue this goal.
@export var relevant_personality_traits: Array[String] = []
## A multiplier applied to the goal's utility if any of the 'relevant_personality_traits' are present
## on the NPC.
@export var trait_pursuit_bonus_multiplier: float = 1.0
## An array of UtilityEvaluator resources that define how this goal's utility is dynamically calculated
## based on NPC state (e.g., needs, tags, personality traits).
@export var utility_evaluators: Array[UtilityEvaluator]
