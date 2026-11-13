## The player's phone: B / Y in a headset (M on a screen) takes it out and
## puts it away. In a headset it lies in the off-hand, screen tilted up at
## the eyes, and the gun hand's pointer taps it; on a screen it sits on the
## right of the view and the mouse clicks it. Two apps (PhoneScreen): the
## town map and the weapons — every weapon the player owns can be taken
## from it at any time, wherever they are.
##
## The FrontGarden owns it (the map shows the raid, the weapons are the
## defense's): it calls step() each frame and feeds the screen whenever
## step() says a refresh is due.
##
##   phone.setup(rig)
##   phone.toggle()
##   if phone.step(delta): ...show the map's markers, the weapons...
##
## Dependencies: XRPlayerRig, WorldScreen, PhoneScreen, Audio autoload
class_name Phone
extends Node3D

## The player tapped [param weapon] in the weapons app.
signal weapon_chosen(weapon: WeaponData)
## The phone was taken out.
signal opened
## The phone was put away.
signal closed

## Seconds between refreshes while open (the map's markers, the clock).
const REFRESH_SECONDS: float = 0.25

@export_group("Holding")
## Where the phone lies relative to the off-hand controller in a headset.
@export var hand_offset: Vector3 = Vector3(0.0, 0.055, -0.07)
## How far the screen tilts up toward the eyes (degrees).
@export var hand_tilt_degrees: float = 58.0
## Where it sits in front of the flat simulator's camera.
@export var view_offset: Vector3 = Vector3(0.14, -0.03, -0.27)

var _rig: XRPlayerRig = null
var _is_open: bool = false
var _seconds_until_refresh: float = 0.0
var _home: Node = null

@onready var _screen: WorldScreen = %PhoneDisplay


func _ready() -> void:
	visible = false
	_screen.set_active(false)
	var content: PhoneScreen = get_screen()
	content.weapon_chosen.connect(func(weapon: WeaponData) -> void: weapon_chosen.emit(weapon))
	content.close_requested.connect(close)


## Called by the FrontGarden: the rig holds it (its off-hand or camera).
func setup(rig: XRPlayerRig) -> void:
	_rig = rig
	_home = get_parent()


## True while the phone is out.
func is_open() -> bool:
	return _is_open


## The phone's apps (map, weapons).
func get_screen() -> PhoneScreen:
	return _screen.content as PhoneScreen


## The in-world panel the apps show on (tests tap it).
func get_display() -> WorldScreen:
	return _screen


## Takes the phone out, or puts it away.
func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


## Takes the phone out: into the off-hand in a headset, on the right of the view on a screen.
func open() -> void:
	if _is_open or _rig == null:
		return
	_is_open = true
	var anchor: Node3D = _rig.get_phone_anchor()
	if get_parent() != anchor:
		get_parent().remove_child(self)
		anchor.add_child(self)
	if _rig.is_xr_active:
		transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-hand_tilt_degrees)), hand_offset)
	else:
		transform = Transform3D(Basis.IDENTITY, view_offset)
	visible = true
	_screen.set_active(true)
	_seconds_until_refresh = 0.0
	Audio.play_ui(Audio.UI_CLICK)
	opened.emit()


## Puts the phone away (back home, hidden).
func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_screen.set_active(false)
	visible = false
	if _home != null and get_parent() != _home:
		get_parent().remove_child(self)
		_home.add_child(self)
	Audio.play_ui(Audio.UI_CLICK)
	closed.emit()


## Per frame. True when the screen is due for fresh data (only while open).
func step(delta: float) -> bool:
	if not _is_open:
		return false
	_seconds_until_refresh -= delta
	if _seconds_until_refresh > 0.0:
		return false
	_seconds_until_refresh = REFRESH_SECONDS
	return true

