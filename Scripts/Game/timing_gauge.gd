## The skill check of every lab step: a needle sweeps back and forth across a
## bar and the player stops it inside the sweet zone. The closer to the
## middle of the zone, the better the step goes (and the better the product).
##
##   var gauge: TimingGauge = TimingGauge.new(0.7, 0.18)
##   gauge.advance(delta)                # every frame while running
##   var accuracy: float = gauge.stop()  # 0..1
##
## Pure logic, no nodes: the workstation draws it.
##
## Dependencies: none
class_name TimingGauge
extends RefCounted

## Accuracy at the very edge of the sweet zone; outside the zone it drops to 0.
const EDGE_ACCURACY: float = 0.5

## Full sweeps (0 -> 1 -> 0) per second.
var sweeps_per_second: float = 0.7
## Middle of the sweet zone, 0..1 along the bar.
var zone_center: float = 0.5
## Width of the sweet zone, 0..1 of the bar.
var zone_width: float = 0.2
## Seconds the needle has been moving.
var elapsed_seconds: float = 0.0


func _init(sweep_rate: float = 0.7, sweet_zone_width: float = 0.2, sweet_zone_center: float = 0.5) -> void:
	sweeps_per_second = maxf(0.01, sweep_rate)
	zone_width = clampf(sweet_zone_width, 0.01, 1.0)
	zone_center = clampf(sweet_zone_center, zone_width * 0.5, 1.0 - zone_width * 0.5)


func advance(delta: float) -> void:
	elapsed_seconds += delta


## Needle position 0..1 (ping-pong, starting at 0).
func get_needle() -> float:
	return pingpong(elapsed_seconds * sweeps_per_second * 2.0, 1.0)


func get_zone_start() -> float:
	return zone_center - zone_width * 0.5


func get_zone_end() -> float:
	return zone_center + zone_width * 0.5


## Accuracy if the needle stopped at [param needle]: 1 in the middle of the
## zone, EDGE_ACCURACY at its edges, falling to 0 half a zone outside it.
func get_accuracy_at(needle: float) -> float:
	var half_width: float = zone_width * 0.5
	var offset: float = absf(needle - zone_center)
	if offset <= half_width:
		return lerpf(1.0, EDGE_ACCURACY, offset / half_width)
	return clampf(EDGE_ACCURACY * (1.0 - (offset - half_width) / half_width), 0.0, EDGE_ACCURACY)


## Stops the needle where it is and returns the accuracy.
func stop() -> float:
	return get_accuracy_at(get_needle())
