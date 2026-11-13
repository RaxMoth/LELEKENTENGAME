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
## an edge or through a ceiling. Blockers stand on every floor; furniture
## (add_obstacle(): tables, shelves, racks) only on the floor it stands on,
## with a smaller margin so stations stay within reach.
##
##   rig.walkable_area = %WalkableArea
##   walkable.add_blockers(yard.get_obstacle_circles())   # Vector3(x, z, radius)
##   walkable.add_rect_blockers(town.get_building_footprints())
##   walkable.add_hole(stairwell); walkable.add_ramp(stairs); walkable.add_floor(cellar)
##   walkable.get_floor_height_at(feet)   # NAN off every floor
##   walkable.find_path(raider, player)   # waypoints through doorways and down stairs
##
## Dependencies: WalkableFloor, WalkableRamp
class_name WalkableArea
extends Node3D

## Floor rectangles in world X / Z: position = (min x, min z), size = (width, depth).
@export var regions: Array[Rect2] = []:
	set(value):
		regions = value
		_is_route_graph_dirty = true
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
## Side (meters) of the grid cells blockers are sorted into for quick lookups.
const BLOCKER_CELL_SIZE: float = 16.0
## Highest step up or down a move may take; more is a wall, an edge or a ceiling.
const MAX_STEP: float = 0.35
## Off every floor, a move may still land on a floor this far up or down
## (meters) — less than a storey.
const OFF_FLOOR_STEP: float = 1.2
## How far (meters) the body keeps from furniture: less than from a wall,
## so the player can stand at a table and work at it.
const OBSTACLE_MARGIN: float = 0.15

## Patches meeting this close (meters) count as joined (a doorway's rect
## against a room's).
const ROUTE_JOIN_MARGIN: float = 0.05

## Furniture footprints (world X / Z) and the floor height each stands on.
var _obstacles: Array[Rect2] = []
var _obstacle_heights: Array[float] = []
## Route finding: every walkable patch and, per patch, [neighbor index, portal point] links.
var _route_patches: Array[RoutePatch] = []
var _route_links: Array[Array] = []
var _is_route_graph_dirty: bool = true
## Blockers sorted into square cells of BLOCKER_CELL_SIZE (indices into
## blockers / rect_blockers), and the rect blockers grown by BODY_RADIUS.
var _circle_grid: Dictionary[Vector2i, PackedInt32Array] = {}
var _rect_grid: Dictionary[Vector2i, PackedInt32Array] = {}
var _grown_rects: Array[Rect2] = []
var _is_blocker_grid_dirty: bool = true
var _grid_circle_count: int = -1
var _grid_rect_count: int = -1


## One walkable patch for route finding: a rect on a floor, or a ramp.
class RoutePatch:
	var rect: Rect2 = Rect2()
	var height: float = 0.0
	var ramp: WalkableRamp = null

	func height_at(point: Vector2) -> float:
		return ramp.get_height(point) if ramp != null else height


## Opens up a floor rectangle at runtime (an open door's threshold).
func add_region(region: Rect2) -> void:
	if not regions.has(region):
		regions.append(region)
		_is_route_graph_dirty = true


## Closes a rectangle added with add_region() again.
func remove_region(region: Rect2) -> void:
	if regions.has(region):
		regions.erase(region)
		_is_route_graph_dirty = true


func has_region(region: Rect2) -> bool:
	return regions.has(region)


## Adds round blockers (Vector3(x, z, radius)) the player can't walk into.
func add_blockers(circles: Array[Vector3]) -> void:
	for circle: Vector3 in circles:
		if not blockers.has(circle):
			blockers.append(circle)
	_is_blocker_grid_dirty = true


## Takes round blockers away again (a tower taken down).
func remove_blockers(circles: Array[Vector3]) -> void:
	for circle: Vector3 in circles:
		blockers.erase(circle)
	_is_blocker_grid_dirty = true


## Adds rectangular blockers (world X / Z) the player can't walk into.
func add_rect_blockers(rects: Array[Rect2]) -> void:
	for rect: Rect2 in rects:
		if not rect_blockers.has(rect):
			rect_blockers.append(rect)
	_is_blocker_grid_dirty = true


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
		_is_route_graph_dirty = true


func remove_floor(extra_floor: WalkableFloor) -> void:
	if extra_floors.has(extra_floor):
		extra_floors.erase(extra_floor)
		_is_route_graph_dirty = true


## Adds a slope between floors (stairs).
func add_ramp(ramp: WalkableRamp) -> void:
	if not ramps.has(ramp):
		ramps.append(ramp)
		_is_route_graph_dirty = true


func remove_ramp(ramp: WalkableRamp) -> void:
	if ramps.has(ramp):
		ramps.erase(ramp)
		_is_route_graph_dirty = true


## Furniture standing on the floor at [param floor_y] (a table, a rack):
## its [param footprint] (world X / Z) blocks only that floor.
func add_obstacle(footprint: Rect2, floor_y: float) -> void:
	_obstacles.append(footprint)
	_obstacle_heights.append(floor_y)


