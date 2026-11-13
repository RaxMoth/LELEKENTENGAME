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
## Interaction order for the dominant trigger or a click: a WorldScreen,
## then (holding something) putting it into the socket next to it or under
## the beam, then a PointerButton, then picking up the item (or a new one
## from a crate) at the hand or under the beam, then the game. So a VR hand
## works like the flat cursor: point and pull to pick up, point and pull to
## put in. The off-hand trigger only clicks screens and buttons or fires.
## Grip grabs with either hand; let go after holding it to put the item
## down, or click it quickly to keep holding until the next grip click.
## A level may claim a grip press first (grip_filter: drawing a weapon from
## a holster). In a headset the hands are gloves whose fingers follow the
## grip and trigger (GloveHand), and a body stands under the player and
## walks with them (WalkingBody: look down to see your legs).
##
## XR: OpenXR must be enabled in Project Settings (see Docs/GAME.md). The
## project uses the "Local Floor" reference space, so the player stands on
## this node and the runtime handles recentering.
##
## Dependencies: XRPointer, XRLocomotion, WorldScreen, Grabbable, ItemSocket,
##               PointerButton, InteractionQuery, GloveHand, WalkingBody,
##               Events, UI, Platform, Settings, Types autoloads
class_name XRPlayerRig
extends XROrigin3D

## Dominant trigger (XR) or a click (flat) that hit nothing interactive.
signal primary_action_pressed(pointer: XRPointer)
## Off-hand trigger (XR) or a right click (flat) that hit no screen or button.
signal secondary_action_pressed(pointer: XRPointer)
## The dominant trigger (XR) or the left mouse button (flat) was let go
## (held actions: a turret's trigger).
signal primary_action_released(pointer: XRPointer)
## The off-hand trigger (XR) or the right mouse button (flat) was let go
## (automatic guns stop firing).
signal secondary_action_released(pointer: XRPointer)
## Menu or B / Y button.
signal menu_pressed
signal item_grabbed(item: Grabbable)
signal item_placed(item: Grabbable, socket: ItemSocket)
## Co-op client: a trigger or grip press (or a flat click, as the dominant
## trigger) the host must carry out (see forwards_hand_input).
signal hand_input_forwarded(hand: Types.Hand, action_name: StringName, is_pressed: bool)

## Command line user argument that forces the in-world popup screen without a
## headset: `godot -- world_ui=1`.
const ARGUMENT_WORLD_UI: String = "world_ui=1"
## Pointer grabs and button presses reach this far.
const POINTER_REACH: float = HandInteractor.POINTER_REACH

## Hand that points at UI and uses things; the other hand is the off-hand.
@export var dominant_hand: Types.Hand = Types.Hand.RIGHT
## Show popups on the in-world screen even without a headset (tests the XR UI path).
@export var force_world_space_ui: bool = false

@export_group("Comfort")
## Where the popup screen appears: this far ahead of the head ...
@export_range(0.8, 4.0, 0.05) var popup_distance: float = 1.9
## ... and this much lower than the eyes.
@export_range(0.0, 1.0, 0.01) var popup_drop: float = 0.15
## Length of a controller rumble (seconds).
@export_range(0.01, 0.5, 0.01) var haptic_seconds: float = 0.06
## Shows the player's own body (torso and walking legs) in a headset.
@export var shows_body: bool = true

@export_group("XR")
## Size of the desktop window while a PC headset is active. The window
## mirrors the headset view, which the menus' portrait window would squeeze
## into a narrow strip.
@export var spectator_window_size: Vector2i = Vector2i(1280, 720)
## Eye height (meters above the floor) a seated player is lifted to while
## the "Standing View When Seated" comfort setting is on.
@export var standing_eye_height: float = 1.8

