## The cellar's auto picker: a gantry under the ceiling. Its bridge runs
## along the cellar, its carriage along the bridge; it heads for the nearest
## ripe plant, lowers its arm and harvests the shrooms into the stash, then
## looks for the next. Bought as "Auto Picker" (faster per level); it waits
## while the stash has no room. Only on the host — a co-op guest sees it
## move through get_net_state() / apply_net_state(). It works only during a
## shift (set_working, from the Cellar).
## State: Idle (looking) -> Moving (to the plant) -> Picking (arm down) -> Idle.
##
##   picker.setup(cellar.get_plants())
##   picker.set_pick_seconds(operation.get_picker_seconds())   # 0 = not bought
##
## Dependencies: ShroomPlant, AutomationMath, PlaceholderMesh3D, Palette, Audio,
##               Types autoloads, SfxSynth
class_name AutoPicker
extends Node3D

## A ripe plant was picked into the stash.
signal picked(plant: ShroomPlant)

## Meters per second the bridge and the carriage travel.
@export var move_speed: float = 1.1
## Seconds between looks for a ripe plant while idle.
@export var look_seconds: float = 0.5
## How far above the plant's pot the arm's claw stops.
@export var arm_clearance: float = 0.32
## Where the carriage may go along the bridge (local X).
@export var carriage_range: Vector2 = Vector2(-1.9, 1.9)

## The plants it tends (every rack plant; inactive ones are skipped).
var plants: Array[ShroomPlant] = []
## Seconds one pick takes (0 = not bought, switched off).
var pick_seconds: float = 0.0

var _target: ShroomPlant = null
var _seconds_until_look: float = 0.0
var _pick_elapsed: float = 0.0
var _has_picked: bool = false
var _arm_length: float = 0.0
var _is_bought: bool = false
var _is_working: bool = false

@onready var _carriage: Node3D = %Carriage
@onready var _arm: Node3D = %Arm
@onready var _claw: Node3D = %Claw
@onready var _lamp: PlaceholderMesh3D = %Lamp
@onready var state_chart: StateChart = %StateChart


func _ready() -> void:
	add_to_group(Types.GROUP_NET_NODE)
	_show_arm(0.0)

# ============================================
# PUBLIC API
# ============================================

## Called by the Cellar at setup: the plants it tends.
func setup(cellar_plants: Array[ShroomPlant]) -> void:
	plants = cellar_plants


## Bought (seconds per pick) or not (0): it shows only when bought.
func set_pick_seconds(seconds: float) -> void:
	pick_seconds = seconds
	_is_bought = seconds > 0.0
	visible = _is_bought
	_update_processing()


## The shift runs (or is over): it works only while it does.
func set_working(is_working: bool) -> void:
	_is_working = is_working
	_update_processing()


## The plant it is heading for or picking, or null.
func get_target() -> ShroomPlant:
	return _target


## Where the claw is above the cellar floor plane (tests).
func get_carriage_position() -> Vector3:
	return _carriage.global_position


## Co-op: how it looks — [bridge z, carriage x, arm length, picking].
func get_net_state() -> Array:
	return [position.z, _carriage.position.x, _arm_length, _target != null and _pick_elapsed > 0.0]


## Co-op guest: show the host's picker.
func apply_net_state(state: Array) -> void:
	position.z = float(state[0])
	_carriage.position.x = float(state[1])
	_show_arm(float(state[2]))
	_lamp.color = Palette.GOLD if bool(state[3]) else Palette.SUCCESS

# ============================================
# STATE CHART CALLBACKS (connected in AutoPicker.tscn)
# ============================================

func _on_idle_state_entered() -> void:
	_target = null
	_show_arm(0.0)
	_lamp.color = Palette.SUCCESS


func _on_idle_state_processing(delta: float) -> void:
	_seconds_until_look -= delta
	if _seconds_until_look > 0.0:
		return
	_seconds_until_look = look_seconds
	_target = _find_ripe_plant()
	if _target != null:
		state_chart.send_event(Types.EVENT_PICKER_TARGET)


func _on_moving_state_physics_processing(delta: float) -> void:
	if not _is_still_worth_picking(_target):
		state_chart.send_event(Types.EVENT_PICKER_DONE)
		return
	var goal: Vector3 = _get_goal(_target)
	var step: float = move_speed * delta
	position.z = move_toward(position.z, goal.z, step)
	_carriage.position.x = move_toward(_carriage.position.x, goal.x, step)
	if is_equal_approx(position.z, goal.z) and is_equal_approx(_carriage.position.x, goal.x):
		state_chart.send_event(Types.EVENT_PICKER_ARRIVED)


func _on_picking_state_entered() -> void:
	_pick_elapsed = 0.0
	_has_picked = false
	_lamp.color = Palette.GOLD
	Audio.play_sfx_at(SfxSynth.get_preset(&"machine"), _carriage.global_position, 0.1, -10.0)


func _on_picking_state_processing(delta: float) -> void:
	_pick_elapsed += delta
	var duration: float = maxf(0.2, pick_seconds)
	var share: float = clampf(_pick_elapsed / duration, 0.0, 1.0)
	# Down in the first half, up again in the second; it picks at the bottom.
	var reach: float = _carriage.global_position.y - (_target.global_position.y + arm_clearance) if is_instance_valid(_target) else 0.0
	_show_arm(reach * (1.0 - absf(share * 2.0 - 1.0)))
	if share >= 0.5 and not _has_picked:
		_has_picked = true
		if is_instance_valid(_target) and _is_still_worth_picking(_target) and _target.harvest(false):
			picked.emit(_target)
	if share >= 1.0:
		state_chart.send_event(Types.EVENT_PICKER_DONE)

# ============================================
# INTERNALS
# ============================================

func _find_ripe_plant() -> ShroomPlant:
	var positions: PackedVector3Array = PackedVector3Array()
	var ready_flags: Array[bool] = []
	for plant: ShroomPlant in plants:
		positions.append(plant.global_position)
		ready_flags.append(_is_still_worth_picking(plant))
	var nearest: int = AutomationMath.find_nearest(_carriage.global_position, positions, ready_flags)
	return plants[nearest] if nearest >= 0 else null


func _is_still_worth_picking(plant: ShroomPlant) -> bool:
	return plant != null and is_instance_valid(plant) and plant.is_active() and plant.is_ripe() and plant.can_store_harvest()


## Bridge z (own position) and carriage x (local) that put the claw over [param plant].
func _get_goal(plant: ShroomPlant) -> Vector3:
	var local_target: Vector3 = to_local(plant.global_position)
	return Vector3(clampf(local_target.x, carriage_range.x, carriage_range.y), 0.0, position.z + local_target.z)


func _update_processing() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT if _is_bought and _is_working else Node.PROCESS_MODE_DISABLED


func _show_arm(length: float) -> void:
	_arm_length = maxf(0.0, length)
	_arm.scale.y = maxf(0.01, _arm_length)
	_claw.position.y = -_arm_length
