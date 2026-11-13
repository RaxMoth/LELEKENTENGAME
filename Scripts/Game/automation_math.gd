## Pure rules behind the lab's automation: what the ingredient hopper still
## has to feed for a recipe, which ripe plant the cellar's auto picker goes
## to next, when a motor jams, and what a crafter (the lab's hand) does next.
##
##   AutomationMath.get_missing_ingredients([&"glowcap", &"sugarsalt"], [&"glowcap"])   # [&"sugarsalt"]
##   AutomationMath.find_nearest(picker_position, plant_positions, ripe_flags)            # index or -1
##   AutomationMath.rolls_jam(randf(), 0.15, runs_since_jam, 2)                           # the motor stuck?
##   AutomationMath.pick_crew_task(has_jam, has_waiting_gauge, has_bag, stash_has_room)   # CrewTask
##
## Dependencies: none
class_name AutomationMath
extends RefCounted

## What a crafter does next in the lab (most urgent first).
enum CrewTask { NONE, UNJAM, STOP_GAUGE, CARRY_BAG }


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


## True when a motor that just finished jams: only every so often
## ([param min_runs_between] clean runs since the last jam at least), and
## then when [param roll] (0..1) falls under [param chance].
static func rolls_jam(roll: float, chance: float, runs_since_jam: int, min_runs_between: int) -> bool:
	if runs_since_jam < min_runs_between:
		return false
	return roll < chance


## The crafter's next job: free a jammed machine first (it holds up the
## whole line), then stop a skill check nobody is running (a station
## without a motor), then carry a packed bag to the stash (when it fits).
static func pick_crew_task(has_jam: bool, has_waiting_gauge: bool, has_bag: bool, stash_has_room: bool) -> CrewTask:
	if has_jam:
		return CrewTask.UNJAM
	if has_waiting_gauge:
		return CrewTask.STOP_GAUGE
	if has_bag and stash_has_room:
		return CrewTask.CARRY_BAG
	return CrewTask.NONE
