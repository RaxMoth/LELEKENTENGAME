## Unit tests for WalkableArea's floor math: where the player may stand and
## how blocked moves slide along walls.
##
## Dependencies: gdUnit4
extends GdUnitTestSuite

## Two rooms joined by a narrow doorway along x = 2.
var _rooms: Array[Rect2] = [Rect2(0.0, 0.0, 2.0, 2.0), Rect2(1.8, 0.8, 0.6, 0.4), Rect2(2.2, 0.0, 2.0, 2.0)]


func test_points_inside_any_region_are_walkable() -> void:
	assert_bool(WalkableArea.contains_point(_rooms, Vector2(1.0, 1.0))).is_true()
	assert_bool(WalkableArea.contains_point(_rooms, Vector2(2.1, 1.0))).is_true()
	assert_bool(WalkableArea.contains_point(_rooms, Vector2(2.1, 0.2))).is_false()


func test_no_regions_means_anywhere() -> void:
	var nowhere: Array[Rect2] = []
	assert_bool(WalkableArea.contains_point(nowhere, Vector2(99.0, -99.0))).is_true()


func test_moves_through_the_doorway() -> void:
	assert_vector(WalkableArea.resolve_move(_rooms, Vector2(1.9, 1.0), Vector2(2.3, 1.0))).is_equal(Vector2(2.3, 1.0))


func test_blocked_moves_slide_along_the_wall() -> void:
	# Walking diagonally into the wall next to the doorway keeps the sideways part.
	assert_vector(WalkableArea.resolve_move(_rooms, Vector2(1.9, 0.5), Vector2(2.1, 0.7))).is_equal(Vector2(1.9, 0.7))
	assert_vector(WalkableArea.resolve_move(_rooms, Vector2(1.9, 0.1), Vector2(2.1, -0.1))).is_equal(Vector2(1.9, 0.1))


func test_blockers_keep_the_player_out() -> void:
	var garden: Array[Rect2] = [Rect2(0.0, 0.0, 10.0, 10.0)]
	var tree: Array[Vector3] = [Vector3(5.0, 5.0, 1.0)]
	assert_bool(WalkableArea.contains_point(garden, Vector2(5.0, 5.5), tree)).is_false()
	# The body keeps its own width from the trunk too.
	assert_bool(WalkableArea.contains_point(garden, Vector2(6.1, 5.0), tree)).is_false()
	assert_bool(WalkableArea.contains_point(garden, Vector2(7.0, 5.0), tree)).is_true()


func test_walking_into_a_blocker_slides_around_it() -> void:
	var garden: Array[Rect2] = [Rect2(0.0, 0.0, 10.0, 10.0)]
	var tree: Array[Vector3] = [Vector3(5.0, 5.0, 1.0)]
	# Heading straight at the trunk: stopped there, sideways part kept.
	assert_vector(WalkableArea.resolve_move(garden, Vector2(5.0, 3.6), Vector2(5.0, 4.0), tree)).is_equal(Vector2(5.0, 3.6))
	assert_vector(WalkableArea.resolve_move(garden, Vector2(5.0, 3.6), Vector2(5.2, 3.9), tree)).is_equal(Vector2(5.2, 3.6))


func test_rectangular_blockers_keep_the_player_out() -> void:
	var town: Array[Rect2] = [Rect2(0.0, 0.0, 20.0, 20.0)]
	var building: Array[Rect2] = [Rect2(5.0, 5.0, 4.0, 4.0)]
	assert_bool(WalkableArea.contains_point(town, Vector2(7.0, 7.0), [], building)).is_false()
	# The body keeps its width from the wall too.
	assert_bool(WalkableArea.contains_point(town, Vector2(9.1, 7.0), [], building)).is_false()
	assert_bool(WalkableArea.contains_point(town, Vector2(9.5, 7.0), [], building)).is_true()


func test_walking_into_a_wall_slides_along_it() -> void:
	var town: Array[Rect2] = [Rect2(0.0, 0.0, 20.0, 20.0)]
	var building: Array[Rect2] = [Rect2(5.0, 5.0, 4.0, 4.0)]
	# Diagonally into the west wall: the move along the wall is kept.
	assert_vector(WalkableArea.resolve_move(town, Vector2(4.6, 6.0), Vector2(4.9, 6.4), [], building)).is_equal(Vector2(4.6, 6.4))
