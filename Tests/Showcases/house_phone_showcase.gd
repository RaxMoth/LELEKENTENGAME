## The phone out in the street during a raid: the house showcase with the
## player a block from the house, police coming, the phone's map open.
## Loaded by Tests/screenshot_tool.gd with `showcase=house_phone`.
##
## Dependencies: house_showcase.gd, HouseLevel, FrontGarden, Phone
extends RefCounted

const HOUSE_SHOWCASE: Script = preload("res://Tests/Showcases/house_showcase.gd")


static func apply(scene: Node) -> void:
	HOUSE_SHOWCASE.call("apply", scene)
	var level: HouseLevel = scene as HouseLevel
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	for kind: StringName in [AttackerDirector.SPAWN_SQUAD, AttackerDirector.SPAWN_CAR]:
		garden.director.spawn_now(kind)
	garden.phone.open()
