## Moves the player around the level. Never leaves the WalkableArea.
## In the flat simulator WASD walks and keys 1-4 jump to the travel spots.
##
## Like VRChat: the dominant-hand stick (right by default) walks where the
## head looks, as long as smooth movement is on in the comfort settings.
## The off-hand stick repositions: push it forward to aim a teleport and let
## go to jump, flick it left / right to snap-turn (or hold it to turn
## smoothly). A trackpad click up teleports, left / right snap-turns.
##
## Dependencies: XRPlayerRig, XRPointer, WalkableArea, RayMath, Settings,
##               PlaceholderMesh3D, Palette, Types autoloads
class_name XRLocomotion
extends Node

signal teleported(target: Vector3)

const STICK_PRESS_THRESHOLD: float = 0.6
const STICK_RELEASE_THRESHOLD: float = 0.3
const STICK_DEADZONE: float = 0.15
const MARKER_OPACITY: float = 0.7

@export var rig: XRPlayerRig
## Ring shown where a teleport would land.
@export var teleport_marker: MeshInstance3D
@export var move_speed: float = 2.0
@export var flat_move_speed: float = 2.6
@export var snap_turn_degrees: float = 30.0
@export var smooth_turn_degrees_per_second: float = 100.0
@export var teleport_range: float = 9.0

## Where the player may stand (null = anywhere).
var walkable_area: WalkableArea = null
## Places keys 1-4 jump to in the flat simulator (their -Z is the view direction).
var travel_spots: Array[Node3D] = []

var _aiming_pointer: XRPointer = null
var _teleport_target: Vector3 = Vector3.ZERO
var _is_target_valid: bool = false
var _walk_stick: Vector2 = Vector2.ZERO
var _reposition_stick: Vector2 = Vector2.ZERO
var _is_turn_flicked: bool = false


func _ready() -> void:
	if teleport_marker != null:
		teleport_marker.top_level = true
		teleport_marker.visible = false

# ============================================
# PUBLIC API
# ============================================

## Thumbstick moved on a controller (called by the rig).
func handle_stick(hand: Types.Hand, value: Vector2, pointer: XRPointer) -> void:
	if hand == rig.dominant_hand:
		_walk_stick = value
		return
	_reposition_stick = value
	if _aiming_pointer != null:
		if value.length() <= STICK_RELEASE_THRESHOLD:
			_aiming_pointer = null
			if _is_target_valid:
				teleport_to(_teleport_target)
			_hide_marker()
		return
	if _is_turn_gesture(value):
		_handle_snap_turn(value)
	elif not _is_turn_flicked and value.y >= STICK_PRESS_THRESHOLD:
		_aiming_pointer = pointer
		_is_target_valid = false
	elif _is_turn_flicked and value.length() <= STICK_RELEASE_THRESHOLD:
		_is_turn_flicked = false


## Trackpad click (HTC Vive wands): up teleports along the pointer, sides turn.
func handle_trackpad_click(pad_position: Vector2, pointer: XRPointer) -> void:
	if absf(pad_position.x) >= 0.35:
		turn_by(-snap_turn_degrees if pad_position.x > 0.0 else snap_turn_degrees)
	elif pad_position.y >= 0.35:
		var target: Vector3 = _find_teleport_target(pointer)
		if _is_valid_target(target):
			teleport_to(target)


## Per physics frame (called by the rig): smooth moves, turns, aim marker, WASD.
func step(delta: float) -> void:
	if rig.is_xr_active:
		_step_xr(delta)
	else:
		_step_flat(delta)


## Puts the player's feet at [param target] (the head stays where it is
## relative to the play space). [param facing] (radians, NAN = keep) turns
## the view to that yaw.
func teleport_to(target: Vector3, facing: float = NAN) -> void:
	var feet: Vector3 = rig.get_feet_position()
	rig.move_origin_by(Vector3(target.x - feet.x, 0.0, target.z - feet.z))
	if not is_nan(facing):
		rig.face_yaw(facing)
	teleported.emit(target)


## Snap / smooth turn around the player's head.
func turn_by(degrees: float) -> void:
	rig.turn_around_head(deg_to_rad(degrees))


## Jumps to travel spot [param spot_index] (flat keys 1-4, tests).
func travel_to_spot(spot_index: int) -> void:
	if spot_index < 0 or spot_index >= travel_spots.size() or travel_spots[spot_index] == null:
		return
	var spot: Node3D = travel_spots[spot_index]
	teleport_to(spot.global_position, spot.global_rotation.y)


