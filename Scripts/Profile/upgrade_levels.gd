## Purchased levels of persistent UpgradeData definitions.
##
## Dependencies: Events, Profile autoloads
class_name UpgradeLevels
extends ProfileModule

var _levels: Dictionary[StringName, int] = {}


func get_save_key() -> StringName:
	return &"upgrades"


func to_dict() -> Dictionary:
	return _levels


func from_dict(data: Dictionary) -> void:
	_levels = to_int_dictionary(data)


func reset() -> void:
	_levels = {}


func get_level(upgrade_id: StringName) -> int:
	return _levels.get(upgrade_id, 0)


## Current effective value of an upgrade (base + per-level growth).
func get_value(upgrade: UpgradeData) -> float:
	return upgrade.get_value(get_level(upgrade.id))


func get_next_cost(upgrade: UpgradeData) -> int:
	return upgrade.get_cost(get_level(upgrade.id))


func can_purchase(upgrade: UpgradeData) -> bool:
	var current_level: int = get_level(upgrade.id)
	return not upgrade.is_maxed(current_level) and Profile.wallet.can_afford(upgrade.currency_id, upgrade.get_cost(current_level))


func purchase(upgrade: UpgradeData) -> bool:
	if not can_purchase(upgrade):
		return false
	var current_level: int = get_level(upgrade.id)
	Profile.wallet.spend(upgrade.currency_id, upgrade.get_cost(current_level))
	_levels[upgrade.id] = current_level + 1
	Events.upgrade_purchased.emit(upgrade.id, current_level + 1)
	mark_dirty()
	return true
