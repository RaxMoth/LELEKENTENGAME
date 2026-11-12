## Pure rules behind the lab's automation: what the ingredient hopper still
## has to feed for a recipe, and which ripe plant the cellar's auto picker
## goes to next.
##
##   AutomationMath.get_missing_ingredients([&"glowcap", &"sugarsalt"], [&"glowcap"])   # [&"sugarsalt"]
##   AutomationMath.find_nearest(picker_position, plant_positions, ripe_flags)            # index or -1
##
## Dependencies: none
class_name AutomationMath
extends RefCounted


## The ingredients of [param recipe_ids] not yet covered by [param present_ids]
## (each present one covers one entry), in the recipe's order.
static func get_missing_ingredients(recipe_ids: Array[StringName], present_ids: Array[StringName]) -> Array[StringName]:
	var unclaimed: Array[StringName] = present_ids.duplicate()
	var missing: Array[StringName] = []
	for ingredient_id: StringName in recipe_ids:
		var present_index: int = unclaimed.find(ingredient_id)
		if present_index >= 0:
			unclaimed.remove_at(present_index)
		else:
			missing.append(ingredient_id)
	return missing


## Index of the candidate nearest [param from] whose flag in [param is_ready]
## is set, or -1 when none is.
static func find_nearest(from: Vector3, candidates: PackedVector3Array, is_ready: Array[bool]) -> int:
	var best_index: int = -1
	var best_distance: float = INF
	for candidate_index: int in mini(candidates.size(), is_ready.size()):
		if not is_ready[candidate_index]:
			continue
		var distance: float = from.distance_squared_to(candidates[candidate_index])
		if distance < best_distance:
			best_distance = distance
			best_index = candidate_index
	return best_index
