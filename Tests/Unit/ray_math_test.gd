## Unit tests for RayMath (pointer picking in 3D / XR scenes).
##
## Dependencies: gdUnit4
extends GdUnitTestSuite

const TOLERANCE: float = 0.0001


func test_ray_hits_the_ground_plane_below_it() -> void:
	var direction: Vector3 = Vector3(0.0, -1.0, -1.0).normalized()
	var distance: float = RayMath.intersect_ground(Vector3(0.0, 2.0, 0.0), direction, 0.0)
	assert_float(distance).is_equal_approx(2.0 * sqrt(2.0), TOLERANCE)
	assert_vector(Vector3(0.0, 2.0, 0.0) + direction * distance).is_equal_approx(Vector3(0.0, 0.0, -2.0), Vector3.ONE * TOLERANCE)


func test_ray_misses_a_plane_it_is_parallel_to_or_points_away_from() -> void:
	assert_float(RayMath.intersect_ground(Vector3(0.0, 2.0, 0.0), Vector3.FORWARD, 0.0)).is_equal(RayMath.NO_HIT)
	assert_float(RayMath.intersect_ground(Vector3(0.0, 2.0, 0.0), Vector3.UP, 0.0)).is_equal(RayMath.NO_HIT)


func test_plane_can_be_hit_from_either_side() -> void:
	var plane_point: Vector3 = Vector3(0.0, 0.0, -5.0)
	assert_float(RayMath.intersect_plane(Vector3.ZERO, Vector3.FORWARD, plane_point, Vector3.BACK)).is_equal_approx(5.0, TOLERANCE)
	assert_float(RayMath.intersect_plane(Vector3(0.0, 0.0, -8.0), Vector3.BACK, plane_point, Vector3.BACK)).is_equal_approx(3.0, TOLERANCE)


func test_ray_hits_the_near_surface_of_a_sphere() -> void:
	var distance: float = RayMath.intersect_sphere(Vector3.ZERO, Vector3.FORWARD, Vector3(0.0, 0.0, -10.0), 2.0)
	assert_float(distance).is_equal_approx(8.0, TOLERANCE)


func test_ray_misses_spheres_beside_and_behind_it() -> void:
	assert_float(RayMath.intersect_sphere(Vector3.ZERO, Vector3.FORWARD, Vector3(3.0, 0.0, -10.0), 2.0)).is_equal(RayMath.NO_HIT)
	assert_float(RayMath.intersect_sphere(Vector3.ZERO, Vector3.FORWARD, Vector3(0.0, 0.0, 10.0), 2.0)).is_equal(RayMath.NO_HIT)


func test_ray_starting_inside_a_sphere_hits_at_zero() -> void:
	assert_float(RayMath.intersect_sphere(Vector3.ZERO, Vector3.FORWARD, Vector3(0.0, 0.5, 0.0), 2.0)).is_equal(0.0)


func test_ray_grazing_a_sphere_still_hits() -> void:
	var distance: float = RayMath.intersect_sphere(Vector3.ZERO, Vector3.FORWARD, Vector3(1.99, 0.0, -10.0), 2.0)
	assert_float(distance).is_greater(9.0)


func test_distance_to_point_measures_the_closest_approach() -> void:
	assert_float(RayMath.distance_to_point(Vector3.ZERO, Vector3.FORWARD, Vector3(3.0, 4.0, -20.0))).is_equal_approx(5.0, TOLERANCE)


func test_distance_to_a_point_behind_the_ray_is_measured_from_its_origin() -> void:
	assert_float(RayMath.distance_to_point(Vector3.ZERO, Vector3.FORWARD, Vector3(0.0, 3.0, 4.0))).is_equal_approx(5.0, TOLERANCE)


func test_screen_point_maps_to_pixels_with_y_flipped() -> void:
	var size: Vector2 = Vector2(2.0, 1.0)
	var resolution: Vector2i = Vector2i(800, 400)
	assert_vector(RayMath.screen_point_to_pixel(Vector2.ZERO, size, resolution)).is_equal_approx(Vector2(400.0, 200.0), Vector2.ONE * TOLERANCE)
	assert_vector(RayMath.screen_point_to_pixel(Vector2(-1.0, 0.5), size, resolution)).is_equal_approx(Vector2.ZERO, Vector2.ONE * TOLERANCE)
	assert_vector(RayMath.screen_point_to_pixel(Vector2(1.0, -0.5), size, resolution)).is_equal_approx(Vector2(800.0, 400.0), Vector2.ONE * TOLERANCE)


func test_pixel_and_screen_point_round_trip() -> void:
	var size: Vector2 = Vector2(6.0, 1.875)
	var resolution: Vector2i = Vector2i(1280, 400)
	for pixel: Vector2 in [Vector2(0.0, 0.0), Vector2(640.0, 200.0), Vector2(1279.0, 12.0), Vector2(33.0, 399.0)]:
		var screen_point: Vector2 = RayMath.pixel_to_screen_point(pixel, size, resolution)
		assert_vector(RayMath.screen_point_to_pixel(screen_point, size, resolution)).is_equal_approx(pixel, Vector2.ONE * 0.001)


func test_is_on_screen_checks_the_half_extents() -> void:
	var size: Vector2 = Vector2(2.0, 1.0)
	assert_bool(RayMath.is_on_screen(Vector2(0.99, -0.49), size)).is_true()
	assert_bool(RayMath.is_on_screen(Vector2(1.01, 0.0), size)).is_false()
	assert_bool(RayMath.is_on_screen(Vector2(0.0, 0.51), size)).is_false()
