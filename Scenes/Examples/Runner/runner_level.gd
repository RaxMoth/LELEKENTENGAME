## Example: endless one-tap runner. Tap (or Space) to jump, tap again in the
## air to double jump; hold for higher jumps. Speed ramps up over time.
##
## Shows: PlatformerMovementComponent (coyote time, buffering, variable
## height), pooled obstacles, Parallax2D, GestureDetector, endless levels
## with best-score tracking.
##
## Dependencies: LevelBase, Pools, Profile, Global autoloads
extends LevelBase

@export var obstacle_scenes: Array[PackedScene] = []
@export var start_speed: float = 420.0
@export var max_speed: float = 950.0
@export var speed_gain_per_second: float = 12.0
@export var min_spawn_gap_seconds: float = 0.85
@export var max_spawn_gap_seconds: float = 1.7
@export var spawn_x: float = 900.0
@export var ground_y: float = 960.0
@export var distance_per_point: float = 60.0

var current_speed: float = 0.0

var _distance_travelled: float = 0.0
var _spawn_remaining: float = 1.2

@onready var player: RunnerPlayer = %Player
@onready var _gesture_detector: GestureDetector = %GestureDetector
@onready var _parallax_layers: Array[Parallax2D] = [%FarLayer, %NearLayer]


func _on_level_setup() -> void:
	current_speed = start_speed
	RunnerObstacle.scroll_speed = 0.0
	player.died.connect(_on_player_died)
	_gesture_detector.touch_started.connect(func(_position: Vector2) -> void: player.jump_pressed())
	_gesture_detector.touch_ended.connect(func(_position: Vector2) -> void: player.jump_released())
	_update_parallax()


func _on_level_started() -> void:
	player.is_running = true


func _level_physics_process(delta: float) -> void:
	current_speed = minf(max_speed, current_speed + speed_gain_per_second * delta)
	RunnerObstacle.scroll_speed = current_speed
	_distance_travelled += current_speed * delta
	var distance_score: int = int(_distance_travelled / distance_per_point)
	if distance_score != score:
		set_score(distance_score)
	_spawn_remaining -= delta
	if _spawn_remaining <= 0.0:
		_spawn_obstacle()
		# Faster runs need slightly longer gaps so jumps stay possible.
		var speed_ratio: float = current_speed / start_speed
		_spawn_remaining = randf_range(min_spawn_gap_seconds, max_spawn_gap_seconds) / sqrt(speed_ratio) * clampf(speed_ratio, 1.0, 1.4)
	_update_parallax()


func _spawn_obstacle() -> void:
	if obstacle_scenes.is_empty():
		return
	Pools.spawn(obstacle_scenes.pick_random(), world, Vector2(spawn_x, ground_y))


func _update_parallax() -> void:
	for layer_index: int in _parallax_layers.size():
		_parallax_layers[layer_index].autoscroll = Vector2(-current_speed * (0.15 + 0.25 * layer_index), 0.0) if is_playing() else Vector2.ZERO


func _on_level_finished(result: LevelResult) -> void:
	RunnerObstacle.scroll_speed = 0.0
	_update_parallax()
	Profile.stats.record_max(Types.STAT_BEST_RUNNER_SCORE, result.score)


func _on_player_died() -> void:
	player.is_running = false
	RunnerObstacle.scroll_speed = 0.0
	await Global.wait(0.6)
	end_run()
