## Acceleration/friction based movement with knockback for CharacterBody2D.
##
##   velocity_component.accelerate_in_direction(input_direction, delta)
##   velocity_component.move(self, delta)
##
## Dependencies: none
class_name VelocityComponent
extends Node

@export var max_speed: float = 300.0
@export var acceleration: float = 2400.0
@export var friction: float = 3000.0
## How quickly knockback fades (higher = snappier).
@export var knockback_recovery: float = 10.0

var velocity: Vector2 = Vector2.ZERO
var speed_multiplier: float = 1.0

var _knockback: Vector2 = Vector2.ZERO


func accelerate_in_direction(direction: Vector2, delta: float) -> void:
	var target_velocity: Vector2 = direction.limit_length(1.0) * max_speed * speed_multiplier
	var rate: float = acceleration if direction != Vector2.ZERO else friction
	velocity = velocity.move_toward(target_velocity, rate * delta)


func accelerate_toward(target_position: Vector2, from_position: Vector2, delta: float) -> void:
	accelerate_in_direction(from_position.direction_to(target_position), delta)


func decelerate(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func apply_knockback(impulse: Vector2) -> void:
	_knockback += impulse


func move(body: CharacterBody2D, delta: float) -> void:
	_knockback = _knockback.lerp(Vector2.ZERO, 1.0 - exp(-knockback_recovery * delta))
	body.velocity = velocity + _knockback
	body.move_and_slide()


func reset() -> void:
	velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	speed_multiplier = 1.0
