## A low-poly body that stands under a player's head and walks with them:
## hips, torso and two legs (thigh, shin, foot). The legs step in a gait
## whose pace follows how fast the head moves across the floor (stick
## walking, arm-swing running or real steps in the room) and settle when
## the player stops; the knees bend to keep the feet on the floor when the
## player crouches. The body turns toward where the head faces with a
## little lag, like a real body, and never tilts with the head. It stands
## a little behind the eyes, so looking down shows the chest and legs.
## Used under the local headset player (XRPlayerRig) and for the co-op
## partner's avatar (RemotePlayer). It also carries the holster spots
## (hip, chest, back) weapons hang on.
##
##   body.follow(head_transform, floor_height, delta)   # once per frame
##   body.get_holster_anchor(WalkingBody.HOLSTER_HIP)
##
## Dependencies: PlaceholderMesh3D, Palette
class_name WalkingBody
extends Node3D

const HOLSTER_HIP: StringName = &"hip"
const HOLSTER_CHEST: StringName = &"chest"
const HOLSTER_BACK: StringName = &"back"
## A jump further than this in one frame (a teleport) restarts the gait.
const TELEPORT_DISTANCE: float = 1.0
## Walking speed (m/s) at which the stride is at its fullest.
const FULL_STRIDE_SPEED: float = 1.6
## Foot height below the ankle (the sole on the floor).
const FOOT_HEIGHT: float = 0.07
## The hip joints sit this far below the pelvis' center.
const HIP_DROP: float = 0.04

@export_group("Proportions")
## Eyes to the top of the shoulders.
@export var neck_drop: float = 0.24
## Shoulders down to the hip joints.
@export var torso_length: float = 0.55
## Hip to knee, and knee to ankle (meters).
@export var thigh_length: float = 0.44
@export var shin_length: float = 0.44
## The body stands this far behind the eyes.
@export var back_offset: float = 0.12

@export_group("Gait")
## Meters covered by one step.
@export var step_length: float = 0.62
## How far a leg swings forward and back (degrees) at full stride...
@export var swing_degrees: float = 28.0
## ...and how far the knee lifts the swinging foot.
@export var knee_lift_degrees: float = 42.0
## How quickly the body turns after the head (per second).
@export var turn_speed: float = 5.0

@export_group("Look")
## Jacket, trousers and shoes.
@export var clothes_color: Color = Palette.STROKE
@export var trouser_color: Color = Palette.SURFACE_RAISED
@export var shoe_color: Color = Palette.BACKGROUND
## The torso and collar show (the co-op partner); off for the player's own
## body, so looking down shows the hips, the holsters and the legs.
@export var shows_upper_body: bool = true:
	set(value):
		shows_upper_body = value
		for part: Node3D in _upper_body_parts:
			part.visible = value
## The collar (a player's color).
@export var accent_color: Color = Palette.PRIMARY:
	set(value):
		accent_color = value
		if _collar != null:
			_collar.color = value

var _pelvis: Node3D = null
var _torso: Node3D = null
## Per leg: [hip pivot, knee pivot, ankle pivot], left first.
var _legs: Array[Array] = []
var _collar: PlaceholderMesh3D = null
var _upper_body_parts: Array[Node3D] = []
var _holsters: Dictionary[StringName, Node3D] = {}
var _phase: float = 0.0
var _stride: float = 0.0
var _last_origin: Vector3 = Vector3.INF
var _yaw: float = 0.0


func _ready() -> void:
	top_level = true
	_build()


## Places the body under [param head] (eyes) standing on [param floor_height],
## turns it toward the head's facing and steps the legs. [param delta] 0 or
## a teleport-sized jump snaps it there.
func follow(head: Transform3D, floor_height: float, delta: float) -> void:
	var forward: Vector3 = -head.basis.z
	forward.y = 0.0
	if forward.length() > 0.01:
		var head_yaw: float = atan2(-forward.x, -forward.z)
		_yaw = head_yaw if delta <= 0.0 else lerp_angle(_yaw, head_yaw, clampf(turn_speed * delta, 0.0, 1.0))
	var facing: Vector3 = Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var origin: Vector3 = Vector3(head.origin.x, floor_height, head.origin.z) - facing * back_offset
	var moved: float = 0.0 if not _last_origin.is_finite() else Vector2(origin.x - _last_origin.x, origin.z - _last_origin.z).length()
	if moved > TELEPORT_DISTANCE or delta <= 0.0:
		moved = 0.0
	_last_origin = origin
	global_transform = Transform3D(Basis(Vector3.UP, _yaw), origin)
	var speed: float = moved / delta if delta > 0.0 else 0.0
	_stride = lerpf(_stride, clampf(speed / FULL_STRIDE_SPEED, 0.0, 1.0), clampf(8.0 * delta, 0.0, 1.0)) if delta > 0.0 else 0.0
	_phase = fposmod(_phase + moved / maxf(0.1, step_length) * PI, TAU)
	_pose_legs(head.origin.y - floor_height)


## Where a weapon hangs: HOLSTER_HIP, HOLSTER_CHEST or HOLSTER_BACK (null for others).
func get_holster_anchor(slot: StringName) -> Node3D:
	return _holsters.get(slot)


