## Sends the police during a raid. The HouseCycle decides when a wave starts
## and what it brings (a RaidWave: cops, SWAT, battering rams, squad cars, an
## armored vehicle, a helicopter, toughness); the FrontGarden hands each wave
## here.
##
## The officers come through the town: every squad sets off at a street
## crossing some way from the house — each squad of a wave from another
## direction — and jogs its own way through the streets (StreetRoutes, a
## different way every raid), spread over the street's width. At the house
## they climb into the yard and fight as before: RaidSquads leapfrog from
## cover to cover and rush the door together. Squad cars drive up and unload
## their cops at the curb, the armored vehicle stops in the street in front
## of the house and shells the door, the helicopter flies straight in and
## circles the yard dropping SWAT. On selling days nothing comes.
##
##   director.queue_wave(wave, raid_data)   # from FrontGarden.on_raid_wave_started
##   director.get_raiders_left()            # pending + still standing; 0 = wave beaten
##
## Dependencies: HouseContext, Yard, Raider, RaidSquad, RaidWave, RaidData,
##               TownData, StreetRoutes
class_name AttackerDirector
extends Node

## Vehicles keep to their side of the street (meters right of the middle).
const VEHICLE_LANE: float = 2.2
## Armored vehicles stand within this far (meters) to the side of the door's
## line, and this far apart from one another.
const SHELLING_SPREAD: float = 8.0
const SHELLING_SPACING: float = 7.0

@export var cop_scene: PackedScene
## Heavier officers with better equipment (from a later raid on).
@export var swat_scene: PackedScene
## Two officers carrying a battering ram (late in later raids).
@export var ram_scene: PackedScene
## A squad car that drives up and unloads cops.
@export var car_scene: PackedScene
## An armored vehicle that shells the front door from the street.
@export var tank_scene: PackedScene
## A helicopter that circles the yard and drops SWAT officers.
@export var helicopter_scene: PackedScene
## The town the police come through (its street grid).
@export var town_data: TownData
## Without RaidData (tests, tutorials): seconds between two officers.
@export var group_spawn_interval: float = 1.4
## Without RaidData: officers per squad.
@export_range(1, 8) var squad_size: int = 3

## Off = queued officers wait (tutorials, tests).
var is_active: bool = true

var _context: HouseContext = null
var _yard: Yard = null
## Officers and vehicles waiting to set off: [{"scene", "delay", "health",
## "squad", "spot", "route"}].
var _pending_spawns: Array[Dictionary] = []
var _squads: Array[RaidSquad] = []
var _streets: StreetRoutes = null
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	if town_data != null:
		_streets = StreetRoutes.new(town_data.street_x, town_data.street_z)


func setup(context: HouseContext, yard: Yard) -> void:
	_context = context
	_yard = yard


## One frame: lets queued officers go and moves the squads' plans on
## (called by the FrontGarden while the shift runs).
func step(delta: float) -> void:
	if not is_active or _context == null:
		return
	_step_pending_spawns(delta)
	for squad_index: int in range(_squads.size() - 1, -1, -1):
		var squad: RaidSquad = _squads[squad_index]
		squad.step(delta)
		if squad.get_alive_members().is_empty() and not _has_pending_for(squad):
			_squads.remove_at(squad_index)


