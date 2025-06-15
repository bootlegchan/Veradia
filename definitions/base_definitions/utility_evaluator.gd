## UtilityEvaluator.gd
## Inheritable resource for defining how GOAP Goals and Actions are evaluated for utility.
## This serves as a base class for specific utility evaluation logic (e.g., based on needs, traits, or tags).
class_name UtilityEvaluator extends Resource

## The type of evaluator, to be defined by subclasses (e.g., "NeedLevel", "PersonalityTrait", "TagPresence").
## This string identifies the specific logic to be applied.
@export var evaluator_type: String = ""
## An identifier for the specific target of this evaluation (e.g., "HUNGER" for a NeedLevelEvaluator,
## "Gluttonous" for a PersonalityTraitEvaluator, "tag_hungry" for a TagPresenceEvaluator).
@export var target_id: String = ""
## A multiplier applied to the final calculated utility score from this evaluator.
@export var multiplier: float = 1.0
## If true, the input value (e.g., need level) will be inverted before evaluation.
## Useful for needs where lower levels mean higher utility (e.g., low hunger = high utility to eat).
@export var invert_value: bool = false
## Optional: Defines a curve for non-linear utility evaluation based on the input value.
## If not set, a linear evaluation or specific subclass logic will apply.
@export var evaluation_curve: Curve

## Virtual method to be overridden by concrete UtilityEvaluator implementations.
## This method calculates and returns a utility score based on the provided NPC state snapshot.
##
## Parameters:
## - npc_blackboard_snapshot: A Dictionary containing a snapshot of the NPC's current state (from NPCBlackboard).
## Returns:
## - float: The calculated utility score from this evaluator, typically between 0.0 and 1.0,
##          which will then be scaled by the 'multiplier' property.
func _evaluate(npc_blackboard_snapshot: Dictionary) -> float:
	push_error("UtilityEvaluator._evaluate() must be overridden by a concrete implementation.")
	return 0.0

## Applies the evaluation curve if present, otherwise returns the direct value.
##
## Parameters:
## - value: The input value to be evaluated by the curve.
## Returns:
## - float: The value after being processed by the evaluation curve, or the original value if no curve is set.
func _apply_curve_or_passthrough(value: float) -> float:
	if evaluation_curve != null:
		return evaluation_curve.sample(value)
	return value

## Applies inversion if 'invert_value' is true.
##
## Parameters:
## - value: The input value to potentially invert.
## Returns:
## - float: The inverted value (1.0 - value) if 'invert_value' is true, otherwise the original value.
func _apply_inversion(value: float) -> float:
	if invert_value:
		return 1.0 - value
	return value
