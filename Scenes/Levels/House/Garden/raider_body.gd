## The body of a raider: hips, torso with vest, head with balaclava, visor
## and cap or helmet, arms with elbows, legs with knees and boots, and what
## it carries (pistol, rifle, riot shield or a share of a battering ram).
## Built from a few exports at load and animated procedurally — a walk cycle
## whose stride follows the speed, crouching behind cover, a strike at the
## door — by turning a handful of joints (cheap enough for a raid of 15 on a
## standalone headset). All meshes are shared PlaceholderMesh3D shapes.
##
##   body.animate(delta, speed_ratio)   # from the raider while it moves
##   body.set_crouched(true)            # in cover
##   body.play_strike()                 # a hit on the door
##
## Dependencies: PlaceholderMesh3D, Palette
@tool
class_name RaiderBody
extends Node3D

enum Headgear { CAP, HELMET }
enum Carry { PISTOL, RIFLE, SHIELD, RAM }

const HIP_HEIGHT: float = 0.95
const CROUCH_HIP_HEIGHT: float = 0.66
## Seconds to settle into or out of a crouch.
const CROUCH_SECONDS: float = 0.25
## Stride cycles per meter walked.
const STRIDES_PER_METER: float = 0.85

@export var uniform_color: Color = Color("#2e364b"):
	set(value):
		uniform_color = value
		_queue_rebuild()
@export var vest_color: Color = Color("#1a2030"):
	set(value):
		vest_color = value
		_queue_rebuild()
## Reflective stripes, visor and other details that read at night.
@export var accent_color: Color = Color("#3cc8e8"):
	set(value):
		accent_color = value
		_queue_rebuild()
@export var headgear: Headgear = Headgear.CAP:
	set(value):
		headgear = value
		_queue_rebuild()
@export var carry: Carry = Carry.RIFLE:
	set(value):
		carry = value
		_queue_rebuild()

var _hips: Node3D = null
var _torso: Node3D = null
var _head: Node3D = null
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _thighs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _walk_phase: float = 0.0
var _crouch: float = 0.0
var _crouch_target: float = 0.0
var _strike: float = 0.0
var _is_rebuild_queued: bool = false
## The pose stopped changing (standing or crouched still): skip re-posing.
var _is_settled: bool = false


func _ready() -> void:
	rebuild()
	_walk_phase = randf() * TAU


## One frame of walking at [param speed_ratio] (0 = standing, 1 = normal
## pace, more = running): legs stride, arms swing (unless they hold
## something with both hands), the hips bob a little.
func animate(delta: float, speed_ratio: float) -> void:
	var pace: float = clampf(speed_ratio, 0.0, 2.0)
	# Standing or crouching still: nothing to re-pose once settled.
	if pace <= 0.0 and _strike <= 0.0 and is_equal_approx(_crouch, _crouch_target):
		if _is_settled:
			return
		_is_settled = true
	else:
		_is_settled = false
	_crouch = move_toward(_crouch, _crouch_target, delta / CROUCH_SECONDS)
	_strike = maxf(0.0, _strike - delta * 3.5)
	_walk_phase += delta * TAU * pace * 1.5 * STRIDES_PER_METER
	var swing: float = sin(_walk_phase) * deg_to_rad(28.0) * minf(1.0, pace)
	var lift: float = maxf(0.0, -cos(_walk_phase))
	_pose(swing, lift, pace)


## Down behind cover (true) or standing (false); eases over a moment.
func set_crouched(is_crouched: bool) -> void:
	_is_settled = false
	_crouch_target = 1.0 if is_crouched else 0.0


## One blow at the door: lean in and swing.
func play_strike() -> void:
	_is_settled = false
	_strike = 1.0


## 0..1: how far down the body is (hit spheres sit lower in a crouch).
func get_crouch_amount() -> float:
	return _crouch


## Back to standing, mid-stride (pool reuse).
func reset_pose() -> void:
	_is_settled = false
	_crouch = 0.0
	_crouch_target = 0.0
	_strike = 0.0
	_pose(0.0, 0.0, 0.0)


func _pose(swing: float, lift: float, pace: float) -> void:
	if _hips == null:
		return
	var crouch_angle: float = _crouch
	_hips.position.y = lerpf(HIP_HEIGHT, CROUCH_HIP_HEIGHT, crouch_angle) + lift * 0.025 * minf(1.0, pace)
	_torso.rotation.x = deg_to_rad(lerpf(4.0 + pace * 4.0, 24.0, crouch_angle) + _strike * 18.0)
	for side: int in 2:
		var direction: float = 1.0 if side == 0 else -1.0
		# Legs: stride while walking; deep knee bend in a crouch.
		_thighs[side].rotation.x = lerpf(swing * direction, deg_to_rad(-75.0), crouch_angle)
		var knee_walk: float = deg_to_rad(10.0 + 45.0 * maxf(0.0, -sin(_walk_phase + (0.0 if side == 0 else PI)))) * minf(1.0, pace)
		_knees[side].rotation.x = lerpf(knee_walk, deg_to_rad(120.0), crouch_angle)
	_pose_arms(swing)