@export_group("Flat simulator")
## The most physics steps per second the flat simulator matches a fast
## monitor with (smooth walking on 120 / 144 Hz screens).
@export_range(60, 240) var max_flat_physics_ticks: int = 144
@export var flat_eye_height: float = 1.8
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
## Co-op client: trigger, grip and clicks don't act here but are emitted as
## hand_input_forwarded for the host (which owns the world). Screens and
## items are left alone locally; menus, walking and turning stay local.
var forwards_hand_input: bool = false
## Claims a grip press before the hands see it (a holster draw): called
## with (hand: Types.Hand, is_pressed: bool), returns true when it took it.
var grip_filter: Callable = Callable()
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
## The hands' rules (grab, put in, buttons); the flat cursor has its own below.
var _hands: HandInteractor = null
## Grip buttons held down right now, per hand (arm-swing walking).
var _grip_down: Dictionary[Types.Hand, bool] = {Types.Hand.LEFT: false, Types.Hand.RIGHT: false}
var _flat_held_item: Grabbable = null
## Meters the play space is raised for seated play (see StandingView).
var _standing_lift: float = 0.0
## Measure the head again once it is tracked (start, recenter, setting change).
var _needs_height_calibration: bool = false
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
@onready var _flat_weapon_anchor: Node3D = %FlatWeaponAnchor
@onready var _flat_wrist_anchor: Node3D = %FlatWristAnchor
@onready var _popup_screen: WorldScreen = %PopupScreen
@onready var _body: WalkingBody = %Body


func _ready() -> void:
	# Pointers and the popup screen must keep working while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hands = HandInteractor.new()
	_hands.name = "Hands"
	_hands.dominant_hand = dominant_hand
	add_child(_hands)
	_hands.setup({Types.Hand.LEFT: _left_hold_anchor, Types.Hand.RIGHT: _right_hold_anchor}, {Types.Hand.LEFT: _left_pointer, Types.Hand.RIGHT: _right_pointer})
	_hands.primary_action_pressed.connect(primary_action_pressed.emit)
	_hands.secondary_action_pressed.connect(secondary_action_pressed.emit)
	_hands.primary_action_released.connect(primary_action_released.emit)
	_hands.secondary_action_released.connect(secondary_action_released.emit)
	_hands.item_grabbed.connect(item_grabbed.emit)
	_hands.item_placed.connect(item_placed.emit)
	_hands.pulse_requested.connect(func(hand: Types.Hand, strength: Types.HapticStrength) -> void: pulse(_get_pointer(hand), strength))
	_default_physics_ticks = Engine.physics_ticks_per_second
	_xr_interface = XRServer.find_interface(Types.XR_INTERFACE_OPENXR)
	is_xr_active = _xr_interface != null and _xr_interface.is_initialized()
	if is_xr_active:
		_enter_xr_mode()
	else:
		_enter_flat_mode()
	_popup_screen.set_active(false)
	_body.visible = is_xr_active and shows_body
	# The hip holster (a knife) sits on the side of the hand that usually draws it.
	_body.set_hip_side(1.0 if dominant_hand == Types.Hand.RIGHT else -1.0)
	set_world_space_ui(is_xr_active or force_world_space_ui or ARGUMENT_WORLD_UI in OS.get_cmdline_user_args())


func _exit_tree() -> void:
	Engine.physics_ticks_per_second = _default_physics_ticks
	if _xr_interface != null and _xr_interface.session_begun.is_connected(_on_xr_session_begun):
		_xr_interface.session_begun.disconnect(_on_xr_session_begun)
		_xr_interface.session_visible.disconnect(_on_xr_session_visible)
		_xr_interface.session_focussed.disconnect(_on_xr_session_focussed)
		var openxr_interface: OpenXRInterface = _xr_interface as OpenXRInterface
		if openxr_interface != null and openxr_interface.pose_recentered.is_connected(_on_xr_pose_recentered):
			openxr_interface.pose_recentered.disconnect(_on_xr_pose_recentered)
		Events.setting_changed.disconnect(_on_setting_changed)
	# With a headset the UI stays in the world; a flat window gets its overlay back.
	if _uses_world_space_ui and not is_xr_active:
		UI.set_world_space_enabled(false)


func _process(delta: float) -> void:
	if _needs_height_calibration and _is_head_tracked():
		_calibrate_standing_view()
	_body.follow(get_head_transform(), get_feet_position().y, delta)
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
	elif button.button_index == MOUSE_BUTTON_RIGHT:
		set_flat_cursor(button.position)
		if forwards_hand_input:
			# A co-op guest's right mouse button is their gun trigger: the host
			# fires it (held, for automatic guns).
			var off_hand: Types.Hand = Types.Hand.LEFT if dominant_hand == Types.Hand.RIGHT else Types.Hand.RIGHT
			hand_input_forwarded.emit(off_hand, Types.XR_ACTION_TRIGGER_CLICK, button.pressed)
		elif not button.pressed:
			secondary_action_released.emit(_flat_pointer)
		elif not _flat_pointer.is_over_screen():
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


