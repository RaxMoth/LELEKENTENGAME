## The house showcase after nightfall (lamps on, moonlight).
## Loaded by Tests/screenshot_tool.gd with `showcase=house_night`.
##
## Dependencies: house_showcase.gd, DayCycle
extends RefCounted

const HOUSE_SHOWCASE: Script = preload("res://Tests/Showcases/house_showcase.gd")


static func apply(scene: Node) -> void:
	HOUSE_SHOWCASE.call("apply", scene)
	var day_cycle: DayCycle = scene.get_node("%DayCycle") as DayCycle
	day_cycle.advance(day_cycle.day_seconds + day_cycle.night_seconds * 0.3 - day_cycle.clock.elapsed_seconds)
