## Unit tests for GridData (board logic used by Match-3 and other grid games).
##
## Dependencies: gdUnit4
extends GdUnitTestSuite

const GEM_RED: int = 0
const GEM_BLUE: int = 1


func test_finds_horizontal_and_vertical_runs() -> void:
	var grid: GridData = GridData.new(4, 4)
	for column: int in 3:
		grid.set_cell(Vector2i(column, 0), GEM_RED)
	for row: int in 3:
		grid.set_cell(Vector2i(3, row + 1), GEM_BLUE)
	var matches: Array[Vector2i] = grid.find_line_matches()
	assert_array(matches).contains_exactly_in_any_order([
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3),
	])


func test_ignores_runs_shorter_than_minimum_and_empty_cells() -> void:
	var grid: GridData = GridData.new(4, 4)
	grid.set_cell(Vector2i(0, 0), GEM_RED)
	grid.set_cell(Vector2i(1, 0), GEM_RED)
	grid.set_cell(Vector2i(2, 0), GEM_BLUE)
	assert_array(grid.find_line_matches()).is_empty()


func test_swap_cells_exchanges_values() -> void:
	var grid: GridData = GridData.new(2, 1)
	grid.set_cell(Vector2i(0, 0), GEM_RED)
	grid.set_cell(Vector2i(1, 0), GEM_BLUE)
	grid.swap_cells(Vector2i(0, 0), Vector2i(1, 0))
	assert_int(grid.get_cell(Vector2i(0, 0))).is_equal(GEM_BLUE)
	assert_int(grid.get_cell(Vector2i(1, 0))).is_equal(GEM_RED)


func test_flood_fill_returns_the_connected_region() -> void:
	var grid: GridData = GridData.new(3, 3)
	grid.fill(GEM_BLUE)
	grid.set_cell(Vector2i(0, 0), GEM_RED)
	grid.set_cell(Vector2i(1, 0), GEM_RED)
	grid.set_cell(Vector2i(1, 1), GEM_RED)
	assert_array(grid.flood_fill(Vector2i(0, 0))).contains_exactly_in_any_order([
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1),
	])


func test_cell_and_world_positions_round_trip() -> void:
	var grid: GridData = GridData.new(8, 8, Vector2(92, 92), Vector2(40, 200))
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(3, 5), Vector2i(7, 7)]:
		assert_that(grid.world_to_cell(grid.cell_to_world(cell))).is_equal(cell)
	assert_bool(grid.is_in_bounds(Vector2i(8, 0))).is_false()
