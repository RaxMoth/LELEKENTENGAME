## A gloved hand shown on a controller in a headset, built from shared
## low-poly parts: palm, four two-jointed fingers, a thumb and a cuff with
## the hand's accent color (the same as its beam). The fingers follow the
## grip, the index finger the trigger, so a full grip closes it into a
## fist. Mirrored for the left hand. Hidden with the controller when it
## isn't tracked (the flat simulator shows none).
##
##   glove.controller = %RightHand    # in the scene
##   glove.set_curl(1.0, 1.0)          # a fist (tests; the controller drives it otherwise)
##
## Dependencies: PlaceholderMesh3D, Palette, Types autoload
class_name GloveHand
extends Node3D

## Finger curl follows the controller's pull this fast (per second).
const CURL_SPEED: float = 18.0
## Joint bends of a full curl (degrees): knuckle, then the middle joint.
const KNUCKLE_BEND: float = 78.0
const MIDDLE_BEND: float = 92.0
## Fingers from the index (top) to the pinky: [height on the palm, first and
## second segment length, radius] in meters.
const FINGERS: Array[Vector4] = [
	Vector4(0.021, 0.044, 0.036, 0.0098),
	Vector4(-0.002, 0.048, 0.039, 0.0100),
	Vector4(-0.024, 0.045, 0.036, 0.0095),
	Vector4(-0.044, 0.035, 0.029, 0.0085),
]

## The controller whose trigger and grip it follows.
@export var controller: XRController3D
## Builds the mirrored (left) hand.
@export var is_left: bool = false
## The glove's leather.
@export var glove_color: Color = Palette.SURFACE_RAISED
## The cuff band (matches the hand's beam).
@export var accent_color: Color = Palette.PRIMARY

var _side: float = 1.0
var _grip_curl: float = 0.0
var _trigger_curl: float = 0.0
## Per finger: [knuckle pivot, middle pivot].
var _finger_joints: Array[Array] = []
var _thumb_root: Node3D = null
var _thumb_middle: Node3D = null
var _is_forced: bool = false


func _ready() -> void:
	_side = -1.0 if is_left else 1.0
	_build()
	_apply_curl()


func _process(delta: float) -> void:
	if controller == null or _is_forced:
		return
	var grip_target: float = _read_pull(Types.XR_ACTION_GRIP, Types.XR_ACTION_GRIP_CLICK)
	var trigger_target: float = _read_pull(Types.XR_ACTION_TRIGGER, Types.XR_ACTION_TRIGGER_CLICK)
	var weight: float = clampf(CURL_SPEED * delta, 0.0, 1.0)
	var new_grip: float = lerpf(_grip_curl, grip_target, weight)
	var new_trigger: float = lerpf(_trigger_curl, trigger_target, weight)
	if absf(new_grip - _grip_curl) < 0.001 and absf(new_trigger - _trigger_curl) < 0.001:
		return
	_grip_curl = new_grip
	_trigger_curl = new_trigger
	_apply_curl()


## Sets the curl directly (0 open, 1 closed) and stops following the controller.
func set_curl(grip: float, trigger: float) -> void:
	_is_forced = true
	_grip_curl = clampf(grip, 0.0, 1.0)
	_trigger_curl = clampf(trigger, 0.0, 1.0)
	_apply_curl()


## How closed the three lower fingers are (0 open, 1 a fist).
func get_grip_curl() -> float:
	return _grip_curl

# ============================================
# INTERNALS
# ============================================

func _read_pull(float_action: StringName, click_action: StringName) -> float:
	var pull: float = controller.get_float(float_action)
	if pull <= 0.0 and controller.is_button_pressed(click_action):
		pull = 1.0
	return clampf(pull, 0.0, 1.0)


## Index finger with the trigger, the rest with the grip; the thumb closes
## over them with whichever is pulled further.
func _apply_curl() -> void:
	for finger_index: int in _finger_joints.size():
		var curl: float = _trigger_curl if finger_index == 0 else _grip_curl
		if finger_index == 0:
			# A full grip half-closes the index too, so a fist looks like one.
			curl = maxf(curl, _grip_curl * 0.7)
		var joints: Array = _finger_joints[finger_index]
		(joints[0] as Node3D).rotation.y = deg_to_rad(KNUCKLE_BEND * curl) * _side
		(joints[1] as Node3D).rotation.y = deg_to_rad(MIDDLE_BEND * curl) * _side
	var thumb_curl: float = maxf(_grip_curl, _trigger_curl * 0.5)
	_thumb_root.rotation = Vector3(deg_to_rad(-18.0 - 32.0 * thumb_curl), deg_to_rad(28.0 + 22.0 * thumb_curl) * _side, 0.0)
	_thumb_middle.rotation.y = deg_to_rad(40.0 * thumb_curl) * _side


func _build() -> void:
	_add_part(self, PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.03, 0.084, 0.092), Vector3(0.002 * _side, -0.012, 0.058), Vector3.ZERO, glove_color).name = "Palm"
	_add_part(self, PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.026, 0.07, 0.03), Vector3(0.008 * _side, -0.012, 0.03), Vector3.ZERO, glove_color)
	for finger: Vector4 in FINGERS:
		var knuckle: Node3D = _add_pivot(self, Vector3(-0.002 * _side, finger.x, 0.014))
		_add_segment(knuckle, finger.y, finger.w)
		var middle: Node3D = _add_pivot(knuckle, Vector3(0.0, 0.0, -finger.y))
		_add_segment(middle, finger.z, finger.w * 0.95)
		_finger_joints.append([knuckle, middle])
	_thumb_root = _add_pivot(self, Vector3(-0.016 * _side, 0.03, 0.045))
	_add_segment(_thumb_root, 0.036, 0.0108)
	_thumb_middle = _add_pivot(_thumb_root, Vector3(0.0, 0.0, -0.036))
	_add_segment(_thumb_middle, 0.03, 0.0102)
	# The cuff runs along the wrist (Z); its band carries the hand's color.
	_add_part(self, PlaceholderMesh3D.ShapeKind.CYLINDER, Vector3(0.068, 0.06, 0.068), Vector3(0.0, -0.012, 0.128), Vector3(PI * 0.5, 0.0, 0.0), glove_color).name = "Cuff"
	var band: PlaceholderMesh3D = _add_part(self, PlaceholderMesh3D.ShapeKind.CYLINDER, Vector3(0.0704, 0.012, 0.0704), Vector3(0.0, -0.012, 0.105), Vector3(PI * 0.5, 0.0, 0.0), accent_color)
	band.glow = 0.25


func _add_pivot(parent: Node3D, offset: Vector3) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = offset
	parent.add_child(pivot)
	return pivot


## A finger segment from [param parent]'s origin forward (-Z), [param length] long.
func _add_segment(parent: Node3D, length: float, radius: float) -> void:
	_add_part(parent, PlaceholderMesh3D.ShapeKind.CAPSULE, Vector3(radius * 2.0, length + radius * 2.0, radius * 2.0), Vector3(0.0, 0.0, -length * 0.5), Vector3(-PI * 0.5, 0.0, 0.0), glove_color)


## One shared-mesh part (PlaceholderMesh3D caches meshes and materials).
func _add_part(parent: Node3D, shape: PlaceholderMesh3D.ShapeKind, part_size: Vector3, offset: Vector3, part_rotation: Vector3, part_color: Color) -> PlaceholderMesh3D:
	var part: PlaceholderMesh3D = PlaceholderMesh3D.new()
	part.shape_kind = shape
	part.size = part_size
	part.color = part_color
	part.position = offset
	part.rotation = part_rotation
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part
