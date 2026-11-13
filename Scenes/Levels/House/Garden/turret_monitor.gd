## One big screen of the office's monitor wall (the Monitor Wall upgrade):
## the live view of one turret — roof turret or field tower — with the same
## controls as the Security PC: switch turrets, take one over, point at the
## view to aim, pull the trigger to fire (held, it keeps firing). Its own
## small camera renders only while the wall is in sight, a few times a second.
##
##   monitor.setup(security_pc, yard, start_index)
##
## Dependencies: SecurityPc, HouseTurret, Yard, TurretConsole, WorldScreen,
##               RayMath, Audio autoload
class_name TurretMonitor
extends Node3D

## Camera view refreshes per second while the wall is in sight.
const FEED_UPDATES_PER_SECOND: float = 6.0

var _pc: SecurityPc = null
var _yard: Yard = null
var _selected_index: int = 0
var _is_firing: bool = false
var _seconds_until_feed_update: float = 0.0
## The turret this screen took over (null when it only watches).
var _controlled: HouseTurret = null

@onready var _screen: WorldScreen = %MonitorScreen
@onready var _feed_viewport: SubViewport = %FeedViewport
@onready var _feed_camera: Camera3D = %FeedCamera


func _ready() -> void:
	_feed_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


# The console shows this screen's camera texture from another viewport:
# let go of it and stop rendering before both are freed (freeing a viewport
# whose texture is still shown elsewhere can crash the engine on shutdown).
func _exit_tree() -> void:
	_feed_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var console: TurretConsole = get_console()
	if console != null:
		console.set_feed(null)


## Watches the turrets [param security_pc] knows, starting at the
## [param start_index]-th mounted one.
func setup(security_pc: SecurityPc, yard: Yard, start_index: int) -> void:
	_pc = security_pc
	_yard = yard
	_selected_index = start_index
	# Screens take turns rendering instead of all on the same frame.
	_seconds_until_feed_update = float(start_index) / (FEED_UPDATES_PER_SECOND * 4.0)
	var console: TurretConsole = get_console()
	console.set_feed(_feed_viewport.get_texture())
	console.aim_moved.connect(aim_at_view)
	console.fire_pressed.connect(func() -> void: _is_firing = true)
	console.fire_released.connect(func() -> void: _is_firing = false)
	console.turret_step_requested.connect(select_next_turret)
	console.control_toggled.connect(toggle_control)
	_refresh_console()


func get_console() -> TurretConsole:
	return _screen.content as TurretConsole


func get_screen() -> WorldScreen:
	return _screen


## The turret on this screen, or null when none is mounted.
func get_selected_turret() -> HouseTurret:
	var mounted: Array[HouseTurret] = _get_mounted()
	if mounted.is_empty():
		return null
	_selected_index = posmod(_selected_index, mounted.size())
	return mounted[_selected_index]


## The next (+1) or previous (-1) turret; a turret taken over is handed back.
func select_next_turret(step: int) -> void:
	release_control()
	_selected_index += step
	Audio.play_ui(Audio.UI_CLICK)
	_refresh_console()


## Takes the shown turret over, or hands it back. A turret someone else
## (the PC, another screen) is steering can't be taken.
func toggle_control() -> void:
	var turret: HouseTurret = get_selected_turret()
	if turret == null or (turret.is_manual and turret != _controlled):
		Audio.play_ui(Audio.UI_ERROR)
		return
	var was_controlled: bool = _controlled == turret
	release_control()
	if not was_controlled:
		turret.set_manual(true)
		_controlled = turret
	Audio.play_ui(Audio.UI_CONFIRM)
	_refresh_console()


## Hands the turret this screen took over back to its own aim.
func release_control() -> void:
	if _controlled != null and is_instance_valid(_controlled):
		_controlled.set_manual(false)
	_controlled = null
	_is_firing = false
	_refresh_console()


## Aims the taken-over turret at the point under [param view_uv] of the view.
func aim_at_view(view_uv: Vector2) -> void:
	if _controlled == null or _controlled != get_selected_turret():
		return
	var pixel: Vector2 = view_uv * Vector2(_feed_viewport.size)
	var origin: Vector3 = _feed_camera.project_ray_origin(pixel)
	var direction: Vector3 = _feed_camera.project_ray_normal(pixel)
	var distance: float = _yard.get_ground_distance(origin, direction) if _yard != null else RayMath.NO_HIT
	if distance == RayMath.NO_HIT or distance > _controlled.range_meters:
		distance = _controlled.range_meters
	_controlled.set_manual_aim(origin + direction * distance)


## Per frame while the wall works: the camera follows the turret, a held trigger fires.
func step(delta: float) -> void:
	if _controlled != null and (not is_instance_valid(_controlled) or not _controlled.is_mounted()):
		release_control()
	var turret: HouseTurret = get_selected_turret()
	if turret == null:
		return
	if _screen.is_rendering():
		_seconds_until_feed_update -= delta
		if _seconds_until_feed_update <= 0.0:
			_seconds_until_feed_update = 1.0 / FEED_UPDATES_PER_SECOND
			_feed_camera.global_transform = turret.get_camera_mount().global_transform
			_feed_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _is_firing and _controlled == turret:
		turret.fire()


func _get_mounted() -> Array[HouseTurret]:
	var mounted: Array[HouseTurret] = []
	if _pc == null:
		return mounted
	for turret: HouseTurret in _pc.get_turrets():
		if is_instance_valid(turret) and turret.is_mounted():
			mounted.append(turret)
	return mounted


func _refresh_console() -> void:
	if _screen == null or get_console() == null:
		return
	var mounted: Array[HouseTurret] = _get_mounted()
	get_console().show_turret(_selected_index + 1 if not mounted.is_empty() else 0, mounted.size(), _controlled != null)
