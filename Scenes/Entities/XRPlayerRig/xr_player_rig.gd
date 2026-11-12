## The player in a 3D / XR scene: headset camera, two tracked controllers
## with pointers, and an in-world screen for popups. Without a headset it
## falls back to a flat-screen simulator (mouse / touch look and a cursor
## ray), so the same scene runs on a desktop or phone for development.
##
##   rig.primary_action_pressed.connect(_on_plant)      # dominant trigger / tap
##   rig.secondary_action_pressed.connect(_on_shoot)    # off-hand trigger / right click
##   var pointer: XRPointer = rig.get_tool_pointer()
##
## XR: OpenXR must be enabled in Project Settings (see Docs/VR.md). Triggers
## click WorldScreens first; only presses that miss every screen reach the
## game. The project uses the "Local Floor" reference space, so the player
## stands on this node and the runtime handles recentering.
## Flat: drag to look, tap / click to act, right click for the off-hand.
##
## Dependencies: XRPointer, WorldScreen, Events, UI, Platform, Settings, Types autoloads
class_name XRPlayerRig
extends XROrigin3D

## Dominant-hand trigger (XR) or a tap / left click (flat) that hit no screen.
signal primary_action_pressed(pointer: XRPointer)
## Off-hand trigger (XR) or a right click (flat) that hit no screen.
signal secondary_action_pressed(pointer: XRPointer)
## Menu or B / Y button.
signal menu_pressed
## Thumbstick flicked, or trackpad clicked, left (-1) or right (+1).
signal selection_step_requested(step: int)

## Command line user argument that forces the in-world popup screen without a
## headset: `godot -- world_ui=1`.
const ARGUMENT_WORLD_UI: String = "world_ui=1"
const STICK_FLICK_THRESHOLD: float = 0.6
const STICK_RELEASE_THRESHOLD: float = 0.3
## A trackpad click this far from the middle counts as left / right.
const TRACKPAD_SIDE_THRESHOLD: float = 0.35
const HAPTIC_SECONDS: float = 0.06

## Hand that points at UI and places things; the other hand is the off-hand.
@export var dominant_hand: Types.Hand = Types.Hand.RIGHT
## Show popups on the in-world screen even without a headset (tests the XR UI path).
@export var force_world_space_ui: bool = false

@export_group("XR")
## Size of the desktop window while a PC headset is active. The window
## mirrors the headset view, which the template's portrait phone window
## would squeeze into a narrow strip.
@export var spectator_window_size: Vector2i = Vector2i(1280, 720)

@export_group("Flat simulator")
@export var flat_eye_height: float = 1.7
@export var flat_pitch_degrees: float = -18.0
## Vertical field of view for wide and tall windows.
@export var flat_fov_landscape: float = 70.0
@export var flat_fov_portrait: float = 92.0
## Degrees of rotation per dragged pixel.
@export var look_sensitivity: float = 0.18
@export var look_yaw_limit_degrees: float = 80.0
@export var look_pitch_limits_degrees: Vector2 = Vector2(-80.0, 35.0)
## A press that moves further than this is a look-drag, not a tap.
@export var drag_threshold_pixels: float = 16.0

## True when a headset is driving the camera; false in the flat simulator.
var is_xr_active: bool = false

var _xr_interface: XRInterface = null
var _uses_world_space_ui: bool = false
var _default_physics_ticks: int = 60
var _stick_is_flicked: Dictionary[Types.Hand, bool] = {Types.Hand.LEFT: false, Types.Hand.RIGHT: false}
var _flat_yaw_degrees: float = 0.0
var _flat_pitch_degrees: float = 0.0
var _flat_cursor: Vector2 = Vector2.ZERO
var _flat_press_position: Vector2 = Vector2.ZERO
var _flat_is_pressed: bool = false
var _flat_is_dragging: bool = false
var _flat_press_on_screen: bool = false

