## An attacker in the front garden: walks its lane toward the front door,
## stops to break the tower in its way, then hammers the door. Thieves
## (junkies) don't fight the door — they grab stock and run.
## Factions differ by exports: armor (shrugs off weak hits), resistance to
## towers (only the player's blaster really hurts a boss), speed, damage.
## State: Alive { Advancing <-> Attacking } -> Dead, Dead -> Alive on respawn
## (pool reuse).
##
## Dependencies: LaneBoard, LaneDefender, FrontDoor, HealthComponent, Pools,
##               Profile, Events, Audio, Types autoloads, SfxSynth
class_name LaneEnemy
extends Node3D

signal defeated(enemy: LaneEnemy)
## Reached the door as a thief (it leaves the garden right after).
signal reached_home(enemy: LaneEnemy)

const DEATH_SECONDS: float = 0.18
## Damage a hit always does, however thick the armor.
const MIN_HIT_DAMAGE: float = 1.0

@export var base_max_health: float = 100.0
## Meters per second toward the door.
@export var base_speed: float = 0.38
@export var bite_damage: float = 20.0
@export var bite_interval_seconds: float = 0.8
@export var score_value: int = 10
## Display name for announcements ("Cops").
@export var faction_name: String = "Attacker"

@export_group("Defense")
## Subtracted from every hit that doesn't pierce armor.
@export var armor: float = 0.0
## Multiplier on damage from towers and guards (bosses resist them).
@export var tower_damage_multiplier: float = 1.0

@export_group("Theft")
## Grabs stock at the door instead of attacking it.
@export var steals_stock: bool = false
@export var units_stolen: int = 1

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
var _target_health: HealthComponent = null
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


## Scales the attacker (raids at high heat, later nights).
func apply_wave_modifiers(health_multiplier: float, speed_multiplier: float) -> void:
	_reset_stats(health_multiplier, speed_multiplier)


func is_alive() -> bool:
	return not health_component.is_dead and not Pools.is_in_pool(self)


## Applies a hit. Tower hits are scaled by tower_damage_multiplier; armor is
## subtracted unless [param pierces_armor].
func take_hit(amount: float, source: Node = null, from_tower: bool = false, pierces_armor: bool = false) -> void:
	var damage: float = amount * (tower_damage_multiplier if from_tower else 1.0)
	if not pierces_armor:
		damage -= armor
	health_component.damage(maxf(MIN_HIT_DAMAGE, damage), source)


## Center of the sphere the blaster aims at.
func get_hit_center() -> Vector3:
	return global_position + Vector3(0.0, hit_height, 0.0)


## True while it is hammering on the front door.
func is_at_door() -> bool:
	return _board != null and _target_health != null and _board.door != null and _target_health == _board.door.health_component

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
	_target_health = null
	_walk_phase = randf() * TAU
	if _has_been_used:
		state_chart.send_event(Types.EVENT_RESPAWN)
	_has_been_used = true


func _on_pool_despawned() -> void:
	_board = null
	_target_health = null

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
	if global_position.z + reach >= _board.get_home_z():
		global_position.z = _board.get_home_z() - reach
		_arrive_at_door()
		return
	var blocker: LaneDefender = _board.get_blocker(lane, global_position.z + reach)
	if blocker != null:
		_target_health = blocker.health_component
		state_chart.send_event(Types.EVENT_TARGET_IN_RANGE)


func _on_attacking_state_entered() -> void:
	_seconds_until_bite = bite_interval_seconds * 0.5
	_visual.rotation.z = 0.0


func _on_attacking_state_physics_processing(delta: float) -> void:
	if _target_health == null or _target_health.is_dead:
		_target_health = null
		state_chart.send_event(Types.EVENT_TARGET_OUT_OF_RANGE)
		return
	_seconds_until_bite -= delta
	if _seconds_until_bite > 0.0:
		return
	_seconds_until_bite = bite_interval_seconds
	_target_health.damage(bite_damage, self)
	Audio.play_sfx_at(SfxSynth.get_preset(&"hit"), global_position, 0.15, -6.0)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_visual, "position:z", reach * 0.7, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_visual, "position:z", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _on_dead_state_entered() -> void:
	Profile.stats.increment(Types.STAT_ENEMIES_DEFEATED)
	Events.enemy_defeated.emit(self)
	defeated.emit(self)
	Audio.play_sfx_at(SfxSynth.get_preset(&"pop"), global_position, 0.15)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_visual, "scale", Vector3.ONE * 0.01, DEATH_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(Pools.despawn.bind(self))

# ============================================
# INTERNALS
# ============================================

func _arrive_at_door() -> void:
	if steals_stock:
		reached_home.emit(self)
		Pools.despawn(self)
		return
	if _board.door == null or not _board.door.is_alive():
		return
	_target_health = _board.door.health_component
	state_chart.send_event(Types.EVENT_TARGET_IN_RANGE)


func _reset_stats(health_multiplier: float, speed_multiplier: float) -> void:
	health_component.revive(base_max_health * health_multiplier)
	_speed = base_speed * speed_multiplier