## Queues every officer and vehicle of [param wave]. With [param raid_data]
## (the raid's tuning) the police come through the town in squads from
## different directions; without it (and without a town) they enter at the
## yard's edges one after another. [param spawn_interval] (seconds between
## two officers) overrides the tuning when not negative (0 = all at once).
func queue_wave(wave: RaidWave, raid_data: RaidData = null, spawn_interval: float = -1.0) -> void:
	var interval: float = raid_data.seconds_between_spawns if raid_data != null else group_spawn_interval
	if spawn_interval >= 0.0:
		interval = spawn_interval
	var squad_interval: float = raid_data.seconds_between_squads if raid_data != null else 0.0
	var size: int = maxi(1, raid_data.squad_size if raid_data != null else squad_size)
	var scenes: Array[PackedScene] = []
	for cop_index: int in wave.cop_count:
		scenes.append(cop_scene)
	for swat_index: int in wave.swat_count:
		scenes.append(swat_scene if swat_scene != null else cop_scene)
	for ram_index: int in wave.ram_count:
		scenes.append(ram_scene if ram_scene != null else cop_scene)
	var squad_count: int = maxi(1, ceili(float(scenes.size()) / size))
	# A lone last officer joins the squad before instead of going it alone.
	if squad_count > 1 and scenes.size() % size == 1:
		squad_count -= 1
	var squads: Array[RaidSquad] = []
	var squad_routes: Array[PackedVector2Array] = []
	var taken_directions: Array[int] = []
	for squad_index: int in squad_count:
		squads.append(RaidSquad.new())
		squad_routes.append(_plan_street_route(raid_data, taken_directions))
	_squads.append_array(squads)
	for raider_index: int in scenes.size():
		var squad_index: int = mini(raider_index / size, squad_count - 1)
		var place_in_squad: int = raider_index - squad_index * size
		var street_way: PackedVector2Array = squad_routes[squad_index]
		var route: PackedVector2Array = PackedVector2Array()
		if not street_way.is_empty():
			route = StreetRoutes.offset_route(street_way, _random.randf_range(-raid_data.lane_spread, raid_data.lane_spread))
			route.append(_yard.get_spawn_point() if _yard != null else street_way[street_way.size() - 1])
		_pending_spawns.append({
			"scene": scenes[raider_index],
			"delay": (squad_index * squad_interval + place_in_squad * interval) if not street_way.is_empty() else interval * raider_index,
			"health": wave.health_multiplier, "squad": squads[squad_index],
			"spot": raider_index, "route": route,
		})
	_queue_vehicles(wave, raid_data, taken_directions)


## Sends one raider into the yard now (tests, tutorials), optionally along
## [param route] (world X / Z, ending in the yard). Without a squad it goes
## straight for the door once it has reached the house.
func spawn_raider(raider_scene: PackedScene, health_multiplier: float = 1.0, squad: RaidSquad = null, door_spot: int = 0, route: PackedVector2Array = PackedVector2Array()) -> Raider:
	if raider_scene == null or _yard == null:
		return null
	var raider: Raider = _yard.spawn_raider(raider_scene, squad, door_spot, route)
	raider.apply_wave_modifiers(health_multiplier, 1.0)
	return raider


func get_pending_spawn_count() -> int:
	return _pending_spawns.size()


## Officers of the current wave still to come or still standing.
func get_raiders_left() -> int:
	return _pending_spawns.size() + (_yard.get_alive_count() if _yard != null else 0)


## The squads of the waves in the yard (tests).
func get_squads() -> Array[RaidSquad]:
	return _squads


## Forgets officers that have not set off yet (the shift ended, admin).
func clear_pending() -> void:
	_pending_spawns.clear()

# ============================================
# ROUTES
# ============================================

## A squad's way through the streets: from a crossing in a direction no other
## squad of the wave took yet, to the crossing nearest the yard. Empty
## without a town or RaidData.
func _plan_street_route(raid_data: RaidData, taken_directions: Array[int]) -> PackedVector2Array:
	if raid_data == null or _streets == null or _yard == null:
		return PackedVector2Array()
	var house: Vector2 = _yard.get_door_point()
	var start: int = _streets.pick_start(house, raid_data.march_start_distance, taken_directions, _random)
	var goal: int = _streets.get_nearest_node(_yard.bounds.get_center())
	return _streets.find_route(start, goal, raid_data.route_variety, _random)


## Squad cars (to the curb next to the yard, from their own directions), the
## armored vehicle (to the street in front of the house) and helicopters
## (straight over the roofs).
func _queue_vehicles(wave: RaidWave, raid_data: RaidData, taken_directions: Array[int]) -> void:
	if raid_data == null or _streets == null or _yard == null:
		return
	var house: Vector2 = _yard.get_door_point()
	var delay: float = 0.0
	for car_index: int in wave.car_count:
		if car_scene == null:
			break
		var curb: Vector2 = _get_curb_point(_yard.get_spawn_point())
		_queue_vehicle(car_scene, wave, _street_route_to(curb, raid_data, taken_directions), delay)
		delay += raid_data.seconds_between_squads
	for tank_index: int in wave.tank_count:
		if tank_scene == null:
			break
		var stand: Vector2 = _get_shelling_point(tank_index)
		_queue_vehicle(tank_scene, wave, _street_route_to(stand, raid_data, taken_directions), delay + raid_data.tank_delay_seconds)
	for helicopter_index: int in wave.helicopter_count:
		if helicopter_scene == null:
			break
		var heading: float = _random.randf_range(0.0, TAU)
		var start: Vector2 = house + Vector2.from_angle(heading) * raid_data.helicopter_start_distance
		var helicopter_delay: float = delay + raid_data.helicopter_delay_seconds + helicopter_index * raid_data.seconds_between_squads * 2.0
		_queue_vehicle(helicopter_scene, wave, PackedVector2Array([start, _yard.bounds.get_center()]), helicopter_delay)