@onready var _xr_camera: XRCamera3D = %XRCamera
@onready var _left_hand: XRController3D = %LeftHand
@onready var _right_hand: XRController3D = %RightHand
@onready var _left_pointer: XRPointer = %LeftPointer
@onready var _right_pointer: XRPointer = %RightPointer
@onready var _flat_camera: Camera3D = %FlatCamera
@onready var _flat_pointer: XRPointer = %FlatPointer
@onready var _popup_screen: WorldScreen = %PopupScreen


func _ready() -> void:
	# Pointers and the popup screen must keep working while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_default_physics_ticks = Engine.physics_ticks_per_second
	_xr_interface = XRServer.find_interface(Types.XR_INTERFACE_OPENXR)
	is_xr_active = _xr_interface != null and _xr_interface.is_initialized()
	if is_xr_active:
		_enter_xr_mode()
	else:
		_enter_flat_mode()
	_popup_screen.set_active(false)
	set_world_space_ui(is_xr_active or force_world_space_ui or ARGUMENT_WORLD_UI in OS.get_cmdline_user_args())


func _exit_tree() -> void:
	Engine.physics_ticks_per_second = _default_physics_ticks
	if _xr_interface != null and _xr_interface.session_begun.is_connected(_on_xr_session_begun):
		_xr_interface.session_begun.disconnect(_on_xr_session_begun)
		_xr_interface.session_visible.disconnect(_on_xr_session_visible)
		_xr_interface.session_focussed.disconnect(_on_xr_session_focussed)
	# With a headset the UI stays in the world; a flat window gets its overlay back.
	if _uses_world_space_ui and not is_xr_active:
		UI.set_world_space_enabled(false)


func _process(_delta: float) -> void:
	if _uses_world_space_ui:
		_popup_screen.set_active(UI.has_visible_content())


func _unhandled_input(event: InputEvent) -> void:
	if is_xr_active:
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		_on_flat_motion(motion)
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null:
		return
	if button.button_index == MOUSE_BUTTON_LEFT:
		set_flat_cursor(button.position)
		if button.pressed:
			_flat_press()
		else:
			_flat_release()
	elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		set_flat_cursor(button.position)
		if not _flat_pointer.is_over_screen():
			secondary_action_pressed.emit(_flat_pointer)

# ============================================
# PUBLIC API
# ============================================

## Shows popups, toasts and loading on the in-world screen in front of the
## player instead of the window overlay. Always on inside a headset.
func set_world_space_ui(is_enabled: bool) -> void:
	_uses_world_space_ui = is_enabled or is_xr_active
	UI.set_world_space_enabled(_uses_world_space_ui)
	if _uses_world_space_ui:
		_popup_screen.attach_viewport(UI.get_world_viewport())
	else:
		_popup_screen.set_active(false)


## Pointer that selects UI and places things (dominant hand, or the cursor ray).
func get_tool_pointer() -> XRPointer:
	if not is_xr_active:
		return _flat_pointer
	return _get_pointer(dominant_hand)


## Pointer of the other hand (the same cursor ray in the flat simulator).
func get_offhand_pointer() -> XRPointer:
	if not is_xr_active:
		return _flat_pointer
	return _get_pointer(Types.Hand.LEFT if dominant_hand == Types.Hand.RIGHT else Types.Hand.RIGHT)


## Every pointer that is live in the current mode.
func get_active_pointers() -> Array[XRPointer]:
	if not is_xr_active:
		return [_flat_pointer]
	return [_left_pointer, _right_pointer]


## Head (camera) transform in world space.
func get_head_transform() -> Transform3D:
	return _xr_camera.global_transform if is_xr_active else _flat_camera.global_transform