## The body standing under the player (also where holsters hang).
func get_body() -> WalkingBody:
	return _body


## Head (camera) transform in world space.
func get_head_transform() -> Transform3D:
	return _xr_camera.global_transform if is_xr_active else _flat_camera.global_transform


## Point on the floor under the player's head (a seated player's lift
## doesn't count: their feet are still on the level's floor).
func get_feet_position() -> Vector3:
	var head: Vector3 = get_head_transform().origin
	return Vector3(head.x, global_position.y - _standing_lift, head.z)


## Where a wrist display belongs: above the off-hand in a headset, the lower
## left of the view in the flat simulator.
func get_wrist_anchor() -> Node3D:
	if not is_xr_active:
		return _flat_wrist_anchor
	return _left_wrist_anchor if _get_offhand() == Types.Hand.LEFT else _right_wrist_anchor


## Where the gun in hand belongs: the off hand in a headset (the trigger
## that fires), the lower right of the view in the flat simulator.
func get_weapon_anchor() -> Node3D:
	if is_xr_active:
		return _get_hold_anchor(_get_offhand())
	return _flat_weapon_anchor


## True while [param hand]'s grip button is held down (arm-swing walking).
func is_grip_down(hand: Types.Hand) -> bool:
	return is_xr_active and _grip_down[hand]


## True while [param hand] holds nothing (no item, no drawn weapon).
func is_hand_empty(hand: Types.Hand) -> bool:
	return _hands.get_held_item(hand) == null and not _hands.is_hand_busy(hand)


## A controller's transform in the play space (relative to this origin, so
## walking or turning doesn't change it — only the hand moving does).
func get_hand_local_transform(hand: Types.Hand) -> Transform3D:
	return _get_controller(hand).transform


## The camera the player sees through (the headset's, or the flat one).
func get_view_camera() -> Camera3D:
	return _xr_camera if is_xr_active else _flat_camera


## True while the gun hand holds an item (the gun is put away meanwhile).
func is_weapon_hand_busy() -> bool:
	if is_xr_active:
		return _hands.get_held_item(_get_offhand()) != null
	return _flat_held_item != null or _hands.get_held_item(dominant_hand) != null


## The ray of a controller. It only follows a real hand inside a headset;
## tests aim it with XRPointer.set_ray().
func get_hand_pointer(hand: Types.Hand) -> XRPointer:
	return _get_pointer(hand)


## A controller button changed (wired from both XRController3Ds). Tests call
## it to drive the VR hand path without a headset.
func handle_controller_button(hand: Types.Hand, action_name: StringName, is_pressed: bool) -> void:
	match action_name:
		Types.XR_ACTION_TRIGGER_CLICK, Types.XR_ACTION_GRIP_CLICK:
			if action_name == Types.XR_ACTION_GRIP_CLICK:
				_grip_down[hand] = is_pressed
				if grip_filter.is_valid() and grip_filter.call(hand, is_pressed):
					return
			if forwards_hand_input:
				hand_input_forwarded.emit(hand, action_name, is_pressed)
			else:
				_hands.handle_button(hand, action_name, is_pressed)
		Types.XR_ACTION_MENU_BUTTON, Types.XR_ACTION_SECONDARY_BUTTON:
			if is_pressed:
				menu_pressed.emit()
		Types.XR_ACTION_TRACKPAD_CLICK:
			if is_pressed:
				locomotion.handle_trackpad_click(_get_controller(hand).get_vector2(Types.XR_ACTION_TRACKPAD), _get_pointer(hand))


## Items currently held (by either hand or the flat cursor).
func get_held_items() -> Array[Grabbable]:
	var held: Array[Grabbable] = _hands.get_held_items()
	if _flat_held_item != null:
		held.append(_flat_held_item)
	return held


## The hands' rules (co-op mirrors what the host says they hold).
func get_hands() -> HandInteractor:
	return _hands


