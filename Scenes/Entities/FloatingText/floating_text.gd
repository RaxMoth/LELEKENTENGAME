## Pooled floating label for damage numbers, "+10 coins", combo text...
##
##   FloatingText.spawn("-12", enemy.global_position, Color.WHITE)
##
## Dependencies: Pools, Global autoloads
class_name FloatingText
extends Node2D

const SCENE_PATH: String = "res://Scenes/Entities/FloatingText/FloatingText.tscn"

@onready var _label: Label = %Label

var _tween: Tween


static func spawn(text: String, world_position: Vector2, color: Color = Color.WHITE, font_size: int = 32) -> FloatingText:
	# load() hits the resource cache after the first call, so this stays cheap.
	var floating_text: FloatingText = Pools.spawn(load(SCENE_PATH) as PackedScene, Global.get_world_root(), world_position) as FloatingText
	floating_text.play(text, color, font_size)
	return floating_text


func play(text: String, color: Color, font_size: int) -> void:
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_font_size_override("font_size", font_size)
	modulate.a = 1.0
	scale = Vector2.ONE * 0.6
	position += Vector2(randf_range(-12.0, 12.0), 0.0)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:y", position.y - 70.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(0.45)
	_tween.chain().tween_callback(Pools.despawn.bind(self))
