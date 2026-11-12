## The raid night at the end of a 3-day cycle: day 3, the police in the
## garden (cops and SWAT), the front door bolted, a gun bought at the armory.
## Loaded by Tests/screenshot_tool.gd with `showcase=house_raid`.
##
## Dependencies: HouseLevel, HouseCycle, FrontGarden, FrontDoor, Armory, RaidWave
extends RefCounted


static func apply(scene: Node) -> void:
	var level: HouseLevel = scene as HouseLevel
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var armory: Armory = level.get_front(Armory) as Armory
	(level.get_front(SalesWindow) as SalesWindow).flow.is_active = false
	Profile.wallet.add(Types.CURRENCY_CASH, 2000)
	armory.buy_weapon(armory.weapon_catalog.find_weapon(&"rifle"))
	Profile.operation.day_number = level.cycle.get_days_per_cycle() * 2
	level.day_cycle.advance(level.day_cycle.day_seconds + 5.0 - level.day_cycle.clock.elapsed_seconds)
	garden.door.set_locked(true)
	level.cycle.skip_wave_break()
	garden.director.queue_wave(RaidWave.new(1, 3, 2, 1.0), 0.0)
	garden.director.step(0.01)
	var lane_offset: int = 0
	for enemy: LaneEnemy in garden.board.get_enemies():
		enemy.global_position.z = garden.board.grid.get_column_z(2 + lane_offset % 3) - lane_offset * 0.4
		lane_offset += 1
