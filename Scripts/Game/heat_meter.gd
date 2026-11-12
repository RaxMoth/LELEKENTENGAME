## Police attention, 0..100. Every sale adds heat, time cools it down, bribes
## knock it back. Crossing a raid threshold on the way up triggers one raid.
##
##   heat.add(units * recipe.heat_per_unit)
##   heat.cool(delta)
##   var raid_level: int = heat.take_pending_raid()   # 0 = none, 1 = first threshold...
##
## Dependencies: none
class_name HeatMeter
extends RefCounted

const MAX_HEAT: float = 100.0

## Heat lost per second.
var cooling_per_second: float = 0.25
## Heat levels that each trigger one raid when crossed on the way up.
var raid_thresholds: Array[float] = [50.0, 80.0]
var value: float = 0.0

## Highest threshold index already crossed since heat was last below it.
var _armed_thresholds: Array[bool] = []
var _pending_raid: int = 0


func _init(cooling_rate: float = 0.25, thresholds: Array[float] = [50.0, 80.0]) -> void:
	cooling_per_second = cooling_rate
	raid_thresholds = thresholds.duplicate()
	_armed_thresholds.resize(raid_thresholds.size())
	_armed_thresholds.fill(true)


func add(amount: float) -> void:
	set_value(value + amount)


func cool(delta: float) -> void:
	set_value(value - cooling_per_second * delta)


func set_value(new_value: float) -> void:
	value = clampf(new_value, 0.0, MAX_HEAT)
	for threshold_index: int in raid_thresholds.size():
		var threshold: float = raid_thresholds[threshold_index]
		if value >= threshold and _armed_thresholds[threshold_index]:
			_armed_thresholds[threshold_index] = false
			_pending_raid = maxi(_pending_raid, threshold_index + 1)
		elif value < threshold * 0.8:
			# Re-arm only well below the threshold, so hovering around it can't spam raids.
			_armed_thresholds[threshold_index] = true


## 0..1 for gauges.
func get_ratio() -> float:
	return value / MAX_HEAT


## Returns the strongest raid triggered since the last call (1-based threshold
## index) and clears it; 0 when no raid is due.
func take_pending_raid() -> int:
	var raid_level: int = _pending_raid
	_pending_raid = 0
	return raid_level
