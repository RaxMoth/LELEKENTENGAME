## Pooled flash of the player's blaster: a thin glowing beam between two
## points that thins out and disappears.
##
## Dependencies: Pools, Events autoloads
class_name BeamTracer
extends Node3D

const FADE_SECONDS: float = 0.12

var _tween: Tween


func fire(from_position: Vector3, to_position: Vector3) -> void:
	Events.beam_fired.emit(from_position, to_position)
	var beam_length: float = from_position.distance_to(to_position)
	if beam_length < 0.01:
		Pools.despawn(self)
		return
	global_position = from_position.lerp(to_position, 0.5)
	var direction: Vector3 = (to_position - from_position) / beam_length
	look_at(to_position, Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD)
	scale = Vector3(1.0, 1.0, beam_length)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector3(0.05, 0.05, beam_length), FADE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(Pools.despawn.bind(self))