func is_smooth_movement() -> bool:
	return Settings.get_bool(Settings.KEY_SMOOTH_MOVEMENT)


func is_smooth_turning() -> bool:
	return Settings.get_bool(Settings.KEY_SMOOTH_TURNING)

# ============================================
# INTERNALS
# ============================================

func _step_xr(delta: float) -> void:
	if is_smooth_movement() and _walk_stick.length() > STICK_DEADZONE:
		var head_basis: Basis = rig.get_head_transform().basis
		var forward: Vector3 = Vector3(-head_basis.z.x, 0.0, -head_basis.z.z).normalized()
		var right: Vector3 = Vector3(head_basis.x.x, 0.0, head_basis.x.z).normalized()
		_walk((right * _walk_stick.x + forward * _walk_stick.y) * move_speed * delta)
	var is_turning_smoothly: bool = is_smooth_turning() and _aiming_pointer == null and _is_turn_gesture(_reposition_stick)
	if is_turning_smoothly and absf(_reposition_stick.x) > STICK_DEADZONE:
		turn_by(-_reposition_stick.x * smooth_turn_degrees_per_second * delta)
	if _aiming_pointer != null:
		_teleport_target = _find_teleport_target(_aiming_pointer)
		_is_target_valid = _is_valid_target(_teleport_target)
		_show_marker(_teleport_target, _is_target_valid)


func _step_flat(delta: float) -> void:
	var input: Vector2 = Input.get_vector(Types.ACTION_MOVE_LEFT, Types.ACTION_MOVE_RIGHT, Types.ACTION_MOVE_BACK, Types.ACTION_MOVE_FORWARD)
	if input == Vector2.ZERO:
		return
	var view_basis: Basis = rig.get_head_transform().basis
	var forward: Vector3 = Vector3(-view_basis.z.x, 0.0, -view_basis.z.z).normalized()
	var right: Vector3 = Vector3(view_basis.x.x, 0.0, view_basis.x.z).normalized()
	_walk((right * input.x + forward * input.y) * flat_move_speed * delta)


func _walk(offset: Vector3) -> void:
	var feet: Vector3 = rig.get_feet_position()
	var target: Vector3 = feet + offset
	if walkable_area != null:
		target = walkable_area.clamp_move(feet, target)
	rig.move_origin_by(Vector3(target.x - feet.x, 0.0, target.z - feet.z))


## The off-hand stick points more sideways than forward: it turns rather
## than aims a teleport.
func _is_turn_gesture(stick: Vector2) -> bool:
	return absf(stick.x) > absf(stick.y)


## One snap per flick: turn when the stick passes the press threshold, and
## again only after it came back to the middle.
func _handle_snap_turn(stick: Vector2) -> void:
	if is_smooth_turning():
		return
	if not _is_turn_flicked and absf(stick.x) >= STICK_PRESS_THRESHOLD:
		_is_turn_flicked = true
		turn_by(-snap_turn_degrees if stick.x > 0.0 else snap_turn_degrees)
	elif _is_turn_flicked and absf(stick.x) <= STICK_RELEASE_THRESHOLD:
		_is_turn_flicked = false


func _find_teleport_target(pointer: XRPointer) -> Vector3:
	var floor_height: float = walkable_area.floor_height if walkable_area != null else rig.get_feet_position().y
	var distance: float = RayMath.intersect_ground(pointer.ray_origin, pointer.ray_direction, floor_height)
	if distance == RayMath.NO_HIT or distance > teleport_range:
		return Vector3(INF, INF, INF)
	return pointer.get_point(distance)


func _is_valid_target(target: Vector3) -> bool:
	return target.is_finite() and (walkable_area == null or walkable_area.contains(target))


func _show_marker(target: Vector3, is_valid: bool) -> void:
	if teleport_marker == null:
		return
	teleport_marker.visible = target.is_finite()
	if teleport_marker.visible:
		teleport_marker.global_position = target + Vector3(0.0, 0.01, 0.0)
		teleport_marker.material_override = PlaceholderMesh3D.get_shared_material(Color(Palette.SUCCESS if is_valid else Palette.DANGER, MARKER_OPACITY), 0.4, true)


func _hide_marker() -> void:
	if teleport_marker != null:
		teleport_marker.visible = false
