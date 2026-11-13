## Where the player's towers stand: kind, spot (world X / Z), facing and
## upgrade level of each. Keeps towers apart (no two closer than
## min_spacing) and saves as plain data, so they are still standing the
## next day.
##
##   if placements.can_place(spot): placements.add(&"mortar", spot, yaw)
##   placements.upgrade(index)
##
## Pure data (to_dict / from_dict); Profile.towers saves it.
## Unit-tested in Tests/Unit/tower_placements_test.gd.
##
## Dependencies: none
class_name TowerPlacements
extends RefCounted

signal changed

## No two towers closer than this (meters).
var min_spacing: float = 2.5

## One entry per tower: {"id": StringName, "x": float, "z": float, "yaw": float, "level": int}.
var _entries: Array[Dictionary] = []


func get_count() -> int:
	return _entries.size()


func get_id(index: int) -> StringName:
	return _entries[index]["id"]


func get_spot(index: int) -> Vector2:
	return Vector2(float(_entries[index]["x"]), float(_entries[index]["z"]))


func get_yaw(index: int) -> float:
	return float(_entries[index]["yaw"])


func get_level(index: int) -> int:
	return int(_entries[index]["level"])


## True when no tower stands within min_spacing of [param spot].
func can_place(spot: Vector2) -> bool:
	for index: int in _entries.size():
		if get_spot(index).distance_to(spot) < min_spacing:
			return false
	return true


## Adds a tower. Returns its index, or -1 when another stands too close.
func add(tower_id: StringName, spot: Vector2, yaw: float = 0.0) -> int:
	if not can_place(spot):
		return -1
	_entries.append({"id": tower_id, "x": spot.x, "z": spot.y, "yaw": yaw, "level": 0})
	changed.emit()
	return _entries.size() - 1


## Raises tower [param index] one level, up to [param max_level]. False when it can't.
func upgrade(index: int, max_level: int) -> bool:
	if index < 0 or index >= _entries.size() or get_level(index) >= max_level:
		return false
	_entries[index]["level"] = get_level(index) + 1
	changed.emit()
	return true


## Takes tower [param index] down.
func remove(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	_entries.remove_at(index)
	changed.emit()


## JSON-friendly: [{"id": "mortar", "x": 3.0, "z": -12.0, "yaw": 0.0, "level": 1}].
func to_dict() -> Dictionary:
	var towers: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		towers.append({"id": String(entry["id"]), "x": entry["x"], "z": entry["z"], "yaw": entry["yaw"], "level": entry["level"]})
	return {"towers": towers}


func from_dict(data: Dictionary) -> void:
	_entries.clear()
	var towers: Variant = data.get("towers", [])
	if not towers is Array:
		return
	for raw: Variant in towers:
		if raw is Dictionary:
			var entry: Dictionary = raw
			_entries.append({
				"id": StringName(str(entry.get("id", ""))), "x": float(entry.get("x", 0.0)),
				"z": float(entry.get("z", 0.0)), "yaw": float(entry.get("yaw", 0.0)),
				"level": maxi(0, int(entry.get("level", 0))),
			})


func clear() -> void:
	_entries.clear()
