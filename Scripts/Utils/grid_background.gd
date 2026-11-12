## Draws a filled area with grid lines — instant floor / board background for
## prototypes. Drawn once and cached by the renderer, so it's cheap.
##
## Dependencies: none
@tool
class_name GridBackground
extends Node2D

@export var area_size: Vector2 = Vector2(1024, 1024):
	set(value):
		area_size = value
		queue_redraw()
@export var cell_size: Vector2 = Vector2(64, 64):
	set(value):
		cell_size = value
		queue_redraw()
@export var fill_color: Color = Palette.WORLD:
	set(value):
		fill_color = value
		queue_redraw()
@export var line_color: Color = Color(1, 1, 1, 0.035):
	set(value):
		line_color = value
		queue_redraw()
@export var line_width: float = 2.0
## Draws a checkerboard instead of lines (board games).
@export var checkerboard: bool = false:
	set(value):
		checkerboard = value
		queue_redraw()
@export var alternate_color: Color = Palette.WORLD_DETAIL:
	set(value):
		alternate_color = value
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, area_size), fill_color)
	var columns: int = ceili(area_size.x / cell_size.x)
	var rows: int = ceili(area_size.y / cell_size.y)
	if checkerboard:
		for row: int in rows:
			for column: int in columns:
				if (row + column) % 2 == 1:
					draw_rect(Rect2(Vector2(column, row) * cell_size, cell_size), alternate_color)
		return
	for column: int in columns + 1:
		draw_line(Vector2(column * cell_size.x, 0), Vector2(column * cell_size.x, area_size.y), line_color, line_width)
	for row: int in rows + 1:
		draw_line(Vector2(0, row * cell_size.y), Vector2(area_size.x, row * cell_size.y), line_color, line_width)
