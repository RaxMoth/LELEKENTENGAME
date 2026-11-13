## The police helicopter: flies straight over the roofs to the house, then
## circles the yard and drops SWAT officers on ropes, a pair at a time. Once
## it has dropped them all it circles a while longer, then flies off (it
## stops holding up the wave once it turns away). Shoot it down before that.
##
## Dependencies: PoliceVehicle, Yard, Raider, Palette
class_name PoliceHelicopter
extends PoliceVehicle

## Rotor turns per second (looks).
const ROTOR_SPEED: float = 18.0

## Flying height (meters) and the circle it flies around the yard's middle.
@export var altitude: float = 16.0
@export var circle_radius: float = 13.0
## Radians per second around that circle.
@export var circle_speed: float = 0.35
## Who comes down the ropes, how many per drop, how many drops, and the
## seconds between drops.
@export var crew_scene: PackedScene
@export_range(1, 4) var crew_per_drop: int = 2
@export_range(1, 10) var drops: int = 3
@export var drop_interval: float = 9.0
## Seconds it keeps circling after the last drop before it flies off.
@export var linger_seconds: float = 20.0
## How far (meters) it flies off before it is gone.
@export var leave_distance: float = 180.0

var _rotor: Node3D = null
var _tail_rotor: Node3D = null
var _circle_angle: float = 0.0
var _drops_left: int = 0
var _seconds_until_drop: float = 0.0
var _is_circling: bool = false
var _is_leaving: bool = false
var _seconds_until_leave: float = 0.0


func _physics_process(delta: float) -> void:
	if _rotor == null or not is_alive():
		return
	_rotor.rotation.y += ROTOR_SPEED * delta
	_tail_rotor.rotation.x += ROTOR_SPEED * 1.6 * delta


## Once it flies off it no longer holds up the wave.
func counts_for_wave() -> bool:
	return is_alive() and not _is_leaving


func _reset_vehicle() -> void:
	_drops_left = drops
	_seconds_until_drop = drop_interval * 0.4
	_is_circling = false
	_is_leaving = false
	_seconds_until_leave = linger_seconds


func _on_march_started() -> void:
	global_position.y = altitude


func _on_arrived() -> void:
	if _is_leaving:
		Pools.despawn(self)
		return
	_is_circling = true
	var center: Vector2 = _yard.bounds.get_center()
	_circle_angle = (Vector2(global_position.x, global_position.z) - center).angle()


func _act(delta: float) -> void:
	if not _is_circling or _yard == null:
		return
	var center: Vector2 = _yard.bounds.get_center()
	_circle_angle += circle_speed * delta
	var spot: Vector2 = center + Vector2.from_angle(_circle_angle) * circle_radius
	var previous: Vector3 = global_position
	global_position = global_position.lerp(Vector3(spot.x, altitude, spot.y), clampf(delta * 1.5, 0.0, 1.0))
	var heading: Vector3 = global_position - previous
	if heading.length() > 0.001:
		rotation.y = lerp_angle(rotation.y, atan2(heading.x, heading.z), clampf(delta * 2.0, 0.0, 1.0))
	if _drops_left <= 0:
		_seconds_until_leave -= delta
		if _seconds_until_leave <= 0.0:
			_fly_off()
		return
	_seconds_until_drop -= delta
	if _seconds_until_drop <= 0.0:
		_seconds_until_drop = drop_interval
		_drops_left -= 1
		_drop_crew()


## Turns away and flies off over the roofs (gone at the end).
func _fly_off() -> void:
	_is_leaving = true
	_is_circling = false
	var here: Vector2 = Vector2(global_position.x, global_position.z)
	var away: Vector2 = here + (here - _yard.bounds.get_center()).normalized() * leave_distance
	_street_route = PackedVector2Array([here, away])
	_street_index = 1


## Officers slide down the ropes to the ground under the helicopter (inside the yard).
func _drop_crew() -> void:
	if crew_scene == null:
		return
	for crew_index: int in crew_per_drop:
		var ground: Vector2 = _yard.clamp_to_bounds(Vector2(global_position.x, global_position.z) + Vector2((crew_index - 0.5) * 1.2, 0.0))
		var officer: Raider = _yard.spawn_raider(crew_scene, null, crew_index, PackedVector2Array([ground, ground]))
		officer.apply_wave_modifiers(_health_multiplier, 1.0)


func _build_model() -> void:
	var body: Color = Palette.SURFACE_RAISED
	var dark: Color = Palette.BACKGROUND
	_part(Vector3(0.0, 0.0, 0.3), PlaceholderMesh3D.ShapeKind.SPHERE, Vector3(2.0, 1.8, 3.6), body)
	_part(Vector3(0.0, 0.15, 1.5), PlaceholderMesh3D.ShapeKind.SPHERE, Vector3(1.5, 1.1, 1.3), Palette.GEM.darkened(0.55), 0.15)
	_part(Vector3(0.0, 0.25, -2.6), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.35, 0.4, 3.6), body)
	_part(Vector3(0.0, 0.7, -4.2), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.12, 1.0, 0.6), body)
	_part(Vector3(0.0, -0.05, 0.3), PlaceholderMesh3D.ShapeKind.BOX, Vector3(2.04, 0.18, 2.6), Palette.PRIMARY.darkened(0.3))
	for skid_side: float in [-0.8, 0.8]:
		_part(Vector3(skid_side, -1.05, 0.3), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.08, 0.08, 2.8), dark)
		_part(Vector3(skid_side, -0.8, 0.3), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.06, 0.5, 0.06), dark)
	_part(Vector3(0.0, -0.95, 1.4), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.18, 0.12, 0.18), Palette.TEXT, 1.0)
	_rotor = Node3D.new()
	_rotor.position = Vector3(0.0, 1.05, 0.2)
	_model_root.add_child(_rotor)
	_part(Vector3(0.0, -0.1, 0.0), PlaceholderMesh3D.ShapeKind.CYLINDER, Vector3(0.25, 0.3, 0.25), dark, 0.0, _rotor)
	_part(Vector3.ZERO, PlaceholderMesh3D.ShapeKind.BOX, Vector3(9.0, 0.04, 0.3), dark, 0.0, _rotor)
	_part(Vector3.ZERO, PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.3, 0.04, 9.0), dark, 0.0, _rotor)
	_tail_rotor = Node3D.new()
	_tail_rotor.position = Vector3(0.25, 0.7, -4.2)
	_model_root.add_child(_tail_rotor)
	_part(Vector3.ZERO, PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.04, 1.4, 0.16), dark, 0.0, _tail_rotor)
