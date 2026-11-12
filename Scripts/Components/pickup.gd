## Collectible (coins, XP gems, hearts, power-ups). Pooled. When a
## CollectorComponent comes near it flies toward the collector and is collected.
## Collection is broadcast via Events.pickup_collected so any system can react.
##
## Dependencies: Events, Pools, Audio autoloads
class_name Pickup
extends Area2D

signal collected(pickup_id: StringName, amount: int)

@export var pickup_id: StringName = &"xp"
@export var amount: int = 1
@export var collect_distance: float = 20.0
@export var magnet_start_speed: float = 150.0
@export var magnet_acceleration: float = 2400.0
## Auto-despawn after N seconds (0 = never).
@export var lifetime_seconds: float = 0.0
@export var collect_sound_preset: StringName = &"coin"

var _magnet_target: Node2D = null
var _magnet_speed: float = 0.0
var _time_alive: float = 0.0


func _ready() -> void:
	add_to_group(Types.GROUP_PICKUP)


func _physics_process(delta: float) -> void:
	_time_alive += delta
	if lifetime_seconds > 0.0 and _time_alive >= lifetime_seconds and _magnet_target == null:
		Pools.despawn(self)
		return
	if not is_instance_valid(_magnet_target) or not _magnet_target.is_inside_tree():
		_magnet_target = null
		return
	_magnet_speed += magnet_acceleration * delta
	var to_target: Vector2 = _magnet_target.global_position - global_position
	if to_target.length() <= collect_distance + _magnet_speed * delta:
		collect()
		return
	global_position += to_target.normalized() * _magnet_speed * delta


func attract_to(collector_target: Node2D) -> void:
	if _magnet_target == null:
		_magnet_target = collector_target
		_magnet_speed = magnet_start_speed


func collect() -> void:
	if Pools.is_in_pool(self):
		return
	Audio.play_sfx(SfxSynth.get_preset(collect_sound_preset), 0.15, -10.0)
	collected.emit(pickup_id, amount)
	Events.pickup_collected.emit(pickup_id, amount, global_position)
	Pools.despawn(self)


func _on_pool_spawned() -> void:
	_magnet_target = null
	_magnet_speed = 0.0
	_time_alive = 0.0
