## The police's armored vehicle: rolls slowly through the streets to the
## road in front of the house, turns its turret on the front door and shells
## it until the door gives — or until it is destroyed. Thick armor: light
## rounds barely scratch it.
##
## Dependencies: PoliceVehicle, Yard, FrontDoor, BeamTracer, PopEffect3D,
##               Pools, Audio autoloads, SfxSynth, Palette
class_name ArmoredVehicle
extends PoliceVehicle

const TRACER_SCENE: PackedScene = preload("res://Scenes/Levels/House/Garden/BeamTracer.tscn")
## Radians per second the turret turns.
const TURRET_TURN_SPEED: float = 1.2

## Damage of one shell on the door (the door's own multipliers apply).
@export var shell_damage: float = 110.0
## Seconds between two shells.
@export var reload_seconds: float = 5.0

var _turret: Node3D = null
var _barrel_tip: Node3D = null
var _seconds_until_shot: float = 0.0
var _has_arrived: bool = false


func _reset_vehicle() -> void:
	_seconds_until_shot = reload_seconds
	_has_arrived = false
	if _turret != null:
		_turret.rotation = Vector3.ZERO


func _on_arrived() -> void:
	_has_arrived = true
	_seconds_until_shot = reload_seconds * 0.6


func _act(delta: float) -> void:
	if not _has_arrived or _yard == null or _yard.door == null:
		return
	var door_point: Vector3 = _yard.door.global_position + Vector3(0.0, 1.0, 0.0)
	_aim_turret(door_point, delta)
	if not _yard.door.is_alive():
		return
	_seconds_until_shot -= delta
	if _seconds_until_shot > 0.0:
		return
	_seconds_until_shot = reload_seconds
	_fire(door_point)


## Turns the turret (around the hull's up axis) toward [param point].
func _aim_turret(point: Vector3, delta: float) -> void:
	var local: Vector3 = to_local(point)
	var target_yaw: float = atan2(local.x, local.z)
	_turret.rotation.y = rotate_toward(_turret.rotation.y, target_yaw, TURRET_TURN_SPEED * delta)


func _fire(door_point: Vector3) -> void:
	var muzzle: Vector3 = _barrel_tip.global_position
	var effects: Node3D = _yard.get_effects_root()
	var tracer: BeamTracer = Pools.spawn(TRACER_SCENE, effects, muzzle) as BeamTracer
	tracer.fire(muzzle, door_point)
	PopEffect3D.spawn(muzzle, Palette.WARNING, 1.2, effects)
	PopEffect3D.spawn(door_point, Palette.DANGER, 2.4, effects)
	Audio.play_sfx_at(SfxSynth.get_preset(&"shot_rifle"), muzzle, 0.05, 6.0)
	Audio.play_sfx_at(SfxSynth.get_preset(&"hit"), door_point, 0.1, 4.0)
	_yard.door.health_component.damage(shell_damage * _yard.door.get_damage_multiplier(), self)


func _build_model() -> void:
	var hull: Color = Palette.SURFACE_RAISED
	var dark: Color = Palette.BACKGROUND
	_part(Vector3(0.0, 0.95, 0.0), PlaceholderMesh3D.ShapeKind.BOX, Vector3(2.6, 1.1, 5.6), hull)
	_part(Vector3(0.0, 0.85, 2.85), PlaceholderMesh3D.ShapeKind.BOX, Vector3(2.4, 0.7, 0.4), hull.darkened(0.15))
	_part(Vector3(0.0, 1.05, 0.0), PlaceholderMesh3D.ShapeKind.BOX, Vector3(2.62, 0.12, 4.0), Palette.PRIMARY.darkened(0.35))
	for track_side: float in [-1.35, 1.35]:
		_part(Vector3(track_side, 0.45, 0.0), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.45, 0.9, 5.4), dark)
	_turret = Node3D.new()
	_turret.position = Vector3(0.0, 1.5, -0.2)
	_model_root.add_child(_turret)
	_part(Vector3.ZERO, PlaceholderMesh3D.ShapeKind.CYLINDER, Vector3(1.8, 0.6, 1.8), hull.lightened(0.05), 0.0, _turret)
	_part(Vector3(0.0, 0.05, 1.5), PlaceholderMesh3D.ShapeKind.CYLINDER, Vector3(0.22, 2.2, 0.22), dark, 0.0, _turret).rotation.x = PI * 0.5
	_part(Vector3(0.0, 0.42, -0.2), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.6, 0.2, 0.5), dark, 0.0, _turret)
	_part(Vector3(0.45, 0.3, 0.6), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.18, 0.08, 0.06), Palette.PRIMARY, 0.9, _turret)
	_barrel_tip = Node3D.new()
	_barrel_tip.position = Vector3(0.0, 0.05, 2.65)
	_turret.add_child(_barrel_tip)
