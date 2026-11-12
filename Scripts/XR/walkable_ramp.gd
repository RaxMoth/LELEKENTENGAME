## A sloped walkable strip that joins two floor heights: the stairs down to
## the cellar. Its height runs evenly from [member bottom_height] at one edge
## of [member rect] to [member top_height] at the opposite edge
## ([member top_edge]), so walking along it carries the player up or down.
##
##   var stairs: WalkableRamp = WalkableRamp.create(Rect2(1.0, 1.85, 3.3, 0.55), 0.0, -2.6, WalkableRamp.Edge.MIN_X)
##   stairs.get_height(Vector2(2.65, 2.1))   # -1.3, half way down
##
## Dependencies: none
class_name WalkableRamp
extends Resource

## Which edge of the rect is the high end.
enum Edge { MIN_X, MAX_X, MIN_Z, MAX_Z }

## The ramp's footprint in world X / Z: position = (min x, min z).
@export var rect: Rect2 = Rect2()
## Floor height at the high edge.
@export var top_height: float = 0.0
## Floor height at the opposite (low) edge.
@export var bottom_height: float = -2.6
@export var top_edge: Edge = Edge.MIN_X


## A ramp over [param footprint] from [param top] (at [param high_edge]) down to [param bottom].
static func create(footprint: Rect2, top: float, bottom: float, high_edge: Edge) -> WalkableRamp:
	var ramp: WalkableRamp = WalkableRamp.new()
	ramp.rect = footprint
	ramp.top_height = top
	ramp.bottom_height = bottom
	ramp.top_edge = high_edge
	return ramp


func has_point(point: Vector2) -> bool:
	return rect.has_point(point)


## Floor height at [param point] (clamped to the ramp's ends outside it).
func get_height(point: Vector2) -> float:
	var share_to_top: float = 0.0
	match top_edge:
		Edge.MIN_X:
			share_to_top = inverse_lerp(rect.end.x, rect.position.x, point.x)
		Edge.MAX_X:
			share_to_top = inverse_lerp(rect.position.x, rect.end.x, point.x)
		Edge.MIN_Z:
			share_to_top = inverse_lerp(rect.end.y, rect.position.y, point.y)
		Edge.MAX_Z:
			share_to_top = inverse_lerp(rect.position.y, rect.end.y, point.y)
	return lerpf(bottom_height, top_height, clampf(share_to_top, 0.0, 1.0))
