## The player: headset camera, two tracked controllers with pointers, hands
## that grab, locomotion and an in-world screen for popups. Without a
## headset it falls back to a flat-screen simulator (mouse / touch look,
## WASD walking, a cursor ray), so the same level runs on a desktop for
## development and tests.
##
##   rig.primary_action_pressed.connect(_on_use)        # dominant trigger / click on nothing interactive
##   rig.secondary_action_pressed.connect(_on_shoot)    # off-hand trigger / right click
##   rig.walkable_area = %WalkableArea
##
## Interaction order for a trigger press or click: a WorldScreen, then a
## PointerButton, then (flat only) an item to grab or a socket to fill, then
## the game. Grip grabs the item at the hand or under its ray; letting go
## near an ItemSocket that takes it puts it there.
##
## XR: OpenXR must be enabled in Project Settings (see Docs/GAME.md). The
## project uses the "Local Floor" reference space, so the player stands on
## this node and the runtime handles recentering.
##
## Dependencies: XRPointer, XRLocomotion, WorldScreen, Grabbable, ItemSocket,
##               PointerButton, InteractionQuery, Events, UI, Platform,
##               Settings, Types autoloads
class_name XRPlayerRig
extends XROrigin3D

## Dominant trigger (XR) or a click (flat) that hit nothing interactive.
signal primary_action_pressed(pointer: XRPointer)
## Off-hand trigger (XR) or a right click (flat) that hit no screen or button.
signal secondary_action_pressed(pointer: XRPointer)
## Menu or B / Y button.
signal menu_pressed
signal item_grabbed(item: Grabbable)
signal item_placed(item: Grabbable, socket: ItemSocket)

## Command line user argument that forces the in-world popup screen without a
## headset: `godot -- world_ui=1`.
const ARGUMENT_WORLD_UI: String = "world_ui=1"
const HAPTIC_SECONDS: float = 0.06
## A hand grabs things this close to its grip point (meters).
const HAND_GRAB_REACH: float = 0.12
## Pointer grabs and button presses reach this far.
const POINTER_REACH: float = 4.5
## Where the popup screen appears: this far ahead of the head and this much lower.
const POPUP_DISTANCE: float = 1.9
const POPUP_DROP: float = 0.15

## Hand that points at UI and uses things; the other hand is the off-hand.
@export var dominant_hand: Types.Hand = Types.Hand.RIGHT
## Show popups on the in-world screen even without a headset (tests the XR UI path).
@export var force_world_space_ui: bool = false

@export_group("XR")
## Size of the desktop window while a PC headset is active. The window
## mirrors the headset view, which the menus' portrait window would squeeze
## into a narrow strip.
@export var spectator_window_size: Vector2i = Vector2i(1280, 720)

@export_group("Flat simulator")
@export var flat_eye_height: float = 1.7
@export var flat_pitch_degrees: float = -12.0
## Vertical field of view for wide and tall windows.
@export var flat_fov_landscape: float = 70.0
@export var flat_fov_portrait: float = 92.0
## Degrees of rotation per dragged pixel.
@export var look_sensitivity: float = 0.18
@export var look_pitch_limits_degrees: Vector2 = Vector2(-80.0, 60.0)
## A press that moves further than this is a look-drag, not a click.
@export var drag_threshold_pixels: float = 16.0
## The wrist panel's stand-in sits this far from the lower-left window corner.
@export var flat_wrist_margin_pixels: float = 24.0
## Half the size of the wrist panel (meters), to keep it inside the corner.
@export var flat_wrist_half_size: Vector2 = Vector2(0.085, 0.05)

## True when a headset is driving the camera; false in the flat simulator.
var is_xr_active: bool = false
## Where the player may stand (set by the level).
var walkable_area: WalkableArea:
	get:
		return locomotion.walkable_area
	set(value):
		locomotion.walkable_area = value

var _xr_interface: XRInterface = null
var _uses_world_space_ui: bool = false
var _is_popup_shown: bool = false
var _default_physics_ticks: int = 60
var _held_items: Dictionary[Types.Hand, Grabbable] = {Types.Hand.LEFT: null, Types.Hand.RIGHT: null}
var _flat_held_item: Grabbable = null
var _highlighted_sockets: Array[ItemSocket] = []
var _flat_yaw_degrees: float = 0.0
var _flat_pitch_degrees: float = 0.0
var _flat_cursor: Vector2 = Vector2.ZERO
var _flat_press_position: Vector2 = Vector2.ZERO
var _flat_is_pressed: bool = false
var _flat_is_dragging: bool = false
var _flat_press_on_screen: bool = false

