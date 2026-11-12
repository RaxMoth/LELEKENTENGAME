## Item counts: consumables (boosters, revives) and permanent unlocks
## (skins, "no ads") which simply have a count of 1.
##
## Dependencies: Events autoload
class_name Inventory
extends ProfileModule

var _item_counts: Dictionary[StringName, int] = {}


func get_save_key() -> StringName:
	return &"inventory"


func to_dict() -> Dictionary:
	return _item_counts


func from_dict(data: Dictionary) -> void:
	_item_counts = to_int_dictionary(data)


func reset() -> void:
	_item_counts = {}


func get_count(item_id: StringName) -> int:
	return _item_counts.get(item_id, 0)


func has_item(item_id: StringName) -> bool:
	return get_count(item_id) > 0


func add_item(item_id: StringName, amount: int = 1) -> void:
	_item_counts[item_id] = maxi(0, get_count(item_id) + amount)
	Events.item_changed.emit(item_id, _item_counts[item_id])
	mark_dirty()


func consume_item(item_id: StringName, amount: int = 1) -> bool:
	if get_count(item_id) < amount:
		return false
	add_item(item_id, -amount)
	return true
