## Every gun the armory sells, in shop order. One shared list for the armory
## terminal (buying) and the front garden (firing).
##
## Instance: Ressources/Weapons/weapon_catalog.tres.
##
## Dependencies: WeaponData
class_name WeaponCatalog
extends Resource

@export var weapons: Array[WeaponData] = []


func find_weapon(weapon_id: StringName) -> WeaponData:
	for weapon: WeaponData in weapons:
		if weapon.id == weapon_id:
			return weapon
	return null


## The free gun every player owns (the first starter in the list), or null.
func get_starter() -> WeaponData:
	for weapon: WeaponData in weapons:
		if weapon.is_starter():
			return weapon
	return null
