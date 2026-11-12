## Where the player may stand: a set of floor rectangles (rooms, doorways,
## the garden, the town's streets) at one height, minus blockers the player
## can't walk into: round ones (trees, rocks, a car) and rectangles
## (buildings, fences). Teleports must land inside; smooth movement slides
## along edges and around blockers instead of passing through.
##
## More floors: [member extra_floors] lie at other heights (the cellar),
## [member ramps] slope between them (the cellar stairs) and [member holes]
## cut openings into the main floor (the stairwell). A position counts as
## walkable on the surface nearest its height, no more than MAX_STEP away,
## so the player walks down a ramp onto the floor below but never steps off
## an edge or through a ceiling. Blockers stand on every floor.
##
##   rig.walkable_area = %WalkableArea
##   walkable.add_blockers(yard.get_obstacle_circles())   # Vector3(x, z, radius)
##   walkable.add_rect_blockers(town.get_building_footprints())
##   walkable.add_hole(stairwell); walkable.add_ramp(stairs); walkable.add_floor(cellar)
##   walkable.get_floor_height_at(feet)   # NAN off every floor
##
## Dependencies: WalkableFloor, WalkableRamp
class_name WalkableArea
extends Node3D

## Floor rectangles in world X / Z: position = (min x, min z), size = (width, depth).
@export var regions: Array[Rect2] = []
@export var floor_height: float = 0.0
## Round things in the way: Vector3(x, z, radius) on the floor plane.
@export var blockers: Array[Vector3] = []
## Rectangular things in the way (world X / Z), e.g. buildings and fences.
@export var rect_blockers: Array[Rect2] = []
## Openings in the main floor (a stairwell): not walkable at floor_height.
@export var holes: Array[Rect2] = []
## Floors at other heights (a cellar).
@export var extra_floors: Array[WalkableFloor] = []
## Slopes between floors (stairs).
@export var ramps: Array[WalkableRamp] = []

## How far (meters) the player's body keeps from a blocker's edge.
const BODY_RADIUS: float = 0.25
## Highest step up or down a move may take; more is a wall, an edge or a ceiling.
const MAX_STEP: float = 0.35


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


## Adds rectangular blockers (world X / Z) the player can't walk into.
func add_rect_blockers(rects: Array[Rect2]) -> void:
	for rect: Rect2 in rects:
		if not rect_blockers.has(rect):
			rect_blockers.append(rect)


## Cuts an opening into the main floor (a stairwell that was opened).
func add_hole(hole: Rect2) -> void:
	if not holes.has(hole):
		holes.append(hole)


func remove_hole(hole: Rect2) -> void:
	holes.erase(hole)


## Adds a floor at another height (the cellar).
func add_floor(extra_floor: WalkableFloor) -> void:
	if not extra_floors.has(extra_floor):
		extra_floors.append(extra_floor)


func remove_floor(extra_floor: WalkableFloor) -> void:
	extra_floors.erase(extra_floor)


## Adds a slope between floors (stairs).
func add_ramp(ramp: WalkableRamp) -> void:
	if not ramps.has(ramp):
		ramps.append(ramp)


func remove_ramp(ramp: WalkableRamp) -> void:
	ramps.erase(ramp)


## True when a player standing at [param world_position] (its y is their
## feet) is on a floor: one within MAX_STEP of that height, off every blocker.
func contains(world_position: Vector3) -> bool:
	return not is_nan(get_floor_height_at(world_position))


## Height of the walkable surface under [param world_position] — of the
## floors, ramps and the main floor there, the one nearest its y and no more
## than [param max_step] away — or NAN when there is none (off the floor, in
## a hole, at a blocker, or a floor much higher or lower).
func get_floor_height_at(world_position: Vector3, max_step: float = MAX_STEP) -> float:
	var point: Vector2 = Vector2(world_position.x, world_position.z)
	if _is_blocked(point):
		return NAN
	var best_height: float = NAN
	var best_gap: float = max_step
	var candidates: Array[float] = []
	if _is_on_main_floor(point):
		candidates.append(floor_height)
	for extra_floor: WalkableFloor in extra_floors:
		if extra_floor.has_point(point):
			candidates.append(extra_floor.height)
	for ramp: WalkableRamp in ramps:
		if ramp.has_point(point):
			candidates.append(ramp.get_height(point))
	for height: float in candidates:
		var gap: float = absf(height - world_position.y)
		if gap <= best_gap:
			best_gap = gap
			best_height = height
	return best_height


## Where a move from [param from_position] toward [param to_position] ends:
## the target when it is walkable, otherwise sliding along one axis, or no
## move at all. The result's y is the floor height there (down a ramp, it
## goes down). From a spot with no floor under it (a hole opened beneath
## the player) any floor counts, so nobody gets stuck.
func clamp_move(from_position: Vector3, to_position: Vector3) -> Vector3:
	var step_limit: float = MAX_STEP if not is_nan(get_floor_height_at(from_position)) else INF
	var candidates: Array[Vector2] = [Vector2(to_position.x, to_position.z), Vector2(to_position.x, from_position.z), Vector2(from_position.x, to_position.z)]
	for candidate: Vector2 in candidates:
		var height: float = get_floor_height_at(Vector3(candidate.x, from_position.y, candidate.y), step_limit)
		if not is_nan(height):
			return Vector3(candidate.x, height, candidate.y)
	return from_position


func _is_blocked(point: Vector2) -> bool:
	return not contains_point([], point, blockers, rect_blockers)


func _is_on_main_floor(point: Vector2) -> bool:
	for hole: Rect2 in holes:
		if hole.has_point(point):
			return false
	if regions.is_empty():
		return true
	for region: Rect2 in regions:
		if region.has_point(point):
			return true
	return false


## True when [param point] is on a floor region (any point without regions)
## and not within a body's width of a blocker (round or rectangular).
static func contains_point(floor_regions: Array[Rect2], point: Vector2, floor_blockers: Array[Vector3] = [], floor_rect_blockers: Array[Rect2] = []) -> bool:
	for blocker: Vector3 in floor_blockers:
		if point.distance_to(Vector2(blocker.x, blocker.y)) < blocker.z + BODY_RADIUS:
			return false
	for rect_blocker: Rect2 in floor_rect_blockers:
		if rect_blocker.grow(BODY_RADIUS).has_point(point):
			return false
	if floor_regions.is_empty():
		return true
	for region: Rect2 in floor_regions:
		if region.has_point(point):
			return true
	return false


## Where a move ends: the target when walkable, otherwise sliding along one
## axis (along a wall, or around a blocker), or no move at all.
static func resolve_move(floor_regions: Array[Rect2], from_point: Vector2, to_point: Vector2, floor_blockers: Array[Vector3] = [], floor_rect_blockers: Array[Rect2] = []) -> Vector2:
	if contains_point(floor_regions, to_point, floor_blockers, floor_rect_blockers):
		return to_point
	var slide_x: Vector2 = Vector2(to_point.x, from_point.y)
	if contains_point(floor_regions, slide_x, floor_blockers, floor_rect_blockers):
		return slide_x
	var slide_z: Vector2 = Vector2(from_point.x, to_point.y)
	if contains_point(floor_regions, slide_z, floor_blockers, floor_rect_blockers):
		return slide_z
	return from_point
