## Pure ray geometry for pointer picking in 3D / XR scenes. Cheaper and more
## predictable than physics raycasts when the targets are simple shapes
## (a lawn plane, an enemy's hit sphere, a floating screen).
##
##   var distance: float = RayMath.intersect_sphere(origin, direction, center, 0.5)
##   if distance != RayMath.NO_HIT: ...
##
## Every [param ray_direction] must be normalized.
##
## Dependencies: none
class_name RayMath
extends RefCounted

## Returned by the intersect functions when the ray misses.
const NO_HIT: float = -1.0
const PARALLEL_EPSILON: float = 0.00001


## Distance along the ray to the plane through [param plane_point] with
## [param plane_normal], or NO_HIT when the ray is parallel or points away.
static func intersect_plane(ray_origin: Vector3, ray_direction: Vector3, plane_point: Vector3, plane_normal: Vector3) -> float:
	var approach: float = ray_direction.dot(plane_normal)
	if absf(approach) < PARALLEL_EPSILON:
		return NO_HIT
	var distance: float = (plane_point - ray_origin).dot(plane_normal) / approach
	return distance if distance >= 0.0 else NO_HIT


## Distance along the ray to the horizontal plane at [param plane_height].
static func intersect_ground(ray_origin: Vector3, ray_direction: Vector3, plane_height: float = 0.0) -> float:
	return intersect_plane(ray_origin, ray_direction, Vector3(0.0, plane_height, 0.0), Vector3.UP)


## Distance along the ray to the first point on a sphere, 0 when the ray
## starts inside it, or NO_HIT.
static func intersect_sphere(ray_origin: Vector3, ray_direction: Vector3, center: Vector3, radius: float) -> float:
	var to_center: Vector3 = center - ray_origin
	if to_center.length_squared() <= radius * radius:
		return 0.0
	var along_ray: float = to_center.dot(ray_direction)
	if along_ray < 0.0:
		return NO_HIT
	var miss_distance_squared: float = to_center.length_squared() - along_ray * along_ray
	if miss_distance_squared > radius * radius:
		return NO_HIT
	return along_ray - sqrt(radius * radius - miss_distance_squared)


## Shortest distance between a point and the ray (the ray does not extend behind its origin).
static func distance_to_point(ray_origin: Vector3, ray_direction: Vector3, point: Vector3) -> float:
	var to_point: Vector3 = point - ray_origin
	var along_ray: float = maxf(0.0, to_point.dot(ray_direction))
	return (ray_origin + ray_direction * along_ray).distance_to(point)


## Maps a point on a flat screen (meters from its center, +Y up) to viewport
## pixels (origin top-left, +Y down).
static func screen_point_to_pixel(local_point: Vector2, size_meters: Vector2, resolution: Vector2i) -> Vector2:
	return Vector2(
		(local_point.x / size_meters.x + 0.5) * resolution.x,
		(0.5 - local_point.y / size_meters.y) * resolution.y)


## Inverse of screen_point_to_pixel().
static func pixel_to_screen_point(pixel: Vector2, size_meters: Vector2, resolution: Vector2i) -> Vector2:
	return Vector2(
		(pixel.x / resolution.x - 0.5) * size_meters.x,
		(0.5 - pixel.y / resolution.y) * size_meters.y)


## True when [param local_point] lies on a screen of [param size_meters] centered on the origin.
static func is_on_screen(local_point: Vector2, size_meters: Vector2) -> bool:
	return absf(local_point.x) <= size_meters.x * 0.5 and absf(local_point.y) <= size_meters.y * 0.5


## Where (0..1 along it) the segment [param from] → [param to] first enters
## [param rect] — 0 when it starts inside — or -1 when it misses (slab test,
## on the floor plane).
static func segment_enters_rect(from: Vector2, to: Vector2, rect: Rect2) -> float:
	var direction: Vector2 = to - from
	var enter: float = 0.0
	var leave: float = 1.0
	for axis: int in 2:
		var start: float = from[axis]
		var step: float = direction[axis]
		var low: float = rect.position[axis]
		var high: float = rect.end[axis]
		if absf(step) < 0.00001:
			if start < low or start > high:
				return -1.0
			continue
		var near: float = (low - start) / step
		var far: float = (high - start) / step
		if near > far:
			var swap: float = near
			near = far
			far = swap
		enter = maxf(enter, near)
		leave = minf(leave, far)
		if enter > leave:
			return -1.0
	return enter