## Puts the hip holster on the right (1) or left (-1) side.
func set_hip_side(side: float) -> void:
	var hip: Node3D = _holsters.get(HOLSTER_HIP)
	if hip != null:
		hip.position.x = absf(hip.position.x) * signf(side)


## How far the legs are into their stride right now (0 standing, 1 full) (tests).
func get_stride() -> float:
	return _stride

# ============================================
# INTERNALS
# ============================================

## Hip height from the eye height; knees bend (two-bone) when it is lower
## than the straight leg, and the walking swing goes on top.
func _pose_legs(eye_height: float) -> void:
	var leg_reach: float = thigh_length + shin_length
	var hip_height: float = clampf(eye_height - neck_drop - torso_length, leg_reach * 0.45, leg_reach + FOOT_HEIGHT + HIP_DROP)
	_pelvis.position.y = hip_height
	var hip_to_ankle: float = clampf(hip_height - HIP_DROP - FOOT_HEIGHT, 0.05, leg_reach - 0.001)
	var thigh_bend: float = acos(clampf((thigh_length * thigh_length + hip_to_ankle * hip_to_ankle - shin_length * shin_length) / (2.0 * thigh_length * hip_to_ankle), -1.0, 1.0))
	var shin_bend: float = acos(clampf((shin_length * shin_length + hip_to_ankle * hip_to_ankle - thigh_length * thigh_length) / (2.0 * shin_length * hip_to_ankle), -1.0, 1.0))
	for leg_index: int in _legs.size():
		var joints: Array = _legs[leg_index]
		var leg_phase: float = _phase + PI * float(leg_index)
		var swing: float = sin(leg_phase) * deg_to_rad(swing_degrees) * _stride
		var lift: float = maxf(0.0, cos(leg_phase)) * deg_to_rad(knee_lift_degrees) * _stride
		var thigh_pitch: float = thigh_bend + swing
		var knee_pitch: float = -(thigh_bend + shin_bend) - lift
		(joints[0] as Node3D).rotation.x = thigh_pitch
		(joints[1] as Node3D).rotation.x = knee_pitch
		# The foot stays level with the floor.
		(joints[2] as Node3D).rotation.x = -(thigh_pitch + knee_pitch)


func _build() -> void:
	_pelvis = Node3D.new()
	_pelvis.name = "Pelvis"
	add_child(_pelvis)
	_add_part(_pelvis, PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.3, 0.15, 0.17), Vector3(0.0, 0.0, 0.0), trouser_color)
	_add_part(_pelvis, PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.31, 0.035, 0.18), Vector3(0.0, 0.065, 0.0), shoe_color)
	for side: float in [-1.0, 1.0]:
		var hip: Node3D = _add_pivot(_pelvis, Vector3(0.09 * side, -HIP_DROP, 0.0))
		_add_part(hip, PlaceholderMesh3D.ShapeKind.CAPSULE, Vector3(0.125, thigh_length + 0.06, 0.125), Vector3(0.0, -thigh_length * 0.5, 0.0), trouser_color)
		var knee: Node3D = _add_pivot(hip, Vector3(0.0, -thigh_length, 0.0))
		_add_part(knee, PlaceholderMesh3D.ShapeKind.CAPSULE, Vector3(0.105, shin_length + 0.05, 0.105), Vector3(0.0, -shin_length * 0.5, 0.0), trouser_color)
		var ankle: Node3D = _add_pivot(knee, Vector3(0.0, -shin_length, 0.0))
		_add_part(ankle, PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.1, FOOT_HEIGHT, 0.25), Vector3(0.0, -FOOT_HEIGHT * 0.5, -0.06), shoe_color)
		_legs.append([hip, knee, ankle])
	_torso = _add_pivot(_pelvis, Vector3(0.0, 0.075, 0.0))
	var chest_height: float = torso_length - 0.075
	_upper_body_parts.append(_add_part(_torso, PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.32, chest_height, 0.18), Vector3(0.0, chest_height * 0.5, 0.0), clothes_color))
	_collar = _add_part(_torso, PlaceholderMesh3D.ShapeKind.CYLINDER, Vector3(0.16, 0.045, 0.16), Vector3(0.0, chest_height + 0.02, 0.0), accent_color)
	_upper_body_parts.append(_collar)
	for part: Node3D in _upper_body_parts:
		part.visible = shows_upper_body
	_holsters[HOLSTER_HIP] = _add_pivot(_pelvis, Vector3(0.2, 0.0, -0.06))
	_holsters[HOLSTER_CHEST] = _add_pivot(_torso, Vector3(0.0, chest_height * 0.62, -0.125))
	_holsters[HOLSTER_BACK] = _add_pivot(_torso, Vector3(0.0, chest_height * 0.72, 0.13))


func _add_pivot(parent: Node3D, offset: Vector3) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = offset
	parent.add_child(pivot)
	return pivot


func _add_part(parent: Node3D, shape: PlaceholderMesh3D.ShapeKind, part_size: Vector3, offset: Vector3, part_color: Color) -> PlaceholderMesh3D:
	var part: PlaceholderMesh3D = PlaceholderMesh3D.new()
	part.shape_kind = shape
	part.size = part_size
	part.color = part_color
	part.position = offset
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part