@onready var locomotion: XRLocomotion = %Locomotion
@onready var _xr_camera: XRCamera3D = %XRCamera
@onready var _left_hand: XRController3D = %LeftHand
@onready var _right_hand: XRController3D = %RightHand
@onready var _left_pointer: XRPointer = %LeftPointer
@onready var _right_pointer: XRPointer = %RightPointer
@onready var _left_hold_anchor: Node3D = %LeftHoldAnchor
@onready var _right_hold_anchor: Node3D = %RightHoldAnchor
@onready var _left_wrist_anchor: Node3D = %LeftWristAnchor
@onready var _right_wrist_anchor: Node3D = %RightWristAnchor
@onready var _flat_camera: Camera3D = %FlatCamera
@onready var _flat_pointer: XRPointer = %FlatPointer
@onready var _flat_hold_anchor: Node3D = %FlatHoldAnchor
@onready var _flat_wrist_anchor: Node3D = %FlatWristAnchor
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
		var should_show_popup: bool = UI.has_visible_content()
		if should_show_popup and not _is_popup_shown:
			_place_popup_in_view()
		_is_popup_shown = should_show_popup
		_popup_screen.set_active(should_show_popup)
	if get_tree().paused:
		return
	for pointer: XRPointer in get_active_pointers():
		pointer.set_interaction_hit_distance(InteractionQuery.get_hover_distance(get_tree(), pointer.ray_origin, pointer.ray_direction, POINTER_REACH))
	_update_socket_highlights()


func _physics_process(delta: float) -> void:
	if not get_tree().paused:
		locomotion.step(delta)


func _unhandled_input(event: InputEvent) -> void:
	if is_xr_active:
		return
	var travel_actions: Array[StringName] = [Types.ACTION_TRAVEL_1, Types.ACTION_TRAVEL_2, Types.ACTION_TRAVEL_3, Types.ACTION_TRAVEL_4]
	for spot_index: int in travel_actions.size():
		if event.is_action_pressed(travel_actions[spot_index]):
			locomotion.travel_to_spot(spot_index)
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


## Pointer that selects UI and uses things (dominant hand, or the cursor ray).
func get_tool_pointer() -> XRPointer:
	if not is_xr_active:
		return _flat_pointer
	return _get_pointer(dominant_hand)


## Pointer of the other hand (the same cursor ray in the flat simulator).
func get_offhand_pointer() -> XRPointer:
	if not is_xr_active:
		return _flat_pointer
	return _get_pointer(_get_offhand())


## Every pointer that is live in the current mode.
func get_active_pointers() -> Array[XRPointer]:
	if not is_xr_active:
		return [_flat_pointer]
	return [_left_pointer, _right_pointer]


## Head (camera) transform in world space.
func get_head_transform() -> Transform3D:
	return _xr_camera.global_transform if is_xr_active else _flat_camera.global_transform


## Point on the floor under the player's head.
func get_feet_position() -> Vector3:
	var head: Vector3 = get_head_transform().origin
	return Vector3(head.x, global_position.y, head.z)


## Where a wrist display belongs: above the off-hand in a headset, the lower
## left of the view in the flat simulator.
func get_wrist_anchor() -> Node3D:
	if not is_xr_active:
		return _flat_wrist_anchor
	return _left_wrist_anchor if _get_offhand() == Types.Hand.LEFT else _right_wrist_anchor


## Items currently held (by either hand or the flat cursor).
func get_held_items() -> Array[Grabbable]:
	var held: Array[Grabbable] = []
	for item: Grabbable in [_held_items[Types.Hand.LEFT], _held_items[Types.Hand.RIGHT], _flat_held_item]:
		if item != null:
			held.append(item)
	return held


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


## Moves the play space (and the player with it).
func move_origin_by(offset: Vector3) -> void:
	global_position += offset


## Turns the player around their head by [param radians] (positive = left).
func turn_around_head(radians: float) -> void:
	if not is_xr_active:
		_flat_yaw_degrees += rad_to_deg(radians)
		_apply_flat_look()
		return
	var pivot: Vector3 = get_feet_position()
	var rotation_around_pivot: Transform3D = Transform3D(Basis.IDENTITY, pivot) * Transform3D(Basis(Vector3.UP, radians), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot)
	global_transform = rotation_around_pivot * global_transform


