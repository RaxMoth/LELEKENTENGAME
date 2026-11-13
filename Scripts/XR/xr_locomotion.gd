## Moves the player around the level. Never leaves the WalkableArea.
## In the flat simulator WASD walks and keys 1-4 jump to the travel spots.
##
## Like most VR games: the off-hand stick (left by default) walks where the
## head looks — forward, back and sideways, like WASD — and the dominant
## stick turns (30° snaps, or smoothly). With smooth movement off in the
## comfort settings the walking stick aims a teleport instead (push forward,
## let go to jump). A trackpad click up teleports, left / right snap-turns.
##
## Arm-swing running: hold both grips with empty hands and swing the arms
## like jogging — the harder the swing, the faster (WalkMotion); you head
## where the hands point. Walking eases in and out instead of jumping to
## full speed, a fully pushed stick sprints, and footsteps sound every stride
## (with a light tap in both hands while arm-swinging). No head bob: the
## camera only ever moves as far as the player walks. Walking down stairs
## (a WalkableRamp) lowers the player with each step, never on its own.
##
## Dependencies: XRPlayerRig, XRPointer, WalkableArea, WalkMotion, RayMath, Settings, Audio,
##               PlaceholderMesh3D, Palette, SfxSynth, Types autoloads
class_name XRLocomotion
extends Node

signal teleported(target: Vector3)

const MARKER_OPACITY: float = 0.7

@export var rig: XRPlayerRig
## Ring shown where a teleport would land.
@export var teleport_marker: MeshInstance3D
@export var move_speed: float = 2.0
@export var flat_move_speed: float = 2.6
@export var snap_turn_degrees: float = 30.0
@export var smooth_turn_degrees_per_second: float = 100.0
@export var teleport_range: float = 9.0

@export_group("Controller sticks")
## A stick pushed this far aims a teleport or snap-turns.
@export_range(0.1, 1.0, 0.05) var stick_press_threshold: float = 0.6
## ... and counts as let go below this (the next flick needs it).
@export_range(0.0, 0.9, 0.05) var stick_release_threshold: float = 0.3
## Stick movement smaller than this is ignored (worn sticks drift).
@export_range(0.0, 0.5, 0.01) var stick_deadzone: float = 0.15

## Scales walking speed (stick, arm swing, WASD): faster shoes, an upgrade.
var speed_multiplier: float = 1.0

## Where the player may stand (null = anywhere).
var walkable_area: WalkableArea = null
## Places keys 1-4 jump to in the flat simulator (their -Z is the view direction).
var travel_spots: Array[Node3D] = []

var _aiming_pointer: XRPointer = null
var _teleport_target: Vector3 = Vector3.ZERO
var _is_target_valid: bool = false
var _walk_stick: Vector2 = Vector2.ZERO
var _turn_stick: Vector2 = Vector2.ZERO
var _is_turn_flicked: bool = false
var _velocity: Vector3 = Vector3.ZERO
## Meters walked since the last footstep.
var _stride_carry: float = 0.0
var _last_left_hand: Vector3 = Vector3.ZERO
var _last_right_hand: Vector3 = Vector3.ZERO
var _has_hand_samples: bool = false

## On = the player stays put (a turret seat); sticks, arm swing and WASD do nothing.
var is_locked: bool = false


func _ready() -> void:
	if teleport_marker != null:
		teleport_marker.top_level = true
		teleport_marker.visible = false

# ============================================
# PUBLIC API
# ============================================

