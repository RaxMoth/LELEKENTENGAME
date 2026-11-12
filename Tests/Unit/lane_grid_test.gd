## Unit tests for LaneGrid (board logic of lane-defense games).
##
## Dependencies: gdUnit4
extends GdUnitTestSuite

const LANES: int = 5
const COLUMNS: int = 7
const CELL: Vector2 = Vector2(1.2, 1.0)
## Home edge of the test board.
const ORIGIN: Vector3 = Vector3(10.0, 0.5, -2.0)


func _create_grid() -> LaneGrid:
	return LaneGrid.new(LANES, COLUMNS, CELL, ORIGIN)


func test_reports_its_size_and_edges() -> void:
	var grid: LaneGrid = _create_grid()
	assert_float(grid.get_width()).is_equal_approx(6.0, 0.0001)
	assert_float(grid.get_depth()).is_equal_approx(7.0, 0.0001)
	assert_float(grid.get_home_z()).is_equal_approx(-2.0, 0.0001)
	assert_float(grid.get_far_z()).is_equal_approx(-9.0, 0.0001)


func test_lanes_run_left_to_right_and_columns_away_from_home() -> void:
	var grid: LaneGrid = _create_grid()
	assert_float(grid.get_lane_x(0)).is_equal_approx(7.6, 0.0001)
	assert_float(grid.get_lane_x(4)).is_equal_approx(12.4, 0.0001)
	assert_float(grid.get_column_z(0)).is_equal_approx(-2.5, 0.0001)
	assert_float(grid.get_column_z(6)).is_equal_approx(-8.5, 0.0001)
	assert_vector(grid.cell_to_position(Vector2i(2, 3))).is_equal_approx(Vector3(10.0, 0.5, -5.5), Vector3.ONE * 0.0001)


func test_position_to_cell_round_trips_every_cell() -> void:
	var grid: LaneGrid = _create_grid()
	for lane: int in LANES:
		for column: int in COLUMNS:
			var cell: Vector2i = Vector2i(lane, column)
			assert_vector(grid.position_to_cell(grid.cell_to_position(cell))).is_equal(cell)


func test_position_to_cell_ignores_height_and_rejects_outside() -> void:
	var grid: LaneGrid = _create_grid()
	assert_vector(grid.position_to_cell(Vector3(10.0, 99.0, -2.1))).is_equal(Vector2i(2, 0))
	assert_vector(grid.position_to_cell(Vector3(6.9, 0.5, -3.0))).is_equal(LaneGrid.INVALID_CELL)
	assert_vector(grid.position_to_cell(Vector3(13.1, 0.5, -3.0))).is_equal(LaneGrid.INVALID_CELL)
	assert_vector(grid.position_to_cell(Vector3(10.0, 0.5, -1.9))).is_equal(LaneGrid.INVALID_CELL)
	assert_vector(grid.position_to_cell(Vector3(10.0, 0.5, -9.1))).is_equal(LaneGrid.INVALID_CELL)


func test_is_valid_cell_checks_both_axes() -> void:
	var grid: LaneGrid = _create_grid()
	assert_bool(grid.is_valid_cell(Vector2i(0, 0))).is_true()
	assert_bool(grid.is_valid_cell(Vector2i(4, 6))).is_true()
	assert_bool(grid.is_valid_cell(Vector2i(5, 0))).is_false()
	assert_bool(grid.is_valid_cell(Vector2i(0, 7))).is_false()
	assert_bool(grid.is_valid_cell(LaneGrid.INVALID_CELL)).is_false()


func test_occupancy_set_get_clear() -> void:
	var grid: LaneGrid = _create_grid()
	var occupant: RefCounted = RefCounted.new()
	var cell: Vector2i = Vector2i(1, 2)
	assert_bool(grid.is_free(cell)).is_true()
	grid.set_occupant(cell, occupant)
	assert_bool(grid.is_free(cell)).is_false()
	assert_object(grid.get_occupant(cell)).is_same(occupant)
	assert_array(grid.get_occupied_cells()).contains_exactly([cell])
	grid.clear_cell(cell)
	assert_bool(grid.is_free(cell)).is_true()
	assert_array(grid.get_occupied_cells()).is_empty()


func test_cells_outside_the_board_are_never_free_or_occupied() -> void:
	var grid: LaneGrid = _create_grid()
	grid.set_occupant(Vector2i(9, 9), RefCounted.new())
	assert_bool(grid.is_free(Vector2i(9, 9))).is_false()
	assert_object(grid.get_occupant(Vector2i(9, 9))).is_null()


func test_freed_occupants_count_as_gone() -> void:
	var grid: LaneGrid = _create_grid()
	var occupant: Node = Node.new()
	grid.set_occupant(Vector2i(0, 0), occupant)
	occupant.free()
	assert_object(grid.get_occupant(Vector2i(0, 0))).is_null()
	assert_bool(grid.is_free(Vector2i(0, 0))).is_true()


func test_blocker_stops_an_attacker_only_once_it_is_close_enough() -> void:
	var grid: LaneGrid = _create_grid()
	var defender: RefCounted = RefCounted.new()
	grid.set_occupant(Vector2i(2, 3), defender)
	var cell_middle_z: float = grid.get_column_z(3)
	# Entering the cell from the far side: not yet at the defender.
	assert_object(grid.get_blocker(2, cell_middle_z - 0.45, 0.4)).is_null()
	assert_object(grid.get_blocker(2, cell_middle_z - 0.4, 0.4)).is_same(defender)
	assert_object(grid.get_blocker(2, cell_middle_z + 0.3, 0.4)).is_same(defender)


func test_blocker_ignores_other_lanes_empty_cells_and_off_board_positions() -> void:
	var grid: LaneGrid = _create_grid()
	grid.set_occupant(Vector2i(2, 3), RefCounted.new())
	var cell_middle_z: float = grid.get_column_z(3)
	assert_object(grid.get_blocker(1, cell_middle_z, 0.4)).is_null()
	assert_object(grid.get_blocker(2, grid.get_column_z(4), 0.4)).is_null()
	assert_object(grid.get_blocker(2, grid.get_far_z() - 1.0, 0.4)).is_null()
	assert_object(grid.get_blocker(7, cell_middle_z, 0.4)).is_null()
