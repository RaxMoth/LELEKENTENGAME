## Unit tests for the police's ways through the town: StreetRoutes (street
## grid, starting points around the house, varied routes, lanes).
##
## Dependencies: gdUnit4
extends GdUnitTestSuite

const XS: PackedFloat32Array = [-100.0, -50.0, 0.0, 50.0, 100.0]
const ZS: PackedFloat32Array = [-100.0, -50.0, 0.0, 50.0, 100.0]


func _streets() -> StreetRoutes:
	return StreetRoutes.new(XS, ZS)


func _seeded(seed_value: int) -> RandomNumberGenerator:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed_value
	return random


func test_crossings_link_along_the_streets() -> void:
	var streets: StreetRoutes = _streets()
	assert_int(streets.get_node_count()).is_equal(25)
	var middle: int = streets.get_nearest_node(Vector2(2.0, -3.0))
	assert_vector(streets.get_node_position(middle)).is_equal(Vector2(0.0, 0.0))
	assert_int(streets.get_neighbors(middle).size()).is_equal(4)
	assert_int(streets.get_neighbors(0).size()).is_equal(2)


func test_a_route_follows_the_streets_from_start_to_goal() -> void:
	var streets: StreetRoutes = _streets()
	var route: PackedVector2Array = streets.find_route(0, 24, 1.0, _seeded(1))
	assert_vector(route[0]).is_equal(Vector2(-100.0, -100.0))
	assert_vector(route[route.size() - 1]).is_equal(Vector2(100.0, 100.0))
	# Plain shortest way on a grid: 8 street pieces, each along one axis.
	assert_int(route.size()).is_equal(9)
	for point_index: int in range(1, route.size()):
		var step: Vector2 = route[point_index] - route[point_index - 1]
		assert_bool(is_zero_approx(step.x) or is_zero_approx(step.y)).is_true()
	assert_float(StreetRoutes.get_length(route)).is_equal_approx(400.0, 0.01)


func test_variety_gives_different_ways() -> void:
	var streets: StreetRoutes = _streets()
	var ways: Dictionary[String, bool] = {}
	for seed_value: int in 12:
		ways[str(streets.find_route(0, 24, 2.5, _seeded(seed_value)))] = true
	assert_int(ways.size()).is_greater(3)


func test_squads_start_in_range_and_from_different_directions() -> void:
	var streets: StreetRoutes = _streets()
	var random: RandomNumberGenerator = _seeded(5)
	var taken: Array[int] = []
	var house: Vector2 = Vector2.ZERO
	for squad: int in 4:
		var start: int = streets.pick_start(house, Vector2(60.0, 150.0), taken, random)
		var distance: float = streets.get_node_position(start).distance_to(house)
		assert_float(distance).is_between(60.0, 150.0)
	# Four squads, four different directions.
	var unique: Dictionary[int, bool] = {}
	for direction: int in taken:
		unique[direction] = true
	assert_int(unique.size()).is_equal(4)


func test_lanes_shift_the_whole_route_sideways() -> void:
	var route: PackedVector2Array = [Vector2(0.0, 0.0), Vector2(50.0, 0.0), Vector2(50.0, 50.0)]
	var lane: PackedVector2Array = StreetRoutes.offset_route(route, 2.0)
	assert_float(absf(lane[0].y)).is_equal_approx(2.0, 0.001)
	# The corner keeps its distance from both streets.
	assert_float(absf(lane[1].y)).is_equal_approx(2.0, 0.001)
	assert_float(absf(lane[1].x - 50.0)).is_equal_approx(2.0, 0.001)
	assert_float(absf(lane[2].x - 50.0)).is_equal_approx(2.0, 0.001)


func test_a_segment_finds_where_it_enters_a_building() -> void:
	var building: Rect2 = Rect2(10.0, -5.0, 10.0, 10.0)
	assert_float(RayMath.segment_enters_rect(Vector2(0.0, 0.0), Vector2(40.0, 0.0), building)).is_equal_approx(0.25, 0.001)
	# Starting inside counts from the start.
	assert_float(RayMath.segment_enters_rect(Vector2(15.0, 0.0), Vector2(40.0, 0.0), building)).is_equal(0.0)
	# Passing beside it, stopping short of it, or running parallel outside: no hit.
	assert_float(RayMath.segment_enters_rect(Vector2(0.0, 8.0), Vector2(40.0, 8.0), building)).is_equal(-1.0)
	assert_float(RayMath.segment_enters_rect(Vector2(0.0, 0.0), Vector2(5.0, 0.0), building)).is_equal(-1.0)
	# Clipping a corner diagonally.
	assert_float(RayMath.segment_enters_rect(Vector2(5.0, -12.0), Vector2(14.0, -3.0), building)).is_greater(0.0)
