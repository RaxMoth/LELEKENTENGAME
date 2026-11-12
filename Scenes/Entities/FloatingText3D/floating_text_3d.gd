## Pooled floating label for 3D scenes ("+25", "Not enough sparks"). Always
## faces the camera and draws on top of the world.
##
##   FloatingText3D.spawn("+25", orb.global_position, Palette.GOLD, effects_root)
##
## Dependencies: Pools autoload, Palette
class_name FloatingText3D
extends Label3D

const SCENE_PATH: String = "res://Scenes/Entities/FloatingText3D/FloatingText3D.tscn"
const RISE_METERS: float = 0.7
const LIFE_SECONDS: float = 0.9

var _tween: Tween


static func spawn(label_text: String, world_position: Vector3, color: Color, parent: Node) -> FloatingText3D:
	# load() hits the resource cache after the first call, so this stays cheap.
	var floating_text: FloatingText3D = Pools.spawn_3d(load(SCENE_PATH) as PackedScene, parent, world_position) as FloatingText3D
	floating_text.play(label_text, color)
	return floating_text


func play(label_text: String, color: Color) -> void:
	text = label_text
	modulate = color
	outline_modulate = Color(Palette.BACKGROUND, 0.9)
	scale = Vector3.ONE * 0.6
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:y", position.y + RISE_METERS, LIFE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(LIFE_SECONDS - 0.3)
	_tween.tween_property(self, "outline_modulate:a", 0.0, 0.3).set_delay(LIFE_SECONDS - 0.3)
	_tween.chain().tween_callback(Pools.despawn.bind(self))
