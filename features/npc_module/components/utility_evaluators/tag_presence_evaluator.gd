## tag_presence_evaluator.gd
## A concrete implementation of UtilityEvaluator that calculates utility based on the presence
## and strength of a specific Tag on the NPC.
## Higher utility is generally associated with the tag being present and stronger.
class_name TagPresenceEvaluator extends UtilityEvaluator

## Overrides the base _evaluate method to assess utility based on a specific tag's presence and strength.
##
## Parameters:
## - npc_blackboard_snapshot: A Dictionary containing a snapshot of the NPC's current state (from NPCBlackboard).
## Returns:
## - float: The calculated utility score based on the target tag's presence and strength, scaled by the evaluator's multiplier.
func _evaluate(npc_blackboard_snapshot: Dictionary) -> float:
	if not npc_blackboard_snapshot.has("active_tags"):
		push_warning("TagPresenceEvaluator: NPCBlackboard snapshot does not contain 'active_tags'. Cannot evaluate.")
		return 0.0

	var active_tags: Dictionary = npc_blackboard_snapshot["active_tags"]

	if not active_tags.has(target_id):
		# If the tag is not present, its "strength" is 0.0.
		# Apply inversion if needed, then curve, then multiplier.
		var evaluated_value: float = _apply_inversion(0.0)
		var final_utility: float = _apply_curve_or_passthrough(evaluated_value)
		return final_utility * multiplier

	var tag_strength: float = active_tags[target_id]
	var evaluated_value: float = _apply_inversion(tag_strength)
	var final_utility: float = _apply_curve_or_passthrough(evaluated_value)

	return final_utility * multiplier
