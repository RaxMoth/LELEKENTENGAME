## Spawns WaveData waves of (pooled) 3D enemies and tracks the living ones,
## so it knows when a wave is cleared. By default each enemy appears at a
## random Marker3D of [member spawn_markers].
##
##   spawner.start()
##   spawner.wave_started.connect(...); spawner.all_waves_cleared.connect(...)
##
## Spawned enemies may implement apply_wave_modifiers(health_multiplier, speed_multiplier).
## Subclasses override _create_enemy() to spawn differently (LaneWaveSpawner
## sends every enemy down a lane of the LaneBoard).
##
## Dependencies: WaveData, Pools, Global, Types autoloads
class_name WaveSpawner
extends Node

signal wave_started(wave_number: int, wave: WaveData)
signal wave_cleared(wave_number: int, wave: WaveData)
signal all_waves_cleared
signal enemy_spawned(enemy: Node)

@export var waves: Array[WaveData] = []
@export var auto_start: bool = false
## After the last wave, repeat it forever with growing multipliers (endless mode).
@export var endless: bool = false
@export var endless_health_growth: float = 1.15

## Where the default _create_enemy() puts new enemies (one picked at random).
@export var spawn_markers: Array[Marker3D] = []

## Global multiplier on enemy health (difficulty settings).
var difficulty_multiplier: float = 1.0
## 1-based number of the wave in progress (0 = not started).
var current_wave_number: int = 0
var alive_enemy_count: int = 0
var is_running: bool = false

var _run_generation: int = 0
var _wave_spawning_finished: bool = false


func _ready() -> void:
	if auto_start:
		start.call_deferred()


func start() -> void:
	if waves.is_empty():
		push_warning("WaveSpawner: no waves configured.")
		return
	stop()
	is_running = true
	current_wave_number = 0
	_start_next_wave(_run_generation)


func stop() -> void:
	_run_generation += 1
	is_running = false


func get_total_waves() -> int:
	return waves.size()


func _start_next_wave(generation: int) -> void:
	if generation != _run_generation:
		return
	if current_wave_number >= waves.size() and not endless:
		is_running = false
		all_waves_cleared.emit()
		return
	current_wave_number += 1
	var wave_index: int = mini(current_wave_number - 1, waves.size() - 1)
	var wave: WaveData = waves[wave_index]
	var endless_multiplier: float = pow(endless_health_growth, maxi(0, current_wave_number - waves.size()))
	await Global.wait(wave.delay_before_wave)
	if generation != _run_generation:
		return
	wave_started.emit(current_wave_number, wave)
	_wave_spawning_finished = false
	for entry: WaveEntry in wave.entries:
		_spawn_entry(entry, wave, endless_multiplier, generation)
	# Wait until every entry has finished spawning, then for the wave to be cleared.
	var longest_entry_seconds: float = 0.0
	for entry: WaveEntry in wave.entries:
		longest_entry_seconds = maxf(longest_entry_seconds, entry.start_delay + entry.spawn_interval * entry.count)
	await Global.wait(longest_entry_seconds + 0.05)
	if generation != _run_generation:
		return
	_wave_spawning_finished = true
	_check_wave_cleared(generation, wave)


func _spawn_entry(entry: WaveEntry, wave: WaveData, extra_multiplier: float, generation: int) -> void:
	if entry.start_delay > 0.0:
		await Global.wait(entry.start_delay)
	for spawn_index: int in entry.count:
		if generation != _run_generation:
			return
		_spawn_enemy(entry.enemy_scene, wave, extra_multiplier, generation)
		await Global.wait(entry.spawn_interval)


func _spawn_enemy(enemy_scene: PackedScene, wave: WaveData, extra_multiplier: float, generation: int) -> void:
	if enemy_scene == null:
		return
	var enemy: Node = _create_enemy(enemy_scene)
	if enemy == null:
		return
	alive_enemy_count += 1
	enemy.tree_exiting.connect(_on_enemy_removed.bind(generation, wave), CONNECT_ONE_SHOT)
	if enemy.has_method(Types.METHOD_APPLY_WAVE_MODIFIERS):
		enemy.call(Types.METHOD_APPLY_WAVE_MODIFIERS, wave.health_multiplier * difficulty_multiplier * extra_multiplier, wave.speed_multiplier)
	enemy_spawned.emit(enemy)


## @virtual Puts one (pooled) enemy into the world. Override for other spawn
## rules, e.g. lanes of a board.
func _create_enemy(enemy_scene: PackedScene) -> Node:
	if spawn_markers.is_empty():
		push_warning("WaveSpawner: no spawn markers; override _create_enemy() or add Marker3Ds.")
		return null
	var marker: Marker3D = spawn_markers.pick_random()
	return Pools.spawn(enemy_scene, Global.get_world_root(), marker.global_position)


func _on_enemy_removed(generation: int, wave: WaveData) -> void:
	alive_enemy_count = maxi(0, alive_enemy_count - 1)
	if generation == _run_generation and _wave_spawning_finished:
		_check_wave_cleared.call_deferred(generation, wave)


func _check_wave_cleared(generation: int, wave: WaveData) -> void:
	if generation != _run_generation or alive_enemy_count > 0 or not _wave_spawning_finished:
		return
	_wave_spawning_finished = false
	wave_cleared.emit(current_wave_number, wave)
	_start_next_wave(generation)
