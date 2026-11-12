## MarginContainer that keeps its content clear of notches, camera cutouts and
## rounded corners. Use it as the first child of every full-screen UI.
##
## Dependencies: Events, Platform autoloads
class_name SafeAreaContainer
extends MarginContainer

## Extra spacing added on top of the device safe area.
@export var base_margin: int = 24
@export var apply_top: bool = true
@export var apply_bottom: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.safe_area_changed.connect(_apply_margins)
	_apply_margins(Platform.safe_margins)


func _apply_margins(safe_margins: Rect2) -> void:
	add_theme_constant_override("margin_left", base_margin + int(safe_margins.position.x))
	add_theme_constant_override("margin_right", base_margin + int(safe_margins.size.x))
	add_theme_constant_override("margin_top", base_margin + (int(safe_margins.position.y) if apply_top else 0))
	add_theme_constant_override("margin_bottom", base_margin + (int(safe_margins.size.y) if apply_bottom else 0))
