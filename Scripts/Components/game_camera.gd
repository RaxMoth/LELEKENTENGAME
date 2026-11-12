## Camera2D with target following, trauma-based screen shake (respects the
## Screen Shake setting) and optional one-finger pan + pinch zoom for
## strategy / tower-defense maps.
##
## Shake from anywhere: Events.camera_shake_requested.emit(0.4)
##
## Dependencies: Events, Settings autoloads
class_name GameCamera
extends Camera2D

@export var follow_target: Node2D
@export_group("Shake")
@export var max_shake_offset: Vector2 = Vector2(28, 20)
@export var max_shake_rotation_degrees: float = 2.0
@export var trauma_decay_per_second: float = 1.6
@export_group("Touch Controls")
@export var enable_touch_pan: bool = false
@export var enable_pinch_zoom: bool = false
@export var min_zoom: float = 0.6
@export var max_zoom: float = 2.0

var trauma: float = 0.0

var _noise: FastNoiseLite = FastNoiseLite.new()
var _noise_time: float = 0.0
var _active_touches: Dictionary[int, Vector2] = {}
var _last_pinch_distance: float = 0.0


func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 2.0
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	Events.camera_shake_requested.connect(add_trauma)
	if follow_target != null:
		global_position = follow_target.global_position
		reset_smoothing.call_deferred()


func add_trauma(amount: float) -> void:
	if Settings.get_bool(Settings.KEY_SCREEN_SHAKE_ENABLED):
		trauma = clampf(trauma + amount, 0.0, 1.0)


func _physics_process(_delta: float) -> void:
	if is_instance_valid(follow_target):
		global_position = follow_target.global_position


func _process(delta: float) -> void:
	if trauma <= 0.0:
		if offset != Vector2.ZERO:
			offset = Vector2.ZERO
			rotation = 0.0
		return
	trauma = maxf(0.0, trauma - trauma_decay_per_second * delta)
	_noise_time += delta * 60.0
	# Squared trauma gives a nicer falloff: small hits barely move the camera.
	var shake_strength: float = trauma * trauma
	offset = Vector2(
		max_shake_offset.x * shake_strength * _noise.get_noise_2d(_noise_time, 0.0),
		max_shake_offset.y * shake_strength * _noise.get_noise_2d(0.0, _noise_time)
	)
	rotation = deg_to_rad(max_shake_rotation_degrees) * shake_strength * _noise.get_noise_2d(_noise_time, _noise_time)


func _unhandled_input(event: InputEvent) -> void:
	if not enable_touch_pan and not enable_pinch_zoom:
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_active_touches[touch.index] = touch.position
		else:
			_active_touches.erase(touch.index)
		_last_pinch_distance = 0.0
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag == null:
		return
	_active_touches[drag.index] = drag.position
	if _active_touches.size() == 1 and enable_touch_pan and follow_target == null:
		global_position -= drag.relative / zoom
	elif _active_touches.size() == 2 and enable_pinch_zoom:
		var touch_points: Array = _active_touches.values()
		var first_point: Vector2 = touch_points[0]
		var pinch_distance: float = first_point.distance_to(touch_points[1])
		if _last_pinch_distance > 0.0:
			var zoom_factor: float = clampf(zoom.x * pinch_distance / _last_pinch_distance, min_zoom, max_zoom)
			zoom = Vector2.ONE * zoom_factor
		_last_pinch_distance = pinch_distance
