## "VR in VR": the turret goggles at the Security PC. Put them on and you
## are in a roof turret — your head where its camera sits, the barrel right
## below you following your hand, the trigger firing it, a modern overlay
## on the edges of your view: which turret (roof turret or field tower) and
## its ability with a bar for reload or heat at the top, buttons at the
## bottom to switch to the previous / next turret right in the goggles
## (A / X — Q on a screen — does too) and to take them off. A mortar lobs
## its shell where the hand points on the ground (a ring shows where it
## lands). Take the goggles off (the overlay's button or the end of the
## shift) and you are back at the desk, exactly where you stood. While
## seated you can't walk (XRLocomotion is locked) and the gun in hand is
## put away.
##
## The FrontGarden owns it (turrets are defense) and routes the triggers here
## while it is active.
##
##   seat.setup(rig, security_pc)
##   seat.enter(turret)  /  seat.switch_turret(1)  /  seat.set_firing(true)  /  seat.leave()
##
## Dependencies: XRPlayerRig, XRPointer, HouseTurret, SecurityPc, TurretHud,
##               WorldScreen, RayMath, Audio autoload
class_name TurretSeat
extends Node3D

signal entered(turret: HouseTurret)
signal left

## How far ahead the turret aims along the hand's ray (meters).
const AIM_DISTANCE: float = 30.0
## The visor frame sits this far in front of the eyes.
const VISOR_DISTANCE: float = 0.4
## Seconds between overlay refreshes.
const HUD_REFRESH_SECONDS: float = 0.1

var _rig: XRPlayerRig = null
var _turret: HouseTurret = null
var _saved_rig_transform: Transform3D = Transform3D.IDENTITY
## Dominant and off-hand trigger held down (index 0 / 1).
var _held_triggers: Array[bool] = [false, false]
## Where the player's head was before sitting down (put back on leaving).
var _saved_head_position: Vector3 = Vector3.ZERO
## Where the turrets to switch between come from (the Security PC knows them all).
var _source: SecurityPc = null
var _seconds_until_hud_refresh: float = 0.0

@onready var _visor: Node3D = %Visor
@onready var _hud_status: WorldScreen = %HudStatus
@onready var _hud_controls: WorldScreen = %HudControls


func _ready() -> void:
	_visor.visible = false
	_set_hud_active(false)
	var controls: TurretHud = _hud_controls.content as TurretHud
	controls.turret_step_requested.connect(switch_turret)
	controls.exit_requested.connect(leave)


## Called by the FrontGarden at setup: [param source] knows every turret
## to switch between (roof turrets and field towers).
func setup(rig: XRPlayerRig, source: SecurityPc = null) -> void:
	_rig = rig
	_source = source


func is_active() -> bool:
	return _turret != null


## The turret being steered, or null.
func get_turret() -> HouseTurret:
	return _turret


## Puts the player into [param turret]: head at its camera, view along its
## barrel, locomotion locked, the turret on manual.
func enter(turret: HouseTurret) -> bool:
	if _rig == null or turret == null or not turret.is_mounted() or is_active():
		return false
	_saved_rig_transform = _rig.global_transform
	_saved_head_position = _rig.get_head_transform().origin
	_rig.locomotion.is_locked = true
	_sit_in(turret)
	var camera: Camera3D = _rig.get_view_camera()
	remove_child(_visor)
	camera.add_child(_visor)
	_visor.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -VISOR_DISTANCE))
	_visor.visible = true
	_set_hud_active(true)
	_refresh_hud()
	Audio.play_ui(Audio.UI_CONFIRM)
	entered.emit(turret)
	return true


## Takes the goggles off: back where the player stood, turret on its own again.
func leave() -> void:
	if not is_active():
		return
	_held_triggers = [false, false]
	_turret.set_manual(false)
	_turret.set_seated(false)
	_turret = null
	_rig.global_transform = _saved_rig_transform
	# The player may have stepped around the room while seated: put the head
	# back where it was, not just the play space.
	var head: Vector3 = _rig.get_head_transform().origin
	_rig.move_origin_by(Vector3(_saved_head_position.x - head.x, 0.0, _saved_head_position.z - head.z))
	_rig.locomotion.is_locked = false
	_visor.visible = false
	_set_hud_active(false)
	if _visor.get_parent() != self:
		_visor.get_parent().remove_child(_visor)
		add_child(_visor)
	Audio.play_ui(Audio.UI_CLICK)
	left.emit()


