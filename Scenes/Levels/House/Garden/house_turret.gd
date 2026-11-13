## A gun turret mounted on the house front (a house upgrade: "Roof
## Turrets", one more per level). On its own it swings toward the raider
## nearest the door that it can see — cover blocks it — and fires when lined
## up. Taken over from the office's Security PC it follows the aim point it
## is given and fires on command; the PC shows the view from its camera mount.
## Not pooled (a few fixed mounts); no physics.
##
##   turret.setup(yard)
##   turret.set_manual(true); turret.set_manual_aim(point); turret.fire()
##
## Dependencies: Yard, Raider, BeamTracer, PopEffect3D, RayMath, Pools,
##               Audio autoloads, Palette, SfxSynth
class_name HouseTurret
extends Node3D

const TRACER_SCENE: PackedScene = preload("res://Scenes/Levels/House/Garden/BeamTracer.tscn")
## Lined up within this angle, the automatic turret fires.
const FIRE_CONE_DEGREES: float = 4.0
const PITCH_LIMITS_DEGREES: Vector2 = Vector2(-60.0, 15.0)

## Turrets upgrade level at which this mount gets its gun (1, 2, 3).
@export_range(1, 10) var mount_level: int = 1
@export var damage: float = 24.0
@export var fire_interval_seconds: float = 0.45
@export var range_meters: float = 24.0
## Degrees per second the head swings.
@export var turn_speed_degrees: float = 150.0
## Seconds between looking for a new target.
@export var retarget_interval_seconds: float = 0.3

var is_manual: bool = false

var _yard: Yard = null
var _target: Raider = null
var _manual_aim_point: Vector3 = Vector3.ZERO
var _cooldown: float = 0.0
var _seconds_until_retarget: float = 0.0
var _recoil_tween: Tween

@onready var _head: Node3D = %Head
@onready var _barrel_pivot: Node3D = %BarrelPivot
@onready var _barrel: Node3D = %Barrel
@onready var _muzzle: Marker3D = %Muzzle
@onready var _camera_mount: Marker3D = %CameraMount
@onready var _flash: MeshInstance3D = %Flash
@onready var _mount_mesh: MeshInstance3D = %Mount
@onready var _housing: MeshInstance3D = %Housing
@onready var _sensor: MeshInstance3D = %Sensor


func _ready() -> void:
	_flash.visible = false
	_manual_aim_point = global_position + -global_transform.basis.z * 10.0 + Vector3(0.0, -global_position.y, 0.0)


## Called by the FrontGarden at setup.
func setup(yard: Yard) -> void:
	_yard = yard


## Shown and working once the Roof Turrets upgrade reaches [member mount_level].
func set_mounted(is_mounted: bool) -> void:
	visible = is_mounted
	if not is_mounted:
		_target = null


func is_mounted() -> bool:
	return visible


## Where the Security PC's camera sits (its view follows this node).
func get_camera_mount() -> Node3D:
	return _camera_mount


func get_muzzle_position() -> Vector3:
	return _muzzle.global_position


## Where the barrel points.
func get_aim_direction() -> Vector3:
	return -_barrel_pivot.global_transform.basis.z


## Taken over by the Security PC (true) or back on its own (false).
func set_manual(should_be_manual: bool) -> void:
	is_manual = should_be_manual
	_target = null


## Someone sits in the turret (the goggles at the Security PC): its own
## housing hides so it doesn't block their view; the barrel stays.
func set_seated(is_seated: bool) -> void:
	_mount_mesh.visible = not is_seated
	_housing.visible = not is_seated
	_sensor.visible = not is_seated


## Manual mode: the point in the world to swing toward.
func set_manual_aim(world_point: Vector3) -> void:
	_manual_aim_point = world_point


## Per frame while the shift runs (FrontGarden).
func step(delta: float) -> void:
	if not is_mounted() or _yard == null:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if is_manual:
		_swing_toward(_manual_aim_point, delta)
		return
	_seconds_until_retarget -= delta
	if _seconds_until_retarget <= 0.0 or _target == null or not _target.is_alive():
		_seconds_until_retarget = retarget_interval_seconds
		_target = _find_target()
	if _target == null:
		return
	var aligned: bool = _swing_toward(_target.get_hit_center(), delta)
	if aligned:
		fire()


## What the turret goggles' overlay calls it.
func get_display_name() -> String:
	return tr("Roof turret %d") % mount_level


## The overlay's ability line: what it does and its state.
func get_ability_text() -> String:
	return tr("Machine gun · ready") if _cooldown <= 0.0 else tr("Machine gun · reloading")


## 0..1 for the overlay's bar: how ready the next shot is (or how hot a beam burns).
func get_ability_ready() -> float:
	return 1.0 - clampf(_cooldown / maxf(0.01, fire_interval_seconds), 0.0, 1.0)


## @virtual The raider to go after (the one nearest the door it can see).
func _find_target() -> Raider:
	return _yard.find_raider_nearest_door(_muzzle.global_position, range_meters)


## Fires one shot along the barrel when ready. Returns the raider hit, or null.
func fire() -> Raider:
	if not is_mounted() or _yard == null or _cooldown > 0.0:
		return null
	_cooldown = fire_interval_seconds
	var origin: Vector3 = _muzzle.global_position
	var direction: Vector3 = get_aim_direction()
	var hit: Raider = _yard.pick_raider(origin, direction, range_meters)
	var shot_end: Vector3 = origin + direction * range_meters
	if hit != null:
		shot_end = hit.get_hit_center()
		hit.take_hit(damage, self, true)
		PopEffect3D.spawn(shot_end, Palette.PROJECTILE, 0.4, _yard.get_effects_root())
	else:
		var ground: float = _yard.get_ground_distance(origin, direction)
		if ground != RayMath.NO_HIT and ground < range_meters:
			shot_end = origin + direction * ground
	var tracer: BeamTracer = Pools.spawn(TRACER_SCENE, _yard.get_effects_root(), origin) as BeamTracer
	tracer.fire(origin, shot_end)
	Audio.play_sfx_at(SfxSynth.get_preset(&"shoot"), origin, 0.1, -6.0)
	_play_recoil()
	return hit


## Turns the head (yaw) and barrel (pitch) toward [param point] at the turn
## speed. Returns true once lined up.
func _swing_toward(point: Vector3, delta: float) -> bool:
	var to_point: Vector3 = point - _barrel_pivot.global_position
	if to_point.length() < 0.01:
		return false
	var local_direction: Vector3 = global_transform.basis.inverse() * to_point.normalized()
	var wanted_yaw: float = atan2(-local_direction.x, -local_direction.z)
	var wanted_pitch: float = clampf(atan2(local_direction.y, Vector2(local_direction.x, local_direction.z).length()), deg_to_rad(PITCH_LIMITS_DEGREES.x), deg_to_rad(PITCH_LIMITS_DEGREES.y))
	var max_step: float = deg_to_rad(turn_speed_degrees) * delta
	_head.rotation.y = rotate_toward(_head.rotation.y, wanted_yaw, max_step)
	_barrel_pivot.rotation.x = move_toward(_barrel_pivot.rotation.x, wanted_pitch, max_step)
	return get_aim_direction().angle_to(to_point) <= deg_to_rad(FIRE_CONE_DEGREES)


func _play_recoil() -> void:
	if _recoil_tween != null:
		_recoil_tween.kill()
	_flash.visible = true
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(_barrel, "position:z", 0.08, 0.04)
	_recoil_tween.tween_callback(func() -> void: _flash.visible = false)
	_recoil_tween.tween_property(_barrel, "position:z", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
