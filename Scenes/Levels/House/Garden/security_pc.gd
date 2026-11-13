## The Security PC on the office desk (a defense upgrade): its monitor shows
## the live view from one of the house's roof turrets. Switch turrets, take
## one over, then point at the view to aim it and pull the trigger to fire —
## a real turret seat, from inside the house. Released, the turret aims on
## its own again. Or put on the turret goggles beside the monitor to sit in
## the turret yourself (TurretSeat). Part of the defense front (FrontGarden owns it and its
## turrets); it only sits in the office.
##
## The view is one small SubViewport whose camera copies the turret's camera
## mount; it renders only while the PC is in sight, at 20 frames a second.
##
## Dependencies: HouseTurret, Yard, TurretConsole, WorldScreen, PointerButton, RayMath, Audio autoload
class_name SecurityPc
extends Node3D

## The turret goggles next to the monitor were picked up: put the player
## into the turret shown on screen (the FrontGarden's TurretSeat does it).
signal goggles_used(turret: HouseTurret)

## Camera view refreshes per second while the PC is in sight.
const FEED_UPDATES_PER_SECOND: float = 20.0

var _turrets: Array[HouseTurret] = []
var _seconds_until_feed_update: float = 0.0
var _yard: Yard = null
var _selected_index: int = 0
var _is_firing: bool = false
var _is_available: bool = false

@onready var _screen: WorldScreen = %PcScreen
@onready var _feed_viewport: SubViewport = %FeedViewport
@onready var _feed_camera: Camera3D = %FeedCamera
@onready var _goggles_button: PointerButton = %GogglesButton


func _ready() -> void:
	_feed_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


# The console shows the feed texture from another viewport: let go of it
# and stop rendering before both are freed (freeing a viewport whose texture
# is still shown elsewhere can crash the engine on shutdown).
func _exit_tree() -> void:
	_feed_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var console: TurretConsole = get_console()
	if console != null:
		console.set_feed(null)


## Called by the FrontGarden at setup with every turret mount on the house.
func setup(turrets: Array[HouseTurret], yard: Yard) -> void:
	_turrets = turrets.duplicate()
	_yard = yard
	var console: TurretConsole = get_console()
	console.set_feed(_feed_viewport.get_texture())
	console.aim_moved.connect(_on_aim_moved)
	console.fire_pressed.connect(func() -> void: _is_firing = true)
	console.fire_released.connect(func() -> void: _is_firing = false)
	console.turret_step_requested.connect(select_next_turret)
	console.control_toggled.connect(toggle_control)
	_goggles_button.pressed.connect(func(_button: PointerButton) -> void: use_goggles())
	_refresh_console()


## Adds a turret to look through and take over (a tower built in the field).
func add_turret(turret: HouseTurret) -> void:
	if not _turrets.has(turret):
		_turrets.append(turret)
	_refresh_console()


## Every turret it can show (roof turrets and field towers, mounted or not).
func get_turrets() -> Array[HouseTurret]:
	return _turrets


## Puts the goggles on: asks to seat the player in the turret on screen.
func use_goggles() -> void:
	var turret: HouseTurret = get_selected_turret()
	if not _is_available or turret == null:
		Audio.play_ui(Audio.UI_ERROR)
		return
	release_control()
	goggles_used.emit(turret)


## The goggles' hot spot (tests).
func get_goggles_button() -> PointerButton:
	return _goggles_button


## Shown once the Security PC upgrade is bought.
func set_available(is_available: bool) -> void:
	_is_available = is_available
	visible = is_available
	_screen.set_active(is_available)
	if not is_available:
		release_control()


func is_available() -> bool:
	return _is_available


func get_console() -> TurretConsole:
	return _screen.content as TurretConsole


func get_screen() -> WorldScreen:
	return _screen


## The turret on screen, or null when none is mounted.
func get_selected_turret() -> HouseTurret:
	var mounted: Array[HouseTurret] = _get_mounted()
	if mounted.is_empty():
		return null
	_selected_index = posmod(_selected_index, mounted.size())
	return mounted[_selected_index]


## Shows the next (+1) or previous (-1) mounted turret; hands the one in use back.
func select_next_turret(step: int) -> void:
	release_control()
	_selected_index += step
	Audio.play_ui(Audio.UI_CLICK)
	_refresh_console()


## Takes the shown turret over, or gives it back.
func toggle_control() -> void:
	var turret: HouseTurret = get_selected_turret()
	if turret == null:
		Audio.play_ui(Audio.UI_ERROR)
		return
	turret.set_manual(not turret.is_manual)
	_is_firing = false
	Audio.play_ui(Audio.UI_CONFIRM)
	_refresh_console()


## Every turret aims on its own again.
func release_control() -> void:
	for turret: HouseTurret in _turrets:
		if turret.is_manual:
			turret.set_manual(false)
	_is_firing = false
	_refresh_console()


## Aims the shown, taken-over turret at the point under [param view_uv] of
## the camera view (tests and the console).
func aim_at_view(view_uv: Vector2) -> void:
	var turret: HouseTurret = get_selected_turret()
	if turret == null or not turret.is_manual:
		return
	var pixel: Vector2 = view_uv * Vector2(_feed_viewport.size)
	var origin: Vector3 = _feed_camera.project_ray_origin(pixel)
	var direction: Vector3 = _feed_camera.project_ray_normal(pixel)
	var distance: float = _yard.get_ground_distance(origin, direction) if _yard != null else RayMath.NO_HIT
	if distance == RayMath.NO_HIT or distance > turret.range_meters:
		distance = turret.range_meters
	turret.set_manual_aim(origin + direction * distance)


## Per frame while the shift runs (FrontGarden): the camera follows the
## turret, a held trigger keeps firing. The view is a second render of the
## scene, so it updates only while someone looks at the PC, and then only
## FEED_UPDATES_PER_SECOND times a second.
func step(delta: float) -> void:
	var turret: HouseTurret = get_selected_turret()
	if turret == null:
		return
	if _is_available and _screen.is_rendering():
		_seconds_until_feed_update -= delta
		if _seconds_until_feed_update <= 0.0:
			_seconds_until_feed_update = 1.0 / FEED_UPDATES_PER_SECOND
			_feed_camera.global_transform = turret.get_camera_mount().global_transform
			_feed_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _is_firing and turret.is_manual:
		turret.fire()


func _on_aim_moved(view_uv: Vector2) -> void:
	aim_at_view(view_uv)


func _get_mounted() -> Array[HouseTurret]:
	var mounted: Array[HouseTurret] = []
	for turret: HouseTurret in _turrets:
		if turret.is_mounted():
			mounted.append(turret)
	return mounted


func _refresh_console() -> void:
	if _screen == null or get_console() == null:
		return
	var mounted: Array[HouseTurret] = _get_mounted()
	var turret: HouseTurret = get_selected_turret()
	get_console().show_turret(_selected_index + 1, mounted.size(), turret != null and turret.is_manual)
