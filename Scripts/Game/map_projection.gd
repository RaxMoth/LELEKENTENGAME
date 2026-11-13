## Turns world ground positions (X / Z) into points on a north-up map view
## and back: the view shows [member span_meters] across its shorter side,
## centered on [member center]. North (-Z) is up, east (+X) right.
##
##   var projection: MapProjection = MapProjection.new(Vector2(540, 760), 160.0)
##   projection.center = Vector2(player.x, player.z)
##   var pixel: Vector2 = projection.to_map(Vector2(raider.x, raider.z))
##
## Pure logic (unit-tested in Tests/Unit/map_projection_test.gd).
##
## Dependencies: none
class_name MapProjection
extends RefCounted

## The map view's size in pixels.
var view_size: Vector2 = Vector2(540.0, 760.0)
## Meters shown across the view's shorter side.
var span_meters: float = 160.0
## The world point (X, Z) in the middle of the view.
var center: Vector2 = Vector2.ZERO


func _init(map_view_size: Vector2 = Vector2(540.0, 760.0), map_span_meters: float = 160.0) -> void:
	view_size = map_view_size
	span_meters = map_span_meters


## Pixels per meter at the current span.
func get_scale() -> float:
	return minf(view_size.x, view_size.y) / maxf(1.0, span_meters)


## The map pixel of world point [param world] (X, Z).
func to_map(world: Vector2) -> Vector2:
	return view_size * 0.5 + (world - center) * get_scale()


## The world point (X, Z) under map pixel [param pixel].
func to_world(pixel: Vector2) -> Vector2:
	return center + (pixel - view_size * 0.5) / get_scale()


## A world rectangle as a map rectangle.
func rect_to_map(world_rect: Rect2) -> Rect2:
	return Rect2(to_map(world_rect.position), world_rect.size * get_scale())


## The world area the view shows.
func get_visible_world_rect() -> Rect2:
	var size_meters: Vector2 = view_size / get_scale()
	return Rect2(center - size_meters * 0.5, size_meters)


## True when map pixel [param pixel] lies inside the view, [param margin] pixels in.
func is_on_map(pixel: Vector2, margin: float = 0.0) -> bool:
	return pixel.x >= margin and pixel.y >= margin and pixel.x <= view_size.x - margin and pixel.y <= view_size.y - margin


## Pulls [param pixel] onto the view's edge ([param margin] pixels in) toward
## the middle — for markers of things off the map (an arrow at the border).
func clamp_to_edge(pixel: Vector2, margin: float) -> Vector2:
	var middle: Vector2 = view_size * 0.5
	var offset: Vector2 = pixel - middle
	var half: Vector2 = middle - Vector2(margin, margin)
	if offset.is_zero_approx() or (absf(offset.x) <= half.x and absf(offset.y) <= half.y):
		return pixel
	var factor: float = minf(half.x / maxf(0.001, absf(offset.x)), half.y / maxf(0.001, absf(offset.y)))
	return middle + offset * factor


## The map direction (radians, 0 = up/north, clockwise) a heading toward
## world direction [param world_direction] (X, Z) has.
static func heading_angle(world_direction: Vector2) -> float:
	return atan2(world_direction.x, -world_direction.y)