## Where [param hand] holds things right now: its controller in a headset,
## in front of the camera in the flat simulator.
func get_hold_anchor(hand: Types.Hand) -> Node3D:
	if is_xr_active:
		return _get_hold_anchor(hand)
	return _flat_hold_anchor


## Everything the host needs to act for this hand (co-op): where it holds
## things and where its beam points — [hold transform, ray origin, ray direction].
func get_hand_pose(hand: Types.Hand) -> Array:
	var pointer: XRPointer = _get_pointer(hand) if is_xr_active else _flat_pointer
	return [get_hold_anchor(hand).global_transform, pointer.ray_origin, pointer.ray_direction]


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
	controller.trigger_haptic_pulse(Types.XR_ACTION_HAPTIC, 0.0, amplitude, haptic_seconds, 0.0)


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
	var openxr_interface: OpenXRInterface = _xr_interface as OpenXRInterface
	if openxr_interface != null:
		openxr_interface.pose_recentered.connect(_on_xr_pose_recentered)
	Events.setting_changed.connect(_on_setting_changed)
	_needs_height_calibration = true
	_match_physics_to_display()


func _is_head_tracked() -> bool:
	var head: XRPositionalTracker = XRServer.get_tracker(&"head") as XRPositionalTracker
	if head == null:
		return false
	var pose: XRPose = head.get_pose(&"default")
	return pose != null and pose.has_tracking_data


## Raises the play space so a seated player's eyes sit at standing height
## (or lowers it back when the setting is off or the player stands). It only
## runs when the session starts, on a recenter (the system jumps the view
## then anyway) or when the player flips the setting — never on its own.
func _calibrate_standing_view() -> void:
	_needs_height_calibration = false
	var lift: float = 0.0
	if Settings.get_bool(Settings.KEY_STANDING_VIEW):
		lift = StandingView.get_lift(_xr_camera.position.y, standing_eye_height)
	global_position.y += lift - _standing_lift
	_standing_lift = lift


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


## Flat screens too: walking moves the camera in physics steps, so they tick
## as often as the monitor refreshes (smooth on 120 / 144 Hz screens).
## Headless runs (no refresh rate) keep the project's rate.
func _match_physics_to_monitor() -> void:
	var refresh_rate: float = DisplayServer.screen_get_refresh_rate()
	if refresh_rate > 0.0:
		Engine.physics_ticks_per_second = clampi(roundi(refresh_rate), _default_physics_ticks, max_flat_physics_ticks)


## Puts the popup screen straight ahead of where the player looks right now.
func _place_popup_in_view() -> void:
	var head: Transform3D = get_head_transform()
	var forward: Vector3 = Vector3(-head.basis.z.x, 0.0, -head.basis.z.z)
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var screen_position: Vector3 = head.origin + forward * popup_distance + Vector3(0.0, -popup_drop, 0.0)
	_popup_screen.global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), screen_position)


func _place(item: Grabbable, socket: ItemSocket) -> void:
	item.detach()
	socket.insert(item)
	item_placed.emit(item, socket)


## Lights up the slot each held item would go into right now (blue), or
## the slot it is aimed at but doesn't fit (red).
func _update_socket_highlights() -> void:
	var wanted: Dictionary[ItemSocket, ItemSocket.Highlight] = {}
	_hands.collect_highlights(wanted)
	if _flat_held_item != null and (not is_instance_valid(_flat_held_item) or Pools.is_in_pool(_flat_held_item) or _flat_held_item.holder == null):
		_flat_held_item = null
	if _flat_held_item != null:
		var origin: Vector3 = _flat_pointer.ray_origin
		var direction: Vector3 = _flat_pointer.ray_direction
		var flat_socket: ItemSocket = InteractionQuery.find_socket_on_ray(get_tree(), _flat_held_item, origin, direction, POINTER_REACH)
		if flat_socket != null:
			wanted[flat_socket] = ItemSocket.Highlight.FITS
		else:
			var refusing_flat_socket: ItemSocket = InteractionQuery.find_refusing_socket_on_ray(get_tree(), _flat_held_item, origin, direction, POINTER_REACH)
			if refusing_flat_socket != null:
				wanted[refusing_flat_socket] = ItemSocket.Highlight.REFUSES
	for socket: ItemSocket in _highlighted_sockets:
		if is_instance_valid(socket) and not wanted.has(socket):
			socket.set_highlight(ItemSocket.Highlight.NONE)
	for socket: ItemSocket in wanted:
		socket.set_highlight(wanted[socket])
	_highlighted_sockets.assign(wanted.keys())


