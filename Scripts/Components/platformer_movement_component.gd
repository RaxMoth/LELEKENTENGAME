## Side-view movement for CharacterBody2D: run, gravity, variable-height jumps,
## coyote time, jump buffering and multi-jumps. Jump physics are authored as
## height + time (designer friendly) instead of raw velocities.
##
##   movement.physics_update(self, Input.get_axis(&"move_left", &"move_right"), delta)
##   movement.request_jump()   # on tap / button press
##   movement.release_jump()   # on release (cuts the jump short)
##
## Dependencies: none
class_name PlatformerMovementComponent
extends Node

signal jumped(jump_number: int)
signal landed

@export_group("Run")
@export var run_speed: float = 420.0
@export var ground_acceleration: float = 3200.0
@export var air_acceleration: float = 1800.0
@export var ground_friction: float = 3600.0

@export_group("Jump")
@export var jump_height: float = 200.0
@export var seconds_to_apex: float = 0.38
@export var seconds_to_land: float = 0.3
@export var max_jumps: int = 2
@export var coyote_seconds: float = 0.1
@export var jump_buffer_seconds: float = 0.12
## Upward velocity multiplier applied when the jump is released early.
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.45
@export var max_fall_speed: float = 1600.0

var jumps_used: int = 0

var _coyote_remaining: float = 0.0
var _buffer_remaining: float = 0.0
var _was_on_floor: bool = false


func get_jump_velocity() -> float:
	return -2.0 * jump_height / seconds_to_apex


func get_rise_gravity() -> float:
	return 2.0 * jump_height / (seconds_to_apex * seconds_to_apex)


func get_fall_gravity() -> float:
	return 2.0 * jump_height / (seconds_to_land * seconds_to_land)


func request_jump() -> void:
	_buffer_remaining = jump_buffer_seconds


func release_jump(body: CharacterBody2D) -> void:
	if body.velocity.y < 0.0:
		body.velocity.y *= jump_cut_multiplier


func physics_update(body: CharacterBody2D, horizontal_input: float, delta: float) -> void:
	var on_floor: bool = body.is_on_floor()
	if on_floor:
		_coyote_remaining = coyote_seconds
		if not _was_on_floor:
			jumps_used = 0
			landed.emit()
	else:
		_coyote_remaining -= delta
	_buffer_remaining -= delta

	var gravity: float = get_rise_gravity() if body.velocity.y < 0.0 else get_fall_gravity()
	body.velocity.y = minf(body.velocity.y + gravity * delta, max_fall_speed)

	var target_speed: float = horizontal_input * run_speed
	var rate: float = ground_acceleration if on_floor else air_acceleration
	if is_zero_approx(horizontal_input) and on_floor:
		rate = ground_friction
	body.velocity.x = move_toward(body.velocity.x, target_speed, rate * delta)

	if _buffer_remaining > 0.0 and _can_jump():
		_perform_jump(body)

	body.move_and_slide()
	_was_on_floor = body.is_on_floor()


func _can_jump() -> bool:
	if _coyote_remaining > 0.0 and jumps_used == 0:
		return true
	return jumps_used > 0 and jumps_used < max_jumps or (jumps_used == 0 and max_jumps > 1)


func _perform_jump(body: CharacterBody2D) -> void:
	# Walking off a ledge without jumping still consumes the "ground" jump.
	if jumps_used == 0 and _coyote_remaining <= 0.0:
		jumps_used = 1
	body.velocity.y = get_jump_velocity()
	jumps_used += 1
	_buffer_remaining = 0.0
	_coyote_remaining = 0.0
	jumped.emit(jumps_used)


func reset() -> void:
	jumps_used = 0
	_coyote_remaining = 0.0
	_buffer_remaining = 0.0
