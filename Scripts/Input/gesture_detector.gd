## Turns raw touches into gestures: tap, double tap, long press, swipe, drag
## and pinch. Add it to a scene and connect the signals you need. Uses
## _unhandled_input, so touches on UI buttons never reach it.
## Positions are in screen (viewport) space — convert with Global.screen_to_world().
##
## Dependencies: Types autoload
class_name GestureDetector
extends Node

signal tapped(screen_position: Vector2)
signal double_tapped(screen_position: Vector2)
signal long_pressed(screen_position: Vector2)
signal swiped(direction: Types.SwipeDirection, start_position: Vector2, swipe_vector: Vector2)
signal touch_started(screen_position: Vector2)
signal touch_ended(screen_position: Vector2)
signal drag_started(screen_position: Vector2)
signal dragged(screen_position: Vector2, relative: Vector2)
signal drag_ended(screen_position: Vector2)
signal pinched(zoom_factor: float, center: Vector2)

@export var max_tap_distance: float = 24.0
@export var max_tap_seconds: float = 0.3
@export var double_tap_seconds: float = 0.3
@export var long_press_seconds: float = 0.5
@export var min_swipe_distance: float = 70.0
@export var max_swipe_seconds: float = 0.5

var _primary_index: int = -1
var _press_position: Vector2 = Vector2.ZERO
var _press_msec: int = 0
var _is_dragging: bool = false
var _long_press_fired: bool = false
var _last_tap_msec: int = -10000
var _last_tap_position: Vector2 = Vector2.ZERO
var _touch_points: Dictionary[int, Vector2] = {}
var _last_pinch_distance: float = 0.0


func _process(_delta: float) -> void:
	if _primary_index < 0 or _is_dragging or _long_press_fired:
		return
	if (Time.get_ticks_msec() - _press_msec) / 1000.0 >= long_press_seconds:
		_long_press_fired = true
		long_pressed.emit(_press_position)


func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		_handle_touch(touch)
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null:
		_handle_drag(drag)


func _handle_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		_touch_points[touch.index] = touch.position
		_last_pinch_distance = 0.0
		if _primary_index < 0:
			_primary_index = touch.index
			_press_position = touch.position
			_press_msec = Time.get_ticks_msec()
			_is_dragging = false
			_long_press_fired = false
			touch_started.emit(touch.position)
		return
	_touch_points.erase(touch.index)
	if touch.index != _primary_index:
		return
	_primary_index = -1
	touch_ended.emit(touch.position)
	var held_seconds: float = (Time.get_ticks_msec() - _press_msec) / 1000.0
	var movement: Vector2 = touch.position - _press_position
	if _is_dragging:
		drag_ended.emit(touch.position)
	if movement.length() >= min_swipe_distance and held_seconds <= max_swipe_seconds:
		swiped.emit(_direction_from_vector(movement), _press_position, movement)
	elif not _is_dragging and not _long_press_fired and held_seconds <= max_tap_seconds:
		_emit_tap(touch.position)


func _handle_drag(drag: InputEventScreenDrag) -> void:
	_touch_points[drag.index] = drag.position
	if _touch_points.size() >= 2:
		var points: Array = _touch_points.values()
		var first_point: Vector2 = points[0]
		var second_point: Vector2 = points[1]
		var pinch_distance: float = first_point.distance_to(second_point)
		if _last_pinch_distance > 0.0:
			pinched.emit(pinch_distance / _last_pinch_distance, (first_point + second_point) * 0.5)
		_last_pinch_distance = pinch_distance
		return
	if drag.index != _primary_index:
		return
	if not _is_dragging and drag.position.distance_to(_press_position) > max_tap_distance:
		_is_dragging = true
		drag_started.emit(_press_position)
	if _is_dragging:
		dragged.emit(drag.position, drag.relative)


func _emit_tap(tap_position: Vector2) -> void:
	var now_msec: int = Time.get_ticks_msec()
	if (now_msec - _last_tap_msec) / 1000.0 <= double_tap_seconds and tap_position.distance_to(_last_tap_position) <= max_tap_distance * 2.0:
		_last_tap_msec = -10000
		double_tapped.emit(tap_position)
		return
	_last_tap_msec = now_msec
	_last_tap_position = tap_position
	tapped.emit(tap_position)


static func _direction_from_vector(movement: Vector2) -> Types.SwipeDirection:
	if absf(movement.x) > absf(movement.y):
		return Types.SwipeDirection.RIGHT if movement.x > 0.0 else Types.SwipeDirection.LEFT
	return Types.SwipeDirection.DOWN if movement.y > 0.0 else Types.SwipeDirection.UP
