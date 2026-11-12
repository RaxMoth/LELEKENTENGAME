## The rules of moving through the open yard in front of the house, on the
## ground plane (x, z) and without physics: steering around round obstacles
## (trees, rocks, cars) and other raiders, staying out of obstacles, line of
## sight (cover blocks shots), finding the next piece of cover on the way to
## the door and the spots around the door where raiders stand.
##
## Obstacles are Vector3(x, z, radius).
##
##   var direction: Vector2 = YardNavigation.steer(position, target, obstacles, neighbours)
##   var cover: Vector2 = YardNavigation.find_cover_spot(position, door, obstacles, taken)
##
## Pure functions (unit-tested in Tests/Unit/yard_navigation_test.gd).
##
## Dependencies: none
class_name YardNavigation
extends RefCounted

## Returned when no spot fits.
const NO_SPOT: Vector2 = Vector2(INF, INF)
## How far ahead (meters) a walker reacts to obstacles in its way.
const LOOK_AHEAD: float = 2.2
## Raiders closer than this push each other apart.
const SEPARATION_DISTANCE: float = 0.9
const SEPARATION_WEIGHT: float = 0.9
## Directions tried on each side of the blocked one, this far apart.
const STEER_SAMPLES: int = 8
const STEER_SAMPLE_RADIANS: float = PI / 8.0
## Sideways slots of one row in front of the door, middle first.
const DOOR_ROW_COLUMNS: Array[float] = [0.0, 1.0, -1.0, 2.0, -2.0]


## Unit direction to walk from [param position] toward [param target]:
## straight at it when the way ahead is clear, otherwise the free direction
## closest to it (sampled in 22.5° steps, keeping to [param previous_direction]
## so walkers don't dither between two sides), kept apart from
## [param neighbours]. Zero when already there.
static func steer(position: Vector2, target: Vector2, obstacles: Array[Vector3], neighbours: PackedVector2Array = PackedVector2Array(), body_radius: float = 0.35, previous_direction: Vector2 = Vector2.ZERO) -> Vector2:
	var to_target: Vector2 = target - position
	var distance: float = to_target.length()
	if distance < 0.05:
		return Vector2.ZERO
	var desired: Vector2 = to_target / distance
	var probe_length: float = minf(LOOK_AHEAD, distance)
	var steering: Vector2 = desired
	if _is_path_blocked(position, desired, probe_length, obstacles, body_radius):
		var best_score: float = -INF
		for step: int in range(1, STEER_SAMPLES + 1):
			for side: float in [1.0, -1.0]:
				var candidate: Vector2 = desired.rotated(side * step * STEER_SAMPLE_RADIANS)
				if _is_path_blocked(position, candidate, probe_length, obstacles, body_radius):
					continue
				var score: float = candidate.dot(desired) + candidate.dot(previous_direction) * 0.5
				if score > best_score:
					best_score = score
					steering = candidate
	for neighbour: Vector2 in neighbours:
		var away: Vector2 = position - neighbour
		var neighbour_distance: float = away.length()
		if neighbour_distance > 0.001 and neighbour_distance < SEPARATION_DISTANCE:
			steering += away / neighbour_distance * SEPARATION_WEIGHT * (1.0 - neighbour_distance / SEPARATION_DISTANCE)
	return steering.normalized() if steering.length() > 0.001 else desired


## [param position] pushed out of every obstacle it overlaps.
static func resolve_overlap(position: Vector2, obstacles: Array[Vector3], body_radius: float = 0.35) -> Vector2:
	var resolved: Vector2 = position
	for obstacle: Vector3 in obstacles:
		var center: Vector2 = Vector2(obstacle.x, obstacle.y)
		var clearance: float = obstacle.z + body_radius
		var away: Vector2 = resolved - center
		var distance: float = away.length()
		if distance < clearance:
			resolved = center + (away / distance if distance > 0.001 else Vector2.RIGHT) * clearance
	return resolved