## Moves to the next (+1) or previous (-1) turret right from the goggles:
## the head goes to that turret's camera, the one before aims on its own
## again. False when there is no other turret.
func switch_turret(step: int) -> bool:
	if not is_active():
		return false
	var turrets: Array[HouseTurret] = _get_turrets()
	var current: int = turrets.find(_turret)
	if turrets.size() < 2 or current < 0:
		Audio.play_ui(Audio.UI_ERROR)
		return false
	var next: HouseTurret = turrets[posmod(current + step, turrets.size())]
	_turret.set_manual(false)
	_turret.set_seated(false)
	_sit_in(next)
	_refresh_hud()
	Audio.play_ui(Audio.UI_CLICK)
	entered.emit(next)
	return true


## A trigger went down (true) or up (false) while seated. Each trigger
## counts on its own ([param is_primary]: dominant / left mouse, otherwise
## off-hand / right mouse); the turret fires while either is held.
func set_firing(is_firing: bool, is_primary: bool = true) -> void:
	_held_triggers[0 if is_primary else 1] = is_firing and is_active()


## Per frame while the shift runs: the barrel follows the aiming hand, a
## held trigger fires. A turret taken off the roof (upgrade lost) ends the seat.
func step(delta: float) -> void:
	if not is_active():
		return
	if not _turret.is_mounted():
		leave()
		return
	var pointer: XRPointer = _rig.get_tool_pointer()
	# Aim where the hand points: on the ground when it points down there
	# (a mortar lobs its shell right there), else far ahead.
	var distance: float = RayMath.intersect_ground(pointer.ray_origin, pointer.ray_direction, 0.0)
	if distance == RayMath.NO_HIT or distance > AIM_DISTANCE * 2.0:
		distance = AIM_DISTANCE
	_turret.set_manual_aim(pointer.ray_origin + pointer.ray_direction * distance)
	_seconds_until_hud_refresh -= delta
	if _seconds_until_hud_refresh <= 0.0:
		_seconds_until_hud_refresh = HUD_REFRESH_SECONDS
		_refresh_hud()
	if _held_triggers[0] or _held_triggers[1]:
		_turret.fire()


## The overlay's two panels: status (top) and controls (bottom).
func get_hud_status() -> TurretHud:
	return _hud_status.content as TurretHud


func get_hud_controls() -> TurretHud:
	return _hud_controls.content as TurretHud


## Takes [param turret] over and puts the head at its camera, looking along it.
func _sit_in(turret: HouseTurret) -> void:
	_turret = turret
	turret.set_manual(true)
	turret.set_seated(true)
	_rig.face_yaw(turret.global_rotation.y)
	_rig.move_origin_by(turret.get_camera_mount().global_position - _rig.get_head_transform().origin)


## Every mounted turret to switch between (just the current one without a source).
func _get_turrets() -> Array[HouseTurret]:
	var turrets: Array[HouseTurret] = []
	if _source != null:
		for turret: HouseTurret in _source.get_turrets():
			if is_instance_valid(turret) and turret.is_mounted():
				turrets.append(turret)
	if turrets.is_empty() and _turret != null:
		turrets.append(_turret)
	return turrets


func _refresh_hud() -> void:
	if _turret == null:
		return
	var turrets: Array[HouseTurret] = _get_turrets()
	get_hud_status().show_status(_turret.get_display_name(), turrets.find(_turret) + 1, turrets.size(), _turret.get_ability_text(), _turret.get_ability_ready())
	get_hud_controls().set_can_switch(turrets.size() > 1)


func _set_hud_active(is_active_now: bool) -> void:
	_hud_status.set_active(is_active_now)
	_hud_controls.set_active(is_active_now)


## Where the overlay's "Take off goggles" button sits in the world (tests tap it).
func get_exit_point() -> Vector3:
	return _hud_controls.pixel_to_world(get_hud_controls().get_exit_button().get_global_rect().get_center())


func _exit_tree() -> void:
	# The visor rides on the camera while seated; it belongs to this scene.
	if _visor != null and is_instance_valid(_visor) and _visor.get_parent() != self:
		_visor.queue_free()
