## Row of star icons: earned stars in Palette.STAR, missing ones faint.
##
## Dependencies: none
class_name StarsDisplay
extends HBoxContainer

const STAR_ICON: Texture2D = preload("res://Assets/Icons/star.svg")

@export var max_stars: int = 3
@export var star_size: int = 40
@export var earned_color: Color = Palette.STAR
@export var missing_color: Color = Color(1, 1, 1, 0.14)

var _stars: Array[TextureRect] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	for star_index: int in max_stars:
		var star: TextureRect = TextureRect.new()
		star.texture = STAR_ICON
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.custom_minimum_size = Vector2(star_size, star_size)
		star.self_modulate = missing_color
		add_child(star)
		_stars.append(star)


func set_stars(earned_stars: int, animate: bool = false) -> void:
	for star_index: int in _stars.size():
		var star: TextureRect = _stars[star_index]
		var is_earned: bool = star_index < earned_stars
		star.self_modulate = earned_color if is_earned else missing_color
		if animate and is_earned:
			star.scale = Vector2.ZERO
			star.pivot_offset = star.size * 0.5
			var tween: Tween = star.create_tween()
			tween.tween_interval(0.15 + star_index * 0.2)
			tween.tween_property(star, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
