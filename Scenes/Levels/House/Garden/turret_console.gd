## The Security PC's screen: the live view from the selected turret's
## camera with a crosshair, which turret it is, and buttons to switch
## turrets and take one over. Point at the view to aim, pull the trigger
## (click) on it to fire — held, it keeps firing. Emits signals only; the
## SecurityPc does the work.
##
## Dependencies: Palette
class_name TurretConsole
extends Control

## The pointer moved over the camera view; [param view_uv] is 0..1 in both axes.
signal aim_moved(view_uv: Vector2)
signal fire_pressed
signal fire_released
## Previous (-1) or next (+1) turret.
signal turret_step_requested(step: int)
signal control_toggled

@onready var _feed: TextureRect = %Feed
@onready var _status_label: Label = %StatusLabel
@onready var _control_button: Button = %ControlButton
@onready var _hint_label: Label = %HintLabel


func _ready() -> void:
	_feed.gui_input.connect(_on_feed_gui_input)


## Shows the camera image (the PC's SubViewport texture).
func set_feed(texture: Texture2D) -> void:
	_feed.texture = texture


## Which turret is shown and whether the player has it.
func show_turret(turret_number: int, turret_count: int, is_manual: bool) -> void:
	if turret_count <= 0:
		_status_label.text = tr("No turrets mounted")
		_control_button.disabled = true
		_hint_label.text = tr("Buy Roof Turrets at the office board")
		return
	_status_label.text = tr("Turret %d of %d · %s") % [turret_number, turret_count, tr("manual") if is_manual else tr("automatic")]
	_control_button.disabled = false
	_control_button.text = tr("Release turret") if is_manual else tr("Take control")
	_control_button.theme_type_variation = &"SecondaryButton" if is_manual else &"SuccessButton"
	_hint_label.text = tr("Point to aim · trigger on the view fires") if is_manual else tr("Take control to aim it yourself")


## The control button (tests).
func get_control_button() -> Button:
	return _control_button


## The camera view (tests).
func get_feed() -> TextureRect:
	return _feed


func _on_feed_gui_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		aim_moved.emit(_to_view_uv(motion.position))
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		aim_moved.emit(_to_view_uv(button.position))
		if button.pressed:
			fire_pressed.emit()
		else:
			fire_released.emit()


func _to_view_uv(local_position: Vector2) -> Vector2:
	return Vector2(local_position.x / maxf(1.0, _feed.size.x), local_position.y / maxf(1.0, _feed.size.y)).clamp(Vector2.ZERO, Vector2.ONE)


func _on_previous_button_pressed() -> void:
	turret_step_requested.emit(-1)


func _on_next_button_pressed() -> void:
	turret_step_requested.emit(1)


func _on_control_button_pressed() -> void:
	control_toggled.emit()