## Turns the view to world yaw [param yaw] (radians, 0 = looking toward -Z).
func face_yaw(yaw: float) -> void:
	var forward: Vector3 = -get_head_transform().basis.z
	turn_around_head(wrapf(yaw - atan2(-forward.x, -forward.z), -PI, PI))


## Flat simulator: aims the cursor ray through a viewport position.
func set_flat_cursor(viewport_position: Vector2) -> void:
	_flat_cursor = viewport_position
	_flat_pointer.set_ray(_flat_camera.project_ray_origin(viewport_position), _flat_camera.project_ray_normal(viewport_position))


## Flat simulator: aims at a world position and clicks it, exactly like a
## click there would (used by automated tests and tutorials).
func tap_world_point(world_point: Vector3) -> void:
	aim_at_world_point(world_point)
	_flat_press()
	_flat_release()


## Flat simulator: turns the view toward a world position and points the
## cursor ray at it, like a player looking at something before clicking.
func aim_at_world_point(world_point: Vector3) -> void:
	var to_point: Vector3 = world_point - _flat_camera.global_position
	_flat_yaw_degrees = rad_to_deg(atan2(-to_point.x, -to_point.z))
	var horizontal_distance: float = Vector2(to_point.x, to_point.z).length()
	_flat_pitch_degrees = clampf(rad_to_deg(atan2(to_point.y, horizontal_distance)), look_pitch_limits_degrees.x, look_pitch_limits_degrees.y)
	_apply_flat_look()
	set_flat_cursor(_flat_camera.unproject_position(world_point))

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


func _get_hold_anchor(hand: Types.Hand) -> Node3D:
	return _left_hold_anchor if hand == Types.Hand.LEFT else _right_hold_anchor


func _get_offhand() -> Types.Hand:
	return Types.Hand.LEFT if dominant_hand == Types.Hand.RIGHT else Types.Hand.RIGHT


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
			elif not pointer.press() and not _press_button_on_ray(pointer):
				if hand == dominant_hand:
					primary_action_pressed.emit(pointer)
				else:
					secondary_action_pressed.emit(pointer)
		Types.XR_ACTION_GRIP_CLICK:
			if is_pressed:
				_grab_with_hand(hand)
			else:
				_release_hand(hand)
		Types.XR_ACTION_MENU_BUTTON, Types.XR_ACTION_SECONDARY_BUTTON:
			if is_pressed:
				menu_pressed.emit()
		Types.XR_ACTION_TRACKPAD_CLICK:
			if is_pressed:
				locomotion.handle_trackpad_click(_get_controller(hand).get_vector2(Types.XR_ACTION_TRACKPAD), pointer)


func _grab_with_hand(hand: Types.Hand) -> void:
	if _held_items[hand] != null or get_tree().paused:
		return
	var anchor: Node3D = _get_hold_anchor(hand)
	var pointer: XRPointer = _get_pointer(hand)
	var target: Node3D = InteractionQuery.find_grab_target_near(get_tree(), anchor.global_position, HAND_GRAB_REACH)
	if target == null:
		target = InteractionQuery.find_grab_target_on_ray(get_tree(), pointer.ray_origin, pointer.ray_direction, POINTER_REACH)
	var item: Grabbable = InteractionQuery.take_from(target)
	if item == null:
		return
	item.attach_to(anchor)
	_held_items[hand] = item
	pulse(pointer, Types.HapticStrength.LIGHT)
	item_grabbed.emit(item)


func _release_hand(hand: Types.Hand) -> void:
	var item: Grabbable = _held_items[hand]
	if item == null:
		return
	_held_items[hand] = null
	var socket: ItemSocket = InteractionQuery.find_socket_near(get_tree(), item, item.global_position)
	if socket != null:
		_place(item, socket)
		pulse(_get_pointer(hand), Types.HapticStrength.MEDIUM)
	else:
		item.drop_nowhere()


## Puts the popup screen straight ahead of where the player looks right now.
func _place_popup_in_view() -> void:
	var head: Transform3D = get_head_transform()
	var forward: Vector3 = Vector3(-head.basis.z.x, 0.0, -head.basis.z.z)
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var screen_position: Vector3 = head.origin + forward * POPUP_DISTANCE + Vector3(0.0, -POPUP_DROP, 0.0)
	_popup_screen.global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), screen_position)


func _place(item: Grabbable, socket: ItemSocket) -> void:
	item.detach()
	socket.insert(item)
	item_placed.emit(item, socket)


