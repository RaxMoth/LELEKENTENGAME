## Moves the player around the level. Never leaves the WalkableArea.
## In the flat simulator WASD walks and keys 1-4 jump to the travel spots.
##
## Like most VR games: the off-hand stick (left by default) walks — forward,
## back and sideways, like WASD — toward where that hand points, so the head
## can look around freely ("Walk Where You Look" in Settings walks where the
## head faces instead). The dominant stick turns (30° snaps, or smoothly).
## Touchpads (HTC Vive, Valve Index) work the same while pressed: press the
## off-hand pad toward a direction to walk there, the dominant pad's sides to
## turn. Nothing ever teleports.
##
## Arm-swing running: hold both grips with empty hands and swing the arms
## like jogging — the harder the swing, the faster (WalkMotion); you head
## where the hands point. Walking eases in and out instead of jumping to
## full speed, a fully pushed stick sprints, and footsteps sound every stride
## (with a light tap in both hands while arm-swinging). No head bob: the
## camera only ever moves as far as the player walks. Walking down stairs
## (a WalkableRamp) lowers the player with each step, never on its own; a
## change in floor height (the top or the foot of the stairs) is eased over a
## few frames instead of dropping the view at once.
##
## Walls hold for real steps too: a player who walks or leans into a wall
## (or the stairwell) in the room stops at its edge, as if it were there;
## furniture can still be leaned over. Real steps onto the stairs follow
## their height like stick walking does.
##
## Dependencies: XRPlayerRig, XRPointer, WalkableArea, WalkMotion, Settings, Audio,
##               SfxSynth, Types autoloads
class_name XRLocomotion
extends Node

signal teleported(target: Vector3)

## Spacing of the floor checks along a real step's way.
const PATH_SAMPLE_METERS: float = 0.1
## How fast the view settles on a new floor height (share per second, eased).
const FLOOR_EASE_PER_SECOND: float = 14.0
## A walking hand pointing steeper than this (up or down) gives no direction:
## the head's is used then.
const MIN_HAND_FLATNESS: float = 0.3
## A head can't move this far in one frame: a jump this big is a teleport
## (travel spot, the cellar's opening), not a real step to check.
const MAX_REAL_STEP_METERS: float = 0.6

@export var rig: XRPlayerRig
@export var move_speed: float = 2.0
@export var flat_move_speed: float = 2.6
@export var snap_turn_degrees: float = 30.0
@export var smooth_turn_degrees_per_second: float = 100.0

@export_group("Controller sticks")
## A stick pushed this far snap-turns.
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

var _walk_stick: Vector2 = Vector2.ZERO
var _turn_stick: Vector2 = Vector2.ZERO
var _is_turn_flicked: bool = false
var _velocity: Vector3 = Vector3.ZERO
## Meters walked since the last footstep.
var _stride_carry: float = 0.0
var _last_left_hand: Vector3 = Vector3.ZERO
var _last_right_hand: Vector3 = Vector3.ZERO
var _has_hand_samples: bool = false
## Last feet position on a floor, for keeping real steps out of walls.
var _last_floor_feet: Vector3 = Vector3.ZERO
var _has_floor_feet: bool = false
## The floor height the feet are easing toward (NAN = none: stand as is).
var _floor_y: float = NAN

## On = the player stays put (a turret seat); sticks, arm swing and WASD do nothing.
var is_locked: bool = false


# ============================================
# PUBLIC API
# ============================================

## Thumbstick moved on a controller (called by the rig): the dominant
## stick turns, the other one walks like WASD.
func handle_stick(hand: Types.Hand, value: Vector2) -> void:
	if is_locked:
		_walk_stick = Vector2.ZERO
		_turn_stick = Vector2.ZERO
		return
	if hand == rig.dominant_hand:
		_turn_stick = value
		if _is_turn_gesture(value):
			_handle_snap_turn(value)
		elif _is_turn_flicked and value.length() <= stick_release_threshold:
			_is_turn_flicked = false
		return
	_walk_stick = value


## Per physics frame (called by the rig): stick walking, turns, WASD.
func step(delta: float) -> void:
	if is_locked:
		_velocity = Vector3.ZERO
		# Keep sampling the hands: leaving a turret seat with both grips held
		# must not read as one huge swing.
		_sample_hands()
		_has_floor_feet = false
		_floor_y = NAN
		return
	if rig.is_xr_active:
		_step_xr(delta)
		_keep_out_of_walls()
	else:
		_step_flat(delta)
	_ease_to_floor(delta)


## Puts the player's feet at [param target], its height included (the head
## stays where it is relative to the play space). [param facing] (radians,
## NAN = keep) turns the view to that yaw.
func teleport_to(target: Vector3, facing: float = NAN) -> void:
	var feet: Vector3 = rig.get_feet_position()
	rig.move_origin_by(target - feet)
	_floor_y = target.y
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


func is_smooth_turning() -> bool:
	return Settings.get_bool(Settings.KEY_SMOOTH_TURNING)


## Forward for the walking stick on the floor: where the off hand points
## (or the head faces, with "Walk Where You Look" on or the hand held
## straight up or down).
func get_walk_forward() -> Vector3:
	if not Settings.get_bool(Settings.KEY_WALK_WHERE_LOOKING):
		var pointer: XRPointer = rig.get_hand_pointer(_get_walk_hand())
		var aim: Vector3 = -pointer.global_basis.z
		var flat_aim: Vector3 = Vector3(aim.x, 0.0, aim.z)
		if flat_aim.length() > MIN_HAND_FLATNESS:
			return flat_aim.normalized()
	var head_basis: Basis = rig.get_head_transform().basis
	return Vector3(-head_basis.z.x, 0.0, -head_basis.z.z).normalized()

