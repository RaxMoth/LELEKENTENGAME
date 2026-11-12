## Clean vector shape drawn in code: rounded corners, soft top-to-bottom
## shading, a soft drop shadow and anti-aliased edges. Crisp at any size and
## good enough for a minimalist art style; swap for a Sprite2D /
## AnimatedSprite2D when final art arrives.
##
## Colors should come from Palette (see Docs/DESIGN.md). Shading and shadow
## follow the screen (light from above) even when the node is rotated; they
## are baked when the shape redraws, so nodes that rotate every frame should
## keep shading low and the shadow off.
##
## Dependencies: none
@tool
class_name PlaceholderShape
extends Node2D

enum ShapeKind { CIRCLE, RECTANGLE, TRIANGLE, DIAMOND, CAPSULE, HEXAGON }

const CIRCLE_SEGMENTS: int = 48
const CORNER_SEGMENTS: int = 8
const EDGE_ANTIALIAS_WIDTH: float = 1.2

@export var shape_kind: ShapeKind = ShapeKind.CIRCLE:
	set(value):
		shape_kind = value
		queue_redraw()
@export var size: Vector2 = Vector2(48, 48):
	set(value):
		size = value
		queue_redraw()
@export var color: Color = Color(0.357, 0.486, 0.98):
	set(value):
		color = value
		queue_redraw()

@export_group("Style")
## Corner radius as a fraction of the shorter side (0 = sharp corners).
@export_range(0.0, 0.5, 0.01) var corner_roundness: float = 0.2:
	set(value):
		corner_roundness = value
		queue_redraw()
## How much lighter the top and darker the bottom are (0 = flat color).
@export_range(0.0, 0.5, 0.01) var shading: float = 0.12:
	set(value):
		shading = value
		queue_redraw()
@export var outline_color: Color = Color(1, 1, 1, 0.0):
	set(value):
		outline_color = value
		queue_redraw()
@export var outline_width: float = 0.0:
	set(value):
		outline_width = value
		queue_redraw()

@export_group("Shadow")
@export var shadow_enabled: bool = true:
	set(value):
		shadow_enabled = value
		queue_redraw()
@export var shadow_color: Color = Color(0.0, 0.0, 0.02, 0.3):
	set(value):
		shadow_color = value
		queue_redraw()
## Downward shadow offset in pixels; negative = derived from the size.
@export var shadow_distance: float = -1.0:
	set(value):
		shadow_distance = value
		queue_redraw()


func _draw() -> void:
	var outline_points: PackedVector2Array = _build_outline()
	if outline_points.size() < 3:
		return
	var screen_down: Vector2 = Vector2.DOWN.rotated(-global_rotation) if is_inside_tree() else Vector2.DOWN
	if shadow_enabled and shadow_color.a > 0.0:
		_draw_shadow(outline_points, screen_down)
	var vertex_colors: PackedColorArray = _shade(outline_points, screen_down)
	draw_polygon(outline_points, vertex_colors)
	var closed_points: PackedVector2Array = outline_points.duplicate()
	closed_points.append(outline_points[0])
	var closed_colors: PackedColorArray = vertex_colors.duplicate()
	closed_colors.append(vertex_colors[0])
	# Polygons have no anti-aliasing in the Compatibility renderer; a thin AA
	# edge in the same colors smooths the silhouette.
	draw_polyline_colors(closed_points, closed_colors, EDGE_ANTIALIAS_WIDTH, true)
	if outline_width > 0.0 and outline_color.a > 0.0:
		draw_polyline(closed_points, outline_color, outline_width, true)


func _draw_shadow(outline_points: PackedVector2Array, screen_down: Vector2) -> void:
	var distance: float = shadow_distance if shadow_distance >= 0.0 else clampf(minf(size.x, size.y) * 0.1, 2.0, 10.0)
	var offset: Vector2 = screen_down * distance
	var shadow_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in outline_points:
		shadow_points.append(point + offset)
	draw_colored_polygon(shadow_points, shadow_color)
	shadow_points.append(shadow_points[0])
	# A wide, faint stroke around the shadow fakes a soft blur edge.
	draw_polyline(shadow_points, Color(shadow_color, shadow_color.a * 0.45), distance * 0.9, true)


