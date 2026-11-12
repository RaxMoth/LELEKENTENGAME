## Session bookkeeping and free-form flags (tutorial seen, rated app, ...).
##
## Dependencies: Global autoload
class_name ProfileMeta
extends ProfileModule

var first_launch_unix: int = 0
var last_seen_unix: int = 0
var session_count: int = 0
var total_play_seconds: float = 0.0
## Seconds the player was away since the previous session (computed on load).
var offline_seconds: int = 0
var flags: Dictionary[StringName, int] = {}


func get_save_key() -> StringName:
	return &"meta"


func to_dict() -> Dictionary:
	last_seen_unix = Global.unix_now()
	return {
		"first_launch_unix": first_launch_unix,
		"last_seen_unix": last_seen_unix,
		"session_count": session_count,
		"total_play_seconds": total_play_seconds,
		"flags": flags,
	}


func from_dict(data: Dictionary) -> void:
	first_launch_unix = int(data.get("first_launch_unix", Global.unix_now()))
	last_seen_unix = int(data.get("last_seen_unix", 0))
	session_count = int(data.get("session_count", 0))
	total_play_seconds = float(data.get("total_play_seconds", 0.0))
	flags = to_int_dictionary(data.get("flags", {}))


func reset() -> void:
	first_launch_unix = Global.unix_now()
	last_seen_unix = 0
	session_count = 0
	total_play_seconds = 0.0
	offline_seconds = 0
	flags = {}


## Called once by Profile after loading.
func begin_session() -> void:
	var now_unix: int = Global.unix_now()
	offline_seconds = maxi(0, now_unix - last_seen_unix) if last_seen_unix > 0 else 0
	session_count += 1
	last_seen_unix = now_unix
	mark_dirty()


func is_first_session() -> bool:
	return session_count <= 1


func has_flag(flag_id: StringName) -> bool:
	return flags.get(flag_id, 0) != 0


func set_flag(flag_id: StringName, enabled: bool = true) -> void:
	flags[flag_id] = 1 if enabled else 0
	mark_dirty()
