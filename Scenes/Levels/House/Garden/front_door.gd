## The front door: the objective of every raider and the way between the
## front room and the porch. It swings on a hinge — grip a handle (inside or
## outside) and pull or push it open, walk through, swing it shut; it latches
## when nearly closed. A deadbolt on each side locks it (only when closed).
## Pulling the trigger on a handle (or a click in the flat simulator) swings
## it fully open or shut.
##
## The door matters in a raid: officers hammer it, and an open or unlocked
## door gives way much faster (get_damage_multiplier). When its health runs
## out it breaks and the shift is lost. Reinforcement upgrades raise its
## health; a bar above the frame shows it and the leaf shakes when hit.
##
## Local frame: the leaf closes along +X from the hinge, +Z is the house's
## inside. Angles are degrees of opening toward the inside.
## State: Closed { Unlocked <-> Locked } <-> Open (opening only when unlocked).
##
## Dependencies: HealthComponent, HingeHandle, PointerButton, PlaceholderMesh3D,
##               FloatingText3D, Palette, Audio, Global, Types autoloads, SfxSynth
class_name FrontDoor
extends Node3D

signal broken
signal opened
## Swung shut and latched.
signal closed
signal lock_changed(is_locked: bool)
## The doorway became wide enough to walk through, or stopped being so.
signal passage_changed(is_passable: bool)

const BAR_WIDTH: float = 1.2
const BAR_HEIGHT: float = 0.08
## Seconds between two "it's locked" rattles while a hand keeps pulling.
const RATTLE_INTERVAL_SECONDS: float = 0.6

@export var base_max_health: float = 600.0

@export_group("Swing")
## How far the leaf opens (toward the inside).
@export var max_open_degrees: float = 100.0
## Open at least this far and the player can walk through.
@export var passable_from_degrees: float = 60.0
## Let go below this angle and the door falls shut and latches.
@export var latch_below_degrees: float = 6.0
## Seconds a click (flat simulator) takes to swing the door fully.
@export var swing_seconds: float = 0.45

@export_group("Raid")
## Damage multiplier for raiders while the door stands open...
@export var open_damage_multiplier: float = 3.0
## ...while it is shut but not bolted...
@export var unlocked_damage_multiplier: float = 1.5
## ...and while it is bolted.
@export var locked_damage_multiplier: float = 1.0

## Share of every raider hit the frame absorbs (Steel Door Frame upgrade).
var damage_reduction: float = 0.0

var _shake_tween: Tween
var _swing_tween: Tween
var _open_angle: float = 0.0
var _is_open: bool = false
var _is_locked: bool = false
var _is_passable: bool = false
## Time.get_ticks_msec() of the last "it's locked" rattle (no per-frame timer).
var _last_rattle_msec: int = -100000

@onready var health_component: HealthComponent = %HealthComponent
@onready var state_chart: StateChart = %DoorChart
@onready var _hinge: Node3D = %Hinge
@onready var _panel: Node3D = %Panel
@onready var _inside_handle: HingeHandle = %InsideHandle
@onready var _outside_handle: HingeHandle = %OutsideHandle
@onready var _inside_handle_press: PointerButton = %InsideHandlePress
@onready var _outside_handle_press: PointerButton = %OutsideHandlePress
@onready var _inside_lock: PointerButton = %InsideLock
@onready var _outside_lock: PointerButton = %OutsideLock
@onready var _bar_fill: MeshInstance3D = %BarFill
@onready var _bar_back: MeshInstance3D = %BarBack


func _ready() -> void:
	add_to_group(Types.GROUP_NET_NODE)
	_bar_back.material_override = PlaceholderMesh3D.get_shared_material(Palette.BACKGROUND, 0.0, true)
	health_component.damaged.connect(_on_damaged)
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(func() -> void: broken.emit())
	for handle: HingeHandle in [_inside_handle, _outside_handle]:
		handle.hinge_origin = _hinge
		handle.angle_dragged.connect(drag_to_angle)
		handle.toggle_requested.connect(toggle_open)
		handle.released.connect(func(_item: Grabbable) -> void: end_drag())
	# The trigger on a handle swings the door fully (grip still drags it by hand).
	for handle_press: PointerButton in [_inside_handle_press, _outside_handle_press]:
		handle_press.pressed.connect(func(_button: PointerButton) -> void: toggle_open())
	for lock_button: PointerButton in [_inside_lock, _outside_lock]:
		lock_button.pressed.connect(func(_button: PointerButton) -> void: toggle_lock())
	set_max_health(base_max_health)
	_apply_lock_look()


