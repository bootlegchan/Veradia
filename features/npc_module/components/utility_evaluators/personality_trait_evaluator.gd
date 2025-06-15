## personality_trait_evaluator.gd
## A concrete implementation of UtilityEvaluator that calculates utility based on the level of a specific PersonalityTrait.
## Higher utility is generally associated with higher trait levels.
class_name PersonalityTraitEvaluator extends UtilityEvaluator

## Overrides the base _evaluate method to assess utility based on a personality trait's level.
##
## Parameters:
## - npc_blackboard_snapshot: A Dictionary containing a snapshot of the NPC's current state (from NPCBlackboard).
## Returns:
## - float: The calculated utility score based on the target trait's current level, scaled by the evaluator's multiplier.
func _evaluate(npc_blackboard_snapshot: Dictionary) -> float:
	if not npc_blackboard_snapshot.has("personality_state"):
		push_warning("PersonalityTraitEvaluator: NPCBlackboard snapshot does not contain 'personality_state'. Cannot evaluate.")
		return 0.0

	var personality_state: Dictionary = npc_blackboard_snapshot["personality_state"]

	if not personality_state.has(target_id):
		push_warning("PersonalityTraitEvaluator: Target trait ID '%s' not found in NPC's personality state. Cannot evaluate." % target_id)
		return 0.0

	var trait_level: float = personality_state[target_id]
	var evaluated_value: float = _apply_inversion(trait_level)
	var final_utility: float = _apply_curve_or_passthrough(evaluated_value)

	return final_utility * multiplier
