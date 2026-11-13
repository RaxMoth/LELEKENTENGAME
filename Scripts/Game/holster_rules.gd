## Which owned weapon hangs in which holster on the player's body: each
## holster slot (WeaponData.holster_slot) holds one weapon — the equipped
## one when it belongs there, otherwise the strongest owned one for it (the
## latest in shop order). The knife hangs on the hip, the axe on the back,
## the gun on the chest.
##
##   HolsterRules.assign(catalog, loadout)   # {&"hip": knife, &"chest": pistol}
##
## Dependencies: WeaponCatalog, WeaponLoadout, WeaponData
class_name HolsterRules
extends RefCounted


## Slot -> weapon for everything [param loadout] owns that has a holster slot.
static func assign(catalog: WeaponCatalog, loadout: WeaponLoadout) -> Dictionary[StringName, WeaponData]:
	var holstered: Dictionary[StringName, WeaponData] = {}
	if catalog == null or loadout == null:
		return holstered
	var equipped: WeaponData = loadout.get_equipped(catalog)
	for weapon: WeaponData in catalog.weapons:
		if weapon.holster_slot == &"" or not loadout.owns(weapon):
			continue
		var current: WeaponData = holstered.get(weapon.holster_slot)
		if current != null and current == equipped:
			continue
		holstered[weapon.holster_slot] = weapon
	return holstered
