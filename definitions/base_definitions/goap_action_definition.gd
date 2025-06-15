## goap_action_definition.gd
## Defines the properties and effects for a GOAP (Goal-Oriented Action Planning) Action.
## These resources are loaded by EntityManager and used by the GOAPPlanner to build plans
## and by NPCAI to execute actions.
class_name GOAPActionDefinition extends Resource

## A unique identifier for this action definition.
@export var action_id: String = ""
## The base cost of performing this action. Higher cost means the planner prefers it less,
## unless it's the only path or highly efficient.
@export var cost: float = 1.0
## A dictionary of key-value pairs representing the conditions that must be true in the
## world state for this action to be considered executable.
## Example: {"has_item_apple": true, "at_location_kitchen": true}
@export var preconditions: Dictionary = {}
## A dictionary of key-value pairs representing the changes this action makes to the
## world state upon successful completion. These are used during planning.
## Example: {"has_item_apple": false, "hunger_satisfied": true}
@export var effects: Dictionary = {}
## A dictionary of key-value pairs representing additional changes if the action succeeds beyond base effects.
## Example: {"skill_cooking_level": 1}
@export var success_effects: Dictionary = {}
## A dictionary of key-value pairs representing changes if the action fails.
## Example: {"mood_frustrated": 0.1}
@export var failure_effects: Dictionary = {}
## An array of dictionaries, each defining a primitive operation to be executed by
## the ActionPrimitiveHandler when this action is performed by an NPC.
## Each dictionary must contain a "type" key (e.g., "CONSUME_ITEM", "MOVE_TO_ENTITY").
## Additional keys depend on the primitive type.
## Example: [{"type": "CONSUME_ITEM", "item_id": "apple"}, {"type": "MOVE_TO_ENTITY", "target_id_key": "location_fridge"}]
@export var primitive_operations: Array[Dictionary] = []
## The ID of a skill (e.g., "Cooking", "Social") that is checked when performing this action.
## The NPC's skill level influences the success chance or outcome.
@export var skill_check: String = ""
## The difficulty of the skill check. Higher values mean a higher skill level is needed for success.
@export var skill_check_difficulty: float = 0.0
## An array of UtilityEvaluator resources that define how this action's utility (or cost) is
## dynamically calculated based on NPC state (e.g., needs, tags, personality traits).
## These can modify the 'cost' or influence the choice between actions.
@export var utility_evaluators: Array[UtilityEvaluator]
## A dictionary mapping other action IDs to utility/cost modifiers. If this action is chosen,
## it can influence the desirability or cost of other actions.
## Example: {"StealItem": -0.1} means if "PickPocket" is chosen, "StealItem" might become slightly cheaper.
@export var influence_on_other_actions: Dictionary = {}
## An array of dictionaries defining potential risks associated with performing this action.
## Each risk can have a "type" (e.g., "discovery"), a "chance" (0.0-1.0), and a "consequence_event" ID
## (e.g., "CrimeDiscovered") to trigger a WorldEvent.
@export var risks: Array[Dictionary] = []
## The ID of a SocialActionDefinition if this GOAPAction involves a direct social interaction.
## This links the action to detailed social rules defined elsewhere.
@export var social_action_id: String = ""
## The expected type of target NPC for social actions (e.g., "NPC_HUMAN"). Used for validation and filtering.
@export var target_npc_type: String = ""
## A specific NPC entity ID if the action targets a predefined NPC.
@export var target_npc_id: String = ""
## The radius around the NPC to search for targets if 'target_npc_id' is not specified.
@export var target_area_radius: float = 0.0
