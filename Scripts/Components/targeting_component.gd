## Finds and keeps a target inside a radius (turrets, auto-aim weapons, AI
## aggro). Detects bodies and areas on its collision mask whose node — or
## node owner — is in target_group. Re-evaluates on a timer, not every frame.
##
## Dependencies: Global, Types autoloads, HealthComponent, PathMoverComponent
class_name TargetingComponent
extends Area2D

signal target_changed(new_target: Node2D)

@export var detection_radius: float = 320.0:
	set(value):
		detection_radius = value
		_apply_radius()
@export var target_group: StringName = &"enemy"
@export var target_priority: Types.TargetPriority = Types.TargetPriority.NEAREST
@export var retarget_interval: float = 0.2
## Keep the current target while it stays in range instead of always switching.
@export var sticky_target: bool = false

var current_target: Node2D = null

var _candidates: Array[Node2D] = []
var _retarget_remaining: float = 0.0
var _detection_shape: CircleShape2D


func _ready() -> void:
	monitorable = false
	_ensure_shape()
	body_entered.connect(_on_node_entered)
	body_exited.connect(_on_node_exited)
	area_entered.connect(_on_node_entered)
	area_exited.connect(_on_node_exited)


func _physics_process(delta: float) -> void:
	_retarget_remaining -= delta
	if _retarget_remaining > 0.0:
		return
	_retarget_remaining = retarget_interval
	_refresh_target()


func has_target() -> bool:
	return is_instance_valid(current_target) and current_target.is_inside_tree()


func get_direction_to_target() -> Vector2:
	return global_position.direction_to(current_target.global_position) if has_target() else Vector2.ZERO


func get_candidates() -> Array[Node2D]:
	_prune_candidates()
	return _candidates


func _refresh_target() -> void:
	_prune_candidates()
	if sticky_target and has_target() and _candidates.has(current_target):
		return
	var best_target: Node2D = null
	var best_score: float = -INF
	for candidate: Node2D in _candidates:
		var candidate_score: float = _score(candidate)
		if candidate_score > best_score:
			best_score = candidate_score
			best_target = candidate
	if best_target != current_target:
		current_target = best_target
		target_changed.emit(current_target)


func _score(candidate: Node2D) -> float:
	match target_priority:
		Types.TargetPriority.FARTHEST:
			return global_position.distance_squared_to(candidate.global_position)
		Types.TargetPriority.STRONGEST, Types.TargetPriority.WEAKEST:
			var health: HealthComponent = Global.find_component(candidate, HealthComponent) as HealthComponent
			var current_health: float = health.current_health if health != null else 0.0
			return current_health if target_priority == Types.TargetPriority.STRONGEST else -current_health
		Types.TargetPriority.FIRST_ON_PATH, Types.TargetPriority.LAST_ON_PATH:
			var path_mover: PathMoverComponent = Global.find_component(candidate, PathMoverComponent) as PathMoverComponent
			var path_progress: float = path_mover.progress if path_mover != null else 0.0
			return path_progress if target_priority == Types.TargetPriority.FIRST_ON_PATH else -path_progress
		_:
			return -global_position.distance_squared_to(candidate.global_position)


func _resolve_target_node(detected: Node) -> Node2D:
	if detected.is_in_group(target_group):
		return detected as Node2D
	if detected.owner != null and detected.owner.is_in_group(target_group):
		return detected.owner as Node2D
	return null


func _on_node_entered(detected: Node) -> void:
	var target_node: Node2D = _resolve_target_node(detected)
	if target_node != null and not _candidates.has(target_node):
		_candidates.append(target_node)
		if not has_target():
			_retarget_remaining = 0.0


func _on_node_exited(detected: Node) -> void:
	var target_node: Node2D = _resolve_target_node(detected)
	if target_node != null:
		_candidates.erase(target_node)
		if target_node == current_target:
			_retarget_remaining = 0.0


func _prune_candidates() -> void:
	for candidate_index: int in range(_candidates.size() - 1, -1, -1):
		var candidate: Variant = _candidates[candidate_index]
		if not is_instance_valid(candidate) or not (candidate as Node2D).is_inside_tree() or not (candidate as Node2D).is_in_group(target_group):
			_candidates.remove_at(candidate_index)


func _ensure_shape() -> void:
	for child: Node in get_children():
		var existing_shape: CollisionShape2D = child as CollisionShape2D
		if existing_shape != null and existing_shape.shape is CircleShape2D:
			_detection_shape = existing_shape.shape as CircleShape2D
	if _detection_shape == null:
		var collision_shape: CollisionShape2D = CollisionShape2D.new()
		_detection_shape = CircleShape2D.new()
		collision_shape.shape = _detection_shape
		add_child(collision_shape)
	_apply_radius()


func _apply_radius() -> void:
	if _detection_shape != null:
		_detection_shape.radius = detection_radius
