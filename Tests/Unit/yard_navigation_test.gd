## Unit tests for moving through the open yard: YardNavigation (steering
## around obstacles, staying out of them, line of sight, cover, door spots).
##
## Dependencies: gdUnit4
extends GdUnitTestSuite


## Walks [param start] toward [param target] the way a raider does; returns
## the closest it ever came to any obstacle's edge and where it ended.
func _walk(start: Vector2, target: Vector2, obstacles: Array[Vector3]) -> Array:
	var position: Vector2 = start
	var previous: Vector2 = Vector2.ZERO
	var closest_edge: float = INF
	for frame: int in 1200:
		var direction: Vector2 = YardNavigation.steer(position, target, obstacles, PackedVector2Array(), 0.35, previous)
		previous = direction
		position = YardNavigation.resolve_overlap(position + direction * 2.0 / 60.0, obstacles)
		for obstacle: Vector3 in obstacles:
			closest_edge = minf(closest_edge, position.distance_to(Vector2(obstacle.x, obstacle.y)) - obstacle.z)
		if position.distance_to(target) < 0.1:
			break
	return [closest_edge, position]


func test_walkers_reach_the_target_around_a_tree() -> void:
	var obstacles: Array[Vector3] = [Vector3(4.0, 0.15, 1.0)]
	var result: Array = _walk(Vector2.ZERO, Vector2(8.0, 0.0), obstacles)
	assert_float(result[0] as float).is_greater_equal(0.3)
	assert_float((result[1] as Vector2).distance_to(Vector2(8.0, 0.0))).is_less(0.1)


func test_walkers_find_their_way_through_a_grove() -> void:
	var obstacles: Array[Vector3] = [Vector3(3.0, -0.6, 0.8), Vector3(3.2, 1.4, 0.7), Vector3(6.0, 0.3, 0.9), Vector3(8.5, -1.0, 0.6)]
	var result: Array = _walk(Vector2(0.0, 0.2), Vector2(11.0, 0.0), obstacles)
	assert_float(result[0] as float).is_greater_equal(0.25)
	assert_float((result[1] as Vector2).distance_to(Vector2(11.0, 0.0))).is_less(0.1)


func test_steering_keeps_raiders_apart() -> void:
	var neighbours: PackedVector2Array = PackedVector2Array([Vector2(0.0, 0.3)])
	var direction: Vector2 = YardNavigation.steer(Vector2.ZERO, Vector2(10.0, 0.0), [], neighbours)
	assert_float(direction.y).is_less(0.0)
	assert_vector(YardNavigation.steer(Vector2.ONE, Vector2.ONE, [])).is_equal(Vector2.ZERO)


func test_overlaps_are_pushed_out() -> void:
	var obstacles: Array[Vector3] = [Vector3(0.0, 0.0, 1.0)]
	var resolved: Vector2 = YardNavigation.resolve_overlap(Vector2(0.5, 0.0), obstacles, 0.3)
	assert_float(resolved.length()).is_equal_approx(1.3, 0.001)


func test_obstacles_block_the_line_of_fire() -> void:
	var obstacles: Array[Vector3] = [Vector3(5.0, 0.0, 1.0)]
	assert_bool(YardNavigation.is_line_blocked(Vector2.ZERO, Vector2(10.0, 0.0), obstacles)).is_true()
	assert_bool(YardNavigation.is_line_blocked(Vector2.ZERO, Vector2(10.0, 3.0), obstacles)).is_false()
	assert_bool(YardNavigation.is_line_blocked(Vector2.ZERO, Vector2(4.0, 0.0), obstacles)).is_false()


func test_cover_is_behind_an_obstacle_on_the_way() -> void:
	var door: Vector2 = Vector2(0.0, 0.0)
	var obstacles: Array[Vector3] = [Vector3(0.0, -6.0, 1.0), Vector3(8.0, -6.0, 1.0)]
	var spot: Vector2 = YardNavigation.find_cover_spot(Vector2(0.5, -12.0), door, obstacles)
	assert_vector(spot).is_not_equal(YardNavigation.NO_SPOT)
	# Behind the near tree as seen from the door, closer than the walker.
	assert_float(spot.x).is_equal_approx(0.0, 0.01)
	assert_float(spot.y).is_less(-6.0)
	var taken: PackedVector2Array = PackedVector2Array([spot])
	assert_vector(YardNavigation.find_cover_spot(Vector2(0.5, -12.0), door, obstacles, taken)).is_not_equal(spot)


func test_no_cover_when_nothing_is_closer_to_the_door() -> void:
	var obstacles: Array[Vector3] = [Vector3(0.0, -20.0, 1.0)]
	assert_vector(YardNavigation.find_cover_spot(Vector2(0.0, -8.0), Vector2.ZERO, obstacles)).is_equal(YardNavigation.NO_SPOT)


func test_door_spots_line_up_in_front_of_the_door() -> void:
	var spots: PackedVector2Array = YardNavigation.get_door_spots(Vector2(0.0, -5.0), Vector2(0.0, -1.0), 7, 0.6, 0.75)
	assert_int(spots.size()).is_equal(7)
	assert_vector(spots[0]).is_equal_approx(Vector2(0.0, -5.6), Vector2(0.001, 0.001))
	for first: int in spots.size():
		assert_float(spots[first].y).is_less(-5.0)
		for second: int in range(first + 1, spots.size()):
			assert_float(spots[first].distance_to(spots[second])).is_greater(0.5)
