## The player's weapons: which ones they own, the rounds left for each gun
## and the one in their hand. The starter (cost 0: the fists) is always
## owned and never runs out, so the player is never unarmed. A weapon is for
## sale only once its required weapon is owned (knife → axe → pistol → the
## other guns). Owned weapons can be upgraded at the armory (more damage,
## faster fire, more rounds) and switched through in hand.
##
##   loadout.can_buy(shotgun, catalog)    # owns the pistol, not the shotgun yet
##   loadout.buy_weapon(shotgun)          # after paying for it
##   loadout.equip(&"shotgun")
##   if loadout.try_fire(shotgun): ...    # takes a round (none for the starter)
##   loadout.upgrade(shotgun)             # after paying get_upgrade_cost
##   loadout.equip_next(catalog)          # the next owned weapon in hand
##
## Pure data (to_dict / from_dict); Profile.armory saves it.
## Unit-tested in Tests/Unit/weapon_loadout_test.gd.
##
## Dependencies: WeaponData, WeaponCatalog
class_name WeaponLoadout
extends RefCounted

signal changed

var equipped_id: StringName = &""

var _owned_ids: Array[StringName] = []
## weapon id -> rounds left.
var _ammo: Dictionary[StringName, int] = {}
## weapon id -> upgrade level bought at the armory.
var _upgrades: Dictionary[StringName, int] = {}


func owns(weapon: WeaponData) -> bool:
	return weapon != null and (weapon.is_starter() or _owned_ids.has(weapon.id))


func get_ammo(weapon: WeaponData) -> int:
	return _ammo.get(weapon.id, 0) if weapon != null else 0


func has_ammo(weapon: WeaponData) -> bool:
	return weapon != null and (weapon.has_unlimited_ammo or get_ammo(weapon) > 0)


## Room left for rounds of [param weapon].
func get_ammo_space(weapon: WeaponData) -> int:
	return 0 if weapon == null or weapon.has_unlimited_ammo else maxi(0, weapon.get_max_ammo(get_upgrade_level(weapon)) - get_ammo(weapon))


## True when [param weapon]'s required weapon (in [param catalog]) is owned,
## or it needs none.
func is_unlocked(weapon: WeaponData, catalog: WeaponCatalog) -> bool:
	if weapon == null:
		return false
	if weapon.required_weapon_id == &"":
		return true
	var required: WeaponData = catalog.find_weapon(weapon.required_weapon_id) if catalog != null else null
	return required != null and owns(required)


## True when [param weapon] is for sale to this player: not owned yet, and unlocked.
func can_buy(weapon: WeaponData, catalog: WeaponCatalog) -> bool:
	return weapon != null and not owns(weapon) and is_unlocked(weapon, catalog)


## Adds a bought gun with its starting rounds. Returns false when already owned.
func buy_weapon(weapon: WeaponData) -> bool:
	if weapon == null or owns(weapon):
		return false
	_owned_ids.append(weapon.id)
	_ammo[weapon.id] = mini(weapon.starting_ammo, weapon.max_ammo)
	changed.emit()
	return true


## Upgrade level of [param weapon] (0 = as bought).
func get_upgrade_level(weapon: WeaponData) -> int:
	return _upgrades.get(weapon.id, 0) if weapon != null else 0


## True when [param weapon] is owned and has another upgrade level to buy.
func can_upgrade(weapon: WeaponData) -> bool:
	return owns(weapon) and get_upgrade_level(weapon) < weapon.get_max_upgrade_level()


## Price of [param weapon]'s next upgrade (0 when it can't be upgraded).
func get_upgrade_cost(weapon: WeaponData) -> int:
	return weapon.get_upgrade_cost(get_upgrade_level(weapon)) if can_upgrade(weapon) else 0


## Raises [param weapon] one upgrade level (after paying). False when it can't.
func upgrade(weapon: WeaponData) -> bool:
	if not can_upgrade(weapon):
		return false
	_upgrades[weapon.id] = get_upgrade_level(weapon) + 1
	changed.emit()
	return true


## Every weapon of [param catalog] the player owns, in catalog order.
func get_owned_weapons(catalog: WeaponCatalog) -> Array[WeaponData]:
	var owned: Array[WeaponData] = []
	if catalog == null:
		return owned
	for weapon: WeaponData in catalog.weapons:
		if owns(weapon):
			owned.append(weapon)
	return owned