func _queue_vehicle(scene: PackedScene, wave: RaidWave, route: PackedVector2Array, delay: float) -> void:
	_pending_spawns.append({
		"scene": scene, "delay": delay, "health": wave.health_multiplier,
		"squad": null, "spot": -1, "route": route,
	})


## A way through the streets for a vehicle to [param destination] (on a street).
func _street_route_to(destination: Vector2, raid_data: RaidData, taken_directions: Array[int]) -> PackedVector2Array:
	var start: int = _streets.pick_start(_yard.get_door_point(), raid_data.march_start_distance, taken_directions, _random)
	var route: PackedVector2Array = _streets.find_route(start, _streets.get_nearest_node(destination), raid_data.route_variety, _random)
	route = StreetRoutes.offset_route(route, VEHICLE_LANE)
	route.append(destination)
	return route


## Where armored vehicle [param tank_index] stands to shell the door: in the
## street the door faces, a little to the side of it (one beside another).
func _get_shelling_point(tank_index: int) -> Vector2:
	var ring: Rect2 = _get_home_street_ring()
	var door: Vector2 = _yard.get_door_point()
	var outward: Vector2 = _yard.get_door_outward()
	var side_shift: float = _random.randf_range(-SHELLING_SPREAD, SHELLING_SPREAD) + tank_index * SHELLING_SPACING
	if absf(outward.y) >= absf(outward.x):
		return Vector2(door.x + side_shift, ring.position.y if outward.y < 0.0 else ring.end.y)
	return Vector2(ring.position.x if outward.x < 0.0 else ring.end.x, door.y + side_shift)


## The street ring around the house's block (street centre lines).
func _get_home_street_ring() -> Rect2:
	var block: Vector2i = town_data.home_block
	var left: float = town_data.street_x[block.x]
	var top: float = town_data.street_z[block.y]
	return Rect2(left, top, town_data.street_x[block.x + 1] - left, town_data.street_z[block.y + 1] - top)


## The point on the street ring around the house's block nearest to
## [param point], moved to the curb (where a car stops).
func _get_curb_point(point: Vector2) -> Vector2:
	var ring: Rect2 = _get_home_street_ring()
	var curb_offset: float = town_data.street_width * 0.5 - 1.4
	var candidates: Array[Vector2] = [
		Vector2(clampf(point.x, ring.position.x, ring.end.x), ring.position.y + curb_offset),
		Vector2(clampf(point.x, ring.position.x, ring.end.x), ring.end.y - curb_offset),
		Vector2(ring.position.x + curb_offset, clampf(point.y, ring.position.y, ring.end.y)),
		Vector2(ring.end.x - curb_offset, clampf(point.y, ring.position.y, ring.end.y)),
	]
	var best: Vector2 = candidates[0]
	for candidate: Vector2 in candidates:
		if candidate.distance_to(point) < best.distance_to(point):
			best = candidate
	return best

# ============================================
# INTERNALS
# ============================================

func _has_pending_for(squad: RaidSquad) -> bool:
	for pending: Dictionary in _pending_spawns:
		if pending["squad"] == squad:
			return true
	return false


func _step_pending_spawns(delta: float) -> void:
	for spawn_index: int in range(_pending_spawns.size() - 1, -1, -1):
		var pending: Dictionary = _pending_spawns[spawn_index]
		pending["delay"] = float(pending["delay"]) - delta
		if float(pending["delay"]) <= 0.0:
			_pending_spawns.remove_at(spawn_index)
			var raider: Raider = spawn_raider(pending["scene"] as PackedScene, float(pending["health"]), pending["squad"] as RaidSquad, maxi(0, int(pending["spot"])), pending["route"] as PackedVector2Array)
			# The first officer of a wave announces it.
			if raider != null and int(pending["spot"]) == 0:
				raider.shout_raid_call()