func _pose_arms(swing: float) -> void:
	match carry:
		Carry.RIFLE:
			# Both hands on the rifle: shoulders forward, elbows bent.
			_shoulders[0].rotation = Vector3(deg_to_rad(-55.0 - _strike * 30.0), 0.0, deg_to_rad(12.0))
			_shoulders[1].rotation = Vector3(deg_to_rad(-40.0 - _strike * 30.0), 0.0, deg_to_rad(-22.0))
			_elbows[0].rotation.x = deg_to_rad(-55.0)
			_elbows[1].rotation.x = deg_to_rad(-70.0)
		Carry.SHIELD:
			# Shield arm up in front, pistol arm swinging low.
			_shoulders[1].rotation = Vector3(deg_to_rad(-70.0), 0.0, deg_to_rad(-15.0))
			_elbows[1].rotation.x = deg_to_rad(-80.0)
			_shoulders[0].rotation = Vector3(-swing * 0.8 - _strike * deg_to_rad(80.0), 0.0, deg_to_rad(6.0))
			_elbows[0].rotation.x = deg_to_rad(-20.0)
		Carry.RAM:
			# Both arms forward and low, carrying the ram at the side.
			for side: int in 2:
				_shoulders[side].rotation = Vector3(deg_to_rad(-38.0 - _strike * 25.0), 0.0, 0.0)
				_elbows[side].rotation.x = deg_to_rad(-35.0)
		_:
			for side: int in 2:
				var direction: float = -1.0 if side == 0 else 1.0
				_shoulders[side].rotation = Vector3(swing * direction * 0.9 - (_strike * deg_to_rad(90.0) if side == 0 else 0.0), 0.0, deg_to_rad(6.0 * direction * -1.0))
				_elbows[side].rotation.x = deg_to_rad(-18.0)

# ============================================
# BUILDING
# ============================================

func _queue_rebuild() -> void:
	if is_inside_tree() and not _is_rebuild_queued:
		_is_rebuild_queued = true
		rebuild.call_deferred()


