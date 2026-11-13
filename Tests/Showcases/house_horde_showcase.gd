## A police horde coming down the street in front of the house: thirty
## officers jogging in their lanes, a squad car, the armored vehicle and the
## helicopter overhead — seen from the garden gate.
## Loaded by Tests/screenshot_tool.gd with `showcase=house_horde`.
##
## Dependencies: HouseLevel, FrontGarden, AttackerDirector, Raider, StreetRoutes
extends RefCounted

const COP: PackedScene = preload("res://Scenes/Levels/House/Garden/Cop.tscn")
const SWAT: PackedScene = preload("res://Scenes/Levels/House/Garden/Swat.tscn")
const CAR: PackedScene = preload("res://Scenes/Levels/House/Garden/Vehicles/SquadCar.tscn")
const TANK: PackedScene = preload("res://Scenes/Levels/House/Garden/Vehicles/ArmoredVehicle.tscn")
const HELICOPTER: PackedScene = preload("res://Scenes/Levels/House/Garden/Vehicles/PoliceHelicopter.tscn")
## The street in front of the house runs along z = -35; the horde comes from +X.
const STREET_Z: float = -35.0
const OFFICERS: int = 30


static func apply(scene: Node) -> void:
	var level: HouseLevel = scene as HouseLevel
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var director: AttackerDirector = garden.director
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 4
	var street_end: Vector2 = Vector2(24.0, STREET_Z)
	for officer_index: int in OFFICERS:
		var start: Vector2 = Vector2(22.0 + officer_index * 1.2 + random.randf_range(-0.6, 0.6), STREET_Z + random.randf_range(-3.4, 3.4))
		var route: PackedVector2Array = PackedVector2Array([start, Vector2(street_end.x, start.y), garden.yard.get_spawn_point()])
		director.spawn_raider(SWAT if officer_index % 5 == 0 else COP, 1.0, null, officer_index, route)
	director.spawn_raider(CAR, 1.0, null, 0, PackedVector2Array([Vector2(110.0, STREET_Z + 2.2), Vector2(22.0, STREET_Z + 2.2)]))
	director.spawn_raider(TANK, 1.0, null, 0, PackedVector2Array([Vector2(90.0, STREET_Z - 2.2), Vector2(8.0, STREET_Z - 2.2)]))
	director.spawn_raider(HELICOPTER, 1.0, null, 0, PackedVector2Array([Vector2(40.0, -60.0), garden.yard.bounds.get_center()]))
	var feet: Vector3 = level.rig.get_feet_position()
	level.rig.move_origin_by(Vector3(6.0 - feet.x, 0.0, STREET_Z + 3.5 - feet.z))
	level.rig.aim_at_world_point(Vector3(40.0, 3.0, STREET_Z))
