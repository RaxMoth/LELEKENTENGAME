## Pooled one-shot "pop": a glowing ball that swells and vanishes. Cheap
## feedback for impacts, placements and defeats in 3D scenes.
##
##   PopEffect3D.spawn(hit_position, Palette.PROJECTILE, 0.5, effects_root)
##
## Dependencies: Pools autoload, PlaceholderMesh3D
class_name PopEffect3D
extends Node3D

const SCENE_PATH: String = "res://Scenes/Entities/PopEffect3D/PopEffect3D.tscn"
const GROW_SECONDS: float = 0.09
const SHRINK_SECONDS: float = 0.12

var _tween: Tween

@onready var _ball: PlaceholderMesh3D = %Ball


static func spawn(world_position: Vector3, color: Color, diameter: float, parent: Node) -> PopEffect3D:
	var pop_effect: PopEffect3D = Pools.spawn(load(SCENE_PATH) as PackedScene, parent, world_position) as PopEffect3D
	pop_effect.play(color, diameter)
	return pop_effect


func play(color: Color, diameter: float) -> void:
	_ball.color = color
	scale = Vector3.ONE * diameter * 0.3
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector3.ONE * diameter, GROW_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector3.ONE * 0.001, SHRINK_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(Pools.despawn.bind(self))
