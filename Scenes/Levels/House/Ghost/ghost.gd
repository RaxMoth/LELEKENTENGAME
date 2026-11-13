## A ghost on the night of day 4, for the player alone. When night falls it
## turns up somewhere behind them (on their floor, in plain sight once they
## turn around): a dark, hooded figure with a pale face and arms reaching
## out, turned away, whispering now and then. The moment the player looks at
## it, it whips around with burning eyes, lunges at them with a shriek and a
## hard rumble in both hands — and is gone, all within a fraction of a
## second. It never moves the camera (only itself), and it is local: in
## co-op each player meets their own.
## State: Waiting -> Lurking (somewhere near, unseen) -> Seen (lunges, vanishes) -> Gone.
##
##   ghost.haunt(rig)   # HouseLevel on nightfall when Profile.operation.day_number == ghost.night_number
##
## Dependencies: XRPlayerRig, XRPointer, WalkableArea, SightMath, Audio, Types autoloads, SfxSynth
class_name Ghost
extends Node3D

## Line-of-sight samples between the player and the ghost (walls block it).
const SIGHT_SAMPLES: int = 16
## Where it may turn up relative to where the player looks (degrees, behind first).
const APPEAR_ANGLES: Array[float] = [180.0, 155.0, 205.0, 130.0, 230.0, 105.0, 255.0]

## The day whose night it haunts.
@export var night_number: int = 4
## Seconds from being seen to gone (it lunges and fades meanwhile).
@export var vanish_seconds: float = 0.22
## How far it lunges at the player as it vanishes (meters).
@export var lunge_distance: float = 0.5
## Seconds between its whispers while it lurks (random between x and y).
@export var whisper_seconds: Vector2 = Vector2(5.0, 9.0)
## Its eyes flare this much bigger when it is seen.
@export var eye_flare_scale: float = 1.8
## Seen when within this angle of the view direction ...
@export var sight_half_angle: float = 22.0
## ... and this close.
@export var sight_distance: float = 14.0
## How far from the player it turns up (min, max).
@export var appear_distance: Vector2 = Vector2(3.0, 6.0)
## Seconds it lurks unseen before it finds a new spot behind the player.
@export var relocate_seconds: float = 45.0
## Hover height of its hem above the floor.
@export var hover_height: float = 0.12
## The figure's materials (faded out at the end).
@export var fading_materials: Array[StandardMaterial3D] = []
## Its eyes (they flare when it is seen).
@export var eyes: Array[Node3D] = []

var _rig: XRPlayerRig = null
var _has_haunted: bool = false
var _state_seconds: float = 0.0
var _is_placed: bool = false
var _is_fading: bool = false
var _was_seen: bool = false
var _base_alphas: Array[float] = []
var _seconds_until_whisper: float = 0.0
var _lunge_start: Vector3 = Vector3.ZERO
var _lunge_direction: Vector3 = Vector3.ZERO

@onready var _figure: Node3D = %Figure
@onready var _head: Node3D = %Head
@onready var state_chart: StateChart = %StateChart


func _ready() -> void:
	for material: StandardMaterial3D in fading_materials:
		_base_alphas.append(material.albedo_color.a)

# ============================================
# PUBLIC API
# ============================================

## Starts the haunting for [param rig] (once per shift: the house reloads every morning).
func haunt(rig: XRPlayerRig) -> void:
	if _has_haunted:
		return
	_has_haunted = true
	_rig = rig
	state_chart.send_event(Types.EVENT_GHOST_APPEAR)


## True while it is out there (lurking, not yet seen).
func is_haunting() -> bool:
	return visible and not _is_fading


## True once the player has looked at it.
func was_seen() -> bool:
	return _was_seen


## Where its eyes are (tests aim at it).
func get_head_position() -> Vector3:
	return _head.global_position

# ============================================
# STATE CHART CALLBACKS (connected in Ghost.tscn)
# ============================================

func _on_waiting_state_entered() -> void:
	visible = false


func _on_lurking_state_entered() -> void:
	_state_seconds = 0.0
	_seconds_until_whisper = randf_range(whisper_seconds.x * 0.5, whisper_seconds.x)
	_is_placed = _place_behind_player()
	visible = _is_placed
	_set_alpha(1.0)
	for eye: Node3D in eyes:
		eye.scale = Vector3.ONE


