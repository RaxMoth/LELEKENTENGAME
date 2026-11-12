## Regenerating energy / lives (casual "hearts" system). Regeneration is
## calculated from real time, so it keeps refilling while the app is closed.
## Disabled when GameConfig.max_energy is 0.
##
## Dependencies: Events, Global autoloads
class_name Energy
extends ProfileModule

var _stored_energy: int = 0
var _last_regen_unix: int = 0


func get_save_key() -> StringName:
	return &"energy"


func to_dict() -> Dictionary:
	_apply_regeneration()
	return {"energy": _stored_energy, "last_regen_unix": _last_regen_unix}


func from_dict(data: Dictionary) -> void:
	_stored_energy = int(data.get("energy", config.max_energy))
	_last_regen_unix = int(data.get("last_regen_unix", Global.unix_now()))


func reset() -> void:
	_stored_energy = config.max_energy
	_last_regen_unix = Global.unix_now()


func is_enabled() -> bool:
	return config.max_energy > 0


func get_current() -> int:
	_apply_regeneration()
	return _stored_energy


func get_max() -> int:
	return config.max_energy


func has_enough(amount: int) -> bool:
	return not is_enabled() or get_current() >= amount


func consume(amount: int) -> bool:
	if not is_enabled():
		return true
	if get_current() < amount:
		return false
	if _stored_energy >= config.max_energy:
		# Regeneration timer starts when energy drops below max.
		_last_regen_unix = Global.unix_now()
	_stored_energy -= amount
	_emit_changed()
	return true


func refill(amount: int = -1) -> void:
	_stored_energy = config.max_energy if amount < 0 else mini(config.max_energy, get_current() + amount)
	_emit_changed()


func seconds_until_next() -> int:
	if not is_enabled() or get_current() >= config.max_energy:
		return 0
	return config.energy_regen_seconds - (Global.unix_now() - _last_regen_unix)


func _apply_regeneration() -> void:
	if not is_enabled() or _stored_energy >= config.max_energy or config.energy_regen_seconds <= 0:
		return
	var elapsed_seconds: int = Global.unix_now() - _last_regen_unix
	var regenerated: int = floori(float(elapsed_seconds) / float(config.energy_regen_seconds))
	if regenerated <= 0:
		return
	_stored_energy = mini(config.max_energy, _stored_energy + regenerated)
	_last_regen_unix += regenerated * config.energy_regen_seconds
	_emit_changed()


func _emit_changed() -> void:
	Events.energy_changed.emit(_stored_energy, config.max_energy)
	mark_dirty()
