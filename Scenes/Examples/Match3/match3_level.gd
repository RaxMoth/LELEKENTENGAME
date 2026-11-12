## Example: match-3 puzzle. Swipe (or tap two neighbors) to swap gems; lines
## of 3+ clear, gems fall and cascades multiply the score. Reach the target
## score before running out of moves.
##
## Shows: GridData (matches, gravity), GestureDetector (swipe + tap),
## tween-driven board animation, LevelData.custom_parameters, stars by score.
##
## Dependencies: LevelBase, Profile, Audio, Global autoloads
extends LevelBase

const GEM_COLORS: Array[Color] = [Palette.CATEGORY[0], Palette.CATEGORY[1], Palette.CATEGORY[2], Palette.CATEGORY[3], Palette.CATEGORY[4]]
const GEM_SHAPES: Array[PlaceholderShape.ShapeKind] = [PlaceholderShape.ShapeKind.CIRCLE, PlaceholderShape.ShapeKind.DIAMOND, PlaceholderShape.ShapeKind.RECTANGLE, PlaceholderShape.ShapeKind.TRIANGLE, PlaceholderShape.ShapeKind.HEXAGON]
const EMPTY_CELL: int = -1
const PARAM_MOVES: StringName = &"moves"
const PARAM_TARGET_SCORE: StringName = &"target_score"

@export var columns: int = 7
@export var rows: int = 8
@export var cell_size: float = 92.0
@export var gem_type_count: int = 5
@export var points_per_gem: int = 10

var moves_left: int = 20
var target_score: int = 1500

var _grid: GridData
var _gem_nodes: Dictionary[Vector2i, PlaceholderShape] = {}
var _is_busy: bool = false
var _selected_cell: Vector2i = Vector2i(-1, -1)

@onready var _board_root: Node2D = %Board
@onready var _board_background: GridBackground = %BoardBackground
@onready var _gesture_detector: GestureDetector = %GestureDetector


func _on_level_setup() -> void:
	if level_data != null:
		moves_left = int(level_data.get_parameter(PARAM_MOVES, moves_left))
		target_score = int(level_data.get_parameter(PARAM_TARGET_SCORE, target_score))
	var board_size: Vector2 = Vector2(columns, rows) * cell_size
	# Center on the camera (slightly below, leaving room for the HUD) so every aspect ratio works.
	var board_origin: Vector2 = camera.global_position - board_size * 0.5 + Vector2(0.0, 40.0)
	_board_background.position = board_origin
	_board_background.area_size = board_size
	_board_background.cell_size = Vector2.ONE * cell_size
	_grid = GridData.new(columns, rows, Vector2.ONE * cell_size, board_origin, EMPTY_CELL)
	_fill_board_without_matches()
	_gesture_detector.swiped.connect(_on_swiped)
	_gesture_detector.tapped.connect(_on_tapped)
	_update_status()


func _fill_board_without_matches() -> void:
	for cell: Vector2i in _grid.get_all_cells():
		var gem_type: int = randi() % gem_type_count
		while _creates_match_at(cell, gem_type):
			gem_type = randi() % gem_type_count
		_grid.set_cell(cell, gem_type)
		_create_gem_node(cell, gem_type, _grid.cell_to_world(cell))


func _creates_match_at(cell: Vector2i, gem_type: int) -> bool:
	var left_match: bool = cell.x >= 2 and _grid.get_cell(cell + Vector2i.LEFT) == gem_type and _grid.get_cell(cell + Vector2i.LEFT * 2) == gem_type
	var up_match: bool = cell.y >= 2 and _grid.get_cell(cell + Vector2i.UP) == gem_type and _grid.get_cell(cell + Vector2i.UP * 2) == gem_type
	return left_match or up_match


func _create_gem_node(cell: Vector2i, gem_type: int, start_position: Vector2) -> PlaceholderShape:
	var gem: PlaceholderShape = PlaceholderShape.new()
	gem.shape_kind = GEM_SHAPES[gem_type % GEM_SHAPES.size()]
	gem.color = GEM_COLORS[gem_type % GEM_COLORS.size()]
	gem.size = Vector2.ONE * cell_size * 0.7
	# Pointy shapes need more rounding to read as the same visual weight as circles.
	gem.corner_roundness = 0.28 if gem.shape_kind == PlaceholderShape.ShapeKind.RECTANGLE else 0.16
	gem.position = start_position
	_board_root.add_child(gem)
	_gem_nodes[cell] = gem
	return gem

# ============================================
# INPUT
# ============================================

func _on_swiped(direction: Types.SwipeDirection, start_position: Vector2, _swipe_vector: Vector2) -> void:
	var start_cell: Vector2i = _grid.world_to_cell(Global.screen_to_world(self, start_position))
	var offsets: Dictionary[Types.SwipeDirection, Vector2i] = {
		Types.SwipeDirection.UP: Vector2i.UP, Types.SwipeDirection.DOWN: Vector2i.DOWN,
		Types.SwipeDirection.LEFT: Vector2i.LEFT, Types.SwipeDirection.RIGHT: Vector2i.RIGHT,
	}
	if offsets.has(direction):
		_clear_selection()
		_try_swap(start_cell, start_cell + offsets[direction])


