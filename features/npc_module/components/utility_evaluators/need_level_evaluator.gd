## need_level_evaluator.gd
## A concrete implementation of UtilityEvaluator that calculates utility based on the level of a specific GranularNeed.
## Higher utility is generally associated with lower need levels when 'invert_value' is true (e.g., more hungry -> higher utility to eat).
class_name NeedLevelEvaluator extends UtilityEvaluator

## Overrides the base _evaluate method to assess utility based on a granular need's level.
##
## Parameters:
## - npc_blackboard_snapshot: A Dictionary containing a snapshot of the NPC's current state (from NPCBlackboard).
## Returns:
## - float: The calculated utility score based on the target need's current level, scaled by the evaluator's multiplier.
func _evaluate(npc_blackboard_snapshot: Dictionary) -> float:
	if not npc_blackboard_snapshot.has("granular_needs_state"):
		push_warning("NeedLevelEvaluator: NPCBlackboard snapshot does not contain 'granular_needs_state'. Cannot evaluate.")
		return 0.0

	var granular_needs_state: Dictionary = npc_blackboard_snapshot["granular_needs_state"]

	if not granular_needs_state.has(target_id):
		push_warning("NeedLevelEvaluator: Target need ID '%s' not found in NPC's granular needs state. Cannot evaluate." % target_id)
		return 0.0

	var need_level: float = granular_needs_state[target_id]
	var evaluated_value: float = _apply_inversion(need_level)
	var final_utility: float = _apply_curve_or_passthrough(evaluated_value)

	return final_utility * multiplier