## Removes every furniture footprint (the House level hands them in again
## whenever upgrades change what stands where).
func clear_obstacles() -> void:
	_obstacles.clear()
	_obstacle_heights.clear()


func get_obstacle_count() -> int:
	return _obstacles.size()


## A walking route from [param from] to [param to] across the floors, ramps
## and doorways: the middle of where each patch meets the next, then
## [param to] itself. Empty when no route joins them, or when either end is
## off every floor. Raiders follow it to hunt the player down.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	_build_route_graph()
	var start: int = _find_route_patch(from)
	var goal: int = _find_route_patch(to)
	var route: PackedVector3Array = PackedVector3Array()
	if start < 0 or goal < 0:
		return route
	var parents: Dictionary[int, int] = {start: -1}
	var queue: Array[int] = [start]
	while not queue.is_empty() and not parents.has(goal):
		var current: int = queue.pop_front()
		for link: Array in _route_links[current]:
			var neighbor: int = int(link[0])
			if not parents.has(neighbor):
				parents[neighbor] = current
				queue.append(neighbor)
	if not parents.has(goal):
		return route
	var chain: Array[int] = []
	var patch_index: int = goal
	while patch_index != -1:
		chain.push_front(patch_index)
		patch_index = parents[patch_index]
	for chain_index: int in range(1, chain.size()):
		route.append(_get_link_portal(chain[chain_index - 1], chain[chain_index]))
	route.append(to)
	return route


## True when a player standing at [param world_position] (its y is their
## feet) is on a floor: one within MAX_STEP of that height, off every blocker.
func contains(world_position: Vector3) -> bool:
	return not is_nan(get_floor_height_at(world_position))


## Height of the walkable surface under [param world_position] — of the
## floors, ramps and the main floor there, the one nearest its y and no more
## than [param max_step] away — or NAN when there is none (off the floor, in
## a hole, at a blocker or furniture, or a floor much higher or lower).
## [param ignores_obstacles] lets furniture through (walking out of a table
## that appeared around the player).
func get_floor_height_at(world_position: Vector3, max_step: float = MAX_STEP, ignores_obstacles: bool = false) -> float:
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
		if not ignores_obstacles and _is_obstructed(point, height):
			continue
		var gap: float = absf(height - world_position.y)
		if gap <= best_gap:
			best_gap = gap
			best_height = height
	return best_height


## Where a move from [param from_position] toward [param to_position] ends:
## the target when it is walkable, otherwise sliding along one axis, or no
## move at all. The result's y is the floor height there (down a ramp, it
## goes down). Nobody gets stuck: from inside furniture that appeared
## around the player, furniture is let through (same floor only); from a
## spot with no floor at all (a hole opened beneath them) any floor within
## OFF_FLOOR_STEP counts.
func clamp_move(from_position: Vector3, to_position: Vector3) -> Vector3:
	var is_off_floor: bool = is_nan(get_floor_height_at(from_position, MAX_STEP, true))
	var is_in_furniture: bool = not is_off_floor and is_nan(get_floor_height_at(from_position))
	# Off every floor (a hole opened beneath them, or the head leaned past
	# the edge of a floor in a headset) any floor near that height counts —
	# but never one a storey up or down: leaning over the cellar's edge must
	# not lift the player into the room above.
	var step_limit: float = OFF_FLOOR_STEP if is_off_floor else MAX_STEP
	var ignores_obstacles: bool = is_off_floor or is_in_furniture
	var candidates: Array[Vector2] = [Vector2(to_position.x, to_position.z), Vector2(to_position.x, from_position.z), Vector2(from_position.x, to_position.z)]
	for candidate: Vector2 in candidates:
		var height: float = get_floor_height_at(Vector3(candidate.x, from_position.y, candidate.y), step_limit, ignores_obstacles)
		if not is_nan(height):
			return Vector3(candidate.x, height, candidate.y)
	return from_position


## (Re)builds the patches and their links once the floors changed.
func _build_route_graph() -> void:
	if not _is_route_graph_dirty:
		return
	_is_route_graph_dirty = false
	_route_patches.clear()
	_route_links.clear()
	for region: Rect2 in regions:
		_add_route_patch(region, floor_height, null)
	for extra_floor: WalkableFloor in extra_floors:
		for region: Rect2 in extra_floor.regions:
			_add_route_patch(region, extra_floor.height, null)
	for ramp: WalkableRamp in ramps:
		_add_route_patch(ramp.rect, ramp.top_height, ramp)
	for patch_index: int in _route_patches.size():
		_route_links.append([])
	for first: int in _route_patches.size():
		for second: int in range(first + 1, _route_patches.size()):
			var portal: Vector3 = _find_portal(_route_patches[first], _route_patches[second])
			if portal.is_finite():
				_route_links[first].append([second, portal])
				_route_links[second].append([first, portal])


func _add_route_patch(rect: Rect2, height: float, ramp: WalkableRamp) -> void:
	var patch: RoutePatch = RoutePatch.new()
	patch.rect = rect
	patch.height = height
	patch.ramp = ramp
	_route_patches.append(patch)


