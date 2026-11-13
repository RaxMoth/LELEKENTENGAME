## A squad car full of cops: races through the streets to the curb next to
## the yard, the light bar flashing, stops, and its crew jumps out and
## storms the yard. Then it drives off the way it came. Shoot it on its way
## in and its crew never gets out.
##
## Dependencies: PoliceVehicle, Yard, Raider, Palette
class_name SquadCar
extends PoliceVehicle

## Who jumps out at the curb, and how many.
@export var crew_scene: PackedScene
@export_range(1, 8) var crew_count: int = 4
## Seconds standing at the curb before the crew is out, and before it leaves.
@export var unload_seconds: float = 0.8
@export var leave_seconds: float = 2.5
## Light bar: seconds per flash.
@export var flash_seconds: float = 0.25

var _has_unloaded: bool = false
var _is_leaving: bool = false
var _seconds_at_curb: float = 0.0
var _flash_time: float = 0.0
var _way_in: PackedVector2Array = PackedVector2Array()
var _bar_left: PlaceholderMesh3D = null
var _bar_right: PlaceholderMesh3D = null
var _is_bar_blue: bool = true


## Remembers the way in (it leaves the way it came).
func march(route: PackedVector2Array, yard: Yard) -> void:
	_way_in = route.duplicate()
	super(route, yard)


func _physics_process(delta: float) -> void:
	if _bar_left == null or not is_alive():
		return
	# The light bar flashes blue and red while the car is out.
	_flash_time += delta
	var is_blue: bool = int(_flash_time / flash_seconds) % 2 == 0
	if is_blue == _is_bar_blue:
		return
	_is_bar_blue = is_blue
	_bar_left.glow = 1.0 if is_blue else 0.1
	_bar_right.glow = 0.1 if is_blue else 1.0


## Once its crew is out and it drives off, it no longer holds up the wave.
func counts_for_wave() -> bool:
	return is_alive() and not _is_leaving


func _reset_vehicle() -> void:
	_has_unloaded = false
	_is_leaving = false
	_seconds_at_curb = 0.0
	_flash_time = 0.0
	_way_in = PackedVector2Array()


func _on_arrived() -> void:
	if _is_leaving:
		# Off the map again: gone, without counting as stopped.
		Pools.despawn(self)
		return
	_seconds_at_curb = 0.0


func _act(delta: float) -> void:
	_seconds_at_curb += delta
	if not _has_unloaded and _seconds_at_curb >= unload_seconds:
		_unload()
	elif _has_unloaded and _seconds_at_curb >= unload_seconds + leave_seconds:
		_leave()


func _unload() -> void:
	_has_unloaded = true
	if crew_scene == null or _yard == null:
		return
	var side: Vector3 = global_transform.basis.x
	for crew_index: int in crew_count:
		var door_side: float = 1.0 if crew_index % 2 == 0 else -1.0
		var along: float = (floori(crew_index / 2.0) - 0.5) * 1.4
		var out: Vector3 = global_position + side * door_side * 1.4 + global_transform.basis.z * along
		var start: Vector2 = Vector2(out.x, out.z)
		var officer: Raider = _yard.spawn_raider(crew_scene, null, crew_index, PackedVector2Array([start, _yard.get_spawn_point()]))
		officer.apply_wave_modifiers(_health_multiplier, 1.0)


## Back out the way it came; despawns at the end (Pools, not counted as a kill).
func _leave() -> void:
	_is_leaving = true
	var way_out: PackedVector2Array = _way_in.duplicate()
	way_out.reverse()
	_street_route = way_out
	_street_index = 1


func _build_model() -> void:
	var paint: Color = Palette.TEXT
	var stripe: Color = Palette.PRIMARY.darkened(0.25)
	_part(Vector3(0.0, 0.62, 0.0), PlaceholderMesh3D.ShapeKind.BOX, Vector3(1.85, 0.62, 4.4), paint)
	_part(Vector3(0.0, 0.66, 0.0), PlaceholderMesh3D.ShapeKind.BOX, Vector3(1.87, 0.16, 4.2), stripe)
	_part(Vector3(0.0, 1.2, -0.25), PlaceholderMesh3D.ShapeKind.BOX, Vector3(1.6, 0.52, 2.2), Palette.BACKGROUND)
	_part(Vector3(0.0, 1.48, -0.25), PlaceholderMesh3D.ShapeKind.BOX, Vector3(1.58, 0.05, 2.0), paint)
	_bar_left = _part(Vector3(-0.32, 1.58, -0.2), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.55, 0.12, 0.26), Palette.PRIMARY, 1.0)
	_bar_right = _part(Vector3(0.32, 1.58, -0.2), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.55, 0.12, 0.26), Palette.DANGER, 0.1)
	_part(Vector3(0.0, 0.55, 2.22), PlaceholderMesh3D.ShapeKind.BOX, Vector3(1.6, 0.18, 0.06), Palette.TEXT_MUTED, 0.6)
	for axle: float in [-1.35, 1.35]:
		for wheel_side: float in [-0.88, 0.88]:
			_part(Vector3(wheel_side, 0.33, axle), PlaceholderMesh3D.ShapeKind.CYLINDER, Vector3(0.66, 0.24, 0.66), Palette.BACKGROUND).rotation.z = PI * 0.5
