## Device & OS abstraction: platform detection, safe area (notches), haptics,
## app lifecycle (backgrounding) and the Android back button.
##
## Signals are forwarded to the Events bus so any system can react:
##   Events.app_paused / app_resumed — app sent to background / foreground
##   Events.back_requested — Android back button or desktop Esc
##   Events.safe_area_changed(safe_margins) — margins in viewport pixels
##
## Dependencies: Events, Settings, Types autoloads
extends Node

## Margins (left, top, right, bottom packed in a Rect2 as position=left/top, size=right/bottom)
## in viewport coordinates that UI must keep clear of notches and rounded corners.
var safe_margins: Rect2 = Rect2()

var _last_window_size: Vector2i = Vector2i.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_recalculate_safe_area)
	_recalculate_safe_area.call_deferred()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			Events.app_paused.emit()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			Events.app_resumed.emit()
			_recalculate_safe_area()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			Events.back_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	# Desktop/web stand-in for the Android back button.
	if not is_mobile() and event.is_action_pressed(&"ui_cancel"):
		Events.back_requested.emit()
		get_viewport().set_input_as_handled()

# ============================================
# PLATFORM DETECTION
# ============================================

func is_mobile() -> bool:
	return OS.has_feature("mobile")


func is_android() -> bool:
	return OS.has_feature("android")


func is_ios() -> bool:
	return OS.has_feature("ios")


func is_web() -> bool:
	return OS.has_feature("web")


func is_desktop() -> bool:
	return OS.has_feature("pc")


func is_debug_build() -> bool:
	return OS.is_debug_build()


## True on platforms where showing a "Quit" button makes sense (stores reject it on iOS).
func can_quit_app() -> bool:
	return is_desktop() or is_android()

# ============================================
# HAPTICS
# ============================================

## Short vibration honoring the user's haptics setting. No-op on desktop.
func vibrate(strength: Types.HapticStrength = Types.HapticStrength.LIGHT) -> void:
	if not is_mobile() or not Settings.get_bool(Settings.KEY_HAPTICS_ENABLED):
		return
	match strength:
		Types.HapticStrength.LIGHT:
			Input.vibrate_handheld(15, 0.3)
		Types.HapticStrength.MEDIUM:
			Input.vibrate_handheld(30, 0.6)
		Types.HapticStrength.HEAVY:
			Input.vibrate_handheld(60, 1.0)

# ============================================
# SAFE AREA
# ============================================

func _recalculate_safe_area() -> void:
	# Focus notifications can arrive before this autoload has entered the tree.
	if not is_inside_tree():
		return
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return
	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	if not is_mobile() or safe_rect.size.x <= 0:
		safe_rect = Rect2i(Vector2i.ZERO, window_size)
	# Convert from window pixels into viewport (stretched canvas) pixels.
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var window_to_viewport: Vector2 = viewport_size / Vector2(window_size)
	var left_margin: float = safe_rect.position.x * window_to_viewport.x
	var top_margin: float = safe_rect.position.y * window_to_viewport.y
	var right_margin: float = maxf(0.0, (window_size.x - safe_rect.end.x) * window_to_viewport.x)
	var bottom_margin: float = maxf(0.0, (window_size.y - safe_rect.end.y) * window_to_viewport.y)
	var new_margins: Rect2 = Rect2(left_margin, top_margin, right_margin, bottom_margin)
	if new_margins != safe_margins or window_size != _last_window_size:
		safe_margins = new_margins
		_last_window_size = window_size
		Events.safe_area_changed.emit(safe_margins)

# ============================================
# EXTERNAL LINKS
# ============================================

func open_store_page() -> void:
	var config: GameConfig = GameConfig.get_default()
	var store_url: String = config.ios_store_url if is_ios() else config.android_store_url
	if not store_url.is_empty():
		OS.shell_open(store_url)


func open_privacy_policy() -> void:
	var privacy_url: String = GameConfig.get_default().privacy_policy_url
	if not privacy_url.is_empty():
		OS.shell_open(privacy_url)
