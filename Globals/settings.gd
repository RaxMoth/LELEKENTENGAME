## Player preferences (audio, controller haptics, language, ...). Stored
## separately from the savegame in user://settings.cfg so "reset progress"
## keeps preferences. There is deliberately no frame-rate cap or screen shake:
## the headset paces the frames, and camera motion the player does not cause
## is uncomfortable in VR.
##
## Add your own setting: put a KEY_ constant + default into DEFAULTS, then use
## Settings.get_value / set_value. Changes are applied immediately, persisted
## and broadcast through Events.setting_changed.
##
## Desktop builds start full screen (KEY_FULLSCREEN, F11 toggles it).
##
## Dependencies: Events, Platform, Types autoloads
extends Node

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "settings"

const KEY_MASTER_VOLUME: StringName = &"master_volume"
const KEY_MUSIC_VOLUME: StringName = &"music_volume"
const KEY_SFX_VOLUME: StringName = &"sfx_volume"
const KEY_HAPTICS_ENABLED: StringName = &"haptics_enabled"
const KEY_SHOW_FPS: StringName = &"show_fps"
## Comfort: continuous turning instead of 30° snaps.
const KEY_SMOOTH_TURNING: StringName = &"smooth_turning"
## Comfort: a player whose head is lower than standing height (seated) is
## lifted to it, so the house is reachable from a chair.
const KEY_STANDING_VIEW: StringName = &"standing_view"
## Development: debug builds ignore the savegame at launch and start fresh
## (release builds always load it). Toggle it off to test saving.
const KEY_FRESH_START_IN_DEV: StringName = &"fresh_start_in_dev"
## Empty string = follow the device language.
const KEY_LOCALE: StringName = &"locale"
## Desktop: the game fills the screen (F11 switches); off: a window.
const KEY_FULLSCREEN: StringName = &"fullscreen"
## Command-line user argument that keeps the window windowed (screenshots).
const ARGUMENT_WINDOWED: String = "windowed=1"

const DEFAULTS: Dictionary[StringName, Variant] = {
	KEY_MASTER_VOLUME: 1.0,
	KEY_MUSIC_VOLUME: 0.7,
	KEY_SFX_VOLUME: 0.9,
	KEY_HAPTICS_ENABLED: true,
	KEY_SHOW_FPS: false,
	KEY_SMOOTH_TURNING: false,
	KEY_STANDING_VIEW: true,
	KEY_FRESH_START_IN_DEV: true,
	KEY_LOCALE: "",
	KEY_FULLSCREEN: true,
}

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"

const SUPPORTED_LOCALES: PackedStringArray = ["en", "de"]

var _values: Dictionary[StringName, Variant] = {}


func _ready() -> void:
	_values = DEFAULTS.duplicate()
	_load()
	for setting_key: StringName in _values:
		_apply(setting_key, _values[setting_key])


func get_value(setting_key: StringName) -> Variant:
	return _values.get(setting_key, DEFAULTS.get(setting_key))


## True when this launch should ignore the savegame (debug build with the
## development fresh-start toggle on).
func starts_fresh() -> bool:
	return OS.is_debug_build() and get_bool(KEY_FRESH_START_IN_DEV)


func get_bool(setting_key: StringName) -> bool:
	return bool(get_value(setting_key))


func get_float(setting_key: StringName) -> float:
	return float(get_value(setting_key))


func set_value(setting_key: StringName, value: Variant) -> void:
	if _values.get(setting_key) == value:
		return
	_values[setting_key] = value
	_apply(setting_key, value)
	_save()
	Events.setting_changed.emit(setting_key, value)


func reset_to_defaults() -> void:
	for setting_key: StringName in DEFAULTS:
		set_value(setting_key, DEFAULTS[setting_key])

# ============================================
# APPLY
# ============================================

func _apply(setting_key: StringName, value: Variant) -> void:
	match setting_key:
		KEY_MASTER_VOLUME:
			_set_bus_volume(BUS_MASTER, float(value))
		KEY_MUSIC_VOLUME:
			_set_bus_volume(BUS_MUSIC, float(value))
		KEY_SFX_VOLUME:
			_set_bus_volume(BUS_SFX, float(value))
		KEY_LOCALE:
			var locale_code: String = str(value)
			if locale_code.is_empty():
				locale_code = OS.get_locale_language()
			TranslationServer.set_locale(locale_code if locale_code in SUPPORTED_LOCALES else "en")
		KEY_FULLSCREEN:
			_apply_window_mode(bool(value))


## True on a desktop with a real window (not a phone, not inside a running
## headset session, not a headless test run, not a screenshot run that asked
## for a window).
func has_desktop_window() -> bool:
	return DisplayServer.get_name() != "headless" and not OS.has_feature("mobile") \
		and not Platform.is_xr_active() and not ARGUMENT_WINDOWED in OS.get_cmdline_user_args()


func _apply_window_mode(is_fullscreen: bool) -> void:
	if not has_desktop_window():
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if is_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Types.ACTION_TOGGLE_FULLSCREEN) and has_desktop_window():
		set_value(KEY_FULLSCREEN, not get_bool(KEY_FULLSCREEN))
		get_viewport().set_input_as_handled()


func _set_bus_volume(bus_name: StringName, linear_volume: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, linear_volume <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(linear_volume, 0.0001)))

# ============================================
# PERSISTENCE
# ============================================

func _load() -> void:
	var config_file: ConfigFile = ConfigFile.new()
	if config_file.load(SETTINGS_PATH) != OK:
		return
	for setting_key: StringName in DEFAULTS:
		var stored_value: Variant = config_file.get_value(SECTION, setting_key, DEFAULTS[setting_key])
		# Guard against hand-edited files storing the wrong type.
		if typeof(stored_value) == typeof(DEFAULTS[setting_key]):
			_values[setting_key] = stored_value


func _save() -> void:
	var config_file: ConfigFile = ConfigFile.new()
	for setting_key: StringName in _values:
		config_file.set_value(SECTION, setting_key, _values[setting_key])
	var error: Error = config_file.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Settings: could not save (%s)" % error_string(error))
