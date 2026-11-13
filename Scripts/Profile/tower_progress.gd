## The player's towers between days: where each stands, its kind and its
## upgrade level (TowerPlacements). The FrontGarden's TowerField builds them
## from it and records every new tower and upgrade.
##
##   Profile.towers.placements.add(&"mortar", spot)
##
## Dependencies: TowerPlacements, SaveManager autoload (through ProfileModule)
class_name TowerProgress
extends ProfileModule

var placements: TowerPlacements = null


func get_save_key() -> StringName:
	return &"towers"


func to_dict() -> Dictionary:
	return placements.to_dict()


func from_dict(data: Dictionary) -> void:
	reset()
	placements.from_dict(data)


func reset() -> void:
	if placements == null:
		placements = TowerPlacements.new()
		placements.changed.connect(mark_dirty)
	placements.clear()
