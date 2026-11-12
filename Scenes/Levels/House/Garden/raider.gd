## A police raider in the open yard. Enters at the edge and works its way to
## the front door with its RaidSquad: dashes to the next cover (a tree, rock,
## bush or the car, picked by YardNavigation), crouches there a while —
## longer when it is being shot at — and waits for the squad; from the last
## cover before the house the whole squad rushes the door together and
## hammers it. A battering-ram team skips cover, waits for the rush and hits
## the door very hard. Officers differ by exports (health, armor, speed,
## door damage). Pooled.
## State: Alive { Moving <-> InCover, Attacking } -> Dead, Dead -> Alive on
## respawn (pool reuse).
##
## Dependencies: Yard, RaidSquad, FrontDoor, YardNavigation, HealthComponent,
##               HitFlash3DComponent, Pools, Profile, Events, Audio, Types
##               autoloads, SfxSynth
class_name Raider
extends Node3D

signal defeated(raider: Raider)

const DEATH_SECONDS: float = 0.25
## Damage a hit always does, however thick the armor.
const MIN_HIT_DAMAGE: float = 1.0
## Arrived when this close to the destination (meters).
const ARRIVE_DISTANCE: float = 0.15
## Seconds after a hit during which the raider counts as pinned down.
const SUPPRESSION_SECONDS: float = 2.5
const TURN_SPEED: float = 8.0
## Hit spheres of a crouching raider sit this much lower.
const CROUCHED_HIT_SCALE: float = 0.7

@export var base_max_health: float = 120.0
## Meters per second between covers...
@export var move_speed: float = 1.7
## ...and when the squad rushes the door.
@export var rush_speed: float = 2.6
@export var door_damage: float = 16.0
@export var hit_interval_seconds: float = 1.0
@export var score_value: int = 15
## Display name for announcements ("Cops").
@export var faction_name: String = "Cops"

@export_group("Defense")
## Subtracted from every hit that doesn't pierce armor.
@export var armor: float = 0.0
## Multiplier on damage from turrets and guards.
@export var tower_damage_multiplier: float = 1.0

@export_group("Tactics")
## Seconds spent in each cover (random between x and y).
@export var cover_seconds: Vector2 = Vector2(1.5, 3.5)
## Farthest dash between two covers.
@export var max_cover_step: float = 7.0
## Closer than this to the door, the raider waits for the squad's rush.
@export var stage_distance: float = 6.5
## A battering-ram team: no cover, waits at the stage line, rams the door.
@export var is_battering_ram: bool = false

@export_group("Body")
## Radius of the sphere shots hit.
@export var hit_radius: float = 0.45
## Height of that sphere's center above the node origin.
@export var hit_height: float = 0.8
## Radius kept clear of obstacles and other raiders.
@export var body_radius: float = 0.35

## The squad this raider moves with (set by the director).
var squad: RaidSquad = null
## Waiting in the last cover for the squad's rush.
var is_staged: bool = false
## Which spot in front of the door is this raider's (set by the director).
var door_spot_index: int = 0

var _yard: Yard = null
var _destination: Vector2 = Vector2.ZERO
var _is_heading_for_door: bool = false
var _is_in_motion: bool = true
var _speed: float = 0.0
var _health_multiplier: float = 1.0
var _seconds_until_move: float = 0.0
var _seconds_since_hit: float = SUPPRESSION_SECONDS
var _seconds_until_hit: float = 0.0
var _last_direction: Vector2 = Vector2.ZERO
var _has_been_used: bool = false
var _is_frozen: bool = false
var _tween: Tween

@onready var health_component: HealthComponent = %HealthComponent
@onready var hit_flash_component: HitFlash3DComponent = %HitFlash3DComponent
@onready var state_chart: StateChart = %StateChart
@onready var _visual: Node3D = %Visual
## The bodies under Visual (one per officer; a ram team has two).
var _bodies: Array[RaiderBody] = []


func _ready() -> void:
	add_to_group(Types.GROUP_ENEMY)
	health_component.died.connect(func() -> void: state_chart.send_event(Types.EVENT_DIED))
	health_component.damaged.connect(func(_damage_info: DamageInfo) -> void: _seconds_since_hit = 0.0)
	_reset_stats()
	for child: Node in _visual.get_children():
		if child is RaiderBody:
			_bodies.append(child as RaiderBody)

# ============================================
# PUBLIC API
# ============================================

## Called by the yard after spawning.
func enter_yard(yard: Yard) -> void:
	_yard = yard
	_plan_next_move()


