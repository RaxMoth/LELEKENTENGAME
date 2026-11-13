## One rat of the cabin's RatPack: it sniffs about for a while, then
## scurries to another spot on the floor (sliding along walls and furniture
## like the player), tail swishing. Close to the player's feet it may bite —
## only once — and then dashes off.
## State: Roaming { Sniffing <-> Scurrying } -> Biting -> Roaming/Scurrying.
##
## Dependencies: RatPack, WalkableArea, Audio, Types autoloads, SfxSynth
class_name Rat
extends Node3D

## Meters per second while scurrying.
@export var run_speed: float = 1.5
## Seconds spent sniffing in one spot (random between x and y).
@export var sniff_seconds: Vector2 = Vector2(0.8, 3.5)
## How far one dash goes (random between x and y meters).
@export var run_distance: Vector2 = Vector2(0.8, 2.6)

## Arrived when this close to where it was going (meters).
const ARRIVE_DISTANCE: float = 0.06
## A player's feet this far above or below (another floor) are out of reach.
const BITE_HEIGHT: float = 0.5
## Tries to find a free spot on the floor for the next dash.
const SPOT_TRIES: int = 6
const TURN_SPEED: float = 14.0
## The bite: a short lunge forward and back (meters, seconds).
const LUNGE_DISTANCE: float = 0.05
const LUNGE_SECONDS: float = 0.12

## The pack it belongs to (set by the RatPack).
var pack: RatPack = null

var _target: Vector3 = Vector3.ZERO
var _seconds_until_run: float = 0.0
var _has_bitten: bool = false
var _animation_time: float = 0.0
var _tween: Tween
var _random: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var state_chart: StateChart = %StateChart
@onready var _body: Node3D = %Body
@onready var _tail: Node3D = %Tail


func _ready() -> void:
	_random.randomize()
	_animation_time = _random.randf() * 10.0


## True once it has bitten (a rat bites only once).
func has_bitten() -> bool:
	return _has_bitten

# ============================================
# STATE CHART CALLBACKS (connected in Rat.tscn)
# ============================================

func _on_sniffing_state_entered() -> void:
	_seconds_until_run = _random.randf_range(sniff_seconds.x, sniff_seconds.y)


func _on_sniffing_state_physics_processing(delta: float) -> void:
	_animate(delta, 0.0)
	if _try_bite(delta):
		return
	_seconds_until_run -= delta
	if _seconds_until_run <= 0.0 and _pick_run_target():
		state_chart.send_event(Types.EVENT_WALK)


func _on_scurrying_state_physics_processing(delta: float) -> void:
	if _try_bite(delta):
		return
	var to_target: Vector3 = Vector3(_target.x - global_position.x, 0.0, _target.z - global_position.z)
	if to_target.length() <= ARRIVE_DISTANCE:
		state_chart.send_event(Types.EVENT_ARRIVED)
		return
	var direction: Vector3 = to_target.normalized()
	var next: Vector3 = global_position + direction * minf(run_speed * delta, to_target.length())
	if pack != null and pack.walkable != null:
		next = pack.walkable.clamp_move(global_position, next)
	if next.is_equal_approx(global_position):
		# Up against a wall or a table: sniff here, then try elsewhere.
		state_chart.send_event(Types.EVENT_ARRIVED)
		return
	global_position = next
	_face(Vector2(direction.x, direction.z), delta)
	_animate(delta, 1.0)


func _on_biting_state_entered() -> void:
	_has_bitten = true
	var feet: Vector3 = pack.get_player_feet() if pack != null else global_position
	_face(Vector2(feet.x - global_position.x, feet.z - global_position.z), 1.0)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_body, "position:z", -LUNGE_DISTANCE, LUNGE_SECONDS * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_land_bite)
	_tween.tween_property(_body, "position:z", 0.0, LUNGE_SECONDS * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_flee_from.bind(feet))

# ============================================
# INTERNALS
# ============================================

## Close to the player's feet a rat that hasn't bitten yet may bite (a
## small chance per second). Returns true when it goes for it.
func _try_bite(delta: float) -> bool:
	if _has_bitten or pack == null:
		return false
	var feet: Vector3 = pack.get_player_feet()
	if not feet.is_finite() or absf(feet.y - global_position.y) > BITE_HEIGHT:
		return false
	if Vector2(feet.x - global_position.x, feet.z - global_position.z).length() > pack.bite_range:
		return false
	if _random.randf() >= pack.bite_chance_per_second * delta:
		return false
	state_chart.send_event(Types.EVENT_TARGET_IN_RANGE)
	return true


func _land_bite() -> void:
	Audio.play_sfx_at(SfxSynth.get_preset(&"squeak"), global_position, 0.2, -4.0)
	if pack != null:
		pack.report_bite()


## After the bite: a dash away from [param feet].
func _flee_from(feet: Vector3) -> void:
	var away: Vector3 = Vector3(global_position.x - feet.x, 0.0, global_position.z - feet.z)
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	_target = global_position + away * run_distance.y
	if pack != null:
		var area: Rect2 = pack.roam_area
		_target = Vector3(clampf(_target.x, area.position.x, area.end.x), global_position.y, clampf(_target.z, area.position.y, area.end.y))
	state_chart.send_event(Types.EVENT_WALK)


## Picks where the next dash goes: a free spot on the floor a little way
## off. Returns false when none was found (it sniffs on).
func _pick_run_target() -> bool:
	if pack == null:
		return false
	for attempt: int in SPOT_TRIES:
		var angle: float = _random.randf() * TAU
		var distance: float = _random.randf_range(run_distance.x, run_distance.y)
		var spot: Vector3 = global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		if not pack.roam_area.has_point(Vector2(spot.x, spot.z)):
			continue
		if pack.walkable != null and not pack.walkable.contains(spot):
			continue
		_target = spot
		return true
	_seconds_until_run = sniff_seconds.x
	return false


func _face(direction: Vector2, delta: float) -> void:
	if direction.length() < 0.001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.y), clampf(TURN_SPEED * delta, 0.0, 1.0))


## A little bob while running and a swishing tail (faster on the run).
func _animate(delta: float, run_ratio: float) -> void:
	_animation_time += delta
	_body.position.y = absf(sin(_animation_time * 28.0)) * 0.006 * run_ratio
	_tail.rotation.y = sin(_animation_time * lerpf(3.0, 14.0, run_ratio)) * lerpf(0.25, 0.45, run_ratio)
