## The player's guns between shifts: owned weapons, ammo and the gun in hand
## (a WeaponLoadout). The armory terminal buys into it, the front garden
## fires from it.
##
##   Profile.armory.loadout.get_equipped(catalog)
##
## Dependencies: WeaponLoadout, SaveManager autoload (through ProfileModule)
class_name ArmoryProgress
extends ProfileModule

var loadout: WeaponLoadout = null


func get_save_key() -> StringName:
	return &"armory"


func to_dict() -> Dictionary:
	return loadout.to_dict()


func from_dict(data: Dictionary) -> void:
	reset()
	loadout.from_dict(data)


func reset() -> void:
	if loadout == null:
		loadout = WeaponLoadout.new()
		# Every shot, purchase and equip is saved (the save itself is debounced).
		loadout.changed.connect(mark_dirty)
	loadout.clear()
