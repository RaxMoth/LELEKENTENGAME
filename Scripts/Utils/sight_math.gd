## Is a point in front of the player's eyes? View-cone math for things that
## react to being looked at (the night-4 ghost), without physics raycasts.
##
##   SightMath.is_in_view(rig.get_head_transform(), ghost_head, 22.0, 14.0)
##
## Dependencies: none
class_name SightMath
extends RefCounted


## Angle in degrees between where [param eye] looks (-Z) and [param point].
static func get_view_angle(eye: Transform3D, point: Vector3) -> float:
	var to_point: Vector3 = point - eye.origin
	if to_point.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg((-eye.basis.z).angle_to(to_point))


## True when [param point] is within [param half_angle_degrees] of the view
## direction and no farther than [param max_distance].
static func is_in_view(eye: Transform3D, point: Vector3, half_angle_degrees: float, max_distance: float) -> bool:
	return eye.origin.distance_to(point) <= max_distance and get_view_angle(eye, point) <= half_angle_degrees
