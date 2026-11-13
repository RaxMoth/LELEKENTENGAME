## The fire extinguisher on the lab wall. Grab it (grip), aim and pull the
## trigger to spray foam (a click sprays a short burst in the flat
## simulator); foam reaching a burning station within range and the spray
## cone puts it out (StationFire.extinguish). Put it down with the grip — or
## click its hook — and it hangs back on the wall.
##
## Dependencies: Grabbable, StationFire, XRPointer, Audio, SfxSynth
class_name Extinguisher
extends Grabbable

## Seconds between two hisses of the spray.
const HISS_SECONDS: float = 0.15

## How far the foam reaches (meters)...
@export var spray_range: float = 2.8
## ...and how wide its cone is (half angle, degrees).
@export var spray_cone_degrees: float = 20.0
## Fire strength put out per second of foam on it.
@export var spray_per_second: float = 55.0
## A click in the flat simulator sprays this long.
@export var flat_burst_seconds: float = 0.9

var _spray_pointer: XRPointer = null
var _is_spraying: bool = false
var _burst_seconds_left: float = 0.0
var _seconds_until_hiss: float = 0.0

@onready var _nozzle: Marker3D = %Nozzle
@onready var _foam: Node3D = %Foam


func _ready() -> void:
	super()
	_foam.top_level = true
	_foam.visible = false


func _process(delta: float) -> void:
	super(delta)
	if _is_spraying:
		_spray(delta)


## It sprays on its holder's trigger.
func get_icon() -> Texture2D:
	return preload("res://Assets/Icons/flame.svg")


func is_usable() -> bool:
	return true


## Sprays while the holder's trigger is held, along [param pointer]'s aim.
func use(is_pressed: bool, pointer: XRPointer) -> void:
	_burst_seconds_left = 0.0
	_set_spraying(is_pressed, pointer)


## A click in the flat simulator: a short burst.
func use_once(pointer: XRPointer) -> void:
	_burst_seconds_left = flat_burst_seconds
	_set_spraying(true, pointer)


## True while foam comes out.
func is_spraying() -> bool:
	return _is_spraying


## Let go of: the spray stops.
func detach() -> void:
	_set_spraying(false, null)
	super()


func _set_spraying(should_spray: bool, pointer: XRPointer) -> void:
	_is_spraying = should_spray and is_held()
	_spray_pointer = pointer if _is_spraying else null
	_foam.visible = _is_spraying
	_seconds_until_hiss = 0.0
	set_process(is_held())


## Foam along the aim (the pointer's ray) from the nozzle; every burning
## fire inside the cone and range gets put out a little.
func _spray(delta: float) -> void:
	if not is_held():
		_set_spraying(false, null)
		return
	var origin: Vector3 = _nozzle.global_position
	var direction: Vector3 = -_nozzle.global_basis.z
	if _spray_pointer != null and is_instance_valid(_spray_pointer) and _spray_pointer.ray_direction.length() > 0.01:
		direction = _spray_pointer.ray_direction.normalized()
	_foam.global_transform = Transform3D(Basis.looking_at(direction, Vector3.UP if absf(direction.y) < 0.95 else Vector3.FORWARD), origin)
	for node: Node in get_tree().get_nodes_in_group(StationFire.GROUP):
		var fire: StationFire = node as StationFire
		if fire == null or not fire.is_burning():
			continue
		var to_fire: Vector3 = fire.get_target_position() - origin
		if to_fire.length() <= spray_range and rad_to_deg(direction.angle_to(to_fire)) <= spray_cone_degrees:
			fire.extinguish(spray_per_second * delta)
	_seconds_until_hiss -= delta
	if _seconds_until_hiss <= 0.0:
		_seconds_until_hiss = HISS_SECONDS
		Audio.play_sfx_at(SfxSynth.get_preset(&"spray"), origin, 0.1, -8.0)
	if _burst_seconds_left > 0.0:
		_burst_seconds_left -= delta
		if _burst_seconds_left <= 0.0:
			_set_spraying(false, null)
