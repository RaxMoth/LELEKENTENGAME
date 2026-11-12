## Where the player may stand: a set of floor rectangles (rooms, doorways)
## at one height. Teleports must land inside; smooth movement slides along
## the edges instead of passing through walls.
##
##   rig.walkable_area = %WalkableArea
##
## Dependencies: none
class_name WalkableArea
extends Node3D

## Floor rectangles in world X / Z: position = (min x, min z), size = (width, depth).
@export var regions: Array[Rect2] = []
@export var floor_height: float = 0.0


## Opens up a floor rectangle at runtime (an open door's threshold).
func add_region(region: Rect2) -> void:
	if not regions.has(region):
		regions.append(region)


## Closes a rectangle added with add_region() again.
func remove_region(region: Rect2) -> void:
	regions.erase(region)


func has_region(region: Rect2) -> bool:
	return regions.has(region)


func contains(world_position: Vector3) -> bool:
	return contains_point(regions, Vector2(world_position.x, world_position.z))


## Where a move from [param from_position] toward [param to_position] ends:
## the target when it is walkable, otherwise sliding along one axis, or no
## move at all.
func clamp_move(from_position: Vector3, to_position: Vector3) -> Vector3:
	var resolved: Vector2 = resolve_move(regions, Vector2(from_position.x, from_position.z), Vector2(to_position.x, to_position.z))
	return Vector3(resolved.x, to_position.y, resolved.y)


static func contains_point(floor_regions: Array[Rect2], point: Vector2) -> bool:
	if floor_regions.is_empty():
		return true
	for region: Rect2 in floor_regions:
		if region.has_point(point):
			return true
	return false


static func resolve_move(floor_regions: Array[Rect2], from_point: Vector2, to_point: Vector2) -> Vector2:
	if contains_point(floor_regions, to_point):
		return to_point
	var slide_x: Vector2 = Vector2(to_point.x, from_point.y)
	if contains_point(floor_regions, slide_x):
		return slide_x
	var slide_z: Vector2 = Vector2(from_point.x, to_point.y)
	if contains_point(floor_regions, slide_z):
		return slide_z
	return from_point
