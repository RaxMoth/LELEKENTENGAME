## Lifetime counters (enemies defeated, coins earned...). Achievements watch these.
##
## Dependencies: Events autoload
class_name Statistics
extends ProfileModule

var _values: Dictionary[StringName, float] = {}


func get_save_key() -> StringName:
	return &"stats"


func to_dict() -> Dictionary:
	return _values


func from_dict(data: Dictionary) -> void:
	_values = to_float_dictionary(data)


func reset() -> void:
	_values = {}


func get_value(stat_id: StringName) -> float:
	return _values.get(stat_id, 0.0)


func increment(stat_id: StringName, amount: float = 1.0) -> void:
	_set_value(stat_id, get_value(stat_id) + amount)


## Keeps the highest value ever reported (best score, longest run...).
func record_max(stat_id: StringName, candidate_value: float) -> void:
	if candidate_value > get_value(stat_id):
		_set_value(stat_id, candidate_value)


func _set_value(stat_id: StringName, new_value: float) -> void:
	_values[stat_id] = new_value
	Events.stat_changed.emit(stat_id, new_value)
	mark_dirty()