## Short controller rumble (phone vibration in the flat simulator). Honors the haptics setting.
func pulse(pointer: XRPointer, strength: Types.HapticStrength = Types.HapticStrength.LIGHT) -> void:
	if not Settings.get_bool(Settings.KEY_HAPTICS_ENABLED):
		return
	var controller: XRController3D = pointer.get_parent() as XRController3D
	if controller == null:
		Platform.vibrate(strength)
		return
	var amplitude: float = 0.3
	match strength:
		Types.HapticStrength.MEDIUM:
			amplitude = 0.6
		Types.HapticStrength.HEAVY:
			amplitude = 1.0
	controller.trigger_haptic_pulse(Types.XR_ACTION_HAPTIC, 0.0, amplitude, HAPTIC_SECONDS, 0.0)


## Flat simulator: aims the cursor ray through a viewport position.
func set_flat_cursor(viewport_position: Vector2) -> void:
	_flat_cursor = viewport_position
	_flat_pointer.set_ray(_flat_camera.project_ray_origin(viewport_position), _flat_camera.project_ray_normal(viewport_position))


## Flat simulator: aims at a world position and taps it, exactly like a click
## there would (used by automated tests and tutorials).
func tap_world_point(world_point: Vector3) -> void:
	set_flat_cursor(_flat_camera.unproject_position(world_point))
	_flat_press()
	_flat_release()

# ============================================
# XR MODE
# ============================================

func _enter_xr_mode() -> void:
	# The headset paces the frames; the window's vsync would only slow it down.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_viewport().use_xr = true
	var window: Window = get_window()
	if Platform.is_desktop() and window.mode == Window.MODE_WINDOWED and window.size != spectator_window_size:
		window.size = spectator_window_size
		window.move_to_center()
	_xr_camera.current = true
	_flat_camera.current = false
	_flat_pointer.is_enabled = false
	_xr_interface.session_begun.connect(_on_xr_session_begun)
	_xr_interface.session_visible.connect(_on_xr_session_visible)
	_xr_interface.session_focussed.connect(_on_xr_session_focussed)
	_match_physics_to_display()


func _get_pointer(hand: Types.Hand) -> XRPointer:
	return _left_pointer if hand == Types.Hand.LEFT else _right_pointer


func _get_controller(hand: Types.Hand) -> XRController3D:
	return _left_hand if hand == Types.Hand.LEFT else _right_hand


## Physics drives gameplay movement, so it must tick as often as the headset
## refreshes or everything would stutter.
func _match_physics_to_display() -> void:
	var openxr_interface: OpenXRInterface = _xr_interface as OpenXRInterface
	if openxr_interface == null:
		return
	var refresh_rate: float = openxr_interface.get_display_refresh_rate()
	if refresh_rate > 0.0:
		Engine.physics_ticks_per_second = roundi(refresh_rate)


func _handle_controller_button(hand: Types.Hand, action_name: StringName, is_pressed: bool) -> void:
	var pointer: XRPointer = _get_pointer(hand)
	match action_name:
		Types.XR_ACTION_TRIGGER_CLICK:
			if not is_pressed:
				pointer.release()
			elif not pointer.press():
				if hand == dominant_hand:
					primary_action_pressed.emit(pointer)
				else:
					secondary_action_pressed.emit(pointer)
		Types.XR_ACTION_MENU_BUTTON, Types.XR_ACTION_SECONDARY_BUTTON:
			if is_pressed:
				menu_pressed.emit()
		Types.XR_ACTION_TRACKPAD_CLICK:
			if is_pressed:
				_handle_trackpad_click(_get_controller(hand).get_vector2(Types.XR_ACTION_TRACKPAD))


## Trackpads step the selection on a click, not on touch like sticks do: Vive
## players rest their thumb on the pad, which must not change the seed.
func _handle_trackpad_click(pad_position: Vector2) -> void:
	if absf(pad_position.x) >= TRACKPAD_SIDE_THRESHOLD:
		selection_step_requested.emit(1 if pad_position.x > 0.0 else -1)


