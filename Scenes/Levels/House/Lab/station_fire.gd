## Fire at a lab station (the cooker): a finished batch left on the hot
## cooker starts to smoke after warn_seconds (take it off and it cools) and
## catches fire after ignite_seconds. The fire burns the batch, the cooker
## takes and starts nothing, a smoke alarm beeps and the neighbours see the
## smoke (heat rises) until the player puts it out with the extinguisher
## (Extinguisher.spray → extinguish). Flames and smoke are a few shared
## glowing shapes, animated by hand (no particles). Co-op: the host runs
## it; the guest shows its flames and smoke (Types.GROUP_NET_NODE).
## State: Calm -> Overheating (-> Calm when the batch is taken) -> Burning -> Calm.
##
##   fire.station = %Cooker      # in the scene
##   fire.step(delta)            # by the Lab while the shift runs
##
## Dependencies: Workstation, ItemSocket, Grabbable, Operation, PlaceholderMesh3D,
##               FloatingText3D, Pools, Palette, Audio, Types autoloads, SfxSynth
class_name StationFire
extends Node3D

## The cooker caught fire / the fire is out.
signal ignited
signal put_out
## The batch left on it started to smoke.
signal overheating

## Fires are found by the extinguisher through this group.
const GROUP: StringName = &"station_fire"
## Seconds between two beeps of the smoke alarm and two crackles.
const ALARM_SECONDS: float = 1.1
const CRACKLE_SECONDS: float = 0.35

## The station that can catch fire.
@export var station: Workstation
## A finished batch left on it starts to smoke after this many seconds...
@export var warn_seconds: float = 14.0
## ...and catches fire after this many.
@export var ignite_seconds: float = 26.0
## How much spraying it takes to put it out (extinguish() amounts).
@export var fire_strength: float = 100.0
## Heat added per second while it burns (the neighbours see the smoke).
@export var heat_per_second: float = 0.6

var operation: Operation = null

var _hot_seconds: float = 0.0
var _strength_left: float = 0.0
var _seconds_until_alarm: float = 0.0
var _seconds_until_crackle: float = 0.0
var _animation_time: float = 0.0
var _flames: Array[Node3D] = []
var _smoke: Array[Node3D] = []

@onready var state_chart: StateChart = %StateChart
@onready var _flame_root: Node3D = %Flames
@onready var _smoke_root: Node3D = %Smoke


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(Types.GROUP_NET_NODE)
	for child: Node in _flame_root.get_children():
		# The tongues flicker; the glowing embers under them don't.
		if not child is MeshInstance3D:
			_flames.append(child as Node3D)
	for child: Node in _smoke_root.get_children():
		_smoke.append(child as Node3D)
	_flame_root.visible = false
	_smoke_root.visible = false


## Called by the Lab at setup.
func setup(house_operation: Operation) -> void:
	operation = house_operation


## Per frame while the shift runs (the Lab).
func step(delta: float) -> void:
	_hot_seconds = _hot_seconds + delta if _has_batch_left() else 0.0
	_sound_and_heat(delta)


## The flames flicker and the smoke rises whenever they show (the guest's too).
func _process(delta: float) -> void:
	if _smoke_root.visible or _flame_root.visible:
		_animation_time += delta
		_animate()


## Co-op: [burning, smoking].
func get_net_state() -> Array:
	return [is_burning(), _smoke_root.visible]


## Co-op guest: show the host's fire.
func apply_net_state(state: Array) -> void:
	if state.size() < 2:
		return
	var burning: bool = bool(state[0])
	_flame_root.visible = burning
	_smoke_root.visible = bool(state[1]) or burning
	_strength_left = fire_strength if burning else 0.0


func is_burning() -> bool:
	return _strength_left > 0.0


func is_overheating() -> bool:
	return _smoke_root.visible and not is_burning()


## Where the extinguisher aims: the middle of the flames.
func get_target_position() -> Vector3:
	return _flame_root.global_position + Vector3(0.0, 0.15, 0.0)


## Foam hits the fire: [param amount] less to go; out at nothing left.
func extinguish(amount: float) -> void:
	if not is_burning():
		return
	_strength_left = maxf(0.0, _strength_left - amount)
	if _strength_left <= 0.0:
		state_chart.send_event(Types.EVENT_COOL_DOWN)