## Scales the raider (later raids). Speed is kept: tougher, not faster.
func apply_wave_modifiers(health_multiplier: float, _speed_multiplier: float) -> void:
	_health_multiplier = health_multiplier
	_reset_stats()


func is_alive() -> bool:
	return not health_component.is_dead and not Pools.is_in_pool(self)


## Out of cover and on the way somewhere (squads let only some move at once).
func is_moving() -> bool:
	return _is_in_motion


## Where it is heading (a cover spot or its spot at the door).
func get_destination() -> Vector2:
	return _destination


## True while it is hitting the front door.
func is_at_door() -> bool:
	return _is_heading_for_door and not _is_in_motion and is_alive()


## Applies a hit. Turret and guard hits are scaled by tower_damage_multiplier;
## armor is subtracted unless [param pierces_armor].
func take_hit(amount: float, source: Node = null, from_tower: bool = false, pierces_armor: bool = false) -> void:
	var damage: float = amount * (tower_damage_multiplier if from_tower else 1.0)
	if not pierces_armor:
		damage -= armor
	health_component.damage(maxf(MIN_HIT_DAMAGE, damage), source)


## Center of the sphere shots aim at (lower while crouching in cover).
func get_hit_center() -> Vector3:
	var crouch: float = _bodies[0].get_crouch_amount() if not _bodies.is_empty() else 0.0
	return global_position + Vector3(0.0, hit_height * lerpf(1.0, CROUCHED_HIT_SCALE, crouch), 0.0)


## The squad rushes: everyone heads for the door.
func on_squad_rush() -> void:
	if not is_alive():
		return
	is_staged = false
	_head_for_door()


## Stops it where it stands (end of the shift, staged scenes) or lets it go again.
func freeze(should_freeze: bool = true) -> void:
	_is_frozen = should_freeze

# ============================================
# POOLING
# ============================================

func _on_pool_spawned() -> void:
	_health_multiplier = 1.0
	_reset_stats()
	hit_flash_component.reset()
	if _tween != null:
		_tween.kill()
	_visual.scale = Vector3.ONE
	_visual.position = Vector3.ZERO
	_visual.rotation = Vector3.ZERO
	for body: RaiderBody in _bodies:
		body.reset_pose()
	squad = null
	is_staged = false
	door_spot_index = 0
	_is_heading_for_door = false
	# Every (re)spawn starts in Moving (the chart's initial / respawn state).
	_is_in_motion = true
	_is_frozen = false
	_last_direction = Vector2.ZERO
	_seconds_since_hit = SUPPRESSION_SECONDS
	if _has_been_used:
		state_chart.send_event(Types.EVENT_RESPAWN)
	_has_been_used = true


func _on_pool_despawned() -> void:
	_yard = null
	squad = null

# ============================================
# STATE CHART CALLBACKS (connected in Raider.tscn)
# ============================================

func _on_moving_state_entered() -> void:
	_is_in_motion = true
	_set_crouched(false)


func _on_moving_state_physics_processing(delta: float) -> void:
	if _yard == null or _is_frozen:
		return
	_seconds_since_hit += delta
	var here: Vector2 = Vector2(global_position.x, global_position.z)
	if here.distance_to(_destination) <= ARRIVE_DISTANCE:
		_arrive()
		return
	var direction: Vector2 = YardNavigation.steer(here, _destination, _yard.get_obstacle_circles(), _yard.get_raider_positions(), body_radius, _last_direction)
	_last_direction = direction
	var next: Vector2 = here + direction * _speed * delta
	next = YardNavigation.resolve_overlap(next, _yard.get_obstacle_circles(), body_radius)
	# Door spots lie right against the house; everything else stays in the field.
	if not _is_heading_for_door:
		next = _yard.clamp_to_bounds(next)
	global_position = Vector3(next.x, global_position.y, next.y)
	_face(direction, delta)
	_animate_bodies(delta, _speed / maxf(0.1, move_speed))


func _on_in_cover_state_entered() -> void:
	_is_in_motion = false
	_set_crouched(not is_battering_ram)
	_seconds_until_move = randf_range(cover_seconds.x, cover_seconds.y)
	_face_toward(_yard.get_door_point() if _yard != null else Vector2.ZERO, 1.0)


func _on_in_cover_state_physics_processing(delta: float) -> void:
	_animate_bodies(delta, 0.0)
	if _yard == null or _is_frozen:
		return
	_seconds_since_hit += delta
	# Pinned down: shots keep the head low.
	if _seconds_since_hit < SUPPRESSION_SECONDS:
		return
	if is_staged:
		return
	_seconds_until_move -= delta
	if _seconds_until_move <= 0.0 and (squad == null or squad.may_move(self)):
		_plan_next_move()


