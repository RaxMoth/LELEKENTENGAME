## The house's 3-day cycle: days of selling (only customers come), then on
## the night of the last day the police raid the house in waves. Once every
## wave is beaten the raid is over and the next cycle of selling begins — with
## a harder raid at its end. Tuned by a RaidData resource.
##
## The House level owns this node: it calls setup() with the fronts, and
## start_raid() when night falls on a raid day; the raid's end wins the shift.
## The cycle talks to the fronts only through HouseFront's raid hooks
## (on_raid_started, on_raid_wave_started, get_raiders_left, on_raid_cleared),
## and fronts ask it whether customers may come (context.cycle).
##
## State: Selling -> Raid { WaveBreak <-> WaveActive } -> Cleared
##
## Dependencies: RaidData, RaidPlanner, RaidWave, HouseContext, HouseFront,
##               Profile, Types autoloads
class_name HouseCycle
extends Node

## The raid night began: [param wave_count] waves are coming.
signal raid_started(raid_number: int, wave_count: int)
## A wave entered the garden.
signal wave_started(wave: RaidWave, wave_count: int)
## Every officer of a wave is down.
signal wave_cleared(wave: RaidWave, wave_count: int)
## Every wave of the raid is beaten.
signal raid_cleared(raid_number: int)

enum Phase { SELLING, RAID, CLEARED }

## Days per cycle, waves, officers and escalation.
@export var raid_data: RaidData

var phase: Phase = Phase.SELLING

var _context: HouseContext = null
var _fronts: Array[HouseFront] = []
var _raid_number: int = 0
var _waves: Array[RaidWave] = []
var _next_wave_index: int = 0
var _active_wave: RaidWave = null
var _seconds_until_wave: float = 0.0

@onready var state_chart: StateChart = %CycleChart

# ============================================
# PUBLIC API
# ============================================

## Called by the House level once its fronts are set up.
func setup(shift_context: HouseContext, fronts: Array[HouseFront]) -> void:
	_context = shift_context
	_fronts = fronts


## 1-based day of the current cycle (1 .. days_per_cycle).
func get_day_in_cycle() -> int:
	return RaidPlanner.get_day_in_cycle(Profile.operation.day_number, raid_data)


func get_days_per_cycle() -> int:
	return raid_data.days_per_cycle


## Number of the raid this cycle ends with (1 for the first cycle).
func get_raid_number() -> int:
	return RaidPlanner.get_raid_number(Profile.operation.day_number, raid_data)


## True on the last day of the cycle: the police come tonight.
func is_raid_day() -> bool:
	return RaidPlanner.is_raid_day(Profile.operation.day_number, raid_data)


## Customers come only while selling, never during a raid.
func allows_customers() -> bool:
	return phase == Phase.SELLING


## True from the raid alarm until the shift ends (also after the last wave).
func is_raid_active() -> bool:
	return phase != Phase.SELLING


func is_wave_active() -> bool:
	return _active_wave != null


## 1-based number of the wave in the garden (or the last one), 0 before the first.
func get_wave_number() -> int:
	return _next_wave_index


func get_wave_count() -> int:
	return _waves.size()


## Seconds until the next wave enters (0 while a wave is in the garden).
func get_seconds_until_wave() -> float:
	return 0.0 if is_wave_active() else maxf(0.0, _seconds_until_wave)


## Starts the raid night: plans the waves (police heat makes it bigger) and
## tells every front. Does nothing outside the selling phase.
func start_raid() -> void:
	if phase != Phase.SELLING or raid_data == null:
		return
	_raid_number = get_raid_number()
	var heat_ratio: float = _context.operation.heat.get_ratio() if _context != null else 0.0
	_waves = RaidPlanner.build_raid(raid_data, _raid_number, heat_ratio)
	_next_wave_index = 0
	_active_wave = null
	state_chart.send_event(Types.EVENT_RAID_START)


## Brings the next wave in right away (tests, a "they're early" event).
func skip_wave_break() -> void:
	if phase == Phase.RAID and not is_wave_active():
		_seconds_until_wave = 0.0


## Admin / tests: every raider of the current wave is taken out at once.
func remove_raiders() -> void:
	for front: HouseFront in _fronts:
		front.remove_raiders()


## What the shift is about today, for the announcement at its start.
func get_day_announcement() -> String:
	var day_line: String = tr("Day %d") % Profile.operation.day_number
	if is_raid_day():
		return day_line + "\n" + tr("Police raid tonight")
	var days_left: int = RaidPlanner.get_days_until_raid(Profile.operation.day_number, raid_data)
	return day_line + "\n" + (tr("Raid in %d days") % days_left if days_left != 1 else tr("Raid tomorrow night"))


## One line for the wrist status.
func get_status_line() -> String:
	match phase:
		Phase.SELLING:
			var days_left: int = RaidPlanner.get_days_until_raid(Profile.operation.day_number, raid_data)
			if days_left == 0:
				return tr("Raid tonight")
			return tr("Raid in %d days") % days_left if days_left != 1 else tr("Raid tomorrow night")
		Phase.RAID:
			if is_wave_active():
				return tr("Wave %d/%d · %d left") % [get_wave_number(), get_wave_count(), _count_raiders_left()]
			return tr("Wave %d/%d in %ds") % [get_wave_number() + 1, get_wave_count(), ceili(get_seconds_until_wave())]
	return tr("Raid beaten")

# ============================================
# STATE CHART CALLBACKS (connected in HouseCycle.tscn)
# ============================================

func _on_selling_state_entered() -> void:
	phase = Phase.SELLING


func _on_raid_state_entered() -> void:
	phase = Phase.RAID
	for front: HouseFront in _fronts:
		front.on_raid_started(_raid_number, _waves.size())
	raid_started.emit(_raid_number, _waves.size())


func _on_wave_break_state_entered() -> void:
	_active_wave = null
	if _next_wave_index >= _waves.size():
		# The last wave is down: the raid ends right away, no break to wait out.
		_seconds_until_wave = 0.0
	elif _next_wave_index == 0:
		_seconds_until_wave = raid_data.seconds_before_first_wave
	else:
		_seconds_until_wave = raid_data.seconds_between_waves


func _on_wave_break_state_processing(delta: float) -> void:
	if not _is_shift_running():
		return
	_seconds_until_wave -= delta
	if _seconds_until_wave > 0.0:
		return
	if _next_wave_index < _waves.size():
		state_chart.send_event(Types.EVENT_WAVE_START)
	else:
		state_chart.send_event(Types.EVENT_RAID_CLEARED)


func _on_wave_active_state_entered() -> void:
	_active_wave = _waves[_next_wave_index]
	_next_wave_index += 1
	for front: HouseFront in _fronts:
		front.on_raid_wave_started(_active_wave)
	wave_started.emit(_active_wave, _waves.size())


func _on_wave_active_state_processing(_delta: float) -> void:
	if not _is_shift_running() or _count_raiders_left() > 0:
		return
	var beaten_wave: RaidWave = _active_wave
	state_chart.send_event(Types.EVENT_WAVE_CLEARED)
	wave_cleared.emit(beaten_wave, _waves.size())


func _on_cleared_state_entered() -> void:
	phase = Phase.CLEARED
	_active_wave = null
	for front: HouseFront in _fronts:
		front.on_raid_cleared(_raid_number)
	raid_cleared.emit(_raid_number)

# ============================================
# INTERNALS
# ============================================

func _is_shift_running() -> bool:
	return _context != null and _context.is_playing()


func _count_raiders_left() -> int:
	var raiders: int = 0
	for front: HouseFront in _fronts:
		raiders += front.get_raiders_left()
	return raiders