func _on_tapped(screen_position: Vector2) -> void:
	var cell: Vector2i = _grid.world_to_cell(Global.screen_to_world(self, screen_position))
	if not _grid.is_in_bounds(cell) or _is_busy:
		return
	if _selected_cell.x >= 0 and (cell - _selected_cell).abs().x + (cell - _selected_cell).abs().y == 1:
		var first_cell: Vector2i = _selected_cell
		_clear_selection()
		_try_swap(first_cell, cell)
		return
	_clear_selection()
	_selected_cell = cell
	_gem_nodes[cell].scale = Vector2.ONE * 1.18


func _clear_selection() -> void:
	if _selected_cell.x >= 0 and _gem_nodes.has(_selected_cell):
		_gem_nodes[_selected_cell].scale = Vector2.ONE
	_selected_cell = Vector2i(-1, -1)

# ============================================
# BOARD LOGIC
# ============================================

func _try_swap(first_cell: Vector2i, second_cell: Vector2i) -> void:
	if _is_busy or not is_playing() or not _grid.is_in_bounds(first_cell) or not _grid.is_in_bounds(second_cell):
		return
	_is_busy = true
	await _animate_swap(first_cell, second_cell)
	if _grid.find_line_matches().is_empty():
		Audio.play_ui(Audio.UI_ERROR)
		await _animate_swap(first_cell, second_cell)
		_is_busy = false
		return
	moves_left -= 1
	await _resolve_board()
	if not _has_possible_move():
		await _shuffle_board()
	_update_status()
	_is_busy = false
	if score >= target_score:
		win()
	elif moves_left <= 0:
		lose()


func _animate_swap(first_cell: Vector2i, second_cell: Vector2i) -> void:
	_grid.swap_cells(first_cell, second_cell)
	var first_gem: PlaceholderShape = _gem_nodes[first_cell]
	var second_gem: PlaceholderShape = _gem_nodes[second_cell]
	_gem_nodes[first_cell] = second_gem
	_gem_nodes[second_cell] = first_gem
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(first_gem, "position", _grid.cell_to_world(second_cell), 0.15).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(second_gem, "position", _grid.cell_to_world(first_cell), 0.15).set_trans(Tween.TRANS_QUAD)
	await tween.finished


func _resolve_board() -> void:
	var combo: int = 1
	while true:
		var matched_cells: Array[Vector2i] = _grid.find_line_matches()
		if matched_cells.is_empty():
			return
		Profile.stats.increment(Types.STAT_MATCHES_MADE)
		add_score(matched_cells.size() * points_per_gem * combo)
		if combo >= 2:
			hud.show_message("Combo x%d" % combo, 0.7)
		Audio.play_sfx(SfxSynth.get_preset(&"pop"), 0.1, -4.0)
		await _clear_cells(matched_cells)
		await _apply_gravity_and_refill()
		combo += 1


func _clear_cells(cells: Array[Vector2i]) -> void:
	var cleared_gems: Array[PlaceholderShape] = []
	var tween: Tween = create_tween().set_parallel(true)
	for cell: Vector2i in cells:
		var gem: PlaceholderShape = _gem_nodes[cell]
		_gem_nodes.erase(cell)
		_grid.set_cell(cell, EMPTY_CELL)
		cleared_gems.append(gem)
		tween.tween_property(gem, "scale", Vector2.ZERO, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	for gem: PlaceholderShape in cleared_gems:
		gem.queue_free()


func _apply_gravity_and_refill() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	var has_animation: bool = false
	for column: int in columns:
		var write_row: int = rows - 1
		for read_row: int in range(rows - 1, -1, -1):
			var read_cell: Vector2i = Vector2i(column, read_row)
			if _grid.is_empty(read_cell):
				continue
			var write_cell: Vector2i = Vector2i(column, write_row)
			if write_cell != read_cell:
				_grid.set_cell(write_cell, _grid.get_cell(read_cell))
				_grid.set_cell(read_cell, EMPTY_CELL)
				_gem_nodes[write_cell] = _gem_nodes[read_cell]
				_gem_nodes.erase(read_cell)
				tween.tween_property(_gem_nodes[write_cell], "position", _grid.cell_to_world(write_cell), 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
				has_animation = true
			write_row -= 1
		for new_row: int in range(write_row, -1, -1):
			var new_cell: Vector2i = Vector2i(column, new_row)
			var gem_type: int = randi() % gem_type_count
			_grid.set_cell(new_cell, gem_type)
			var spawn_position: Vector2 = _grid.cell_to_world(Vector2i(column, new_row - write_row - 1))
			var gem: PlaceholderShape = _create_gem_node(new_cell, gem_type, spawn_position)
			tween.tween_property(gem, "position", _grid.cell_to_world(new_cell), 0.28).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			has_animation = true
	if has_animation:
		await tween.finished
	else:
		tween.kill()


func _has_possible_move() -> bool:
	for cell: Vector2i in _grid.get_all_cells():
		for offset: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + offset
			if not _grid.is_in_bounds(neighbor):
				continue
			_grid.swap_cells(cell, neighbor)
			var creates_match: bool = not _grid.find_line_matches().is_empty()
			_grid.swap_cells(cell, neighbor)
			if creates_match:
				return true
	return false


func _shuffle_board() -> void:
	hud.show_message("Shuffle!", 0.8)
	for gem: PlaceholderShape in _gem_nodes.values():
		gem.queue_free()
	_gem_nodes.clear()
	_grid.fill(EMPTY_CELL)
	_fill_board_without_matches()
	await Global.wait(0.3)


func _update_status() -> void:
	hud.set_progress(score, target_score, "Moves %d   ·   Target %s" % [moves_left, NumberFormat.with_separators(target_score)])
