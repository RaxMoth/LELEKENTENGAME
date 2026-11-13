## Purchased levels of persistent UpgradeData definitions. An upgrade can be
## bought once the operation has its required reputation.
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
	_own_requirements()


## An owned upgrade's prerequisite is owned too: a save from before a
## prerequisite was added (the cellar now needs the extended house) loads
## with it instead of a cellar the cabin can't reach.
func _own_requirements() -> void:
	if config == null:
		return
	var has_changed: bool = true
	while has_changed:
		has_changed = false
		for upgrade: UpgradeData in config.get_upgrades():
			var required_id: StringName = upgrade.required_upgrade_id
			if get_level(upgrade.id) > 0 and not required_id.is_empty() and get_level(required_id) <= 0:
				_levels[required_id] = 1
				has_changed = true


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
	return not upgrade.is_maxed(current_level) and is_reputation_met(upgrade) and is_requirement_met(upgrade) \
		and Profile.wallet.can_afford(upgrade.currency_id, upgrade.get_cost(current_level))


func is_reputation_met(upgrade: UpgradeData) -> bool:
	return Profile.operation.reputation >= upgrade.required_reputation


## True when the upgrade it builds on (UpgradeData.required_upgrade_id) is owned.
func is_requirement_met(upgrade: UpgradeData) -> bool:
	return is_owned(upgrade.required_upgrade_id)


## True when [param upgrade_id] is empty or bought at least once.
func is_owned(upgrade_id: StringName) -> bool:
	return upgrade_id.is_empty() or get_level(upgrade_id) > 0


func purchase(upgrade: UpgradeData) -> bool:
	if not can_purchase(upgrade):
		return false
	var current_level: int = get_level(upgrade.id)
	Profile.wallet.spend(upgrade.currency_id, upgrade.get_cost(current_level))
	_levels[upgrade.id] = current_level + 1
	Events.upgrade_purchased.emit(upgrade.id, current_level + 1)
	mark_dirty()
	return true