func _handle_thumbstick(hand: Types.Hand, action_name: StringName, value: Vector2) -> void:
	if action_name == Types.XR_ACTION_THUMBSTICK:
		locomotion.handle_stick(hand, value, _get_pointer(hand))


func _on_left_hand_button_pressed(action_name: String) -> void:
	handle_controller_button(Types.Hand.LEFT, StringName(action_name), true)


func _on_left_hand_button_released(action_name: String) -> void:
	handle_controller_button(Types.Hand.LEFT, StringName(action_name), false)


func _on_right_hand_button_pressed(action_name: String) -> void:
	handle_controller_button(Types.Hand.RIGHT, StringName(action_name), true)


func _on_right_hand_button_released(action_name: String) -> void:
	handle_controller_button(Types.Hand.RIGHT, StringName(action_name), false)


func _on_left_hand_input_vector2_changed(action_name: String, value: Vector2) -> void:
	_handle_thumbstick(Types.Hand.LEFT, StringName(action_name), value)


func _on_right_hand_input_vector2_changed(action_name: String, value: Vector2) -> void:
	_handle_thumbstick(Types.Hand.RIGHT, StringName(action_name), value)


func _on_xr_session_begun() -> void:
	_match_physics_to_display()


## Headset taken off or system menu opened: treat it like the app going to the background.
func _on_xr_session_visible() -> void:
	_forget_grip_state()
	Events.app_paused.emit()


func _on_xr_session_focussed() -> void:
	_forget_grip_state()
	Events.app_resumed.emit()


## Button releases are lost while the system has focus: don't wait for them.
func _forget_grip_state() -> void:
	_hands.forget_grip_state()


## The player held the system button to recenter: measure their height again
## (they may have sat down or stood up).
func _on_xr_pose_recentered() -> void:
	_needs_height_calibration = true


func _on_setting_changed(setting_key: StringName, _value: Variant) -> void:
	if setting_key == Settings.KEY_STANDING_VIEW:
		_needs_height_calibration = true

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
	_match_physics_to_monitor()


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
	# A co-op client's clicks (screens too) are carried out by the host.
	_flat_press_on_screen = false if forwards_hand_input else _flat_pointer.press()


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
	primary_action_released.emit(_flat_pointer)


## One click of the flat cursor: put down what it holds, press a button,
## pick something up, or hand the click to the game.
func _flat_click() -> void:
	if forwards_hand_input:
		hand_input_forwarded.emit(dominant_hand, Types.XR_ACTION_TRIGGER_CLICK, true)
		hand_input_forwarded.emit(dominant_hand, Types.XR_ACTION_TRIGGER_CLICK, false)
		return
	var origin: Vector3 = _flat_pointer.ray_origin
	var direction: Vector3 = _flat_pointer.ray_direction
	if _flat_held_item != null:
		var item: Grabbable = _flat_held_item
		_flat_held_item = null
		var socket: ItemSocket = InteractionQuery.find_socket_on_ray(get_tree(), item, origin, direction, POINTER_REACH)
		if socket != null:
			_place(item, socket)
			return
		if item.is_usable():
			# A usable item (the extinguisher) acts on the click and stays in hand;
			# clicking its place puts it back.
			_flat_held_item = item
			item.use_once(_flat_pointer)
			return
		var refusing_socket: ItemSocket = InteractionQuery.find_refusing_socket_on_ray(get_tree(), item, origin, direction, POINTER_REACH)
		if refusing_socket != null:
			refusing_socket.refuse(item)
		item.drop_nowhere()
		return
	if _hands.press_button_on_ray(_flat_pointer, dominant_hand):
		return
	var item_to_take: Grabbable = InteractionQuery.take_from(InteractionQuery.find_grab_target_on_ray(get_tree(), origin, direction, POINTER_REACH))
	if item_to_take != null:
		item_to_take.attach_to(_flat_hold_anchor)
		_flat_held_item = item_to_take
		item_grabbed.emit(item_to_take)
		return
	primary_action_pressed.emit(_flat_pointer)
