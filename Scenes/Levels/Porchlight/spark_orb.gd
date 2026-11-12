## Pooled spark: the currency of the garden. Drops to a hover height, waits
## to be caught (the level sweeps the pointers over it) and fades if ignored.
##
## Dependencies: Pools autoload
class_name SparkOrb
extends Node3D

@export var hover_seconds: float = 12.0
## How close a pointer ray must pass to catch the spark.
@export var catch_radius: float = 0.5
@export var bob_height: float = 0.06
## Blink for this long before fading out.
@export var warning_seconds: float = 3.0

var value: int = 25
## False while collected / expiring, so it cannot be caught twice.
var is_catchable: bool = false

var _seconds_left: float = 0.0
var _rest_height: float = 0.0
var _bob_phase: float = 0.0
var _tween: Tween

@onready var _visual: Node3D = %Visual


## Appears at [param from_position] and settles at [param rest_position].
func drop(from_position: Vector3, rest_position: Vector3, spark_value: int, fall_seconds: float) -> void:
	value = spark_value
	global_position = from_position
	_rest_height = rest_position.y
	_seconds_left = hover_seconds + fall_seconds
	is_catchable = true
	_visual.scale = Vector3.ONE * 0.01
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_visual, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position", rest_position, fall_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Caught by the player: flies up and vanishes.
func collect() -> void:
	if not is_catchable:
		return
	is_catchable = false
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "global_position:y", global_position.y + 0.5, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_visual, "scale", Vector3.ONE * 0.01, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(Pools.despawn.bind(self))


func _on_pool_despawned() -> void:
	is_catchable = false
	_kill_tween()


func _physics_process(delta: float) -> void:
	if not is_catchable or Pools.is_in_pool(self):
		return
	_seconds_left -= delta
	_bob_phase += delta * 2.2
	_visual.position.y = sin(_bob_phase) * bob_height
	# Blink faster and faster before it is gone.
	_visual.visible = _seconds_left > warning_seconds or fmod(_seconds_left, 0.4) > 0.14
	if _seconds_left <= 0.0:
		is_catchable = false
		Pools.despawn(self)


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
	_visual.visible = true
