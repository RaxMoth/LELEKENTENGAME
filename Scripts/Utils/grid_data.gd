## Generic 2D grid for board / puzzle games (match-3, merge, sokoban, 2048...).
## Stores any Variant per cell and provides neighbor, match and flood-fill queries
## plus conversions between cells and world positions.
##
## Dependencies: none
class_name GridData
extends RefCounted

const NEIGHBORS_4: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const NEIGHBORS_8: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

var width: int
var height: int
var cell_size: Vector2
## World position of the top-left corner of cell (0, 0).
var origin: Vector2
var empty_value: Variant
var _cells: Array = []


func _init(grid_width: int, grid_height: int, grid_cell_size: Vector2 = Vector2(64, 64), grid_origin: Vector2 = Vector2.ZERO, empty_cell_value: Variant = null) -> void:
	width = grid_width
	height = grid_height
	cell_size = grid_cell_size
	origin = grid_origin
	empty_value = empty_cell_value
	_cells.resize(width * height)
	fill(empty_value)


func fill(value: Variant) -> void:
	_cells.fill(value)


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func get_cell(cell: Vector2i) -> Variant:
	return _cells[cell.y * width + cell.x] if is_in_bounds(cell) else empty_value


func set_cell(cell: Vector2i, value: Variant) -> void:
	if is_in_bounds(cell):
		_cells[cell.y * width + cell.x] = value


func is_empty(cell: Vector2i) -> bool:
	return get_cell(cell) == empty_value


func swap_cells(first_cell: Vector2i, second_cell: Vector2i) -> void:
	var first_value: Variant = get_cell(first_cell)
	set_cell(first_cell, get_cell(second_cell))
	set_cell(second_cell, first_value)


func get_neighbors(cell: Vector2i, include_diagonals: bool = false) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for offset: Vector2i in (NEIGHBORS_8 if include_diagonals else NEIGHBORS_4):
		if is_in_bounds(cell + offset):
			neighbors.append(cell + offset)
	return neighbors


func get_all_cells() -> Array[Vector2i]:
	var all_cells: Array[Vector2i] = []
	for row: int in height:
		for column: int in width:
			all_cells.append(Vector2i(column, row))
	return all_cells


func cell_to_world(cell: Vector2i) -> Vector2:
	return origin + Vector2(cell) * cell_size + cell_size * 0.5


func world_to_cell(world_position: Vector2) -> Vector2i:
	var local_position: Vector2 = (world_position - origin) / cell_size
	return Vector2i(floori(local_position.x), floori(local_position.y))


## Returns every cell that belongs to a horizontal or vertical run of at least
## [param minimum_run] equal, non-empty values (classic match-3 rule).
func find_line_matches(minimum_run: int = 3) -> Array[Vector2i]:
	var matched: Dictionary[Vector2i, bool] = {}
	for row: int in height:
		_collect_runs(Vector2i(0, row), Vector2i.RIGHT, width, minimum_run, matched)
	for column: int in width:
		_collect_runs(Vector2i(column, 0), Vector2i.DOWN, height, minimum_run, matched)
	var matched_cells: Array[Vector2i] = []
	matched_cells.assign(matched.keys())
	return matched_cells


## Connected region of cells sharing the start cell's value.
func flood_fill(start_cell: Vector2i, include_diagonals: bool = false) -> Array[Vector2i]:
	var region: Array[Vector2i] = []
	if not is_in_bounds(start_cell) or is_empty(start_cell):
		return region
	var target_value: Variant = get_cell(start_cell)
	var visited: Dictionary[Vector2i, bool] = {start_cell: true}
	var frontier: Array[Vector2i] = [start_cell]
	while not frontier.is_empty():
		var current_cell: Vector2i = frontier.pop_back()
		region.append(current_cell)
		for neighbor: Vector2i in get_neighbors(current_cell, include_diagonals):
			if not visited.has(neighbor) and get_cell(neighbor) == target_value:
				visited[neighbor] = true
				frontier.append(neighbor)
	return region


func _collect_runs(start_cell: Vector2i, step: Vector2i, line_length: int, minimum_run: int, matched: Dictionary[Vector2i, bool]) -> void:
	var run_start: int = 0
	for line_index: int in range(1, line_length + 1):
		var run_continues: bool = false
		if line_index < line_length:
			var current_value: Variant = get_cell(start_cell + step * line_index)
			run_continues = current_value != empty_value and current_value == get_cell(start_cell + step * run_start)
		if not run_continues:
			if line_index - run_start >= minimum_run and get_cell(start_cell + step * run_start) != empty_value:
				for run_index: int in range(run_start, line_index):
					matched[start_cell + step * run_index] = true
			run_start = line_index