func _on_attacking_state_entered() -> void:
	_is_in_motion = false
	_set_crouched(false)
	_seconds_until_hit = hit_interval_seconds * 0.5
	_face_toward(_yard.get_door_point() if _yard != null else Vector2.ZERO, 1.0)


func _on_attacking_state_physics_processing(delta: float) -> void:
	_animate_bodies(delta, 0.0)
	if _yard == null or _is_frozen or _yard.door == null or not _yard.door.is_alive():
		return
	_seconds_until_hit -= delta
	if _seconds_until_hit > 0.0:
		return
	_seconds_until_hit = hit_interval_seconds
	# An open or unbolted front door gives way faster (FrontDoor.get_damage_multiplier).
	_yard.door.health_component.damage(door_damage * _yard.door.get_damage_multiplier(), self)
	Audio.play_sfx_at(SfxSynth.get_preset(&"hit"), global_position, 0.15, -2.0 if is_battering_ram else -6.0)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	var lunge: float = 0.45 if is_battering_ram else 0.25
	for body: RaiderBody in _bodies:
		body.play_strike()
	_tween.tween_property(_visual, "position:z", lunge, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_visual, "position:z", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _on_dead_state_entered() -> void:
	_is_in_motion = false
	is_staged = false
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

## Picks where to go next: the squad's rush → the door; otherwise the next
## cover toward the house, or — near the house — wait here for the rush.
func _plan_next_move() -> void:
	if _yard == null:
		return
	if squad != null and squad.is_rushing():
		_head_for_door()
		return
	var here: Vector2 = Vector2(global_position.x, global_position.z)
	var door_point: Vector2 = _yard.get_door_point()
	if is_battering_ram:
		var stage_point: Vector2 = door_point + (here - door_point).normalized() * stage_distance
		if here.distance_to(door_point) <= stage_distance + 0.3:
			_stage()
		else:
			_go_to(stage_point, move_speed)
		return
	var cover: Vector2 = YardNavigation.NO_SPOT
	if here.distance_to(door_point) > stage_distance:
		cover = YardNavigation.find_cover_spot(here, door_point, _yard.get_obstacle_circles(), _yard.get_reserved_spots(self), max_cover_step, 1.5, body_radius)
	if cover == YardNavigation.NO_SPOT:
		if here.distance_to(door_point) <= stage_distance + max_cover_step * 0.5:
			_stage()
		else:
			# Open ground ahead: dash a stretch straight at the house.
			_go_to(here + (door_point - here).normalized() * minf(max_cover_step, here.distance_to(door_point) - stage_distance), move_speed)
		return
	_go_to(cover, move_speed)


func _stage() -> void:
	is_staged = true
	_destination = Vector2(global_position.x, global_position.z)
	if squad == null:
		_head_for_door()
	elif _is_in_motion:
		state_chart.send_event(Types.EVENT_TAKE_COVER)


func _head_for_door() -> void:
	if _yard == null:
		return
	var spots: PackedVector2Array = _yard.get_door_spots(door_spot_index + 1)
	_is_heading_for_door = true
	_go_to(spots[door_spot_index], rush_speed)


func _go_to(destination: Vector2, speed: float) -> void:
	_destination = destination
	_speed = speed
	if not _is_in_motion:
		state_chart.send_event(Types.EVENT_MOVE)


func _arrive() -> void:
	if _is_heading_for_door:
		state_chart.send_event(Types.EVENT_TARGET_IN_RANGE)
	else:
		state_chart.send_event(Types.EVENT_TAKE_COVER)


func _set_crouched(is_crouched: bool) -> void:
	for body: RaiderBody in _bodies:
		body.set_crouched(is_crouched)


func _face(direction: Vector2, delta: float) -> void:
	if direction.length() < 0.01:
		return
	var target_yaw: float = atan2(direction.x, direction.y)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))


func _face_toward(point: Vector2, weight: float) -> void:
	var direction: Vector2 = point - Vector2(global_position.x, global_position.z)
	if direction.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.y), weight)


func _reset_stats() -> void:
	health_component.revive(base_max_health * _health_multiplier)


## Walk cycle, crouch easing and strikes of every body (a ram team has two).
func _animate_bodies(delta: float, speed_ratio: float) -> void:
	for body: RaiderBody in _bodies:
		body.animate(delta, speed_ratio)
