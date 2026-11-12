## Sends the police into the garden during a raid. The HouseCycle decides
## when a wave starts and what it brings (a RaidWave: cops, SWAT, toughness);
## the FrontGarden hands each wave here and the director walks its officers
## in one after another. On selling days nothing comes (customers only).
##
##   director.queue_wave(wave)          # from FrontGarden.on_raid_wave_started
##   director.get_raiders_left()        # pending + still standing; 0 = wave beaten
##
## Dependencies: HouseContext, LaneBoard, LaneEnemy, RaidWave
class_name AttackerDirector
extends Node

@export var cop_scene: PackedScene
## Heavier officers with better equipment (from a later raid on).
@export var swat_scene: PackedScene
## Seconds between two officers of one wave entering the garden.
@export var group_spawn_interval: float = 1.4

## Off = queued officers wait (tutorials, tests).
var is_active: bool = true

var _context: HouseContext = null
var _board: LaneBoard = null
## Officers waiting to enter: [{"scene": PackedScene, "delay": float, "health": float}].
var _pending_spawns: Array[Dictionary] = []


func setup(context: HouseContext, board: LaneBoard) -> void:
	_context = context
	_board = board


## One frame: lets queued officers in (called by the FrontGarden while the shift runs).
func step(delta: float) -> void:
	if not is_active or _context == null:
		return
	_step_pending_spawns(delta)


## Queues every officer of [param wave]: cops first, SWAT behind them.
func queue_wave(wave: RaidWave, spawn_interval: float = -1.0) -> void:
	var interval: float = group_spawn_interval if spawn_interval < 0.0 else spawn_interval
	var queued: int = 0
	for cop_index: int in wave.cop_count:
		_queue(cop_scene, interval * queued, wave.health_multiplier)
		queued += 1
	for swat_index: int in wave.swat_count:
		_queue(swat_scene if swat_scene != null else cop_scene, interval * queued, wave.health_multiplier)
		queued += 1


## Sends one attacker into the garden now with [param health_multiplier].
func spawn_attacker(enemy_scene: PackedScene, health_multiplier: float = 1.0) -> LaneEnemy:
	if enemy_scene == null or _board == null:
		return null
	var enemy: LaneEnemy = _board.spawn_enemy(enemy_scene)
	enemy.apply_wave_modifiers(health_multiplier, 1.0)
	return enemy


func get_pending_spawn_count() -> int:
	return _pending_spawns.size()


## Officers of the current wave still to come or still standing.
func get_raiders_left() -> int:
	var standing: int = 0
	if _board != null:
		for enemy: LaneEnemy in _board.get_enemies():
			if enemy.is_alive():
				standing += 1
	return _pending_spawns.size() + standing


## Forgets officers that have not entered yet (the shift ended).
func clear_pending() -> void:
	_pending_spawns.clear()


func _queue(enemy_scene: PackedScene, delay: float, health_multiplier: float) -> void:
	_pending_spawns.append({"scene": enemy_scene, "delay": delay, "health": health_multiplier})


func _step_pending_spawns(delta: float) -> void:
	for spawn_index: int in range(_pending_spawns.size() - 1, -1, -1):
		var pending: Dictionary = _pending_spawns[spawn_index]
		pending["delay"] = float(pending["delay"]) - delta
		if float(pending["delay"]) <= 0.0:
			_pending_spawns.remove_at(spawn_index)
			spawn_attacker(pending["scene"] as PackedScene, float(pending["health"]))
