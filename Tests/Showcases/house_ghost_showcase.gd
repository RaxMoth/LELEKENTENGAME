## Night 4 in the house: the ghost has turned up behind the player, who
## turned around and looks at it — it stares back (held for the picture).
## Loaded by Tests/screenshot_tool.gd with `showcase=house_ghost`.
##
## Dependencies: HouseLevel, Ghost, DayCycle, Profile autoload
extends RefCounted


static func apply(scene: Node) -> void:
	var level: HouseLevel = scene as HouseLevel
	var ghost: Ghost = level.get_ghost()
	ghost.stare_seconds = 1000.0
	level.rig.locomotion.teleport_to(Vector3(0.0, 0.0, -1.2), 0.0)
	Profile.operation.day_number = ghost.night_number
	var day_cycle: DayCycle = level.day_cycle
	day_cycle.advance(day_cycle.day_seconds + day_cycle.night_seconds * 0.3 - day_cycle.clock.elapsed_seconds)
	level.rig.aim_at_world_point(ghost.get_head_position())