func _press_button_on_ray(pointer: XRPointer) -> bool:
	var button: PointerButton = InteractionQuery.find_button_on_ray(get_tree(), pointer.ray_origin, pointer.ray_direction, POINTER_REACH)
	if button == null:
		return false
	if button.press():
		pulse(pointer, Types.HapticStrength.LIGHT)
	return true


## Lights up the sockets each held item could go into right now.
func _update_socket_highlights() -> void:
	_forget_lost_items()
	var wanted: Array[ItemSocket] = []
	for hand: Types.Hand in _held_items:
		var item: Grabbable = _held_items[hand]
		if item != null:
			var socket: ItemSocket = InteractionQuery.find_socket_near(get_tree(), item, item.global_position)
			if socket != null:
				wanted.append(socket)
	if _flat_held_item != null:
		var flat_socket: ItemSocket = InteractionQuery.find_socket_on_ray(get_tree(), _flat_held_item, _flat_pointer.ray_origin, _flat_pointer.ray_direction, POINTER_REACH)
		if flat_socket != null:
			wanted.append(flat_socket)
	for socket: ItemSocket in _highlighted_sockets:
		if is_instance_valid(socket) and not wanted.has(socket):
			socket.set_highlighted(false)
	for socket: ItemSocket in wanted:
		socket.set_highlighted(true)
	_highlighted_sockets = wanted


## A held item that was pooled or freed elsewhere is no longer in a hand.
func _forget_lost_items() -> void:
	for hand: Types.Hand in _held_items:
		var item: Grabbable = _held_items[hand]
		if item != null and (not is_instance_valid(item) or Pools.is_in_pool(item) or item.holder == null):
			_held_items[hand] = null
	if _flat_held_item != null and (not is_instance_valid(_flat_held_item) or Pools.is_in_pool(_flat_held_item) or _flat_held_item.holder == null):
		_flat_held_item = null


func _handle_thumbstick(hand: Types.Hand, action_name: StringName, value: Vector2) -> void:
	if action_name == Types.XR_ACTION_THUMBSTICK:
		locomotion.handle_stick(hand, value, _get_pointer(hand))


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
	_flat_pointer.set_ray(_flat_camera.project_ray_origin(_flat_cursor), _flat_camera.project_ray_normal(_flat_cursor))


func _apply_flat_fov() -> void:
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	_flat_camera.fov = flat_fov_portrait if view_size.y > view_size.x else flat_fov_landscape
	_place_flat_wrist_anchor()


## Pins the flat wrist panel to the lower-left corner of the window at its depth.
func _place_flat_wrist_anchor() -> void:
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var depth: float = -_flat_wrist_anchor.position.z
	var corner_pixel: Vector2 = Vector2(flat_wrist_margin_pixels, view_size.y - flat_wrist_margin_pixels)
	var corner: Vector3 = _flat_camera.to_local(_flat_camera.project_position(corner_pixel, depth))
	_flat_wrist_anchor.position = Vector3(corner.x + flat_wrist_half_size.x, corner.y + flat_wrist_half_size.y, -depth)


func _on_flat_motion(motion: InputEventMouseMotion) -> void:
	if _flat_is_pressed and not _flat_press_on_screen:
		if not _flat_is_dragging and motion.position.distance_to(_flat_press_position) > drag_threshold_pixels:
			_flat_is_dragging = true
		if _flat_is_dragging:
			_flat_yaw_degrees = wrapf(_flat_yaw_degrees - motion.relative.x * look_sensitivity, -180.0, 180.0)
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
		_flat_click()
	_flat_is_dragging = false


## One click of the flat cursor: put down what it holds, press a button,
## pick something up, or hand the click to the game.
func _flat_click() -> void:
	var origin: Vector3 = _flat_pointer.ray_origin
	var direction: Vector3 = _flat_pointer.ray_direction
	if _flat_held_item != null:
		var item: Grabbable = _flat_held_item
		_flat_held_item = null
		var socket: ItemSocket = InteractionQuery.find_socket_on_ray(get_tree(), item, origin, direction, POINTER_REACH)
		if socket != null:
			_place(item, socket)
		else:
			item.drop_nowhere()
		return
	if _press_button_on_ray(_flat_pointer):
		return
	var item_to_take: Grabbable = InteractionQuery.take_from(InteractionQuery.find_grab_target_on_ray(get_tree(), origin, direction, POINTER_REACH))
	if item_to_take != null:
		item_to_take.attach_to(_flat_hold_anchor)
		_flat_held_item = item_to_take
		item_grabbed.emit(item_to_take)
		return
	primary_action_pressed.emit(_flat_pointer)
