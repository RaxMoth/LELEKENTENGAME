## Unit tests for walking between floor heights: a WalkableRamp (stairs)
## from the main floor down to a WalkableFloor (a cellar) through a hole in
## the main floor, with WalkableArea picking the surface nearest the feet.
##
## Dependencies: gdUnit4, WalkableArea, WalkableFloor, WalkableRamp
extends GdUnitTestSuite

const CELLAR_HEIGHT: float = -2.6
## A room on the main floor, x 0..6, z 0..4.
const ROOM: Rect2 = Rect2(0.0, 0.0, 6.0, 4.0)
## The stairwell along the room's south side, high end at x = 1, low end at x = 5.
const STAIRWELL: Rect2 = Rect2(1.0, 0.0, 4.0, 1.0)
const TOLERANCE: float = 0.001


## The room, a stairwell down to a cellar under it, the cellar floor
## around (not under) the stairs.
func _make_area() -> WalkableArea:
	var area: WalkableArea = auto_free(WalkableArea.new()) as WalkableArea
	area.regions = [ROOM]
	area.add_hole(STAIRWELL)
	area.add_ramp(WalkableRamp.create(STAIRWELL, 0.0, CELLAR_HEIGHT, WalkableRamp.Edge.MIN_X))
	area.add_floor(WalkableFloor.create(CELLAR_HEIGHT, [Rect2(0.0, 1.0, 6.0, 3.0), Rect2(5.0, 0.0, 1.0, 1.0)]))
	return area


func test_ramp_height_runs_from_top_to_bottom() -> void:
	var ramp: WalkableRamp = WalkableRamp.create(STAIRWELL, 0.0, CELLAR_HEIGHT, WalkableRamp.Edge.MIN_X)
	assert_float(ramp.get_height(Vector2(1.0, 0.5))).is_equal_approx(0.0, TOLERANCE)
	assert_float(ramp.get_height(Vector2(3.0, 0.5))).is_equal_approx(CELLAR_HEIGHT * 0.5, TOLERANCE)
	assert_float(ramp.get_height(Vector2(5.0, 0.5))).is_equal_approx(CELLAR_HEIGHT, TOLERANCE)
	var rising_toward_z: WalkableRamp = WalkableRamp.create(Rect2(0.0, 0.0, 1.0, 2.0), 1.0, 0.0, WalkableRamp.Edge.MAX_Z)
	assert_float(rising_toward_z.get_height(Vector2(0.5, 1.5))).is_equal_approx(0.75, TOLERANCE)


func test_floor_height_is_the_surface_nearest_the_feet() -> void:
	var area: WalkableArea = _make_area()
	# Above the cellar: upstairs on the main floor, downstairs on the cellar floor.
	assert_float(area.get_floor_height_at(Vector3(3.0, 0.0, 3.0))).is_equal_approx(0.0, TOLERANCE)
	assert_float(area.get_floor_height_at(Vector3(3.0, CELLAR_HEIGHT, 3.0))).is_equal_approx(CELLAR_HEIGHT, TOLERANCE)
	# Half way up nothing is near: no floor there.
	assert_bool(is_nan(area.get_floor_height_at(Vector3(3.0, -1.3, 3.0)))).is_true()


func test_hole_is_not_walkable_on_the_main_floor() -> void:
	var area: WalkableArea = _make_area()
	assert_bool(area.contains(Vector3(3.0, 0.0, 0.5))).is_false()
	area.remove_hole(STAIRWELL)
	assert_bool(area.contains(Vector3(3.0, 0.0, 0.5))).is_true()


func test_walking_down_the_ramp_lowers_the_feet() -> void:
	var area: WalkableArea = _make_area()
	var feet: Vector3 = Vector3(1.05, 0.0, 1.2)
	# Onto the top of the stairs from the side: a small step down.
	feet = area.clamp_move(feet, Vector3(1.05, feet.y, 0.5))
	assert_float(feet.z).is_equal_approx(0.5, TOLERANCE)
	assert_float(feet.y).is_less(0.0)
	for step_index: int in 39:
		feet = area.clamp_move(feet, feet + Vector3(0.1, 0.0, 0.0))
	assert_float(feet.x).is_equal_approx(4.95, TOLERANCE)
	assert_float(feet.y).is_equal_approx(CELLAR_HEIGHT, 0.1)
	# Off the bottom onto the cellar floor.
	feet = area.clamp_move(feet, Vector3(5.5, feet.y, 0.5))
	assert_float(feet.x).is_equal_approx(5.5, TOLERANCE)
	assert_float(feet.y).is_equal_approx(CELLAR_HEIGHT, TOLERANCE)


func test_no_stepping_off_an_edge_or_into_the_middle_of_the_stairs() -> void:
	var area: WalkableArea = _make_area()
	# From the room into the stairwell half way down: a drop, so blocked.
	var upstairs: Vector3 = Vector3(3.0, 0.0, 1.2)
	assert_vector(area.clamp_move(upstairs, Vector3(3.0, 0.0, 0.8))).is_equal(upstairs)
	# From the cellar up onto the middle of the stairs: too high.
	var downstairs: Vector3 = Vector3(3.0, CELLAR_HEIGHT, 1.2)
	assert_vector(area.clamp_move(downstairs, Vector3(3.0, CELLAR_HEIGHT, 0.8))).is_equal(downstairs)


func test_blockers_stand_on_every_floor() -> void:
	var area: WalkableArea = _make_area()
	area.add_blockers([Vector3(3.0, 3.0, 0.3)])
	assert_bool(area.contains(Vector3(3.0, 0.0, 3.0))).is_false()
	assert_bool(area.contains(Vector3(3.0, CELLAR_HEIGHT, 3.0))).is_false()


func test_a_single_floor_works_as_before() -> void:
	var area: WalkableArea = auto_free(WalkableArea.new()) as WalkableArea
	area.regions = [ROOM]
	assert_bool(area.contains(Vector3(2.0, 0.0, 2.0))).is_true()
	assert_bool(area.contains(Vector3(7.0, 0.0, 2.0))).is_false()
	var slid: Vector3 = area.clamp_move(Vector3(5.8, 0.0, 2.0), Vector3(6.3, 0.0, 2.5))
	assert_vector(slid).is_equal(Vector3(5.8, 0.0, 2.5))


func test_furniture_blocks_only_its_own_floor() -> void:
	var area: WalkableArea = _make_area()
	area.add_obstacle(Rect2(2.5, 2.5, 1.0, 0.5), 0.0)
	assert_bool(area.contains(Vector3(3.0, 0.0, 2.75))).is_false()
	# The cellar under the table is free.
	assert_bool(area.contains(Vector3(3.0, CELLAR_HEIGHT, 2.75))).is_true()
	# Close to the table is fine (a smaller margin than a wall's blocker).
	assert_bool(area.contains(Vector3(3.0, 0.0, 2.5 - WalkableArea.OBSTACLE_MARGIN - 0.02))).is_true()
	area.clear_obstacles()
	assert_bool(area.contains(Vector3(3.0, 0.0, 2.75))).is_true()


func test_a_player_caught_in_furniture_can_walk_out() -> void:
	var area: WalkableArea = _make_area()
	area.add_obstacle(Rect2(2.0, 2.0, 2.0, 1.0), 0.0)
	var inside: Vector3 = Vector3(3.0, 0.0, 2.5)
	var moved: Vector3 = area.clamp_move(inside, inside + Vector3(0.0, 0.0, 0.1))
	assert_float(moved.z).is_equal_approx(2.6, 0.001)
