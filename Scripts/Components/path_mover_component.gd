## Moves its owner along a Path2D at constant speed (tower-defense creeps,
## patrols, conveyor items). Exposes progress for "first on path" targeting.
##
## Dependencies: none
class_name PathMoverComponent
extends Node

signal reached_end

@export var path: Path2D
@export var speed: float = 120.0
@export var loop: bool = false
@export var rotate_body: bool = false
## Node that gets moved (defaults to owner).
@export var body: Node2D

## Distance travelled along the path in pixels.
var progress: float = 0.0
var speed_multiplier: float = 1.0

var _finished: bool = false


func _ready() -> void:
	if body == null:
		body = owner as Node2D


func set_path(new_path: Path2D, start_progress: float = 0.0) -> void:
	path = new_path
	progress = start_progress
	_finished = false
	_apply_position()


func _physics_process(delta: float) -> void:
	if path == null or path.curve == null or body == null or _finished:
		return
	progress += speed * speed_multiplier * delta
	var path_length: float = path.curve.get_baked_length()
	if progress >= path_length:
		if loop:
			progress = fmod(progress, path_length)
		else:
			progress = path_length
			_finished = true
			_apply_position()
			reached_end.emit()
			return
	_apply_position()


func get_progress_ratio() -> float:
	if path == null or path.curve == null:
		return 0.0
	return progress / maxf(1.0, path.curve.get_baked_length())


func _apply_position() -> void:
	if path == null or path.curve == null or body == null:
		return
	var path_transform: Transform2D = path.global_transform * path.curve.sample_baked_with_rotation(progress)
	body.global_position = path_transform.origin
	if rotate_body:
		body.global_rotation = path_transform.get_rotation()