## Puts the next owned weapon (catalog order, [param step] = -1 the one
## before) in hand, wrapping around; [param guns_only] skips fists and
## blades. Returns the weapon now in hand (null when there is none).
func equip_next(catalog: WeaponCatalog, step: int = 1, guns_only: bool = false) -> WeaponData:
	var owned: Array[WeaponData] = []
	for weapon: WeaponData in get_owned_weapons(catalog):
		if not guns_only or not weapon.is_melee():
			owned.append(weapon)
	if owned.is_empty():
		return null
	var current: int = owned.find(get_equipped(catalog))
	var next: WeaponData = owned[posmod(current + step, owned.size())]
	equip(next)
	return next


## True when an ammo box for [param weapon] would add rounds.
func can_add_ammo(weapon: WeaponData) -> bool:
	return owns(weapon) and get_ammo_space(weapon) > 0


## Adds rounds (capped at max_ammo). Returns how many were added.
func add_ammo(weapon: WeaponData, rounds: int) -> int:
	if not can_add_ammo(weapon) or rounds <= 0:
		return 0
	var added: int = mini(rounds, get_ammo_space(weapon))
	_ammo[weapon.id] = get_ammo(weapon) + added
	changed.emit()
	return added


## Puts a gun the player owns in their hand. Returns false when not owned.
func equip(weapon: WeaponData) -> bool:
	if not owns(weapon):
		return false
	if equipped_id != weapon.id:
		equipped_id = weapon.id
		changed.emit()
	return true


## The gun in hand: the equipped one when owned, otherwise the catalog's starter.
func get_equipped(catalog: WeaponCatalog) -> WeaponData:
	var weapon: WeaponData = catalog.find_weapon(equipped_id) if catalog != null else null
	if weapon != null and owns(weapon):
		return weapon
	return catalog.get_starter() if catalog != null else null


## Takes one round for a shot. Returns false (no shot) when empty.
func try_fire(weapon: WeaponData) -> bool:
	if weapon == null or not owns(weapon):
		return false
	if weapon.has_unlimited_ammo:
		return true
	var rounds: int = get_ammo(weapon)
	if rounds <= 0:
		return false
	_ammo[weapon.id] = rounds - 1
	changed.emit()
	return true


## JSON-friendly: {"equipped": "smg", "owned": ["smg"], "ammo": {"smg": 40}, "upgrades": {"smg": 1}}.
func to_dict() -> Dictionary:
	var ammo_data: Dictionary = {}
	for weapon_id: StringName in _ammo:
		ammo_data[String(weapon_id)] = _ammo[weapon_id]
	var owned_data: Array[String] = []
	for weapon_id: StringName in _owned_ids:
		owned_data.append(String(weapon_id))
	var upgrade_data: Dictionary = {}
	for weapon_id: StringName in _upgrades:
		upgrade_data[String(weapon_id)] = _upgrades[weapon_id]
	return {"equipped": String(equipped_id), "owned": owned_data, "ammo": ammo_data, "upgrades": upgrade_data}


func from_dict(data: Dictionary) -> void:
	clear()
	equipped_id = StringName(str(data.get("equipped", "")))
	var owned_data: Variant = data.get("owned", [])
	if owned_data is Array:
		for raw_id: Variant in owned_data:
			var weapon_id: StringName = StringName(str(raw_id))
			if not _owned_ids.has(weapon_id):
				_owned_ids.append(weapon_id)
	var ammo_data: Variant = data.get("ammo", {})
	if ammo_data is Dictionary:
		for raw_id: Variant in ammo_data:
			_ammo[StringName(str(raw_id))] = maxi(0, int(ammo_data[raw_id]))
	var upgrade_data: Variant = data.get("upgrades", {})
	if upgrade_data is Dictionary:
		for raw_id: Variant in upgrade_data:
			_upgrades[StringName(str(raw_id))] = maxi(0, int(upgrade_data[raw_id]))


func clear() -> void:
	equipped_id = &""
	_owned_ids.clear()
	_ammo.clear()
	_upgrades.clear()