# ============================================
# PUBLIC API
# ============================================

## False once raiders broke it down.
func is_alive() -> bool:
	return not health_component.is_dead


## Sets a new maximum (reinforcement upgrades) and repairs the door fully.
func set_max_health(new_max_health: float) -> void:
	health_component.revive(new_max_health)


## Door health, 0 (broken) to 1 (intact).
func get_health_ratio() -> float:
	return health_component.get_health_ratio()


## True from the moment it swings off the latch until it latches again.
func is_open() -> bool:
	return _is_open


## True while the bolt is thrown.
func is_locked() -> bool:
	return _is_locked


## Open wide enough to walk through.
func is_passable() -> bool:
	return _is_passable


## How far the leaf stands open, in degrees toward the inside.
func get_open_angle() -> float:
	return _open_angle


## How much harder raiders hit the door right now: open > unlocked > bolted,
## less with a steel frame ([member damage_reduction]).
func get_damage_multiplier() -> float:
	var state_multiplier: float = locked_damage_multiplier if _is_locked else unlocked_damage_multiplier
	if _is_open:
		state_multiplier = open_damage_multiplier
	return state_multiplier * (1.0 - clampf(damage_reduction, 0.0, 0.9))


## A hand pulls the leaf to [param angle_degrees] (HingeHandle). A bolted door rattles.
func drag_to_angle(angle_degrees: float) -> void:
	if _is_locked:
		var now_msec: int = Time.get_ticks_msec()
		if angle_degrees > latch_below_degrees and now_msec - _last_rattle_msec >= roundi(RATTLE_INTERVAL_SECONDS * 1000.0):
			_last_rattle_msec = now_msec
			_say(tr("Bolted"), Palette.WARNING)
		return
	_stop_swing()
	_set_angle(angle_degrees)


## The hand let go: nearly shut means it falls shut and latches.
func end_drag() -> void:
	if _open_angle <= latch_below_degrees:
		_set_angle(0.0)
		if _is_open:
			state_chart.send_event(Types.EVENT_DOOR_CLOSED)
			Audio.play_sfx_at(SfxSynth.get_preset(&"hit"), global_position + Vector3(0.0, 1.0, 0.0), 0.05, -8.0)


## Opens a closed door fully, closes an open one (a click in the flat simulator).
func toggle_open() -> void:
	if _is_open:
		close_fully()
	else:
		open_fully()


## Swings the door wide open. Returns false when it is bolted.
func open_fully() -> bool:
	if _is_locked:
		_say(tr("Bolted"), Palette.WARNING)
		return false
	_swing_to(max_open_degrees)
	return true


## Swings the door shut; it latches at the end.
func close_fully() -> void:
	_swing_to(0.0)


## Throws or draws the bolt. Returns false (and says why) while the door is open.
func toggle_lock() -> bool:
	return set_locked(not _is_locked)


func set_locked(should_lock: bool) -> bool:
	if should_lock == _is_locked:
		return true
	if should_lock and (_is_open or _open_angle > 0.0):
		_say(tr("Close the door first"), Palette.WARNING)
		return false
	state_chart.send_event(Types.EVENT_DOOR_LOCKED if should_lock else Types.EVENT_DOOR_UNLOCKED)
	return true


func get_inside_handle() -> HingeHandle:
	return _inside_handle


func get_outside_handle() -> HingeHandle:
	return _outside_handle


func get_inside_lock() -> PointerButton:
	return _inside_lock


func get_outside_lock() -> PointerButton:
	return _outside_lock

## Co-op: how the door looks right now — [open angle, bolted, health, max health].
func get_net_state() -> Array:
	return [_open_angle, _is_locked, health_component.current_health, health_component.max_health]


