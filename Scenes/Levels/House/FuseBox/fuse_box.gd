## The fuse box on the front room wall. At night the old wiring may trip it
## (a chance each night hour, at most a few times a night): the power goes
## out (Operation.set_power) — the lamps go dark and the lab stands still —
## until the player flips the breaker back (the lever: trigger or click).
## Co-op: the host trips and resets it; the guest shows its state
## (Types.GROUP_NET_NODE) and their press on the lever reaches the host.
## State: On <-> Tripped.
##
##   fuse_box.setup(operation)
##   fuse_box.on_hour_passed(day_cycle.is_night())   # each in-game hour (host)
##
## Dependencies: Operation, PointerButton, PlaceholderMesh3D, Palette, Audio,
##               Types autoloads, SfxSynth
class_name FuseBox
extends Node3D

## The power went out / came back.
signal tripped
signal reset_done

## Lever angle (degrees) while the power is on / tripped.
const LEVER_ON_DEGREES: float = -35.0
const LEVER_TRIPPED_DEGREES: float = 35.0

## Chance each night hour that the fuses blow...
@export_range(0.0, 1.0, 0.01) var trip_chance_per_night_hour: float = 0.2
## ...but at most this often a night.
@export_range(0, 10) var max_trips_per_night: int = 1

var operation: Operation = null

var _trips_tonight: int = 0
var _is_tripped: bool = false
var _tween: Tween
var _random: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var state_chart: StateChart = %StateChart
@onready var _lever: Node3D = %Lever
@onready var _lever_button: PointerButton = %LeverButton
@onready var _light: PlaceholderMesh3D = %Light
@onready var _label: Label3D = %Label


func _ready() -> void:
	add_to_group(Types.GROUP_NET_NODE)
	_random.randomize()
	_lever_button.pressed.connect(func(_button: PointerButton) -> void: reset())
	_lever.rotation.x = deg_to_rad(LEVER_ON_DEGREES)
	_apply_light()


## Called by the House level at setup.
func setup(house_operation: Operation) -> void:
	operation = house_operation


## An in-game hour passed: at night the fuses may blow.
func on_hour_passed(is_night: bool) -> void:
	if not is_night:
		_trips_tonight = 0
		return
	if _is_tripped or _trips_tonight >= max_trips_per_night:
		return
	if _random.randf() < trip_chance_per_night_hour:
		trip()


## The fuses blow: the power goes out.
func trip() -> void:
	if not _is_tripped:
		_trips_tonight += 1
		state_chart.send_event(Types.EVENT_POWER_OUT)


## The breaker is flipped back: the power comes on.
func reset() -> void:
	if _is_tripped:
		state_chart.send_event(Types.EVENT_POWER_ON)


## True while the power is out.
func is_tripped() -> bool:
	return _is_tripped


## The lever that resets it (tests).
func get_lever_button() -> PointerButton:
	return _lever_button


## Co-op: [tripped].
func get_net_state() -> Array:
	return [_is_tripped]


## Co-op guest: show the host's fuse box (and its power) without rolling dice.
func apply_net_state(state: Array) -> void:
	if state.is_empty():
		return
	var should_trip: bool = bool(state[0])
	if should_trip != _is_tripped:
		state_chart.send_event(Types.EVENT_POWER_OUT if should_trip else Types.EVENT_POWER_ON)

# ============================================
# STATE CHART CALLBACKS (connected in FuseBox.tscn)
# ============================================

func _on_on_state_entered() -> void:
	var was_tripped: bool = _is_tripped
	_is_tripped = false
	_swing_lever(LEVER_ON_DEGREES)
	_apply_light()
	if operation != null:
		operation.set_power(true)
	if was_tripped:
		Audio.play_sfx_at(SfxSynth.get_preset(&"breaker"), global_position, 0.05, -2.0)
		reset_done.emit()


func _on_tripped_state_entered() -> void:
	_is_tripped = true
	_swing_lever(LEVER_TRIPPED_DEGREES)
	_apply_light()
	if operation != null:
		operation.set_power(false)
	Audio.play_sfx_at(SfxSynth.get_preset(&"breaker"), global_position, 0.05, 0.0)
	Audio.play_sfx_at(SfxSynth.get_preset(&"crackle"), global_position, 0.2, -4.0)
	tripped.emit()

# ============================================
# INTERNALS
# ============================================

func _swing_lever(degrees: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_lever, "rotation:x", deg_to_rad(degrees), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _apply_light() -> void:
	_light.color = Palette.DANGER if _is_tripped else Palette.SUCCESS
	_label.text = tr("Flip the lever") if _is_tripped else tr("Fuses")
	_label.modulate = Palette.DANGER if _is_tripped else Palette.TEXT
	_lever_button.is_enabled = _is_tripped