func _handle_thumbstick(hand: Types.Hand, action_name: StringName, value: Vector2) -> void:
	if action_name != Types.XR_ACTION_THUMBSTICK:
		return
	if not _stick_is_flicked[hand] and absf(value.x) >= STICK_FLICK_THRESHOLD:
		_stick_is_flicked[hand] = true
		selection_step_requested.emit(1 if value.x > 0.0 else -1)
	elif _stick_is_flicked[hand] and absf(value.x) <= STICK_RELEASE_THRESHOLD:
		_stick_is_flicked[hand] = false


func _on_left_hand_button_pressed(action_name: String) -> void:
	_handle_controller_button(Types.Hand.LEFT, StringName(action_name), true)


func _on_left_hand_button_released(action_name: String) -> void:
	_handle_controller_button(Types.Hand.LEFT, StringName(action_name), false)


func _on_right_hand_button_pressed(action_name: String) -> void:
	_handle_controller_button(Types.Hand.RIGHT, StringName(action_name), true)


func _on_right_hand_button_released(action_name: String) -> void:
	_handle_controller_button(Types.Hand.RIGHT, StringName(action_name), false)


func _on_left_hand_input_vector2_changed(action_name: String, value: Vector2) -> void:
	_handle_thumbstick(Types.Hand.LEFT, StringName(action_name), value)


func _on_right_hand_input_vector2_changed(action_name: String, value: Vector2) -> void:
	_handle_thumbstick(Types.Hand.RIGHT, StringName(action_name), value)


func _on_xr_session_begun() -> void:
	_match_physics_to_display()


## Headset taken off or system menu opened: treat it like the app going to the background.
func _on_xr_session_visible() -> void:
	Events.app_paused.emit()


func _on_xr_session_focussed() -> void:
	Events.app_resumed.emit()

# ============================================
# FLAT SIMULATOR
# ============================================

func _enter_flat_mode() -> void:
	_xr_camera.current = false
	_left_hand.visible = false
	_right_hand.visible = false
	_left_pointer.is_enabled = false
	_right_pointer.is_enabled = false
	_flat_camera.position = Vector3(0.0, flat_eye_height, 0.0)
	_flat_pitch_degrees = flat_pitch_degrees
	_flat_camera.current = true
	_apply_flat_look()
	_apply_flat_fov()
	get_viewport().size_changed.connect(_apply_flat_fov)
	set_flat_cursor(get_viewport().get_visible_rect().size * 0.5)


func _apply_flat_look() -> void:
	_flat_camera.rotation_degrees = Vector3(_flat_pitch_degrees, _flat_yaw_degrees, 0.0)


func _apply_flat_fov() -> void:
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	_flat_camera.fov = flat_fov_portrait if view_size.y > view_size.x else flat_fov_landscape


func _on_flat_motion(motion: InputEventMouseMotion) -> void:
	if _flat_is_pressed and not _flat_press_on_screen:
		if not _flat_is_dragging and motion.position.distance_to(_flat_press_position) > drag_threshold_pixels:
			_flat_is_dragging = true
		if _flat_is_dragging:
			_flat_yaw_degrees = clampf(_flat_yaw_degrees - motion.relative.x * look_sensitivity, -look_yaw_limit_degrees, look_yaw_limit_degrees)
			_flat_pitch_degrees = clampf(_flat_pitch_degrees - motion.relative.y * look_sensitivity, look_pitch_limits_degrees.x, look_pitch_limits_degrees.y)
			_apply_flat_look()
	set_flat_cursor(motion.position)


func _flat_press() -> void:
	_flat_is_pressed = true
	_flat_is_dragging = false
	_flat_press_position = _flat_cursor
	_flat_press_on_screen = _flat_pointer.press()


## A press that did not turn into a look-drag acts on release, like a tap.
func _flat_release() -> void:
	if not _flat_is_pressed:
		return
	_flat_is_pressed = false
	if _flat_press_on_screen:
		_flat_pointer.release()
	elif not _flat_is_dragging:
		primary_action_pressed.emit(_flat_pointer)
	_flat_is_dragging = false
