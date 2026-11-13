## A wooden snap trap from the cabin's TrapBox. Carry it (grip or trigger)
## and let go over the floor: it settles on the floor there, armed. A rat
## that runs over it is caught (the bar snaps over) and the trap clears
## away a moment later. Let go somewhere it can't stand (off the floor) and
## it goes back into the box. An armed trap can be picked up and moved.
## Pooled.
##
## Dependencies: Grabbable, RatPack, TrapBox, WalkableArea, Pools, Audio, SfxSynth
class_name RatTrap
extends Grabbable

## The bar's angle while set / after it snapped (degrees about the trap's width).
const SET_DEGREES: float = 0.0
const SNAPPED_DEGREES: float = 180.0
## A sprung trap clears away after this many seconds.
const CLEAR_SECONDS: float = 2.5
## Looks this far below where it was let go for a floor to stand on.
const FLOOR_SEARCH: float = 2.5

## Ready to catch a rat (set on the floor).
var is_armed: bool = false
## Snapped shut on a rat: it clears away and can't be picked up.
var is_sprung: bool = false

var _pack: RatPack = null
var _box: TrapBox = null
var _tween: Tween

@onready var _bar: Node3D = %Bar


## Called by the box that handed it out.
func setup(rat_pack: RatPack, trap_box: TrapBox) -> void:
	_pack = rat_pack
	_box = trap_box
	is_armed = false
	is_sprung = false
	_bar.rotation.z = deg_to_rad(SET_DEGREES)


## A sprung trap stays where it snapped until it clears away.
func get_display_name() -> String:
	return tr("Rat trap")


func can_grab() -> bool:
	return not is_sprung and super()


## Picked up: no longer set.
func attach_to(new_holder: Node3D) -> void:
	_disarm()
	super(new_holder)


## A rat ran over it: the bar snaps over and it clears away.
func spring() -> void:
	_disarm()
	is_sprung = true
	Audio.play_sfx_at(SfxSynth.get_preset(&"hit"), global_position, 0.1, -2.0)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_bar, "rotation:z", deg_to_rad(SNAPPED_DEGREES), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_interval(CLEAR_SECONDS)
	_tween.tween_callback(Pools.despawn.bind(self))
	if _pack != null:
		_pack.report_catch()


## Let go away from any socket: set it on the floor below, or back into the box.
func _on_released_nowhere() -> void:
	var walkable: WalkableArea = _pack.walkable if _pack != null else null
	var drop_point: Vector3 = global_position
	var floor_height: float = walkable.get_floor_height_at(Vector3(drop_point.x, drop_point.y - FLOOR_SEARCH * 0.5, drop_point.z), FLOOR_SEARCH) if walkable != null else NAN
	if is_nan(floor_height):
		if _box != null:
			_box.take_back(self)
		return
	var yaw: float = global_rotation.y
	global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(drop_point.x, floor_height, drop_point.z))
	is_armed = true
	_bar.rotation.z = deg_to_rad(SET_DEGREES)
	if _pack != null:
		_pack.register_trap(self)
	Audio.play_sfx_at(SfxSynth.get_preset(&"click"), global_position, 0.1, -6.0)


func _disarm() -> void:
	is_armed = false
	if _pack != null:
		_pack.unregister_trap(self)


func _on_pool_spawned() -> void:
	if _tween != null:
		_tween.kill()
	is_armed = false
	is_sprung = false
	if _bar != null:
		_bar.rotation.z = deg_to_rad(SET_DEGREES)


func _on_pool_despawned() -> void:
	if _tween != null:
		_tween.kill()
	_disarm()
	super()