func _shade(outline_points: PackedVector2Array, screen_down: Vector2) -> PackedColorArray:
	var vertex_colors: PackedColorArray = PackedColorArray()
	var lowest: float = INF
	var highest: float = -INF
	for point: Vector2 in outline_points:
		var depth: float = point.dot(screen_down)
		lowest = minf(lowest, depth)
		highest = maxf(highest, depth)
	var top_color: Color = color.lightened(shading)
	var bottom_color: Color = color.darkened(shading)
	var span: float = maxf(highest - lowest, 0.001)
	for point: Vector2 in outline_points:
		vertex_colors.append(top_color.lerp(bottom_color, (point.dot(screen_down) - lowest) / span))
	return vertex_colors


func _build_outline() -> PackedVector2Array:
	var half_size: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * corner_roundness
	match shape_kind:
		ShapeKind.CIRCLE:
			var circle_points: PackedVector2Array = PackedVector2Array()
			for segment_index: int in CIRCLE_SEGMENTS:
				circle_points.append(Vector2.from_angle(TAU * segment_index / CIRCLE_SEGMENTS) * half_size)
			return circle_points
		ShapeKind.RECTANGLE:
			return _round_corners(PackedVector2Array([-half_size, Vector2(half_size.x, -half_size.y), half_size, Vector2(-half_size.x, half_size.y)]), radius)
		ShapeKind.CAPSULE:
			return _round_corners(PackedVector2Array([-half_size, Vector2(half_size.x, -half_size.y), half_size, Vector2(-half_size.x, half_size.y)]), minf(half_size.x, half_size.y))
		ShapeKind.TRIANGLE:
			return _round_corners(PackedVector2Array([Vector2(half_size.x, 0), Vector2(-half_size.x, half_size.y), Vector2(-half_size.x, -half_size.y)]), radius)
		ShapeKind.DIAMOND:
			return _round_corners(PackedVector2Array([Vector2(0, -half_size.y), Vector2(half_size.x, 0), Vector2(0, half_size.y), Vector2(-half_size.x, 0)]), radius)
		ShapeKind.HEXAGON:
			var hexagon_points: PackedVector2Array = PackedVector2Array()
			for corner_index: int in 6:
				hexagon_points.append(Vector2.from_angle(TAU * corner_index / 6.0) * half_size)
			return _round_corners(hexagon_points, radius)
	return PackedVector2Array()


## Replaces every corner of a convex polygon with a circular arc.
func _round_corners(corners: PackedVector2Array, radius: float) -> PackedVector2Array:
	if radius <= 0.0:
		return corners
	var rounded: PackedVector2Array = PackedVector2Array()
	var corner_count: int = corners.size()
	for corner_index: int in corner_count:
		var corner: Vector2 = corners[corner_index]
		var to_previous: Vector2 = corners[(corner_index - 1 + corner_count) % corner_count] - corner
		var to_next: Vector2 = corners[(corner_index + 1) % corner_count] - corner
		var half_angle: float = to_previous.angle_to(to_next) * 0.5
		var tangent_length: float = minf(radius / absf(tan(half_angle)), minf(to_previous.length(), to_next.length()) * 0.5)
		var corner_radius: float = tangent_length * absf(tan(half_angle))
		var arc_start: Vector2 = corner + to_previous.normalized() * tangent_length
		var arc_end: Vector2 = corner + to_next.normalized() * tangent_length
		var bisector: Vector2 = (to_previous.normalized() + to_next.normalized()).normalized()
		var center: Vector2 = corner + bisector * (corner_radius / absf(sin(half_angle)))
		var start_angle: float = (arc_start - center).angle()
		var sweep: float = angle_difference(start_angle, (arc_end - center).angle())
		for segment_index: int in CORNER_SEGMENTS + 1:
			rounded.append(center + Vector2.from_angle(start_angle + sweep * segment_index / CORNER_SEGMENTS) * corner_radius)
	return rounded
