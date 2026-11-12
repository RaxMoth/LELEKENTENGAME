## Per-level results: completion, best score, stars, attempts.
##
## Dependencies: none
class_name LevelProgress
extends ProfileModule

const KEY_COMPLETED: String = "completed"
const KEY_STARS: String = "stars"
const KEY_BEST_SCORE: String = "best_score"
const KEY_ATTEMPTS: String = "attempts"

var _records: Dictionary = {}


func get_save_key() -> StringName:
	return &"levels"


func to_dict() -> Dictionary:
	return _records


func from_dict(data: Dictionary) -> void:
	_records = data.duplicate(true)


func reset() -> void:
	_records = {}


## Stores a finished attempt. Returns true when this was a new best score.
func record_result(result: LevelResult) -> bool:
	var record: Dictionary = _get_record(result.level_id)
	record[KEY_ATTEMPTS] = int(record.get(KEY_ATTEMPTS, 0)) + 1
	var is_new_best: bool = result.score > int(record.get(KEY_BEST_SCORE, 0))
	if is_new_best:
		record[KEY_BEST_SCORE] = result.score
	if result.counts_as_completed():
		record[KEY_COMPLETED] = true
		record[KEY_STARS] = maxi(int(record.get(KEY_STARS, 0)), result.stars)
	_records[String(result.level_id)] = record
	mark_dirty()
	return is_new_best


func is_completed(level_id: StringName) -> bool:
	return bool(_get_record(level_id).get(KEY_COMPLETED, false))


func get_stars(level_id: StringName) -> int:
	return int(_get_record(level_id).get(KEY_STARS, 0))


func get_best_score(level_id: StringName) -> int:
	return int(_get_record(level_id).get(KEY_BEST_SCORE, 0))


func get_attempts(level_id: StringName) -> int:
	return int(_get_record(level_id).get(KEY_ATTEMPTS, 0))


func get_total_stars() -> int:
	var total_stars: int = 0
	for record: Variant in _records.values():
		total_stars += int((record as Dictionary).get(KEY_STARS, 0))
	return total_stars


func is_unlocked(level: LevelData) -> bool:
	if level.always_unlocked:
		return true
	var level_index: int = config.get_level_index(level.id)
	if level_index <= 0:
		return true
	return is_completed(config.levels[level_index - 1].id)


func unlock_all_for_debug() -> void:
	for level: LevelData in config.levels:
		var record: Dictionary = _get_record(level.id)
		record[KEY_COMPLETED] = true
		_records[String(level.id)] = record
	mark_dirty()


func _get_record(level_id: StringName) -> Dictionary:
	var record: Variant = _records.get(String(level_id), {})
	return (record as Dictionary).duplicate() if record is Dictionary else {}
