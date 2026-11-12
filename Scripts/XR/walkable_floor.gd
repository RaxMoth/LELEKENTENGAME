## One more floor the player can walk on besides WalkableArea's main one,
## at its own height: the cellar under the house. Reached over a
## WalkableRamp; floors may lie under each other (the player stays on the
## one nearest their feet).
##
##   var cellar: WalkableFloor = WalkableFloor.create(-2.6, [Rect2(1.05, -1.75, 3.7, 3.15)])
##
## Dependencies: none
class_name WalkableFloor
extends Resource

## Height of this floor.
@export var height: float = 0.0
## Its walkable rectangles in world X / Z: position = (min x, min z).
@export var regions: Array[Rect2] = []


static func create(floor_height: float, floor_regions: Array[Rect2]) -> WalkableFloor:
	var walkable_floor: WalkableFloor = WalkableFloor.new()
	walkable_floor.height = floor_height
	walkable_floor.regions = floor_regions
	return walkable_floor


func has_point(point: Vector2) -> bool:
	for region: Rect2 in regions:
		if region.has_point(point):
			return true
	return false
