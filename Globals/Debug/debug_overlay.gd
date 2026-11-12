## Developer overlay (debug builds only — removes itself in release exports).
## Shows FPS / memory / node count and a cheat panel.
##
## Open: F3 on desktop, or tap the top-left screen corner 5 times on a phone.
## Add cheats: append to _build_cheats().
##
## Dependencies: Profile, Settings, SceneManager, Pools autoloads
extends CanvasLayer

const CORNER_TAP_SIZE: float = 90.0
const CORNER_TAPS_REQUIRED: int = 5
const CORNER_TAP_WINDOW_MSEC: int = 2000

var _corner_tap_count: int = 0
var _first_corner_tap_msec: int = 0
var _stats_refresh_accumulator: float = 0.0

@onready var _stats_label: Label = %StatsLabel
@onready var _cheat_panel: PanelContainer = %CheatPanel
@onready var _cheat_list: VBoxContainer = %CheatList


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cheat_panel.hide()
	_build_cheats()
	_update_stats_visibility()
	Events.setting_changed.connect(func(_setting_key: StringName, _value: Variant) -> void: _update_stats_visibility())


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(Types.ACTION_DEBUG_TOGGLE):
		_toggle_panel()
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch == null or not touch.pressed or touch.position.x > CORNER_TAP_SIZE or touch.position.y > CORNER_TAP_SIZE:
		return
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _first_corner_tap_msec > CORNER_TAP_WINDOW_MSEC:
		_first_corner_tap_msec = now_msec
		_corner_tap_count = 0
	_corner_tap_count += 1
	if _corner_tap_count >= CORNER_TAPS_REQUIRED:
		_corner_tap_count = 0
		_toggle_panel()


func _process(delta: float) -> void:
	if not _stats_label.visible:
		return
	_stats_refresh_accumulator += delta
	if _stats_refresh_accumulator < 0.25:
		return
	_stats_refresh_accumulator = 0.0
	_stats_label.text = "FPS %d | %.1f MB | nodes %d | pooled %d" % [
		Engine.get_frames_per_second(),
		OS.get_static_memory_usage() / 1048576.0,
		get_tree().get_node_count(),
		Pools.get_idle_count(),
	]


func _toggle_panel() -> void:
	_cheat_panel.visible = not _cheat_panel.visible
	_update_stats_visibility()


func _update_stats_visibility() -> void:
	_stats_label.visible = _cheat_panel.visible or Settings.get_bool(Settings.KEY_SHOW_FPS)


func _build_cheats() -> void:
	_add_cheat("+1000 coins", func() -> void: Profile.wallet.add(Types.CURRENCY_COINS, 1000))
	_add_cheat("+100 gems", func() -> void: Profile.wallet.add(Types.CURRENCY_GEMS, 100))
	_add_cheat("Unlock all levels", func() -> void: Profile.levels.unlock_all_for_debug())
	_add_cheat("Refill energy", func() -> void: Profile.energy.refill())
	_add_cheat("Win level", func() -> void: _call_on_level(&"win"))
	_add_cheat("Lose level", func() -> void: _call_on_level(&"lose"))
	_add_cheat("Time scale x1 / x3", func() -> void: Engine.time_scale = 3.0 if Engine.time_scale < 2.0 else 1.0)
	_add_cheat("Reset daily reward", func() -> void: Profile.daily_rewards.last_claim_day = -1)
	_add_cheat("Reset progress", func() -> void:
		Profile.reset_progress()
		SceneManager.go_to_main_menu())
	_add_cheat("Close", _toggle_panel)


func _add_cheat(label_text: String, action: Callable) -> void:
	var cheat_button: Button = Button.new()
	cheat_button.text = label_text
	cheat_button.theme_type_variation = &"SecondaryButton"
	cheat_button.add_theme_font_size_override("font_size", 24)
	cheat_button.pressed.connect(action)
	_cheat_list.add_child(cheat_button)


func _call_on_level(method_name: StringName) -> void:
	var active_scene: Node = get_tree().current_scene
	if active_scene is LevelBase:
		active_scene.call(method_name)
