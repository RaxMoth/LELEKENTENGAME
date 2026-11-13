## Unit tests for MapProjection (the phone map's world <-> map pixels).
##
## Dependencies: gdUnit4, MapProjection
extends GdUnitTestSuite


func test_the_center_lands_in_the_middle() -> void:
	var projection: MapProjection = MapProjection.new(Vector2(400.0, 600.0), 100.0)
	projection.center = Vector2(30.0, -12.0)
	assert_vector(projection.to_map(Vector2(30.0, -12.0))).is_equal(Vector2(200.0, 300.0))


func test_north_is_up_and_east_is_right() -> void:
	var projection: MapProjection = MapProjection.new(Vector2(400.0, 600.0), 100.0)
	# 400 px across 100 m: 4 px per meter.
	assert_float(projection.get_scale()).is_equal_approx(4.0, 0.0001)
	assert_vector(projection.to_map(Vector2(10.0, 0.0))).is_equal(Vector2(240.0, 300.0))
	assert_vector(projection.to_map(Vector2(0.0, -10.0))).is_equal(Vector2(200.0, 260.0))


func test_to_world_undoes_to_map() -> void:
	var projection: MapProjection = MapProjection.new(Vector2(540.0, 760.0), 160.0)
	projection.center = Vector2(-80.0, 45.0)
	var world: Vector2 = Vector2(-61.5, 12.25)
	assert_vector(projection.to_world(projection.to_map(world))).is_equal_approx(world, Vector2(0.001, 0.001))


func test_rects_scale_with_the_span() -> void:
	var projection: MapProjection = MapProjection.new(Vector2(400.0, 400.0), 200.0)
	var rect: Rect2 = projection.rect_to_map(Rect2(0.0, 0.0, 10.0, 20.0))
	assert_vector(rect.position).is_equal(Vector2(200.0, 200.0))
	assert_vector(rect.size).is_equal(Vector2(20.0, 40.0))
	assert_vector(projection.get_visible_world_rect().size).is_equal(Vector2(200.0, 200.0))


func test_off_map_points_are_pulled_to_the_edge() -> void:
	var projection: MapProjection = MapProjection.new(Vector2(400.0, 400.0), 100.0)
	var far_east: Vector2 = projection.to_map(Vector2(500.0, 0.0))
	assert_bool(projection.is_on_map(far_east)).is_false()
	var edge: Vector2 = projection.clamp_to_edge(far_east, 20.0)
	assert_float(edge.x).is_equal_approx(380.0, 0.001)
	assert_float(edge.y).is_equal_approx(200.0, 0.001)
	# A point already on the map stays where it is.
	assert_vector(projection.clamp_to_edge(Vector2(150.0, 260.0), 20.0)).is_equal(Vector2(150.0, 260.0))


func test_heading_angles_turn_clockwise_from_north() -> void:
	assert_float(MapProjection.heading_angle(Vector2(0.0, -1.0))).is_equal_approx(0.0, 0.0001)
	assert_float(MapProjection.heading_angle(Vector2(1.0, 0.0))).is_equal_approx(PI * 0.5, 0.0001)
	assert_float(absf(MapProjection.heading_angle(Vector2(0.0, 1.0)))).is_equal_approx(PI, 0.0001)