func _on_lurking_state_processing(delta: float) -> void:
	_state_seconds += delta
	if not _is_placed or _state_seconds >= relocate_seconds:
		_state_seconds = 0.0
		_is_placed = _place_behind_player()
		visible = _is_placed
		return
	# A slow hover; the figure only, never the player's view.
	_figure.position.y = hover_height + sin(_state_seconds * 1.7) * 0.03
	# Now and then a whisper from where it waits: something is behind you.
	_seconds_until_whisper -= delta
	if _seconds_until_whisper <= 0.0:
		_seconds_until_whisper = randf_range(whisper_seconds.x, whisper_seconds.y)
		Audio.play_sfx_at(SfxSynth.get_preset(&"whisper"), get_head_position(), 0.2, -10.0)
	if _is_in_sight():
		state_chart.send_event(Types.EVENT_GHOST_SEEN)


func _on_seen_state_entered() -> void:
	_was_seen = true
	_is_fading = true
	_state_seconds = 0.0
	# It whips around to face the player, eyes burning, and lunges.
	var head: Vector3 = _rig.get_head_transform().origin
	var facing: Vector3 = Vector3(head.x, global_position.y, head.z)
	if facing.distance_to(global_position) > 0.01:
		look_at(facing, Vector3.UP)
	_lunge_start = global_position
	_lunge_direction = (facing - global_position).normalized()
	for eye: Node3D in eyes:
		eye.scale = Vector3.ONE * eye_flare_scale
	Audio.play_sfx_at(SfxSynth.get_preset(&"scare"), get_head_position(), 0.05, 2.0)
	for pointer: XRPointer in _rig.get_active_pointers():
		_rig.pulse(pointer, Types.HapticStrength.HEAVY)


func _on_seen_state_processing(delta: float) -> void:
	_state_seconds += delta
	var share: float = clampf(_state_seconds / maxf(0.01, vanish_seconds), 0.0, 1.0)
	global_position = _lunge_start + _lunge_direction * lunge_distance * ease(share, 0.4)
	_set_alpha(1.0 - share * share)
	if share >= 1.0:
		state_chart.send_event(Types.EVENT_GHOST_GONE)


func _on_gone_state_entered() -> void:
	visible = false

# ============================================
# INTERNALS
# ============================================

## Finds a spot on the player's floor behind them, in a straight walkable
## line from them (so turning around shows it), and turns it away from them.
func _place_behind_player() -> bool:
	if _rig == null:
		return false
	var feet: Vector3 = _rig.get_feet_position()
	var view: Vector3 = -_rig.get_head_transform().basis.z
	var view_yaw: float = atan2(view.x, view.z)
	for angle: float in APPEAR_ANGLES:
		for distance: float in [appear_distance.y, lerpf(appear_distance.x, appear_distance.y, 0.5), appear_distance.x]:
			var yaw: float = view_yaw + deg_to_rad(angle)
			var spot: Vector3 = feet + Vector3(sin(yaw), 0.0, cos(yaw)) * distance
			if _is_walkable(spot) and _has_line_between(feet, spot):
				global_position = spot
				# Turned away from the player until it is seen.
				var away: Vector3 = spot + (spot - feet).normalized()
				look_at(Vector3(away.x, spot.y, away.z), Vector3.UP)
				return true
	return false


func _is_in_sight() -> bool:
	var eyes: Transform3D = _rig.get_head_transform()
	return SightMath.is_in_view(eyes, get_head_position(), sight_half_angle, sight_distance) \
		and _has_line_between(_rig.get_feet_position(), global_position)


func _is_walkable(spot: Vector3) -> bool:
	var walkable: WalkableArea = _rig.walkable_area
	return walkable == null or walkable.contains(spot)


## No wall between: every sample along the floor from [param from] to [param to] is walkable.
func _has_line_between(from: Vector3, to: Vector3) -> bool:
	for sample_index: int in range(1, SIGHT_SAMPLES + 1):
		var point: Vector3 = from.lerp(to, float(sample_index) / float(SIGHT_SAMPLES))
		if not _is_walkable(Vector3(point.x, from.y, point.z)):
			return false
	return true


func _set_alpha(share: float) -> void:
	for material_index: int in fading_materials.size():
		var material: StandardMaterial3D = fading_materials[material_index]
		material.albedo_color.a = _base_alphas[material_index] * share
