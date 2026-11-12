## A conversation in the street: the player stands on the sidewalk in front
## of the garden gate talking to a passer-by, the dialogue panel beside them.
## Loaded by Tests/screenshot_tool.gd with `showcase=house_town_talk`.
##
## Dependencies: HouseLevel, Town, Pedestrian
extends RefCounted

## Where the player stands and the passer-by waits (world X / Z).
const PLAYER_SPOT: Vector3 = Vector3(0.0, 0.0, -31.5)
const PARTNER_SPOT: Vector3 = Vector3(0.4, 0.0, -33.3)


static func apply(scene: Node) -> void:
	var level: HouseLevel = scene as HouseLevel
	var town: Town = level.get_front(Town) as Town
	var feet: Vector3 = level.rig.get_feet_position()
	level.rig.move_origin_by(Vector3(PLAYER_SPOT.x - feet.x, 0.0, PLAYER_SPOT.z - feet.z))
	var partner: Pedestrian = town.get_pedestrians()[0]
	partner.global_position = PARTNER_SPOT
	level.rig.aim_at_world_point(PARTNER_SPOT + Vector3(0.35, 1.45, 0.0))
	town.start_talk(partner)