# ============================================
# STATE CHART CALLBACKS (connected in StationFire.tscn)
# ============================================

func _on_calm_state_entered() -> void:
	_flame_root.visible = false
	_smoke_root.visible = false
	_strength_left = 0.0


func _on_calm_state_processing(_delta: float) -> void:
	if _hot_seconds >= warn_seconds:
		state_chart.send_event(Types.EVENT_OVERHEAT)


func _on_overheating_state_entered() -> void:
	_smoke_root.visible = true
	overheating.emit()


func _on_overheating_state_processing(_delta: float) -> void:
	if not _has_batch_left():
		state_chart.send_event(Types.EVENT_COOL_DOWN)
	elif _hot_seconds >= ignite_seconds:
		state_chart.send_event(Types.EVENT_IGNITE)


func _on_burning_state_entered() -> void:
	_strength_left = fire_strength
	_flame_root.visible = true
	_smoke_root.visible = true
	_seconds_until_alarm = 0.0
	_burn_batch()
	if station != null:
		station.set_burning(true)
	ignited.emit()


func _on_burning_state_exited() -> void:
	_strength_left = 0.0
	_hot_seconds = 0.0
	if station != null:
		station.set_burning(false)
	Audio.play_sfx_at(SfxSynth.get_preset(&"spray"), global_position, 0.1, -6.0)
	put_out.emit()

# ============================================
# INTERNALS
# ============================================

## A cooked batch still waits on the station's output tray.
func _has_batch_left() -> bool:
	return station != null and not station.get_output_socket().is_empty()


## The fire ruins whatever waits on the tray.
func _burn_batch() -> void:
	var tray: ItemSocket = station.get_output_socket() if station != null else null
	if tray == null or tray.is_empty():
		return
	var batch: Grabbable = tray.remove_item()
	FloatingText3D.spawn(tr("Batch burnt"), tray.global_position + Vector3(0.0, 0.35, 0.0), Palette.DANGER, Global.get_world_root())
	Pools.despawn(batch)


## Flicker and rising smoke while they show.
func _animate() -> void:
	for puff_index: int in _smoke.size():
		var rise: float = fposmod(_animation_time * 0.35 + float(puff_index) / float(_smoke.size()), 1.0)
		var puff: Node3D = _smoke[puff_index]
		puff.position = Vector3(sin(_animation_time + puff_index) * 0.05, 0.2 + rise * 0.9, cos(_animation_time * 0.7 + puff_index) * 0.05)
		puff.scale = Vector3.ONE * lerpf(0.6, 1.6, rise)
	if not _flame_root.visible:
		return
	var size_share: float = clampf(_strength_left / fire_strength * 1.2, 0.35, 1.0)
	for flame_index: int in _flames.size():
		var flicker: float = 0.8 + 0.22 * sin(_animation_time * (9.0 + flame_index * 2.7) + flame_index * 1.7) + 0.08 * sin(_animation_time * 23.0 + flame_index)
		_flames[flame_index].scale = Vector3(1.0, flicker, 1.0) * size_share
		_flames[flame_index].rotation.z = 0.06 * sin(_animation_time * (3.0 + flame_index) + flame_index)


## While it burns: the smoke alarm, crackling and the neighbours' heat.
func _sound_and_heat(delta: float) -> void:
	if not is_burning():
		return
	_seconds_until_alarm -= delta
	if _seconds_until_alarm <= 0.0:
		_seconds_until_alarm = ALARM_SECONDS
		Audio.play_sfx_at(SfxSynth.get_preset(&"alarm"), global_position + Vector3(0.0, 1.2, 0.0), 0.0, -8.0)
	_seconds_until_crackle -= delta
	if _seconds_until_crackle <= 0.0:
		_seconds_until_crackle = CRACKLE_SECONDS * randf_range(0.6, 1.4)
		Audio.play_sfx_at(SfxSynth.get_preset(&"crackle"), global_position, 0.3, -10.0)
	if operation != null:
		operation.add_heat(heat_per_second * delta)
