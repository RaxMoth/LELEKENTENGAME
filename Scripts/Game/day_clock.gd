## Time of day for one shift at the house: day from dawn to dusk, then night
## until the next dawn, each squeezed into a configurable number of real
## seconds. The shift is over when dawn comes around again.
##
##   clock.advance(delta)
##   var hour: float = clock.get_hour()          # 6.0 .. 30.0 (past midnight keeps counting)
##   if clock.get_phase() == DayClock.Phase.NIGHT: ...
##
## Dependencies: none
class_name DayClock
extends RefCounted

enum Phase { DAY, NIGHT }

## Hour the shift starts (and ends, a day later).
var dawn_hour: float = 6.0
var dusk_hour: float = 20.0
## Real seconds the day part and the night part take.
var day_seconds: float = 300.0
var night_seconds: float = 240.0
## Hour the shift begins at (after dawn, so the first minutes are calm).
var start_hour: float = 7.0
var elapsed_seconds: float = 0.0


func _init(day_length_seconds: float = 300.0, night_length_seconds: float = 240.0, first_hour: float = 7.0) -> void:
	day_seconds = maxf(1.0, day_length_seconds)
	night_seconds = maxf(1.0, night_length_seconds)
	start_hour = first_hour
	elapsed_seconds = _seconds_until_hour(first_hour)


func advance(delta: float) -> void:
	elapsed_seconds = minf(elapsed_seconds + maxf(delta, 0.0), get_cycle_seconds())


func get_cycle_seconds() -> float:
	return day_seconds + night_seconds


## Hour since the dawn this shift started from: dawn_hour .. dawn_hour + 24.
func get_hour() -> float:
	var day_hours: float = dusk_hour - dawn_hour
	if elapsed_seconds <= day_seconds:
		return dawn_hour + day_hours * elapsed_seconds / day_seconds
	var night_hours: float = 24.0 - day_hours
	return dusk_hour + night_hours * (elapsed_seconds - day_seconds) / night_seconds


## Hour on a 24 h clock face (0..24).
func get_clock_hour() -> float:
	return fmod(get_hour(), 24.0)


func get_phase() -> Phase:
	return Phase.DAY if elapsed_seconds < day_seconds else Phase.NIGHT


## 0..1 progress through the current phase.
func get_phase_progress() -> float:
	if get_phase() == Phase.DAY:
		return elapsed_seconds / day_seconds
	return (elapsed_seconds - day_seconds) / night_seconds


## True once the next dawn has come.
func is_shift_over() -> bool:
	return elapsed_seconds >= get_cycle_seconds()


## "21:30" for the wrist display.
func format_time() -> String:
	var clock_hour: float = get_clock_hour()
	var whole_hours: int = floori(clock_hour)
	var minutes: int = floori((clock_hour - whole_hours) * 60.0)
	return "%02d:%02d" % [whole_hours, minutes]


## Real seconds from dawn until [param hour] (an hour within this shift).
func _seconds_until_hour(hour: float) -> float:
	var day_hours: float = dusk_hour - dawn_hour
	if hour <= dusk_hour:
		return clampf((hour - dawn_hour) / day_hours, 0.0, 1.0) * day_seconds
	return day_seconds + clampf((hour - dusk_hour) / (24.0 - day_hours), 0.0, 1.0) * night_seconds


## True when [param hour] (counted like get_hour()) was passed during the
## last advance of [param delta] seconds — for scheduled events like boss waves.
func just_passed_hour(hour: float, delta: float) -> bool:
	var target_seconds: float = _seconds_until_hour(hour)
	return elapsed_seconds >= target_seconds and elapsed_seconds - delta < target_seconds
