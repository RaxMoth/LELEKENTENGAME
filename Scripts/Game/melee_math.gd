## Pure rules of close combat: is a hand moving fast enough to be a swing,
## and how close a fist or blade comes to a standing body (an upright
## segment from the feet up). No physics: bodies are segments, weapons are
## the stretch from the hand to their tip.
##
##   MeleeMath.get_speed(last_hand, hand, delta) >= swing_speed
##   MeleeMath.get_distance_to_body(hand, blade_tip, raider_feet, 1.6) <= body_radius
##
## Dependencies: none
class_name MeleeMath
extends RefCounted

## Points sampled along a weapon's stretch (hand to tip).
const STRETCH_SAMPLES: int = 4


## Meters per second between two samples of a hand [param delta] seconds apart.
static func get_speed(previous: Vector3, current: Vector3, delta: float) -> float:
	return previous.distance_to(current) / maxf(delta, 0.001)


## The shortest distance from the stretch [param from] → [param to] (a fist:
## both the same; a knife or axe: hand to tip) to a body standing at
## [param feet], [param height] tall.
static func get_distance_to_body(from: Vector3, to: Vector3, feet: Vector3, height: float) -> float:
	var nearest: float = INF
	for sample_index: int in STRETCH_SAMPLES + 1:
		var point: Vector3 = from.lerp(to, float(sample_index) / float(STRETCH_SAMPLES))
		var on_body: Vector3 = Vector3(feet.x, clampf(point.y, feet.y, feet.y + maxf(0.0, height)), feet.z)
		nearest = minf(nearest, point.distance_to(on_body))
	return nearest
