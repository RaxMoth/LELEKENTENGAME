## The automated house (house_automation_showcase.gd) seen from down in
## the cellar: grow racks, grow lights, the picker's gantry, the stairs.
## Loaded by Tests/screenshot_tool.gd with `showcase=house_cellar` (stand
## and look keep the cellar's floor height).
##
## Dependencies: house_automation_showcase.gd, HouseLevel, XRLocomotion
extends RefCounted

const AUTOMATION_SHOWCASE: GDScript = preload("res://Tests/Showcases/house_automation_showcase.gd")


static func apply(scene: Node) -> void:
	AUTOMATION_SHOWCASE.apply(scene)
	(scene as HouseLevel).rig.locomotion.teleport_to(Vector3(2.0, -2.6, 2.2))
