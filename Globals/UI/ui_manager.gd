## Global overlay for popups, toasts and the loading spinner. Lives above every
## scene (CanvasLayer 50) and keeps running while the game is paused.
## Also adds press feedback (scale, click sound, haptic) to every Button in the
## project automatically — set meta "no_juice" on a button to opt out.
##
##   var result: Variant = await UI.open_popup(MY_POPUP, {"title": "Hi"}).closed
##   if await UI.confirm("Quit?", ""): ...
##   UI.toast("Saved!")
##
## 3D / XR scenes can not show a screen-space overlay inside the headset, so
## set_world_space_enabled(true) moves popups, toasts and the loading overlay
## into an off-screen viewport that a WorldScreen displays in the world.
##
## Dependencies: Audio, Events, Platform, Types autoloads
extends CanvasLayer

const CONFIRM_POPUP: PackedScene = preload("res://Scenes/UI/Popups/ConfirmPopup/ConfirmPopup.tscn")
const META_NO_JUICE: StringName = &"no_juice"
const TOAST_SECONDS: float = 2.2
## Resolution of the world-space viewport: the portrait size popups are designed for.
const WORLD_VIEWPORT_SIZE: Vector2i = Vector2i(720, 1280)

var _popup_stack: Array[BasePopup] = []
var _world_viewport: SubViewport = null

@onready var _popup_layer: Control = %PopupLayer
@onready var _toast_container: VBoxContainer = %ToastContainer
@onready var _loading_overlay: Control = %LoadingOverlay
@onready var _loading_label: Label = %LoadingLabel
@onready var _loading_spinner: Control = %LoadingSpinner


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_loading_overlay.hide()
	get_tree().node_added.connect(_on_node_added)
	Events.achievement_unlocked.connect(func(achievement: AchievementData) -> void:
		toast("%s: %s" % [tr("Achievement unlocked"), achievement.title]))


func _process(delta: float) -> void:
	if _loading_overlay.visible:
		_loading_spinner.rotation += TAU * delta
	if is_world_space_enabled():
		# An empty overlay costs nothing: only render while something is on it.
		var update_mode: SubViewport.UpdateMode = SubViewport.UPDATE_ALWAYS if has_visible_content() else SubViewport.UPDATE_DISABLED
		if _world_viewport.render_target_update_mode != update_mode:
			_world_viewport.render_target_update_mode = update_mode

# ============================================
# POPUPS
# ============================================

## Opens a popup scene whose root extends BasePopup. Await `.closed` for its result.
func open_popup(popup_scene: PackedScene, popup_data: Dictionary = {}) -> BasePopup:
	var popup: BasePopup = popup_scene.instantiate() as BasePopup
	_popup_layer.add_child(popup)
	_popup_stack.append(popup)
	popup.closed.connect(func(_result: Variant) -> void: _popup_stack.erase(popup), CONNECT_ONE_SHOT)
	popup.open(popup_data)
	return popup


## Yes/no dialog. Pass an empty [param cancel_text] for a single-button message.
func confirm(title: String, message: String, confirm_text: String = "Yes", cancel_text: String = "No") -> bool:
	var popup: BasePopup = open_popup(CONFIRM_POPUP, {
		"title": title,
		"message": message,
		"confirm_text": confirm_text,
		"cancel_text": cancel_text,
	})
	var result: Variant = await popup.closed
	return result == true


func has_open_popup() -> bool:
	return not _popup_stack.is_empty()


## The popup on top (the one the player sees), or null.
func get_top_popup() -> BasePopup:
	return null if _popup_stack.is_empty() else _popup_stack.back()


## Back-button handling: closes the top-most popup. Returns false if none was open.
func close_top_popup() -> bool:
	for stack_index: int in range(_popup_stack.size() - 1, -1, -1):
		var popup: BasePopup = _popup_stack[stack_index]
		if is_instance_valid(popup) and not popup.is_closing():
			popup.handle_back()
			return true
	return false


func close_all_popups() -> void:
	for popup: BasePopup in _popup_stack.duplicate():
		if is_instance_valid(popup):
			popup.queue_free()
	_popup_stack.clear()

# ============================================
# WORLD-SPACE MODE (3D / XR)
# ============================================

## Shows popups, toasts and loading inside get_world_viewport() instead of on
## the window. The viewport lives in this autoload, so it survives scene changes.
func set_world_space_enabled(is_enabled: bool) -> void:
	if is_enabled == is_world_space_enabled():
		return
	if is_enabled and _world_viewport == null:
		_world_viewport = SubViewport.new()
		_world_viewport.name = "WorldViewport"
		_world_viewport.size = WORLD_VIEWPORT_SIZE
		_world_viewport.transparent_bg = true
		_world_viewport.disable_3d = true
		add_child(_world_viewport)
	var content_parent: Node = _world_viewport if is_enabled else self
	for content: Control in [_popup_layer, _toast_container, _loading_overlay]:
		content.reparent(content_parent, false)
	_world_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func is_world_space_enabled() -> bool:
	return _world_viewport != null and _popup_layer.get_parent() == _world_viewport


## Viewport that holds the UI while world-space mode is on (null before first use).
func get_world_viewport() -> SubViewport:
	return _world_viewport


## True while a popup, toast or the loading overlay is on screen.
func has_visible_content() -> bool:
	return has_open_popup() or _toast_container.get_child_count() > 0 or _loading_overlay.visible

# ============================================
# TOASTS & LOADING
# ============================================

func toast(message: String) -> void:
	var toast_panel: PanelContainer = PanelContainer.new()
	toast_panel.theme_type_variation = &"ToastPanel"
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var toast_label: Label = Label.new()
	toast_label.text = message
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.custom_minimum_size.x = 420
	toast_panel.add_child(toast_label)
	_toast_container.add_child(toast_panel)
	toast_panel.modulate.a = 0.0
	var tween: Tween = toast_panel.create_tween()
	tween.tween_property(toast_panel, "modulate:a", 1.0, 0.2)
	tween.tween_interval(TOAST_SECONDS)
	tween.tween_property(toast_panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(toast_panel.queue_free)


func show_loading(message: String = "") -> void:
	_loading_label.text = message
	_loading_label.visible = not message.is_empty()
	_loading_overlay.show()


func hide_loading() -> void:
	_loading_overlay.hide()

# ============================================
# BUTTON JUICE
# ============================================

func _on_node_added(node: Node) -> void:
	var button: BaseButton = node as BaseButton
	# A reparented button enters the tree again; it must not be wired twice.
	if button == null or button.has_meta(META_NO_JUICE) or button.pressed.is_connected(_on_any_button_pressed):
		return
	button.button_down.connect(_animate_button.bind(button, 0.93))
	button.button_up.connect(_animate_button.bind(button, 1.0))
	button.pressed.connect(_on_any_button_pressed)


func _animate_button(button: BaseButton, target_scale: float) -> void:
	button.pivot_offset = button.size * 0.5
	var tween: Tween = button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * target_scale, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_any_button_pressed() -> void:
	Audio.play_ui(Audio.UI_CLICK)
	Platform.vibrate(Types.HapticStrength.LIGHT)