# ============================================
# INTERNALS
# ============================================

func _step_xr(delta: float) -> void:
	var target_velocity: Vector3 = Vector3.ZERO
	if _walk_stick.length() > stick_deadzone:
		var forward: Vector3 = get_walk_forward()
		var right: Vector3 = forward.cross(Vector3.UP)
		var stick_direction: Vector3 = (right * _walk_stick.x + forward * _walk_stick.y).normalized()
		target_velocity = stick_direction * WalkMotion.get_stick_speed(_walk_stick, move_speed * speed_multiplier)
	var swing_velocity: Vector3 = _get_arm_swing_velocity(delta) * speed_multiplier
	if swing_velocity.length() > target_velocity.length():
		target_velocity = swing_velocity
	_move_with(target_velocity, delta, swing_velocity != Vector3.ZERO)
	var is_turning_smoothly: bool = is_smooth_turning() and _is_turn_gesture(_turn_stick)
	if is_turning_smoothly and absf(_turn_stick.x) > stick_deadzone:
		turn_by(-_turn_stick.x * smooth_turn_degrees_per_second * delta)


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
	var feet: Vector3 = _get_floor_feet()
	var target: Vector3 = feet + offset
	if walkable_area != null:
		# Also up or down to the floor there (stairs): eased in _ease_to_floor().
		target = walkable_area.clamp_move(feet, target)
	rig.move_origin_by(Vector3(target.x - feet.x, 0.0, target.z - feet.z))
	_floor_y = target.y


## The feet on the floor they stand on (the view may still be easing there).
func _get_floor_feet() -> Vector3:
	var feet: Vector3 = rig.get_feet_position()
	if not is_nan(_floor_y):
		feet.y = _floor_y
	return feet


## Lets the view settle on the floor height smoothly: a step onto or off
## the stairs is a short glide, not a jolt. A jump of a storey (something
## else moved the player) is taken over as it is.
func _ease_to_floor(delta: float) -> void:
	if is_nan(_floor_y):
		return
	var gap: float = _floor_y - rig.get_feet_position().y
	if absf(gap) > WalkableArea.OFF_FLOOR_STEP:
		_floor_y = NAN
		return
	if absf(gap) < 0.0005:
		return
	rig.move_origin_by(Vector3(0.0, gap * (1.0 - exp(-FLOOR_EASE_PER_SECOND * delta)), 0.0))


func _get_walk_hand() -> Types.Hand:
	return Types.Hand.LEFT if rig.dominant_hand == Types.Hand.RIGHT else Types.Hand.RIGHT


## The dominant stick points more sideways than forward: a turn.
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


## Real steps and leaning: when the head went where nobody can stand (a
## wall, the stairwell, out of the house), the play space is held back so
## the feet stay at the last spot on a floor, slid along the wall. Furniture
## doesn't count, so leaning over a table to reach something still works.
func _keep_out_of_walls() -> void:
	if walkable_area == null:
		return
	var feet: Vector3 = _get_floor_feet()
	var height: float = walkable_area.get_floor_height_at(feet, WalkableArea.MAX_STEP, true)
	var moved: float = Vector2(feet.x - _last_floor_feet.x, feet.z - _last_floor_feet.z).length()
	var is_real_step: bool = _has_floor_feet and moved <= MAX_REAL_STEP_METERS
	# A floor on the other side of a wall doesn't count: the way there must be floor too.
	if not is_nan(height) and is_real_step and not _has_clear_path(_last_floor_feet, Vector3(feet.x, _last_floor_feet.y, feet.z)):
		height = NAN
	if not is_nan(height):
		# A real step onto the stairs follows their height (eased).
		_floor_y = height
		_last_floor_feet = Vector3(feet.x, height, feet.z)
		_has_floor_feet = true
		return
	if not is_real_step:
		return
	var allowed: Vector3 = walkable_area.clamp_move(_last_floor_feet, Vector3(feet.x, _last_floor_feet.y, feet.z))
	rig.move_origin_by(Vector3(allowed.x - feet.x, 0.0, allowed.z - feet.z))
	_floor_y = allowed.y
	_last_floor_feet = allowed


## True when the straight way from [param from] to [param to] stays on the
## floor (a real step never crosses a wall or the stairwell).
func _has_clear_path(from: Vector3, to: Vector3) -> bool:
	if walkable_area == null:
		return true
	var sample_count: int = maxi(1, ceili(Vector2(to.x - from.x, to.z - from.z).length() / PATH_SAMPLE_METERS))
	for sample_index: int in range(1, sample_count + 1):
		var point: Vector3 = from.lerp(to, float(sample_index) / float(sample_count))
		if is_nan(walkable_area.get_floor_height_at(Vector3(point.x, from.y, point.z), WalkableArea.MAX_STEP, true)):
			return false
	return true


func _sample_hands() -> void:
	_last_left_hand = rig.get_hand_local_transform(Types.Hand.LEFT).origin
	_last_right_hand = rig.get_hand_local_transform(Types.Hand.RIGHT).origin
	_has_hand_samples = true
