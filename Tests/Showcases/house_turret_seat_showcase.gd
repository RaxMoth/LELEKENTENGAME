## The view from inside a roof turret ("VR in VR"): the house showcase with
## the player wearing the turret goggles, aiming down into the yard.
## Loaded by Tests/screenshot_tool.gd with `showcase=house_turret_seat`.
##
## Dependencies: house_showcase.gd, HouseLevel, FrontGarden, TurretSeat
extends RefCounted

const HOUSE_SHOWCASE: Script = preload("res://Tests/Showcases/house_showcase.gd")


static func apply(scene: Node) -> void:
	HOUSE_SHOWCASE.call("apply", scene)
	var level: HouseLevel = scene as HouseLevel
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	garden.turret_seat.enter(garden.get_turrets()[0])
	level.rig.aim_at_world_point(Vector3(0.5, 0.8, -12.5))
