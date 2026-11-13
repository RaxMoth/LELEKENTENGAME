## Ways through the town's street grid: the crossings of the streets are the
## nodes, the street pieces between them the links. A police squad sets off
## at a crossing some way from the house and follows its own way there —
## every way is the shortest under randomly stretched street lengths, so
## squads of one raid come from different sides and take different streets,
## and no two raids look the same.
##
##   var streets: StreetRoutes = StreetRoutes.new(town_data.street_x, town_data.street_z)
##   var start: int = streets.pick_start(house_point, Vector2(110, 190), taken_directions, random)
##   var way: PackedVector2Array = streets.find_route(start, streets.get_nearest_node(target), 2.2, random)
##   way = StreetRoutes.offset_route(way, 2.5)    # one officer's lane
##
## Pure logic (unit-tested in Tests/Unit/street_routes_test.gd).
##
## Dependencies: none
class_name StreetRoutes
extends RefCounted

var _xs: PackedFloat32Array = PackedFloat32Array()
var _zs: PackedFloat32Array = PackedFloat32Array()


## [param street_x] / [param street_z]: centre lines of the streets
## (TownData.street_x / street_z), ascending.
func _init(street_x: PackedFloat32Array, street_z: PackedFloat32Array) -> void:
	_xs = street_x
	_zs = street_z


func get_node_count() -> int:
	return _xs.size() * _zs.size()


## Where crossing [param node] lies (world X / Z).
func get_node_position(node: int) -> Vector2:
	return Vector2(_xs[node % _xs.size()], _zs[node / _xs.size()])


## The crossing nearest to [param point].
func get_nearest_node(point: Vector2) -> int:
	var nearest: int = 0
	var nearest_distance: float = INF
	for node: int in get_node_count():
		var distance: float = get_node_position(node).distance_squared_to(point)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = node
	return nearest


## The crossings next to [param node] along a street.
func get_neighbors(node: int) -> PackedInt32Array:
	var neighbors: PackedInt32Array = PackedInt32Array()
	var column: int = node % _xs.size()
	var row: int = node / _xs.size()
	if column > 0:
		neighbors.append(node - 1)
	if column < _xs.size() - 1:
		neighbors.append(node + 1)
	if row > 0:
		neighbors.append(node - _xs.size())
	if row < _zs.size() - 1:
		neighbors.append(node + _xs.size())
	return neighbors


## A crossing between [param distance_range] (meters, x = nearest, y = farthest)
## from [param target] to set off from, in a direction (one of eight around
## the target) that is not in [param taken_directions] yet when that can be
## helped. The chosen direction is appended to [param taken_directions].
func pick_start(target: Vector2, distance_range: Vector2, taken_directions: Array[int], random: RandomNumberGenerator) -> int:
	var in_range: Array[int] = []
	var fresh: Array[int] = []
	for node: int in get_node_count():
		var distance: float = get_node_position(node).distance_to(target)
		if distance < distance_range.x or distance > distance_range.y:
			continue
		in_range.append(node)
		if not taken_directions.has(get_direction_index(target, get_node_position(node))):
			fresh.append(node)
	var candidates: Array[int] = fresh if not fresh.is_empty() else in_range
	if candidates.is_empty():
		# The town is smaller than the range: the farthest crossing it has.
		var farthest: int = 0
		for node: int in get_node_count():
			if get_node_position(node).distance_to(target) > get_node_position(farthest).distance_to(target):
				farthest = node
		candidates.append(farthest)
	var picked: int = candidates[random.randi_range(0, candidates.size() - 1)]
	taken_directions.append(get_direction_index(target, get_node_position(picked)))
	return picked


## Which of eight directions (0 = +X, counter-clockwise) [param point] lies in, seen from [param target].
static func get_direction_index(target: Vector2, point: Vector2) -> int:
	var angle: float = (point - target).angle()
	return posmod(roundi(angle / (TAU / 8.0)), 8)


## The crossings from [param from_node] to [param to_node] (both included, as
## positions): the shortest way when every street piece is stretched by a
## random factor between 1 and [param variety] (1 = plain shortest way).
func find_route(from_node: int, to_node: int, variety: float, random: RandomNumberGenerator) -> PackedVector2Array:
	var count: int = get_node_count()
	var distances: PackedFloat32Array = PackedFloat32Array()
	var parents: PackedInt32Array = PackedInt32Array()
	var done: Array[bool] = []
	distances.resize(count)
	parents.resize(count)
	done.resize(count)
	for node: int in count:
		distances[node] = INF
		parents[node] = -1
		done[node] = false
	# One stretch per street piece for this whole search, so a detour stays consistent.
	var stretch: Dictionary[int, float] = {}
	distances[from_node] = 0.0
	for step: int in count:
		var current: int = -1
		for node: int in count:
			if not done[node] and (current < 0 or distances[node] < distances[current]):
				current = node
		if current < 0 or is_inf(distances[current]) or current == to_node:
			break
		done[current] = true
		for neighbor: int in get_neighbors(current):
			var key: int = mini(current, neighbor) * count + maxi(current, neighbor)
			if not stretch.has(key):
				stretch[key] = random.randf_range(1.0, maxf(1.0, variety))
			var length: float = get_node_position(current).distance_to(get_node_position(neighbor)) * stretch[key]
			if distances[current] + length < distances[neighbor]:
				distances[neighbor] = distances[current] + length
				parents[neighbor] = current
	var route: PackedVector2Array = PackedVector2Array()
	var node_on_way: int = to_node
	while node_on_way >= 0:
		route.insert(0, get_node_position(node_on_way))
		if node_on_way == from_node:
			break
		node_on_way = parents[node_on_way]
	return route


## [param route] moved [param lateral] meters to one side of the walking
## direction (the sign picks the side): one officer's lane down the
## street, so a squad spreads over the street's width instead of walking in
## a single file. Corners keep the offset of both streets.
static func offset_route(route: PackedVector2Array, lateral: float) -> PackedVector2Array:
	if route.size() < 2 or is_zero_approx(lateral):
		return route
	var moved: PackedVector2Array = PackedVector2Array()
	for point_index: int in route.size():
		var incoming: Vector2 = Vector2.ZERO
		var outgoing: Vector2 = Vector2.ZERO
		if point_index > 0:
			incoming = (route[point_index] - route[point_index - 1]).normalized()
		if point_index < route.size() - 1:
			outgoing = (route[point_index + 1] - route[point_index]).normalized()
		var side: Vector2 = Vector2.ZERO
		if incoming != Vector2.ZERO:
			side += Vector2(-incoming.y, incoming.x)
		if outgoing != Vector2.ZERO:
			side += Vector2(-outgoing.y, outgoing.x)
		# Straight on: the same side twice; at a corner the two sides add up to the diagonal.
		var both: bool = incoming != Vector2.ZERO and outgoing != Vector2.ZERO
		if both and incoming.dot(outgoing) > 0.99:
			side *= 0.5
		moved.append(route[point_index] + side * lateral)
	return moved


## Length of [param route] in meters.
static func get_length(route: PackedVector2Array) -> float:
	var length: float = 0.0
	for point_index: int in range(1, route.size()):
		length += route[point_index - 1].distance_to(route[point_index])
	return length
