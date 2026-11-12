## "VR in VR": the turret goggles at the Security PC. Put them on and you
## are in a roof turret — your head where its camera sits, the barrel right
## below you following your hand, the trigger firing it, a visor frame with
## the turret's name around your view. Take them off (the button floating
## in front of you, or the end of the shift) and you are back at the desk,
## exactly where you stood. While seated you can't walk (XRLocomotion is
## locked) and the gun in hand is put away.
##
## The FrontGarden owns it (turrets are defense) and routes the triggers here
## while it is active.
##
##   seat.setup(rig)
##   seat.enter(turret)  /  seat.set_firing(true)  /  seat.leave()
##
## Dependencies: XRPlayerRig, XRPointer, HouseTurret, PointerButton, Audio autoload
class_name TurretSeat
extends Node3D

signal entered(turret: HouseTurret)
signal left

## How far ahead the turret aims along the hand's ray (meters).
const AIM_DISTANCE: float = 30.0
## The visor frame sits this far in front of the eyes.
const VISOR_DISTANCE: float = 0.4

var _rig: XRPlayerRig = null
var _turret: HouseTurret = null
var _saved_rig_transform: Transform3D = Transform3D.IDENTITY
## Dominant and off-hand trigger held down (index 0 / 1).
var _held_triggers: Array[bool] = [false, false]
## Where the player's head was before sitting down (put back on leaving).
var _saved_head_position: Vector3 = Vector3.ZERO

@onready var _visor: Node3D = %Visor
@onready var _visor_label: Label3D = %VisorLabel
@onready var _exit_button: PointerButton = %ExitButton


func _ready() -> void:
	_visor.visible = false
	_exit_button.visible = false
	_exit_button.pressed.connect(func(_button: PointerButton) -> void: leave())


## Called by the FrontGarden at setup.
func setup(rig: XRPlayerRig) -> void:
	_rig = rig


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
	_turret = turret
	_saved_rig_transform = _rig.global_transform
	_saved_head_position = _rig.get_head_transform().origin
	_rig.locomotion.is_locked = true
	turret.set_manual(true)
	turret.set_seated(true)
	_rig.face_yaw(turret.global_rotation.y)
	var mount: Vector3 = turret.get_camera_mount().global_position
	_rig.move_origin_by(mount - _rig.get_head_transform().origin)
	# The way out floats low and to the side of the view, world-locked.
	var forward: Vector3 = -turret.global_transform.basis.z
	var side: Vector3 = turret.global_transform.basis.x
	# Its cap faces back up at the player's eyes.
	var facing: Vector3 = (-forward + Vector3.UP * 0.9).normalized()
	var button_basis: Basis = Basis(side, facing, side.cross(facing).normalized())
	_exit_button.global_transform = Transform3D(button_basis, mount + forward * 1.1 - side * 0.75 + Vector3(0.0, -0.75, 0.0))
	_exit_button.visible = true
	var camera: Camera3D = _rig.get_view_camera()
	remove_child(_visor)
	camera.add_child(_visor)
	_visor.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -VISOR_DISTANCE))
	_visor.visible = true
	_visor_label.text = tr("Turret %d · live") % (turret.mount_level)
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
	_exit_button.visible = false
	_visor.visible = false
	if _visor.get_parent() != self:
		_visor.get_parent().remove_child(_visor)
		add_child(_visor)
	Audio.play_ui(Audio.UI_CLICK)
	left.emit()


## A trigger went down (true) or up (false) while seated. Each trigger
## counts on its own ([param is_primary]: dominant / left mouse, otherwise
## off-hand / right mouse); the turret fires while either is held.
func set_firing(is_firing: bool, is_primary: bool = true) -> void:
	_held_triggers[0 if is_primary else 1] = is_firing and is_active()


## Per frame while the shift runs: the barrel follows the aiming hand, a
## held trigger fires. A turret taken off the roof (upgrade lost) ends the seat.
func step(_delta: float) -> void:
	if not is_active():
		return
	if not _turret.is_mounted():
		leave()
		return
	var pointer: XRPointer = _rig.get_tool_pointer()
	_turret.set_manual_aim(pointer.ray_origin + pointer.ray_direction * AIM_DISTANCE)
	if _held_triggers[0] or _held_triggers[1]:
		_turret.fire()


## The floating "take off goggles" button (tests).
func get_exit_button() -> PointerButton:
	return _exit_button


func _exit_tree() -> void:
	# The visor rides on the camera while seated; it belongs to this scene.
	if _visor != null and is_instance_valid(_visor) and _visor.get_parent() != self:
		_visor.queue_free()