## Builds the joints and meshes from the exports.
func rebuild() -> void:
	_is_rebuild_queued = false
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_shoulders.clear()
	_elbows.clear()
	_thighs.clear()
	_knees.clear()
	var skin: Color = Palette.BACKGROUND_RAISED
	_hips = _joint(self, Vector3(0.0, HIP_HEIGHT, 0.0))
	_part(_hips, Vector3(0.0, 0.0, 0.0), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.36, 0.16, 0.22), uniform_color)
	_torso = _joint(_hips, Vector3(0.0, 0.08, 0.0))
	_part(_torso, Vector3(0.0, 0.25, 0.0), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.4, 0.46, 0.22), uniform_color)
	_part(_torso, Vector3(0.0, 0.25, 0.005), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.43, 0.36, 0.26), vest_color)
	# The reflective band across the vest.
	_part(_torso, Vector3(0.0, 0.33, 0.133), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.42, 0.035, 0.01), accent_color, 0.5)
	_part(_torso, Vector3(0.0, 0.5, 0.0), PlaceholderMesh3D.ShapeKind.CYLINDER, Vector3(0.1, 0.06, 0.1), skin)
	_head = _joint(_torso, Vector3(0.0, 0.62, 0.01))
	_part(_head, Vector3.ZERO, PlaceholderMesh3D.ShapeKind.SPHERE, Vector3(0.22, 0.25, 0.23), skin)
	# Visor / eye slit: the one thing that glows, so raiders read at night.
	_part(_head, Vector3(0.0, 0.02, 0.105), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.15, 0.035, 0.02), accent_color, 0.9)
	match headgear:
		Headgear.HELMET:
			_part(_head, Vector3(0.0, 0.07, -0.01), PlaceholderMesh3D.ShapeKind.SPHERE, Vector3(0.27, 0.2, 0.28), vest_color)
			_part(_head, Vector3(0.0, 0.0, -0.13), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.22, 0.1, 0.04), vest_color)
		_:
			_part(_head, Vector3(0.0, 0.1, 0.0), PlaceholderMesh3D.ShapeKind.CYLINDER, Vector3(0.24, 0.08, 0.24), Palette.BACKGROUND)
			_part(_head, Vector3(0.0, 0.07, 0.13), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.2, 0.015, 0.09), Palette.BACKGROUND)
	for side: int in 2:
		var direction: float = 1.0 if side == 0 else -1.0
		var shoulder: Node3D = _joint(_torso, Vector3(0.25 * direction, 0.43, 0.0))
		_part(shoulder, Vector3(0.0, -0.14, 0.0), PlaceholderMesh3D.ShapeKind.CAPSULE, Vector3(0.11, 0.32, 0.11), uniform_color)
		var elbow: Node3D = _joint(shoulder, Vector3(0.0, -0.29, 0.0))
		_part(elbow, Vector3(0.0, -0.13, 0.0), PlaceholderMesh3D.ShapeKind.CAPSULE, Vector3(0.095, 0.28, 0.095), uniform_color)
		_part(elbow, Vector3(0.0, -0.29, 0.0), PlaceholderMesh3D.ShapeKind.SPHERE, Vector3(0.085, 0.1, 0.085), Palette.BACKGROUND)
		_shoulders.append(shoulder)
		_elbows.append(elbow)
		var thigh: Node3D = _joint(_hips, Vector3(0.1 * direction, -0.04, 0.0))
		_part(thigh, Vector3(0.0, -0.22, 0.0), PlaceholderMesh3D.ShapeKind.CAPSULE, Vector3(0.15, 0.46, 0.15), uniform_color)
		var knee: Node3D = _joint(thigh, Vector3(0.0, -0.44, 0.0))
		_part(knee, Vector3(0.0, -0.2, 0.0), PlaceholderMesh3D.ShapeKind.CAPSULE, Vector3(0.12, 0.42, 0.12), uniform_color)
		_part(knee, Vector3(0.0, -0.44, 0.04), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.12, 0.09, 0.24), Palette.BACKGROUND)
		_thighs.append(thigh)
		_knees.append(knee)
	_build_carry()
	_pose(0.0, 0.0, 0.0)


func _build_carry() -> void:
	match carry:
		Carry.RIFLE:
			# A carbine held across the chest: receiver, barrel, magazine, stock.
			var rifle: Node3D = _joint(_torso, Vector3(0.02, 0.2, 0.26))
			rifle.rotation = Vector3(deg_to_rad(8.0), deg_to_rad(-20.0), 0.0)
			_part(rifle, Vector3.ZERO, PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.05, 0.07, 0.4), Palette.BACKGROUND)
			_part(rifle, Vector3(0.0, 0.01, 0.28), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.025, 0.025, 0.2), Palette.BACKGROUND)
			_part(rifle, Vector3(0.0, -0.08, 0.06), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.03, 0.12, 0.05), Palette.SURFACE)
			_part(rifle, Vector3(0.0, -0.01, -0.27), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.04, 0.09, 0.15), Palette.SURFACE)
			_part(rifle, Vector3(0.0, 0.055, 0.02), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.03, 0.03, 0.08), Palette.SURFACE)
		Carry.SHIELD:
			# Riot shield on the left arm with a viewport, pistol in the right hand.
			var shield: Node3D = _joint(_elbows[1], Vector3(0.05, -0.18, 0.18))
			_part(shield, Vector3.ZERO, PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.55, 0.85, 0.05), Palette.SURFACE_RAISED)
			_part(shield, Vector3(0.0, 0.25, 0.03), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.28, 0.08, 0.01), accent_color, 0.4)
			_part(shield, Vector3(0.0, -0.15, 0.03), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.4, 0.04, 0.01), Palette.TEXT, 0.0)
			_part(_elbows[0], Vector3(0.0, -0.32, 0.06), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.03, 0.05, 0.15), Palette.BACKGROUND)
		Carry.PISTOL:
			_part(_elbows[0], Vector3(0.0, -0.32, 0.06), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.03, 0.05, 0.15), Palette.BACKGROUND)


func _joint(parent: Node3D, local_position: Vector3) -> Node3D:
	var joint: Node3D = Node3D.new()
	joint.position = local_position
	parent.add_child(joint)
	return joint


func _part(parent: Node3D, local_position: Vector3, shape: PlaceholderMesh3D.ShapeKind, part_size: Vector3, color: Color, glow: float = 0.0) -> void:
	var part: PlaceholderMesh3D = PlaceholderMesh3D.new()
	part.shape_kind = shape
	part.size = part_size
	part.color = color
	part.glow = glow
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.position = local_position
	parent.add_child(part)
