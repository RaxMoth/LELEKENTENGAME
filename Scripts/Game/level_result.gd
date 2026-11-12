## Outcome of one level attempt, produced by LevelBase and consumed by
## Profile, Analytics and the results popup.
##
## Dependencies: Types autoload
class_name LevelResult
extends RefCounted

var level_id: StringName = &""
var outcome: Types.LevelOutcome = Types.LevelOutcome.NONE
var score: int = 0
var stars: int = 0
var duration_seconds: float = 0.0
var is_endless: bool = false
var is_new_best: bool = false
var rewards: Dictionary[StringName, int] = {}


func is_won() -> bool:
	return outcome == Types.LevelOutcome.WON


## Endless levels count every finished run as completed.
func counts_as_completed() -> bool:
	return is_won() or (is_endless and outcome == Types.LevelOutcome.LOST)


func to_analytics() -> Dictionary:
	return {
		"level_id": String(level_id),
		"outcome": Types.LevelOutcome.keys()[outcome],
		"score": score,
		"stars": stars,
		"duration": snappedf(duration_seconds, 0.1),
	}
