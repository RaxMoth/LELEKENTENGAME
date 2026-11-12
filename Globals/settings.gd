## Player preferences (audio, haptics, language, ...). Stored separately from
## the savegame in user://settings.cfg so "reset progress" keeps preferences.
##
## Add your own setting: put a KEY_ constant + default into DEFAULTS, then use
## Settings.get_value / set_value. Changes are applied immediately, persisted
## and broadcast through Events.setting_changed.
##
## Dependencies: Events autoload
extends Node

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "settings"

const KEY_MASTER_VOLUME: StringName = &"master_volume"
const KEY_MUSIC_VOLUME: StringName = &"music_volume"
const KEY_SFX_VOLUME: StringName = &"sfx_volume"
const KEY_HAPTICS_ENABLED: StringName = &"haptics_enabled"
const KEY_SCREEN_SHAKE_ENABLED: StringName = &"screen_shake_enabled"
const KEY_SHOW_FPS: StringName = &"show_fps"
const KEY_BATTERY_SAVER: StringName = &"battery_saver"
## Empty string = follow the device language.
const KEY_LOCALE: StringName = &"locale"

const DEFAULTS: Dictionary[StringName, Variant] = {
	KEY_MASTER_VOLUME: 1.0,
	KEY_MUSIC_VOLUME: 0.7,
	KEY_SFX_VOLUME: 0.9,
	KEY_HAPTICS_ENABLED: true,
	KEY_SCREEN_SHAKE_ENABLED: true,
	KEY_SHOW_FPS: false,
	KEY_BATTERY_SAVER: false,
	KEY_LOCALE: "",
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
		KEY_BATTERY_SAVER:
			# 30 FPS halves GPU work on phones; 0 = uncapped (vsync limited).
			Engine.max_fps = 30 if bool(value) else 0
		KEY_LOCALE:
			var locale_code: String = str(value)
			if locale_code.is_empty():
				locale_code = OS.get_locale_language()
			TranslationServer.set_locale(locale_code if locale_code in SUPPORTED_LOCALES else "en")


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
