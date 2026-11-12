## Versioned, crash-safe JSON savegame built from independent "sections".
##
## Any system can persist itself by registering two callables:
##   SaveManager.register_section(&"my_system", _to_dict, _from_dict)
## Saving writes to a temp file, keeps the previous save as a backup and then
## swaps files, so a crash mid-write never destroys progress. Saves are
## debounced (request_save) and forced when the app goes to the background.
##
## Dependencies: Events autoload
extends Node

signal saved
signal loaded

const SAVE_PATH: String = "user://savegame.json"
const BACKUP_PATH: String = "user://savegame.backup.json"
const TEMP_PATH: String = "user://savegame.tmp"
## Bump when the save layout changes and handle the old layout in _migrate().
const SAVE_VERSION: int = 1
const DEBOUNCE_SECONDS: float = 1.0
const KEY_VERSION: String = "version"
const KEY_SAVED_AT: String = "saved_at"
const KEY_SECTIONS: String = "sections"

var _save_callables: Dictionary[StringName, Callable] = {}
var _load_callables: Dictionary[StringName, Callable] = {}
var _loaded_sections: Dictionary = {}
var _debounce_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_debounce_timer = Timer.new()
	_debounce_timer.one_shot = true
	_debounce_timer.wait_time = DEBOUNCE_SECONDS
	_debounce_timer.timeout.connect(save_now)
	add_child(_debounce_timer)
	Events.app_paused.connect(save_now)
	_read_from_disk()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()


## Registers a persistent section. If data for it was already loaded from disk
## it is handed to [param from_dict] immediately.
func register_section(section_key: StringName, to_dict: Callable, from_dict: Callable) -> void:
	_save_callables[section_key] = to_dict
	_load_callables[section_key] = from_dict
	var section_data: Variant = _loaded_sections.get(String(section_key))
	if section_data is Dictionary:
		from_dict.call(section_data)


func unregister_section(section_key: StringName) -> void:
	_save_callables.erase(section_key)
	_load_callables.erase(section_key)


## Schedules a save shortly after the last change (cheap to call often).
func request_save() -> void:
	_debounce_timer.start()


func save_now() -> bool:
	_debounce_timer.stop()
	var sections: Dictionary = _loaded_sections.duplicate()
	for section_key: StringName in _save_callables:
		sections[String(section_key)] = _save_callables[section_key].call()
	var payload: Dictionary = {
		KEY_VERSION: SAVE_VERSION,
		KEY_SAVED_AT: int(Time.get_unix_time_from_system()),
		KEY_SECTIONS: sections,
	}
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write save (%s)" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(BACKUP_PATH)
		DirAccess.rename_absolute(SAVE_PATH, BACKUP_PATH)
	DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	_loaded_sections = sections
	saved.emit()
	return true


## Wipes every section back to defaults (used by "Reset progress").
func delete_save() -> void:
	_debounce_timer.stop()
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.remove_absolute(BACKUP_PATH)
	_loaded_sections = {}
	Events.progress_reset.emit()
	save_now()


func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _read_from_disk() -> void:
	var payload: Dictionary = _read_json(SAVE_PATH)
	if payload.is_empty() and FileAccess.file_exists(BACKUP_PATH):
		push_warning("SaveManager: main save unreadable, restoring backup.")
		payload = _read_json(BACKUP_PATH)
	if payload.is_empty():
		return
	payload = _migrate(payload)
	var sections: Variant = payload.get(KEY_SECTIONS, {})
	_loaded_sections = sections if sections is Dictionary else {}
	loaded.emit()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## Upgrades old save layouts to SAVE_VERSION. Add a branch per version bump.
func _migrate(payload: Dictionary) -> Dictionary:
	var file_version: int = int(payload.get(KEY_VERSION, 1))
	if file_version > SAVE_VERSION:
		push_warning("SaveManager: save is from a newer game version (%d)." % file_version)
	# Example for the future:
	# if file_version < 2:
	#     payload[KEY_SECTIONS]["wallet"]["gems"] = 0
	payload[KEY_VERSION] = SAVE_VERSION
	return payload
