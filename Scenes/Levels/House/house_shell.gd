## The house's walls, floor and ceiling, built from a few numbers at load:
## move a wall, a door or a window by editing the lists, not dozens of nodes.
## Walls run along X or Z between two floor points; doors and windows are
## gaps on a wall line (doors from the floor up, windows from the sill up).
## Also runs in the editor, so the house shows while you design around it.
##
## Dependencies: PlaceholderMesh3D, Palette
@tool
class_name HouseShell
extends Node3D

## Wall segments (x1, z1, x2, z2) on the floor plane; must be axis-aligned.
@export var walls: Array[Vector4] = []:
	set(value):
		walls = value
		_queue_rebuild()
## Door gaps (x1, z1, x2, z2) lying on a wall line.
@export var doors: Array[Vector4] = []:
	set(value):
		doors = value
		_queue_rebuild()
## Window gaps (x1, z1, x2, z2) lying on a wall line.
@export var windows: Array[Vector4] = []:
	set(value):
		windows = value
		_queue_rebuild()
## Interior floor (and ceiling) rectangle: position = (min x, min z).
@export var floor_rect: Rect2 = Rect2(-5.0, -5.0, 10.0, 10.0):
	set(value):
		floor_rect = value
		_queue_rebuild()
@export var wall_height: float = 2.6
@export var wall_thickness: float = 0.16
@export var door_height: float = 2.1
@export var window_sill: float = 1.0
@export var window_top: float = 2.1
@export var has_ceiling: bool = true
@export var wall_color: Color = Palette.SURFACE_RAISED
@export var floor_color: Color = Palette.STROKE
@export var ceiling_color: Color = Palette.SURFACE

var _is_rebuild_queued: bool = false


func _ready() -> void:
	rebuild()


## Drops the generated geometry and builds it again from the lists.
func rebuild() -> void:
	_is_rebuild_queued = false
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_add_box(Vector3(floor_rect.get_center().x, -0.025, floor_rect.get_center().y), Vector3(floor_rect.size.x, 0.05, floor_rect.size.y), floor_color)
	if has_ceiling:
		_add_box(Vector3(floor_rect.get_center().x, wall_height + 0.025, floor_rect.get_center().y), Vector3(floor_rect.size.x, 0.05, floor_rect.size.y), ceiling_color)
	for wall: Vector4 in walls:
		_build_wall(wall)


func _queue_rebuild() -> void:
	if is_inside_tree() and not _is_rebuild_queued:
		_is_rebuild_queued = true
		rebuild.call_deferred()


func _build_wall(wall: Vector4) -> void:
	var runs_along_x: bool = is_equal_approx(wall.y, wall.w)
	var line_value: float = wall.y if runs_along_x else wall.x
	var start: float = minf(wall.x, wall.z) if runs_along_x else minf(wall.y, wall.w)
	var end: float = maxf(wall.x, wall.z) if runs_along_x else maxf(wall.y, wall.w)
	# Gaps on this wall: [from, to, bottom, top], sorted along the wall.
	var gaps: Array[Vector4] = []
	for door: Vector4 in doors:
		var door_span: Vector2 = _get_span_on_line(door, runs_along_x, line_value)
		if door_span != Vector2.INF:
			gaps.append(Vector4(door_span.x, door_span.y, 0.0, door_height))
	for window: Vector4 in windows:
		var window_span: Vector2 = _get_span_on_line(window, runs_along_x, line_value)
		if window_span != Vector2.INF:
			gaps.append(Vector4(window_span.x, window_span.y, window_sill, window_top))
	gaps.sort_custom(func(first: Vector4, second: Vector4) -> bool: return first.x < second.x)
	var cursor: float = start
	for gap: Vector4 in gaps:
		var gap_start: float = clampf(gap.x, start, end)
		var gap_end: float = clampf(gap.y, start, end)
		if gap_start > cursor:
			_add_wall_piece(runs_along_x, line_value, cursor, gap_start, 0.0, wall_height)
		if gap.z > 0.0:
			_add_wall_piece(runs_along_x, line_value, gap_start, gap_end, 0.0, gap.z)
		_add_wall_piece(runs_along_x, line_value, gap_start, gap_end, gap.w, wall_height)
		cursor = maxf(cursor, gap_end)
	if cursor < end:
		_add_wall_piece(runs_along_x, line_value, cursor, end, 0.0, wall_height)


## The part of [param gap] along a wall line, or Vector2.INF when it isn't on it.
func _get_span_on_line(gap: Vector4, runs_along_x: bool, line_value: float) -> Vector2:
	if runs_along_x:
		if not is_equal_approx(gap.y, line_value) or not is_equal_approx(gap.w, line_value):
			return Vector2.INF
		return Vector2(minf(gap.x, gap.z), maxf(gap.x, gap.z))
	if not is_equal_approx(gap.x, line_value) or not is_equal_approx(gap.z, line_value):
		return Vector2.INF
	return Vector2(minf(gap.y, gap.w), maxf(gap.y, gap.w))


func _add_wall_piece(runs_along_x: bool, line_value: float, from_value: float, to_value: float, bottom: float, top: float) -> void:
	var length: float = to_value - from_value
	var height: float = top - bottom
	if length <= 0.001 or height <= 0.001:
		return
	var middle: float = (from_value + to_value) * 0.5
	var center: Vector3 = Vector3(middle, bottom + height * 0.5, line_value) if runs_along_x else Vector3(line_value, bottom + height * 0.5, middle)
	var piece_size: Vector3 = Vector3(length, height, wall_thickness) if runs_along_x else Vector3(wall_thickness, height, length)
	_add_box(center, piece_size, wall_color)


func _add_box(center: Vector3, box_size: Vector3, color: Color) -> void:
	var box: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = box_size
	box.mesh = box_mesh
	box.position = center
	box.material_override = PlaceholderMesh3D.get_shared_material(color)
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(box)
