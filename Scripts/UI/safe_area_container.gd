## MarginContainer that keeps its content clear of notches, camera cutouts and
## rounded corners. Use it as the first child of every full-screen UI. With
## max_content_width a portrait menu stays a centered column in a wide
## (full-screen desktop) window instead of stretching across it.
##
## Dependencies: Events, Platform autoloads
class_name SafeAreaContainer
extends MarginContainer

## Extra spacing added on top of the device safe area.
@export var base_margin: int = 24
@export var apply_top: bool = true
@export var apply_bottom: bool = true
## Content never gets wider than this (pixels); wider windows add side
## margins to center it. 0 = full width.
@export var max_content_width: int = 0

var _safe_margins: Rect2 = Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.safe_area_changed.connect(_apply_margins)
	resized.connect(func() -> void: _apply_margins(_safe_margins))
	_apply_margins(Platform.safe_margins)


func _apply_margins(safe_margins: Rect2) -> void:
	_safe_margins = safe_margins
	var left: int = base_margin + int(safe_margins.position.x)
	var right: int = base_margin + int(safe_margins.size.x)
	if max_content_width > 0:
		var extra: int = floori(maxf(0.0, size.x - left - right - max_content_width) * 0.5)
		left += extra
		right += extra
	add_theme_constant_override("margin_left", left)
	add_theme_constant_override("margin_right", right)
	add_theme_constant_override("margin_top", base_margin + (int(safe_margins.position.y) if apply_top else 0))
	add_theme_constant_override("margin_bottom", base_margin + (int(safe_margins.size.y) if apply_bottom else 0))
