## Makes a world object tappable (build spots, chests, NPCs, cards).
## Uses physics picking, which works with touch out of the box.
##
## Dependencies: none
class_name TapArea
extends Area2D

signal tapped(tap_area: TapArea)

@export var enabled: bool = true
## Fire on finger down (snappy, good for clickers) instead of finger up (safer for scrolling maps).
@export var trigger_on_press: bool = false


func _ready() -> void:
	input_pickable = true
	monitoring = false


func _input_event(_viewport: Viewport, event: InputEvent, _shape_index: int) -> void:
	if not enabled:
		return
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed == trigger_on_press:
		get_viewport().set_input_as_handled()
		tapped.emit(self)
