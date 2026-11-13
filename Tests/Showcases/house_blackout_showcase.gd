## A night with the fuses blown: the fuse box on the front room wall shows
## red with its lever down, the lamps are dark.
## Loaded by Tests/screenshot_tool.gd with `showcase=house_blackout`.
##
## Dependencies: HouseLevel, FuseBox, DayCycle
extends RefCounted


static func apply(scene: Node) -> void:
	var level: HouseLevel = scene as HouseLevel
	level.day_cycle.advance(level.day_cycle.day_seconds + 20.0 - level.day_cycle.clock.elapsed_seconds)
	level.get_fuse_box().trip()