## Thumbstick moved on a controller (called by the rig): the dominant
## stick turns, the other one walks (or aims a teleport without smooth movement).
func handle_stick(hand: Types.Hand, value: Vector2, pointer: XRPointer) -> void:
	if is_locked:
		_walk_stick = Vector2.ZERO
		_turn_stick = Vector2.ZERO
		_aiming_pointer = null
		return
	if hand == rig.dominant_hand:
		_turn_stick = value
		if _is_turn_gesture(value):
			_handle_snap_turn(value)
		elif _is_turn_flicked and value.length() <= stick_release_threshold:
			_is_turn_flicked = false
		return
	if is_smooth_movement():
		_walk_stick = value
		return
	_walk_stick = Vector2.ZERO
	if _aiming_pointer != null:
		if value.length() <= stick_release_threshold:
			_aiming_pointer = null
			if _is_target_valid:
				teleport_to(_teleport_target)
			_hide_marker()
		return
	if value.y >= stick_press_threshold:
		_aiming_pointer = pointer
		_is_target_valid = false


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
	if is_locked:
		_velocity = Vector3.ZERO
		_hide_marker()
		# Keep sampling the hands: leaving a turret seat with both grips held
		# must not read as one huge swing.
		_sample_hands()
		return
	if rig.is_xr_active:
		_step_xr(delta)
	else:
		_step_flat(delta)


## Puts the player's feet at [param target], its height included (the head
## stays where it is relative to the play space). [param facing] (radians,
## NAN = keep) turns the view to that yaw.
func teleport_to(target: Vector3, facing: float = NAN) -> void:
	var feet: Vector3 = rig.get_feet_position()
	rig.move_origin_by(target - feet)
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


## Where the walking stick points right now (tests).
func get_walk_stick() -> Vector2:
	return _walk_stick


func is_smooth_movement() -> bool:
	return Settings.get_bool(Settings.KEY_SMOOTH_MOVEMENT)


func is_smooth_turning() -> bool:
	return Settings.get_bool(Settings.KEY_SMOOTH_TURNING)

# ============================================
# INTERNALS
# ============================================

func _step_xr(delta: float) -> void:
	var target_velocity: Vector3 = Vector3.ZERO
	if is_smooth_movement() and _walk_stick.length() > stick_deadzone:
		var head_basis: Basis = rig.get_head_transform().basis
		var forward: Vector3 = Vector3(-head_basis.z.x, 0.0, -head_basis.z.z).normalized()
		var right: Vector3 = Vector3(head_basis.x.x, 0.0, head_basis.x.z).normalized()
		var stick_direction: Vector3 = (right * _walk_stick.x + forward * _walk_stick.y).normalized()
		target_velocity = stick_direction * WalkMotion.get_stick_speed(_walk_stick, move_speed * speed_multiplier)
	var swing_velocity: Vector3 = _get_arm_swing_velocity(delta) * speed_multiplier
	if swing_velocity.length() > target_velocity.length():
		target_velocity = swing_velocity
	_move_with(target_velocity, delta, swing_velocity != Vector3.ZERO)
	var is_turning_smoothly: bool = is_smooth_turning() and _is_turn_gesture(_turn_stick)
	if is_turning_smoothly and absf(_turn_stick.x) > stick_deadzone:
		turn_by(-_turn_stick.x * smooth_turn_degrees_per_second * delta)
	if _aiming_pointer != null:
		_teleport_target = _find_teleport_target(_aiming_pointer)
		_is_target_valid = _is_valid_target(_teleport_target)
		_show_marker(_teleport_target, _is_target_valid)


func _step_flat(delta: float) -> void:
	var input: Vector2 = Input.get_vector(Types.ACTION_MOVE_LEFT, Types.ACTION_MOVE_RIGHT, Types.ACTION_MOVE_BACK, Types.ACTION_MOVE_FORWARD)
	var view_basis: Basis = rig.get_head_transform().basis
	var forward: Vector3 = Vector3(-view_basis.z.x, 0.0, -view_basis.z.z).normalized()
	var right: Vector3 = Vector3(view_basis.x.x, 0.0, view_basis.x.z).normalized()
	_move_with((right * input.x + forward * input.y) * flat_move_speed * speed_multiplier, delta, false)


## Eases the walking velocity toward [param target_velocity], moves, and
## lets footsteps fall every stride (with a light tap in both hands while
## running with the arms).
func _move_with(target_velocity: Vector3, delta: float, is_arm_swinging: bool) -> void:
	_velocity = WalkMotion.ease_velocity(_velocity, target_velocity, delta)
	if _velocity.length() < 0.01:
		_velocity = Vector3.ZERO
		return
	var before: Vector3 = rig.get_feet_position()
	_walk(_velocity * delta)
	var walked: float = Vector2(rig.get_feet_position().x - before.x, rig.get_feet_position().z - before.z).length()
	if walked < 0.0001:
		# A wall: stop instead of pushing into it.
		_velocity = Vector3.ZERO
		return
	var steps: Array[float] = WalkMotion.count_footsteps(_stride_carry, walked)
	_stride_carry = steps[1]
	if steps[0] > 0.0:
		_play_footstep(is_arm_swinging)


