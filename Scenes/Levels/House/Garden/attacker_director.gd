## Sends attackers down the garden, day and night: junkies all the time (more
## when the stash is full), police patrols (more with heat) and raids when
## heat crosses a threshold, mafia crews at night once the operation has a
## reputation, and the boss wave at a set hour. Attackers get tougher every
## day survived and at night.
##
## Dependencies: HouseContext, LaneBoard, LaneEnemy, Profile autoload
class_name AttackerDirector
extends Node

## Cops arrive in force (heat crossed a threshold). [param raid_level] 1, 2...
signal raid_started(raid_level: int)
signal mafia_crew_started
signal boss_wave_started

@export var junkie_scene: PackedScene
@export var cop_scene: PackedScene
@export var goon_scene: PackedScene
@export var boss_scene: PackedScene
@export var day_junkie_interval: float = 16.0
@export var night_junkie_interval: float = 10.0
## Each this many units in the stash bring junkies once more as often.
@export var stash_units_per_extra_junkies: float = 20.0
## A police patrol at zero heat comes this often; heat shortens it.
@export var patrol_interval: float = 70.0
@export var night_mafia_interval: float = 45.0
## Reputation before mafia crews start coming at night.
@export var mafia_min_reputation: int = 10
@export var mafia_crew_size: int = 2
## Shift hour of the boss wave (25 = 01:00 after midnight).
@export var boss_hour: float = 25.0
@export var boss_escorts: int = 3
## Cops per raid level (index 0 = first threshold).
@export var raid_sizes: Array[int] = [3, 6]
## Seconds between attackers of one raid or crew.
@export var group_spawn_interval: float = 1.6
## Attacker health grows this much per day survived.
@export var health_growth_per_day: float = 0.12
@export var night_health_multiplier: float = 1.15

## Off = no attackers come on their own (tutorials, tests).
var is_active: bool = true

var _context: HouseContext = null
var _board: LaneBoard = null
var _seconds_until_junkie: float = 8.0
var _seconds_until_patrol: float = 40.0
var _seconds_until_mafia: float = 0.0
## Attackers waiting to enter: [{"scene": PackedScene, "delay": float}].
var _pending_spawns: Array[Dictionary] = []


func setup(context: HouseContext, board: LaneBoard) -> void:
	_context = context
	_board = board
	_seconds_until_mafia = night_mafia_interval * 0.5


## One frame of pressure (called by the FrontGarden while the shift runs).
func step(delta: float) -> void:
	if not is_active or _context == null:
		return
	var is_night: bool = _context.day_cycle.is_night()
	_seconds_until_junkie -= delta
	if _seconds_until_junkie <= 0.0:
		_seconds_until_junkie = _get_junkie_interval(is_night)
		spawn_attacker(junkie_scene)
	_seconds_until_patrol -= delta
	if _seconds_until_patrol <= 0.0:
		_seconds_until_patrol = patrol_interval * (1.0 - _context.operation.heat.get_ratio() * 0.75)
		spawn_attacker(cop_scene)
	if is_night and Profile.operation.reputation >= mafia_min_reputation:
		_seconds_until_mafia -= delta
		if _seconds_until_mafia <= 0.0:
			_seconds_until_mafia = night_mafia_interval
			_queue_group(goon_scene, mafia_crew_size)
			mafia_crew_started.emit()
	if _context.day_cycle.clock.just_passed_hour(boss_hour, delta):
		start_boss_wave()
	var raid_level: int = _context.operation.heat.take_pending_raid()
	if raid_level > 0:
		start_raid(raid_level)
	_step_pending_spawns(delta)


## Sends one attacker into the garden, scaled for the day and time.
func spawn_attacker(enemy_scene: PackedScene) -> LaneEnemy:
	if enemy_scene == null:
		return null
	var enemy: LaneEnemy = _board.spawn_enemy(enemy_scene)
	enemy.apply_wave_modifiers(_get_health_multiplier(), 1.0)
	return enemy


func start_raid(raid_level: int) -> void:
	_queue_group(cop_scene, raid_sizes[clampi(raid_level - 1, 0, raid_sizes.size() - 1)])
	raid_started.emit(raid_level)


func start_boss_wave() -> void:
	_queue_group(boss_scene, 1)
	_queue_group(goon_scene, boss_escorts)
	boss_wave_started.emit()


func get_pending_spawn_count() -> int:
	return _pending_spawns.size()


func _get_junkie_interval(is_night: bool) -> float:
	var base_interval: float = night_junkie_interval if is_night else day_junkie_interval
	return base_interval / (1.0 + _context.operation.stash.get_total() / stash_units_per_extra_junkies)


func _get_health_multiplier() -> float:
	var day_factor: float = 1.0 + health_growth_per_day * (Profile.operation.day_number - 1)
	return day_factor * (night_health_multiplier if _context.day_cycle.is_night() else 1.0)


func _queue_group(enemy_scene: PackedScene, count: int) -> void:
	for member_index: int in count:
		_pending_spawns.append({"scene": enemy_scene, "delay": group_spawn_interval * member_index})


func _step_pending_spawns(delta: float) -> void:
	for spawn_index: int in range(_pending_spawns.size() - 1, -1, -1):
		var pending: Dictionary = _pending_spawns[spawn_index]
		pending["delay"] = float(pending["delay"]) - delta
		if float(pending["delay"]) <= 0.0:
			_pending_spawns.remove_at(spawn_index)
			spawn_attacker(pending["scene"] as PackedScene)
