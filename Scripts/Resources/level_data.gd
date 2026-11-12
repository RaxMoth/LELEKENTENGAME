## Definition of one playable level or game mode.
##
## Dependencies: none
class_name LevelData
extends Resource

@export var id: StringName = &""
@export var title: String = "Level"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export_file("*.tscn") var scene_path: String = ""
## Scores needed for 1, 2 and 3 stars (ascending).
@export var star_score_thresholds: Array[int] = [100, 200, 300]
## Endless levels never "win": finishing always counts as completed and stars come from score.
@export var is_endless: bool = false
@export var always_unlocked: bool = false
## Energy consumed when starting (only if GameConfig.max_energy > 0).
@export var energy_cost: int = 1
## Rewards granted the first time the level is won.
@export var first_clear_rewards: Dictionary[StringName, int] = {}
## Rewards granted on every win (or every finish for endless levels).
@export var completion_rewards: Dictionary[StringName, int] = {}
## Free-form tuning values read by the level script (moves, targets, timers...).
@export var custom_parameters: Dictionary[StringName, Variant] = {}


func get_stars_for_score(score: int) -> int:
	var earned_stars: int = 0
	for threshold: int in star_score_thresholds:
		if score >= threshold:
			earned_stars += 1
	return earned_stars


func get_parameter(parameter_key: StringName, default_value: Variant) -> Variant:
	return custom_parameters.get(parameter_key, default_value)
