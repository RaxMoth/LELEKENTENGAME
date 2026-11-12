## Board logic for lane-defense games: a grid of lanes (side by side along X)
## and columns (along -Z, away from "home"), with one occupant per cell.
## Pure data — the visuals live in the scene that owns it.
##
##   var grid: LaneGrid = LaneGrid.new(5, 7, Vector2(1.2, 1.2), Vector3(0, 0, -2.4))
##   var cell: Vector2i = grid.position_to_cell(hit_point)      # Vector2i(lane, column)
##   if grid.is_free(cell): grid.set_occupant(cell, defender)
##
## Lane 0 is the leftmost lane (-X). Column 0 touches the home edge at
## origin.z; higher columns lie further away (-Z). Attackers walk toward +Z.
##
## Dependencies: none
class_name LaneGrid
extends RefCounted

const INVALID_CELL: Vector2i = Vector2i(-1, -1)

var lane_count: int = 5
var column_count: int = 7
## x = lane width, y = column depth (meters).
var cell_size: Vector2 = Vector2.ONE
## Ground point in the middle of the home edge.
var origin: Vector3 = Vector3.ZERO

## cell -> occupant
var _occupants: Dictionary[Vector2i, Object] = {}


func _init(lanes: int = 5, columns: int = 7, size_of_cell: Vector2 = Vector2.ONE, grid_origin: Vector3 = Vector3.ZERO) -> void:
	lane_count = lanes
	column_count = columns
	cell_size = size_of_cell
	origin = grid_origin

# ============================================
# GEOMETRY
# ============================================

func get_width() -> float:
	return lane_count * cell_size.x


func get_depth() -> float:
	return column_count * cell_size.y


## Z of the edge attackers must not cross.
func get_home_z() -> float:
	return origin.z


## Z of the edge attackers enter through.
func get_far_z() -> float:
	return origin.z - get_depth()


func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < lane_count and cell.y >= 0 and cell.y < column_count


func is_valid_lane(lane: int) -> bool:
	return lane >= 0 and lane < lane_count


## X of the middle of a lane.
func get_lane_x(lane: int) -> float:
	return origin.x + (lane + 0.5) * cell_size.x - get_width() * 0.5


## Z of the middle of a column.
func get_column_z(column: int) -> float:
	return origin.z - (column + 0.5) * cell_size.y


## Ground position of the middle of a cell.
func cell_to_position(cell: Vector2i) -> Vector3:
	return Vector3(get_lane_x(cell.x), origin.y, get_column_z(cell.y))


## Lane that contains [param x], or -1 outside the board.
func get_lane_at_x(x: float) -> int:
	var lane: int = floori((x - origin.x + get_width() * 0.5) / cell_size.x)
	return lane if is_valid_lane(lane) else -1


## Column that contains [param z], or -1 outside the board.
func get_column_at_z(z: float) -> int:
	var column: int = floori((origin.z - z) / cell_size.y)
	return column if column >= 0 and column < column_count else -1


## Cell under a world position (height is ignored), or INVALID_CELL.
func position_to_cell(world_position: Vector3) -> Vector2i:
	var lane: int = get_lane_at_x(world_position.x)
	var column: int = get_column_at_z(world_position.z)
	return Vector2i(lane, column) if lane >= 0 and column >= 0 else INVALID_CELL

# ============================================
# OCCUPANCY
# ============================================

func is_free(cell: Vector2i) -> bool:
	return is_valid_cell(cell) and get_occupant(cell) == null


func set_occupant(cell: Vector2i, occupant: Object) -> void:
	if is_valid_cell(cell):
		_occupants[cell] = occupant


func clear_cell(cell: Vector2i) -> void:
	_occupants.erase(cell)


## Occupant of a cell, or null. Freed occupants count as gone.
func get_occupant(cell: Vector2i) -> Object:
	# Untyped on purpose: a freed occupant can not be assigned to an Object variable.
	var occupant: Variant = _occupants.get(cell)
	if not is_instance_valid(occupant):
		_occupants.erase(cell)
		return null
	return occupant


func get_occupied_cells() -> Array[Vector2i]:
	var occupied_cells: Array[Vector2i] = []
	for cell: Vector2i in _occupants.keys():
		if get_occupant(cell) != null:
			occupied_cells.append(cell)
	return occupied_cells


func clear_all() -> void:
	_occupants.clear()


## Occupant that stops an attacker walking toward home in [param lane].
## [param front_z] is the attacker's leading edge; it is blocked once that
## edge is within [param stop_distance] of the middle of an occupied cell.
func get_blocker(lane: int, front_z: float, stop_distance: float) -> Object:
	var column: int = get_column_at_z(front_z)
	if column < 0 or not is_valid_lane(lane):
		return null
	var occupant: Object = get_occupant(Vector2i(lane, column))
	if occupant == null or front_z < get_column_z(column) - stop_distance:
		return null
	return occupant
