## The player's towers in action: the tower depot by the porch with a kit on
## its table, and a sentry, a shock coil, a mortar and a heat lance in the
## garden and the street, firing at officers.
## Loaded by Tests/screenshot_tool.gd with `showcase=house_towers`.
##
## Dependencies: HouseLevel, FrontGarden, TowerField, Raider
extends RefCounted

const COP: PackedScene = preload("res://Scenes/Levels/House/Garden/Cop.tscn")
const TOWERS: Array[Array] = [[&"sentry", Vector2(-5.0, -14.0)], [&"shock", Vector2(5.5, -18.0)], [&"mortar", Vector2(-9.0, -22.0)], [&"heat_lance", Vector2(8.0, -10.5)]]
const COP_SPOTS: Array[Vector2] = [Vector2(-2.0, -24.0), Vector2(3.0, -26.0), Vector2(6.0, -31.0), Vector2(-6.0, -33.0), Vector2(12.0, -34.0)]


static func apply(scene: Node) -> void:
	var level: HouseLevel = scene as HouseLevel
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var field: TowerField = garden.tower_field
	Profile.wallet.add(Types.CURRENCY_CASH, 5000)
	for entry: Array in TOWERS:
		field.build(field.catalog.find_tower(entry[0]), entry[1])
	field.buy_kit(field.catalog.find_tower(&"mortar"))
	for spot: Vector2 in COP_SPOTS:
		var cop: Raider = garden.director.spawn_raider(COP)
		cop.global_position = Vector3(spot.x, 0.0, spot.y)
		cop.freeze()
