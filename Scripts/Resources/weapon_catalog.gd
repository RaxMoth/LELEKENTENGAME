## Every weapon there is, in shop order: the fists (the starter), the knife,
## the axe, then the guns. One shared list for the armory terminal (buying)
## and the front garden (fighting).
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


## The free weapon every player owns (the first starter in the list: the fists), or null.
func get_starter() -> WeaponData:
	for weapon: WeaponData in weapons:
		if weapon.is_starter():
			return weapon
	return null
