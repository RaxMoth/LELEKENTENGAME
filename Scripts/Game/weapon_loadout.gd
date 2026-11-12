## The player's guns: which ones they own, the rounds left for each and the
## one in their hand. Starter guns (cost 0) are always owned and never run
## out of ammo, so the player is never unarmed.
##
##   loadout.buy_weapon(shotgun)          # after paying for it
##   loadout.equip(&"shotgun")
##   if loadout.try_fire(shotgun): ...    # takes a round (none for the starter)
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


func owns(weapon: WeaponData) -> bool:
	return weapon != null and (weapon.is_starter() or _owned_ids.has(weapon.id))


func get_ammo(weapon: WeaponData) -> int:
	return _ammo.get(weapon.id, 0) if weapon != null else 0


func has_ammo(weapon: WeaponData) -> bool:
	return weapon != null and (weapon.has_unlimited_ammo or get_ammo(weapon) > 0)


## Room left for rounds of [param weapon].
func get_ammo_space(weapon: WeaponData) -> int:
	return 0 if weapon == null or weapon.has_unlimited_ammo else maxi(0, weapon.max_ammo - get_ammo(weapon))


## Adds a bought gun with its starting rounds. Returns false when already owned.
func buy_weapon(weapon: WeaponData) -> bool:
	if weapon == null or owns(weapon):
		return false
	_owned_ids.append(weapon.id)
	_ammo[weapon.id] = mini(weapon.starting_ammo, weapon.max_ammo)
	changed.emit()
	return true


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


## JSON-friendly: {"equipped": "smg", "owned": ["smg"], "ammo": {"smg": 40}}.
func to_dict() -> Dictionary:
	var ammo_data: Dictionary = {}
	for weapon_id: StringName in _ammo:
		ammo_data[String(weapon_id)] = _ammo[weapon_id]
	var owned_data: Array[String] = []
	for weapon_id: StringName in _owned_ids:
		owned_data.append(String(weapon_id))
	return {"equipped": String(equipped_id), "owned": owned_data, "ammo": ammo_data}


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


func clear() -> void:
	equipped_id = &""
	_owned_ids.clear()
	_ammo.clear()
