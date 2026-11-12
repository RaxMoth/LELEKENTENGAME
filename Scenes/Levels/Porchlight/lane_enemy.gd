## Attacker in a lane-defense game: walks down its lane toward home, stops to
## bite the defender in its way and costs the player a life when it arrives.
## Flying attackers pass over defenders and can only be shot by hand.
## State: Alive { Advancing <-> Attacking } -> Dead, Dead -> Alive on respawn
## (pool reuse).
##
## Dependencies: LaneBoard, LaneDefender, HealthComponent, Pools, Profile,
##               Events, Audio, Types autoloads, SfxSynth
class_name LaneEnemy
extends Node3D

signal defeated(enemy: LaneEnemy)
signal reached_home(enemy: LaneEnemy)

const DEATH_SECONDS: float = 0.18

@export var base_max_health: float = 100.0
## Meters per second toward home.
@export var base_speed: float = 0.38
@export var bite_damage: float = 20.0
@export var bite_interval_seconds: float = 0.8
@export var score_value: int = 10
## Flies over defenders and bolts; only the player's blaster reaches it.
@export var is_flying: bool = false

@export_group("Body")
## Radius of the sphere the player's blaster can hit.
@export var hit_radius: float = 0.45
## Height of that sphere's center above the node origin.
@export var hit_height: float = 0.75
## Distance from the origin to the front of the body.
@export var reach: float = 0.35

@export_group("Animation")
@export var step_frequency: float = 5.0
@export var bob_height: float = 0.05
@export var sway_degrees: float = 5.0

var lane: int = 0

var _board: LaneBoard = null
var _speed: float = 0.0
var _target: LaneDefender = null
var _seconds_until_bite: float = 0.0
var _walk_phase: float = 0.0
var _has_been_used: bool = false
var _tween: Tween

@onready var health_component: HealthComponent = %HealthComponent
@onready var hit_flash_component: HitFlash3DComponent = %HitFlash3DComponent
@onready var state_chart: StateChart = %StateChart
@onready var _visual: Node3D = %Visual


func _ready() -> void:
	add_to_group(Types.GROUP_ENEMY)
	health_component.died.connect(func() -> void: state_chart.send_event(Types.EVENT_DIED))
	_reset_stats(1.0, 1.0)

# ============================================
# PUBLIC API
# ============================================

## Called by the board after spawning: which lane to walk.
func enter_lane(board: LaneBoard, lane_index: int) -> void:
	_board = board
	lane = lane_index


## Called by the wave spawner after spawning.
func apply_wave_modifiers(health_multiplier: float, speed_multiplier: float) -> void:
	_reset_stats(health_multiplier, speed_multiplier)


func is_alive() -> bool:
	return not health_component.is_dead and not Pools.is_in_pool(self)


func take_hit(amount: float, source: Node = null) -> void:
	health_component.damage(amount, source)


## Center of the sphere the blaster aims at.
func get_hit_center() -> Vector3:
	return global_position + Vector3(0.0, hit_height, 0.0)

# ============================================
# POOLING
# ============================================

func _on_pool_spawned() -> void:
	_reset_stats(1.0, 1.0)
	hit_flash_component.reset()
	if _tween != null:
		_tween.kill()
	_visual.scale = Vector3.ONE
	_visual.position = Vector3.ZERO
	_visual.rotation = Vector3.ZERO
	_target = null
	_walk_phase = randf() * TAU
	if _has_been_used:
		state_chart.send_event(Types.EVENT_RESPAWN)
	_has_been_used = true


func _on_pool_despawned() -> void:
	_board = null
	_target = null

# ============================================
# STATE CHART CALLBACKS
# ============================================

func _on_advancing_state_physics_processing(delta: float) -> void:
	if _board == null:
		return
	global_position.z += _speed * delta
	_walk_phase += delta * step_frequency
	_visual.position.y = absf(sin(_walk_phase)) * bob_height
	_visual.rotation.z = sin(_walk_phase) * deg_to_rad(sway_degrees)
	if global_position.z >= _board.get_home_z():
		reached_home.emit(self)
		Pools.despawn(self)
		return
	if is_flying:
		return
	var blocker: LaneDefender = _board.get_blocker(lane, global_position.z + reach)
	if blocker != null:
		_target = blocker
		state_chart.send_event(Types.EVENT_TARGET_IN_RANGE)


func _on_attacking_state_entered() -> void:
	_seconds_until_bite = bite_interval_seconds * 0.5
	_visual.rotation.z = 0.0


func _on_attacking_state_physics_processing(delta: float) -> void:
	if not is_instance_valid(_target) or not _target.is_alive():
		_target = null
		state_chart.send_event(Types.EVENT_TARGET_OUT_OF_RANGE)
		return
	_seconds_until_bite -= delta
	if _seconds_until_bite > 0.0:
		return
	_seconds_until_bite = bite_interval_seconds
	_target.health_component.damage(bite_damage, self)
	Audio.play_sfx_at_3d(SfxSynth.get_preset(&"hit"), global_position, 0.15, -6.0)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_visual, "position:z", reach * 0.7, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_visual, "position:z", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _on_dead_state_entered() -> void:
	Profile.stats.increment(Types.STAT_ENEMIES_DEFEATED)
	Events.enemy_defeated.emit(self)
	defeated.emit(self)
	Audio.play_sfx_at_3d(SfxSynth.get_preset(&"pop"), global_position, 0.15)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_visual, "scale", Vector3.ONE * 0.01, DEATH_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(Pools.despawn.bind(self))

# ============================================
# INTERNALS
# ============================================

func _reset_stats(health_multiplier: float, speed_multiplier: float) -> void:
	health_component.revive(base_max_health * health_multiplier)
	_speed = base_speed * speed_multiplier