## Co-op guest: show the host's door (its swing, bolt and health) and let
## the guest walk through when it stands open — without running its rules.
func apply_net_state(state: Array) -> void:
	var angle: float = float(state[0])
	if not is_equal_approx(angle, _open_angle):
		_open_angle = clampf(angle, 0.0, max_open_degrees)
		_hinge.rotation.y = -deg_to_rad(_open_angle)
		_inside_handle.current_angle_degrees = _open_angle
		_outside_handle.current_angle_degrees = _open_angle
		_is_open = _open_angle > latch_below_degrees
		var now_passable: bool = _open_angle >= passable_from_degrees
		if now_passable != _is_passable:
			_is_passable = now_passable
			passage_changed.emit(_is_passable)
	var bolted: bool = bool(state[1])
	if bolted != _is_locked:
		_is_locked = bolted
		_apply_lock_look()
	_on_health_changed(float(state[2]), float(state[3]))

# ============================================
# STATE CHART CALLBACKS (connected in FrontDoor.tscn)
# ============================================

func _on_unlocked_state_entered() -> void:
	_is_open = false
	if _is_locked:
		_is_locked = false
		_apply_lock_look()
		Audio.play_sfx_at(SfxSynth.get_preset(&"pop"), _inside_lock.global_position, 0.05, -6.0)
		lock_changed.emit(false)


func _on_locked_state_entered() -> void:
	_is_open = false
	_is_locked = true
	_apply_lock_look()
	Audio.play_sfx_at(SfxSynth.get_preset(&"hit"), _inside_lock.global_position, 0.05, -4.0)
	lock_changed.emit(true)


func _on_closed_state_entered() -> void:
	if _is_open:
		_is_open = false
		closed.emit()


func _on_open_state_entered() -> void:
	_is_open = true
	opened.emit()

# ============================================
# INTERNALS
# ============================================

func _set_angle(angle_degrees: float) -> void:
	_open_angle = clampf(angle_degrees, 0.0, max_open_degrees)
	_hinge.rotation.y = -deg_to_rad(_open_angle)
	_inside_handle.current_angle_degrees = _open_angle
	_outside_handle.current_angle_degrees = _open_angle
	if not _is_open and _open_angle > latch_below_degrees:
		state_chart.send_event(Types.EVENT_DOOR_OPENED)
	var now_passable: bool = _open_angle >= passable_from_degrees
	if now_passable != _is_passable:
		_is_passable = now_passable
		passage_changed.emit(_is_passable)


func _swing_to(angle_degrees: float) -> void:
	_stop_swing()
	var seconds: float = swing_seconds * absf(angle_degrees - _open_angle) / maxf(1.0, max_open_degrees)
	_swing_tween = create_tween()
	_swing_tween.tween_method(_set_angle, _open_angle, angle_degrees, maxf(0.01, seconds)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_callback(end_drag)


func _stop_swing() -> void:
	if _swing_tween != null:
		_swing_tween.kill()
		_swing_tween = null


func _apply_lock_look() -> void:
	for lock_button: PointerButton in [_inside_lock, _outside_lock]:
		lock_button.caption = tr("Bolted") if _is_locked else tr("Unbolted")
		lock_button.color = Palette.SUCCESS if _is_locked else Palette.WARNING


func _say(message: String, color: Color) -> void:
	Audio.play_ui(Audio.UI_ERROR)
	FloatingText3D.spawn(message, _panel.global_position + Vector3(0.0, 1.9, 0.0), color, Global.get_world_root())


func _on_health_changed(current_health: float, max_health: float) -> void:
	var ratio: float = current_health / maxf(1.0, max_health)
	_bar_fill.scale.x = maxf(0.001, ratio)
	_bar_fill.position.x = -BAR_WIDTH * 0.5 * (1.0 - ratio)
	_bar_fill.material_override = PlaceholderMesh3D.get_shared_material(Palette.SUCCESS if ratio > 0.5 else (Palette.WARNING if ratio > 0.25 else Palette.DANGER), 0.6, true)


func _on_damaged(_damage_info: DamageInfo) -> void:
	if _shake_tween != null:
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.tween_property(_panel, "rotation:y", deg_to_rad(2.5), 0.04)
	_shake_tween.tween_property(_panel, "rotation:y", 0.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
