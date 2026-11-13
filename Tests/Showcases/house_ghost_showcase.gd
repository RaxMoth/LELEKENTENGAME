## A haunted night in the house: the ghost has turned up behind the player, who
## turned around and looks at it — it whips around with burning eyes to
## lunge (held for the picture; it would be gone in a blink).
## Loaded by Tests/screenshot_tool.gd with `showcase=house_ghost`.
##
## Dependencies: HouseLevel, Ghost, DayCycle, Profile autoload
extends RefCounted


static func apply(scene: Node) -> void:
	var level: HouseLevel = scene as HouseLevel
	var ghost: Ghost = level.get_ghost()
	ghost.vanish_seconds = 1000.0
	level.rig.locomotion.teleport_to(Vector3(0.0, 0.0, -1.2), 0.0)
	# Make sure this night is haunted.
	ghost.haunt_chance = 1.0
	Profile.operation.day_number = ghost.first_haunt_night
	Profile.operation.last_ghost_night = 0
	var day_cycle: DayCycle = level.day_cycle
	day_cycle.advance(day_cycle.day_seconds + day_cycle.night_seconds * 0.3 - day_cycle.clock.elapsed_seconds)
	level.rig.aim_at_world_point(ghost.get_head_position())
