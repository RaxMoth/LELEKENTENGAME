## The raid night at the end of a 3-day cycle: day 3, the police in the
## yard (cops, SWAT and a battering ram working their way in from cover to
## cover), the front door shut, a gun bought at the armory.
## Loaded by Tests/screenshot_tool.gd with `showcase=house_raid`.
##
## Dependencies: HouseLevel, HouseCycle, FrontGarden, FrontDoor, Armory, RaidWave, AttackerDirector
extends RefCounted


static func apply(scene: Node) -> void:
	var level: HouseLevel = scene as HouseLevel
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var armory: Armory = level.get_front(Armory) as Armory
	(level.get_front(SalesWindow) as SalesWindow).flow.is_active = false
	Profile.wallet.add(Types.CURRENCY_CASH, 2000)
	# The weapons come one after the other (knife, axe, pistol): buy the way up to the rifle.
	for weapon_id: StringName in [&"knife", &"axe", &"pistol", &"rifle"]:
		armory.buy_weapon(armory.weapon_catalog.find_weapon(weapon_id))
	Profile.operation.day_number = level.cycle.get_days_per_cycle() * 2
	level.day_cycle.advance(level.day_cycle.day_seconds + 5.0 - level.day_cycle.clock.elapsed_seconds)
	level.cycle.skip_wave_break()
	# A ram team on top of the wave; the squads then work their way in on their own.
	garden.director.queue_wave(RaidWave.new(1, 3, 2, 1.0, 1), null, 0.0)
	garden.director.step(0.01)