## Velocity of an arm-swing run: both grips held with empty hands, the hands
## swinging like jogging; heads where the hands point. Zero otherwise.
func _get_arm_swing_velocity(delta: float) -> Vector3:
	var left: Transform3D = rig.get_hand_local_transform(Types.Hand.LEFT)
	var right: Transform3D = rig.get_hand_local_transform(Types.Hand.RIGHT)
	var had_samples: bool = _has_hand_samples
	var left_velocity: Vector3 = (left.origin - _last_left_hand) / maxf(delta, 0.001)
	var right_velocity: Vector3 = (right.origin - _last_right_hand) / maxf(delta, 0.001)
	_last_left_hand = left.origin
	_last_right_hand = right.origin
	_has_hand_samples = true
	var is_swinging: bool = rig.is_grip_down(Types.Hand.LEFT) and rig.is_grip_down(Types.Hand.RIGHT) \
		and rig.is_hand_empty(Types.Hand.LEFT) and rig.is_hand_empty(Types.Hand.RIGHT)
	if not is_swinging or not had_samples:
		return Vector3.ZERO
	# Speeds in the hands' own frame of the play space, so turning doesn't count.
	var speed: float = WalkMotion.get_arm_swing_speed(left_velocity, right_velocity)
	if speed <= 0.0:
		return Vector3.ZERO
	var pointing: Vector3 = rig.global_transform.basis * -(left.basis.z + right.basis.z)
	var direction: Vector3 = Vector3(pointing.x, 0.0, pointing.z)
	if direction.length() < 0.01:
		var head_basis: Basis = rig.get_head_transform().basis
		direction = Vector3(-head_basis.z.x, 0.0, -head_basis.z.z)
	return direction.normalized() * speed


func _play_footstep(with_hands: bool) -> void:
	Audio.play_sfx_at(SfxSynth.get_preset(&"step"), rig.get_feet_position(), 0.15, -10.0)
	if with_hands:
		for pointer: XRPointer in rig.get_active_pointers():
			rig.pulse(pointer, Types.HapticStrength.LIGHT)


func _walk(offset: Vector3) -> void:
	var feet: Vector3 = rig.get_feet_position()
	var target: Vector3 = feet + offset
	if walkable_area != null:
		# Also up or down to the floor there (stairs).
		target = walkable_area.clamp_move(feet, target)
	rig.move_origin_by(target - feet)


## The off-hand stick points more sideways than forward: it turns rather
## than aims a teleport.
func _is_turn_gesture(stick: Vector2) -> bool:
	return absf(stick.x) > absf(stick.y)


## One snap per flick: turn when the stick passes the press threshold, and
## again only after it came back to the middle.
func _handle_snap_turn(stick: Vector2) -> void:
	if is_smooth_turning():
		return
	if not _is_turn_flicked and absf(stick.x) >= stick_press_threshold:
		_is_turn_flicked = true
		turn_by(-snap_turn_degrees if stick.x > 0.0 else snap_turn_degrees)
	elif _is_turn_flicked and absf(stick.x) <= stick_release_threshold:
		_is_turn_flicked = false


func _find_teleport_target(pointer: XRPointer) -> Vector3:
	# Teleports stay on the floor the player stands on (the cellar or the house).
	var distance: float = RayMath.intersect_ground(pointer.ray_origin, pointer.ray_direction, rig.get_feet_position().y)
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


func _sample_hands() -> void:
	_last_left_hand = rig.get_hand_local_transform(Types.Hand.LEFT).origin
	_last_right_hand = rig.get_hand_local_transform(Types.Hand.RIGHT).origin
	_has_hand_samples = true
