## Where the player may stand: a set of floor rectangles (rooms, doorways,
## the garden) at one height, minus round blockers (trees, rocks, a car) the
## player can't walk into. Teleports must land inside; smooth movement
## slides along edges and around blockers instead of passing through.
##
##   rig.walkable_area = %WalkableArea
##   walkable.add_blockers(yard.get_obstacle_circles())   # Vector3(x, z, radius)
##
## Dependencies: none
class_name WalkableArea
extends Node3D

## Floor rectangles in world X / Z: position = (min x, min z), size = (width, depth).
@export var regions: Array[Rect2] = []
@export var floor_height: float = 0.0
## Round things in the way: Vector3(x, z, radius) on the floor plane.
@export var blockers: Array[Vector3] = []

## How far (meters) the player's body keeps from a blocker's edge.
const BODY_RADIUS: float = 0.25


## Opens up a floor rectangle at runtime (an open door's threshold).
func add_region(region: Rect2) -> void:
	if not regions.has(region):
		regions.append(region)


## Closes a rectangle added with add_region() again.
func remove_region(region: Rect2) -> void:
	regions.erase(region)


func has_region(region: Rect2) -> bool:
	return regions.has(region)


## Adds round blockers (Vector3(x, z, radius)) the player can't walk into.
func add_blockers(circles: Array[Vector3]) -> void:
	for circle: Vector3 in circles:
		if not blockers.has(circle):
			blockers.append(circle)


func contains(world_position: Vector3) -> bool:
	return contains_point(regions, Vector2(world_position.x, world_position.z), blockers)


## Where a move from [param from_position] toward [param to_position] ends:
## the target when it is walkable, otherwise sliding along one axis, or no
## move at all.
func clamp_move(from_position: Vector3, to_position: Vector3) -> Vector3:
	var resolved: Vector2 = resolve_move(regions, Vector2(from_position.x, from_position.z), Vector2(to_position.x, to_position.z), blockers)
	return Vector3(resolved.x, to_position.y, resolved.y)


## True when [param point] is on a floor region (any point without regions)
## and not within a body's width of a blocker.
static func contains_point(floor_regions: Array[Rect2], point: Vector2, floor_blockers: Array[Vector3] = []) -> bool:
	for blocker: Vector3 in floor_blockers:
		if point.distance_to(Vector2(blocker.x, blocker.y)) < blocker.z + BODY_RADIUS:
			return false
	if floor_regions.is_empty():
		return true
	for region: Rect2 in floor_regions:
		if region.has_point(point):
			return true
	return false


## Where a move ends: the target when walkable, otherwise sliding along one
## axis (along a wall, or around a blocker), or no move at all.
static func resolve_move(floor_regions: Array[Rect2], from_point: Vector2, to_point: Vector2, floor_blockers: Array[Vector3] = []) -> Vector2:
	if contains_point(floor_regions, to_point, floor_blockers):
		return to_point
	var slide_x: Vector2 = Vector2(to_point.x, from_point.y)
	if contains_point(floor_regions, slide_x, floor_blockers):
		return slide_x
	var slide_z: Vector2 = Vector2(from_point.x, to_point.y)
	if contains_point(floor_regions, slide_z, floor_blockers):
		return slide_z
	return from_point
