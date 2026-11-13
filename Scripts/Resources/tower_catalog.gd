## Every kind of tower the depot sells, in shop order.
## Instance: Ressources/Towers/tower_catalog.tres.
##
## Dependencies: TowerData
class_name TowerCatalog
extends Resource

@export var towers: Array[TowerData] = []


## The tower kind with [param tower_id], or null.
func find_tower(tower_id: StringName) -> TowerData:
	for tower: TowerData in towers:
		if tower != null and tower.id == tower_id:
			return tower
	return null
