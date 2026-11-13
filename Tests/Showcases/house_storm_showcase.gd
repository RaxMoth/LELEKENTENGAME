## The raid night after the front door broke: it stands wide open, the
## police have stormed into the front room after the player, and the player
## is hurt (the wrist shows their health in red).
## Loaded by Tests/screenshot_tool.gd with `showcase=house_storm`.
##
## Dependencies: HouseLevel, HouseCycle, FrontGarden, FrontDoor, Yard, Raider,
##               RaidWave, AttackerDirector, PlayerVitals
extends RefCounted

## Where the raiders that got in stand (x, z): two in the front room, one in the doorway.
const INSIDE_SPOTS: Array[Vector2] = [Vector2(-1.2, -3.6), Vector2(1.0, -3.9), Vector2(0.0, -5.6)]
## Damage per hit while staged, so the player stays up for the picture.
const STAGED_PLAYER_DAMAGE: float = 0.5


static func apply(scene: Node) -> void:
	var level: HouseLevel = scene as HouseLevel
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	(level.get_front(SalesWindow) as SalesWindow).flow.is_active = false
	Profile.operation.day_number = level.cycle.get_days_per_cycle()
	level.day_cycle.advance(level.day_cycle.day_seconds + 5.0 - level.day_cycle.clock.elapsed_seconds)
	level.cycle.skip_wave_break()
	garden.director.queue_wave(RaidWave.new(1, 2, 1, 1.0, 0), null, 0.0)
	garden.director.step(0.01)
	garden.door.health_component.damage(1000000.0)
	var raiders: Array[Raider] = garden.yard.get_raiders()
	for raider_index: int in mini(raiders.size(), INSIDE_SPOTS.size()):
		var spot: Vector2 = INSIDE_SPOTS[raider_index]
		raiders[raider_index].global_position = Vector3(spot.x, 0.0, spot.y)
		raiders[raider_index].player_damage = STAGED_PLAYER_DAMAGE
	level.player_vitals.take_damage(level.player_vitals.get_max_health() * 0.72)
