## The starter cabin with its rats: a fresh operation (one room), the rats
## gathered on the floor in front of the player.
## Loaded by Tests/screenshot_tool.gd with `showcase=house_rats`.
##
## Dependencies: HouseLevel, RatPack, Rat, Profile autoload
extends RefCounted

## Where the rats sit for the picture (x, z) and which way they look.
const RAT_SPOTS: Array[Vector3] = [Vector3(-2.2, -0.6, 0.4), Vector3(-1.5, -0.2, 2.6), Vector3(-2.7, 0.3, -1.2), Vector3(-1.0, -1.1, 1.9)]


static func apply(scene: Node) -> void:
	var level: HouseLevel = scene as HouseLevel
	# A new operation's house (no upgrades, in memory only: the save stays as it is).
	Profile.upgrades.reset()
	level.apply_upgrades()
	var rats: Array[Rat] = level.get_rats().get_rats()
	for rat_index: int in mini(rats.size(), RAT_SPOTS.size()):
		var spot: Vector3 = RAT_SPOTS[rat_index]
		rats[rat_index].global_position = Vector3(spot.x, 0.0, spot.y)
		rats[rat_index].rotation.y = spot.z