## Where two patches join at about the same height (a doorway, the top or
## foot of the stairs), or INF when they don't.
static func _find_portal(first: RoutePatch, second: RoutePatch) -> Vector3:
	var overlap: Rect2 = first.rect.grow(ROUTE_JOIN_MARGIN).intersection(second.rect.grow(ROUTE_JOIN_MARGIN))
	if overlap.size.x <= 0.0 or overlap.size.y <= 0.0:
		return Vector3.INF
	# A ramp meets a floor only at its ends: try the middle, then the middle of each side.
	var center: Vector2 = overlap.get_center()
	var candidates: Array[Vector2] = [center, Vector2(overlap.position.x, center.y), Vector2(overlap.end.x, center.y), Vector2(center.x, overlap.position.y), Vector2(center.x, overlap.end.y)]
	for point: Vector2 in candidates:
		var first_height: float = first.height_at(point)
		var second_height: float = second.height_at(point)
		if absf(first_height - second_height) <= MAX_STEP:
			return Vector3(point.x, (first_height + second_height) * 0.5, point.y)
	return Vector3.INF


func _get_link_portal(from_patch: int, to_patch: int) -> Vector3:
	for link: Array in _route_links[from_patch]:
		if int(link[0]) == to_patch:
			return link[1] as Vector3
	return Vector3.INF


## The patch under [param world_position] at about its height, or -1.
func _find_route_patch(world_position: Vector3) -> int:
	var point: Vector2 = Vector2(world_position.x, world_position.z)
	var best: int = -1
	var best_gap: float = MAX_STEP * 2.0
	for patch_index: int in _route_patches.size():
		var patch: RoutePatch = _route_patches[patch_index]
		if not patch.rect.has_point(point):
			continue
		var gap: float = absf(patch.height_at(point) - world_position.y)
		if gap <= best_gap:
			best_gap = gap
			best = patch_index
	return best


## True when furniture on the floor at [param height] stands at [param point].
func _is_obstructed(point: Vector2, height: float) -> bool:
	for obstacle_index: int in _obstacles.size():
		if absf(_obstacle_heights[obstacle_index] - height) <= MAX_STEP and _obstacles[obstacle_index].grow(OBSTACLE_MARGIN).has_point(point):
			return true
	return false


## True when [param point] is within a body's width of a blocker. Only the
## blockers in its grid cell are tested (a town has hundreds).
func _is_blocked(point: Vector2) -> bool:
	_build_blocker_grid()
	var cell: Vector2i = Vector2i(floori(point.x / BLOCKER_CELL_SIZE), floori(point.y / BLOCKER_CELL_SIZE))
	var circle_indices: PackedInt32Array = _circle_grid.get(cell, PackedInt32Array())
	for circle_index: int in circle_indices:
		var blocker: Vector3 = blockers[circle_index]
		if point.distance_to(Vector2(blocker.x, blocker.y)) < blocker.z + BODY_RADIUS:
			return true
	var rect_indices: PackedInt32Array = _rect_grid.get(cell, PackedInt32Array())
	for rect_index: int in rect_indices:
		if _grown_rects[rect_index].has_point(point):
			return true
	return false


## Sorts the blockers into grid cells (once, after blockers were added).
func _build_blocker_grid() -> void:
	# Blockers set in the inspector (or assigned) count too: rebuild when the counts changed.
	if not _is_blocker_grid_dirty and _grid_circle_count == blockers.size() and _grid_rect_count == rect_blockers.size():
		return
	_is_blocker_grid_dirty = false
	_grid_circle_count = blockers.size()
	_grid_rect_count = rect_blockers.size()
	_circle_grid.clear()
	_rect_grid.clear()
	_grown_rects.clear()
	for circle_index: int in blockers.size():
		var circle: Vector3 = blockers[circle_index]
		var reach: float = circle.z + BODY_RADIUS
		_add_to_grid(_circle_grid, Rect2(circle.x - reach, circle.y - reach, reach * 2.0, reach * 2.0), circle_index)
	for rect_index: int in rect_blockers.size():
		var grown: Rect2 = rect_blockers[rect_index].grow(BODY_RADIUS)
		_grown_rects.append(grown)
		_add_to_grid(_rect_grid, grown, rect_index)


static func _add_to_grid(grid: Dictionary[Vector2i, PackedInt32Array], area: Rect2, index: int) -> void:
	for cell_x: int in range(floori(area.position.x / BLOCKER_CELL_SIZE), floori(area.end.x / BLOCKER_CELL_SIZE) + 1):
		for cell_y: int in range(floori(area.position.y / BLOCKER_CELL_SIZE), floori(area.end.y / BLOCKER_CELL_SIZE) + 1):
			var cell: Vector2i = Vector2i(cell_x, cell_y)
			var indices: PackedInt32Array = grid.get(cell, PackedInt32Array())
			indices.append(index)
			grid[cell] = indices


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