## True when an obstacle stands between [param from] and [param to] (cover
## blocks a turret's or a guard's shot). [param shrink] lets shots graze edges.
static func is_line_blocked(from: Vector2, to: Vector2, obstacles: Array[Vector3], shrink: float = 0.1) -> bool:
	var segment: Vector2 = to - from
	var length_squared: float = segment.length_squared()
	for obstacle: Vector3 in obstacles:
		var center: Vector2 = Vector2(obstacle.x, obstacle.y)
		var radius: float = obstacle.z - shrink
		if radius <= 0.0:
			continue
		# Ends inside the obstacle don't count: whoever hides there is covered
		# from the other side only.
		if from.distance_to(center) <= radius or to.distance_to(center) <= radius:
			continue
		var along: float = 0.0 if length_squared <= 0.0 else clampf((center - from).dot(segment) / length_squared, 0.0, 1.0)
		if center.distance_to(from + segment * along) < radius:
			return true
	return false


## The next cover on the way from [param position] to [param goal]: the spot
## right behind an obstacle (seen from the goal) that is closer to the goal
## than the walker by at least [param min_progress], at most [param max_step]
## away and not already in [param taken]. NO_SPOT when none fits.
static func find_cover_spot(position: Vector2, goal: Vector2, obstacles: Array[Vector3], taken: PackedVector2Array = PackedVector2Array(), max_step: float = 7.0, min_progress: float = 1.5, body_radius: float = 0.35) -> Vector2:
	var best_spot: Vector2 = NO_SPOT
	var best_score: float = -INF
	var distance_now: float = position.distance_to(goal)
	for obstacle: Vector3 in obstacles:
		var center: Vector2 = Vector2(obstacle.x, obstacle.y)
		var away_from_goal: Vector2 = center - goal
		if away_from_goal.length() < 0.001:
			continue
		var spot: Vector2 = center + away_from_goal.normalized() * (obstacle.z + body_radius + 0.15)
		var progress: float = distance_now - spot.distance_to(goal)
		var step: float = position.distance_to(spot)
		if progress < min_progress or step > max_step or _is_taken(spot, taken):
			continue
		# Prefer real progress with short dashes in the open.
		var score: float = progress - step * 0.6
		if score > best_score:
			best_score = score
			best_spot = spot
	return best_spot


## [param count] spots on an arc in front of the door, [param spacing] apart,
## [param distance] out along [param outward] (unit, pointing away from the house).
static func get_door_spots(door: Vector2, outward: Vector2, count: int, distance: float = 0.6, spacing: float = 0.75) -> PackedVector2Array:
	var spots: PackedVector2Array = PackedVector2Array()
	var across: Vector2 = outward.orthogonal()
	for spot_index: int in maxi(0, count):
		# Rows of five, middle first (0, +1, -1, +2, -2); later rows stand further out.
		var row: int = spot_index / DOOR_ROW_COLUMNS.size()
		var column: float = DOOR_ROW_COLUMNS[spot_index % DOOR_ROW_COLUMNS.size()]
		spots.append(door + outward * (distance + row * spacing) + across * column * spacing)
	return spots


## True when walking [param length] along [param direction] would run into
## an obstacle (ones the walker already touches don't count: it's leaving them).
static func _is_path_blocked(position: Vector2, direction: Vector2, length: float, obstacles: Array[Vector3], body_radius: float) -> bool:
	for obstacle: Vector3 in obstacles:
		var center: Vector2 = Vector2(obstacle.x, obstacle.y)
		var clearance: float = obstacle.z + body_radius
		var to_center: Vector2 = center - position
		if to_center.length() < clearance:
			if to_center.dot(direction) > 0.0:
				return true
			continue
		var along: float = clampf(to_center.dot(direction), 0.0, length)
		if center.distance_to(position + direction * along) < clearance:
			return true
	return false


static func _is_taken(spot: Vector2, taken: PackedVector2Array) -> bool:
	for other: Vector2 in taken:
		if other.distance_to(spot) < SEPARATION_DISTANCE:
			return true
	return false
