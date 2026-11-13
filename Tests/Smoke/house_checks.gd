## Smoke checks of the house itself: walking and travel, the office (buying
## upgrades, bribes, reputation gates), how upgrades change the house's look
## (renovations, door straps, steel frame, stash shelves), crew wages and
## strikes, controller mapping, popups on the in-world screen, the cabin's
## rats (they bite once each, for 1 health), nightfall,
## raiders storming in through a broken door and hunting the player, and
## losing the shift when the player goes down.
## Owned by whoever works on the house (level, office, crew, XR).
##
## Dependencies: SmokeTest, HouseLevel, HouseStages, Office, FrontGarden, Worker, DayCycle, RatPack, Rat,
##               HouseShell, ShellRenovation, UpgradeLook, Ghost
class_name HouseSmokeChecks
extends RefCounted


## Before the fronts' checks: the player can move around the house.
static func run_start(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var walkable: WalkableArea = rig.walkable_area
	test.check(not rig.is_xr_active and walkable != null, "rig runs the flat simulator with a walkable area")
	test.check(walkable.contains(rig.get_feet_position()), "the player starts on a walkable floor")
	test.check(walkable.contains(Vector3(0.0, 0.0, -9.0)) and walkable.contains(Vector3(0.0, 0.0, -35.0)), "the garden and the street beyond its gate are walkable")
	var town: Town = level.get_front(Town) as Town
	var building: Rect2 = town.layout.building_footprints[0]
	test.check(not walkable.contains(Vector3(building.get_center().x, 0.0, building.get_center().y)), "the town's buildings can't be walked into")
	test.check(not walkable.contains(Vector3(town.layout.bounds.position.x - 3.0, 0.0, 0.0)), "the town ends beyond its outer streets")
	test.check(not walkable.contains(Vector3(0.0, 0.0, -5.0)), "a shut front door keeps the player inside")
	rig.locomotion.travel_to_spot(0)
	var lab_spot: Vector3 = rig.locomotion.travel_spots[0].global_position
	test.check(rig.get_feet_position().distance_to(Vector3(lab_spot.x, rig.global_position.y, lab_spot.z)) < 0.05, "quick travel moves the player to the lab")
	var before: Vector3 = rig.get_feet_position()
	Input.action_press(Types.ACTION_MOVE_FORWARD)
	await test.physics_frames(20)
	Input.action_release(Types.ACTION_MOVE_FORWARD)
	test.check(rig.get_feet_position().distance_to(before) > 0.2 and walkable.contains(rig.get_feet_position()), "walking moves the player and stays on the floor")
	test.check(rig.get_body().get_stride() > 0.05, "the body under the player strides as they walk")
	var glove: GloveHand = rig.get_hand_pointer(Types.Hand.LEFT).get_parent_node_3d().find_child("Glove", false, false) as GloveHand
	test.check(glove != null, "each controller wears a glove")
	if glove != null:
		glove.set_curl(1.0, 1.0)
		test.check(is_equal_approx(glove.get_grip_curl(), 1.0), "a full grip closes the glove into a fist")
	await _check_house_stages(test, level)


## A new operation starts in the one-room cabin; Extend the House builds the
## full house (the rest of the checks run in it).
static func _check_house_stages(test: SmokeTest, level: HouseLevel) -> void:
	var stages: HouseStages = level.get_node("%Stages") as HouseStages
	var walkable: WalkableArea = level.rig.walkable_area
	var office: Office = level.get_front(Office) as Office
	var shelf: Node3D = level.get_node("%StashShelf") as Node3D
	var config: GameConfig = GameConfig.get_default()
	var office_spot: Vector3 = Vector3(3.0, 0.0, -0.5)
	test.check(stages.get_layout().stage_name == "Cabin" and level.get_house_shell().walls.size() == 6, "a new operation starts in a one-room cabin")
	test.check(walkable.contains(Vector3(-0.3, 0.0, 0.0)) and not walkable.contains(office_spot), "the cabin's room is walkable; the house's office isn't there yet")
	test.check(office.get_screen().global_position.x < 1.0 and shelf.global_position.x < 1.0, "the office board and the stash shelf stand in the cabin")
	test.check(not Profile.upgrades.is_requirement_met(config.find_upgrade(Types.UPGRADE_CELLAR)), "the cellar needs the full house first")
	await _check_rats(test, level)
	var extension: UpgradeData = config.find_upgrade(Types.UPGRADE_HOUSE_EXTENSION)
	Profile.wallet.add(Types.CURRENCY_CASH, Profile.upgrades.get_next_cost(extension), false)
	office.buy_upgrade(extension)
	await test.frames(2)
	test.check(stages.get_layout().stage_name == "House" and level.get_house_shell().walls.size() == 9 and walkable.contains(office_spot), "Extend the House builds the office, the stash room and the hallway")
	test.check(office.get_screen().global_position.x > 4.0 and shelf.global_position.x > 4.0, "the office board and the stash shelf move into their rooms")
	test.check(not level.get_rats().is_about(), "the rats are gone once the house is extended")


## After the fronts' checks: office, crew, controllers, popups, night, losing.
static func run_end(test: SmokeTest, level: HouseLevel) -> void:
	await _check_admin(test, level)
	await _check_office(test, level)
	await _check_house_looks(test, level)
	_check_crew_wages(test, level)
	await _check_controllers(test, level)
	await _check_world_popup(test, level)
	var day_cycle: DayCycle = level.day_cycle
	var nights: Array[int] = [0]
	day_cycle.nightfall.connect(func() -> void: nights[0] += 1)
	day_cycle.advance(day_cycle.day_seconds)
	await test.frames(3)
	test.check(day_cycle.is_night() and nights[0] == 1, "the day turns into night")
	test.check(not level.cycle.is_raid_active() and level.cycle.allows_customers(), "the night of a selling day brings no raid")
	if Profile.operation.day_number != level.get_ghost().night_number:
		test.check(not level.get_ghost().is_haunting(), "no ghost on other nights")
	await _check_ghost(test, level)
	await _check_fuse_box(test, level)
	_check_skills(test, level)
	await _check_holsters(test, level)
	await _check_raid_waves(test, level)
	await _check_storming_in(test, level)
	var operation: Operation = level.operation
	operation.add_product(operation.recipes[0], 2, 3)
	level.player_vitals.take_damage(level.player_vitals.get_health() + 1.0)
	test.check(await test.wait_until(func() -> bool: return UI.has_open_popup() and level.phase == LevelBase.Phase.FINISHED), "going down ends the shift (mid-raid)")
	test.check(operation.stash.get_total() == 0, "going down loses the stash")
	test.check(operation.is_shift_over() and operation.add_product(operation.recipes[0], 2, 3) == 0, "nothing more goes into the stash once the shift is lost")
	await test.frames(30)
	UI.close_top_popup()


## The starter cabin has rats: they run about, and one close to the
## player's feet may bite — once, for 1 health.
static func _check_rats(test: SmokeTest, level: HouseLevel) -> void:
	var rats: RatPack = level.get_rats()
	var rat_list: Array[Rat] = rats.get_rats()
	test.check(rats.is_about() and rat_list.size() >= 3, "rats live in the starter cabin")
	var start_spots: Array[Vector3] = []
	for rat: Rat in rat_list:
		start_spots.append(rat.global_position)
	test.check(await test.wait_until(func() -> bool:
		for rat_index: int in rat_list.size():
			if rat_list[rat_index].global_position.distance_to(start_spots[rat_index]) > 0.3:
				return true
		return false), "the rats scurry about")
	# One rat, right at the player's feet, sure to bite; the others sit still meanwhile.
	level.rig.locomotion.teleport_to(Vector3(-2.0, 0.0, 0.0), 0.0)
	await test.frames(2)
	var biter: Rat = rat_list[0]
	for rat: Rat in rat_list:
		rat.process_mode = Node.PROCESS_MODE_INHERIT if rat == biter else Node.PROCESS_MODE_DISABLED
	var chance_before: float = rats.bite_chance_per_second
	rats.bite_chance_per_second = 1000.0
	var vitals: PlayerVitals = level.player_vitals
	var health_before: float = vitals.get_health()
	biter.global_position = level.rig.get_feet_position() + Vector3(0.2, 0.0, 0.0)
	test.check(await test.wait_until(func() -> bool: return biter.has_bitten()), "a rat at the player's feet bites")
	await test.frames(10)
	test.check(is_equal_approx(health_before - vitals.get_health(), rats.bite_damage) and is_equal_approx(rats.bite_damage, 1.0), "a bite costs 1 health")
	biter.global_position = level.rig.get_feet_position() + Vector3(0.2, 0.0, 0.0)
	await test.frames(40)
	test.check(is_equal_approx(health_before - vitals.get_health(), rats.bite_damage), "each rat bites only once")
	rats.bite_chance_per_second = chance_before
	for rat: Rat in rat_list:
		rat.process_mode = Node.PROCESS_MODE_INHERIT
	await _check_rat_traps(test, level, rats)


## The rats chew through stash bags; traps from the box beside the shelf,
## set on the floor, catch them (a trap let go off the floor goes back in).
static func _check_rat_traps(test: SmokeTest, level: HouseLevel, rats: RatPack) -> void:
	var rat_list: Array[Rat] = rats.get_rats()
	var operation: Operation = level.operation
	operation.add_product(operation.recipes[0], 2, 4)
	var stash_before: int = operation.stash.get_total()
	var chewer: Rat = rat_list[1]
	var chew_before: float = rats.chew_seconds
	rats.chew_seconds = 0.4
	chewer.global_position = Vector3(rats.get_stash_point().x - 0.6, 0.0, rats.get_stash_point().z)
	chewer.go_for_stash()
	test.check(await test.wait_until(func() -> bool: return operation.stash.get_total() < stash_before), "a rat at the stash shelf chews through a bag")
	rats.chew_seconds = chew_before
	var box: TrapBox = rats.get_trap_box()
	var traps_before: int = box.get_traps_left()
	var trap: RatTrap = box.take_item() as RatTrap
	test.check(trap != null and box.get_traps_left() == traps_before - 1, "the box hands out a rat trap")
	trap.global_position = Vector3(-2.2, 1.0, 0.6)
	trap.drop_nowhere()
	test.check(trap.is_armed and absf(trap.global_position.y) < 0.05, "a trap let go over the floor is set on the floor")
	var caught: Rat = rat_list[2]
	caught.global_position = trap.global_position + Vector3(0.05, 0.0, 0.0)
	test.check(await test.wait_until(func() -> bool: return caught.is_caught()), "a rat that runs over a set trap is caught")
	test.check(rats.get_free_rat_count() == rat_list.size() - 1, "a caught rat is gone for the day")
	var stray: RatTrap = box.take_item() as RatTrap
	stray.global_position = Vector3(-2.2, 12.0, 0.6)
	stray.drop_nowhere()
	test.check(box.get_traps_left() == traps_before - 1, "a trap let go off the floor goes back into the box")


## The admin terminal in the office (debug builds): cash and day by pointer.
static func _check_admin(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var admin: AdminPanel = level.get_front(AdminPanel) as AdminPanel
	test.check(admin != null and admin.visible, "the admin terminal is there in debug builds")
	rig.locomotion.teleport_to(Vector3(2.4, 0.0, -0.4), 0.0)
	await test.frames(3)
	var screen: WorldScreen = admin.get_screen()
	var board: AdminBoard = admin.get_board()
	var cash_before: int = level.operation.get_cash()
	rig.tap_world_point(screen.pixel_to_world(board.get_button(AdminBoard.ACTION_CASH_SMALL).get_global_rect().get_center()))
	await test.frames(3)
	test.check(level.operation.get_cash() == cash_before + AdminPanel.SMALL_CASH, "admin: pointing at +$1,000 gives cash")
	var day_before: int = Profile.operation.day_number
	rig.tap_world_point(screen.pixel_to_world(board.get_button(AdminBoard.ACTION_DAY_FORWARD).get_global_rect().get_center()))
	await test.frames(3)
	test.check(Profile.operation.day_number == day_before + 1 and level.cycle.get_day_in_cycle() == RaidPlanner.get_day_in_cycle(day_before + 1, level.cycle.raid_data), "admin: Day +1 moves the cycle on")
	test.check(admin.run_action(AdminBoard.ACTION_DAY_BACK) and Profile.operation.day_number == day_before, "admin: Day -1 moves it back")
	test.check(not admin.run_action(AdminBoard.ACTION_NEXT_WAVE), "admin: wave actions wait for a raid")


static func _check_office(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var office: Office = level.get_front(Office) as Office
	rig.locomotion.travel_to_spot(3)
	var office_screen: WorldScreen = office.get_screen()
	var office_board: OfficeBoard = office.get_board()
	rig.tap_world_point(office_screen.pixel_to_world(office_board.get_tab(&"defense").get_global_rect().get_center()))
	await test.frames(3)
	var first_row: ShopItemRow = office_board.find_child("Rows", true, false).get_child(0) as ShopItemRow
	var door: FrontDoor = (level.get_front(FrontGarden) as FrontGarden).door
	var max_before: float = door.health_component.max_health
	rig.tap_world_point(office_screen.pixel_to_world(first_row.get_buy_button().get_global_rect().get_center()))
	await test.frames(5)
	test.check(Profile.upgrades.get_level(Types.UPGRADE_DOOR) == 1 and door.health_component.max_health > max_before, "buying Reinforced Door on the office board strengthens the door")
	var operation: Operation = level.operation
	operation.add_heat(30.0)
	var heat_before: float = operation.heat.value
	test.check(operation.bribe() and operation.heat.value < heat_before, "a bribe cools the heat")
	Profile.operation.add_reputation(-Profile.operation.reputation)
	test.check(not Profile.upgrades.can_purchase(GameConfig.get_default().find_upgrade(Types.UPGRADE_VIP)), "upgrades stay locked until the reputation is there")


## Night 4: the ghost turns up behind the player, freezes when looked at,
## stares for a second and is gone.
static func _check_ghost(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var ghost: Ghost = level.get_ghost()
	# In the hallway looking north: the hall behind stays in a straight line.
	rig.locomotion.teleport_to(Vector3(0.0, 0.0, -1.2), 0.0)
	rig.aim_at_world_point(Vector3(0.0, 1.6, -6.0))
	ghost.haunt(rig)
	await test.frames(10)
	var to_ghost: Vector3 = ghost.global_position - rig.get_feet_position()
	test.check(ghost.is_haunting() and not ghost.was_seen() and to_ghost.z > 2.0, "on night 4 a ghost turns up behind the player")
	rig.aim_at_world_point(ghost.get_head_position())
	await test.frames(3)
	test.check(ghost.was_seen() and ghost.is_haunting(), "looking at the ghost makes it stop and stare")
	await test.frames(20)
	test.check(ghost.is_haunting(), "it keeps staring for a moment")
	test.check(await test.wait_until(func() -> bool: return not ghost.visible), "then it vanishes")


## Upgrades change how the house looks: a renovation swaps a shell surface
## to its next material (and cools heat faster), Reinforced Door bolts iron
## straps on, Steel Door Frame shows its frame, Bigger Stash real shelves.
static func _check_house_looks(test: SmokeTest, level: HouseLevel) -> void:
	var office: Office = level.get_front(Office) as Office
	var config: GameConfig = GameConfig.get_default()
	var shell: HouseShell = level.get_house_shell()
	var door: FrontDoor = (level.get_front(FrontGarden) as FrontGarden).door
	var straps: UpgradeLook = door.find_child("Straps", true, false) as UpgradeLook
	var middle_strap: UpgradeLook = door.find_child("MiddleStrap", true, false) as UpgradeLook
	test.check(straps != null and straps.is_shown() and straps.visible and not middle_strap.is_shown(), "Reinforced Door level 1 bolts the first iron straps on the door")
	var reputation_before: int = Profile.operation.reputation
	Profile.operation.add_reputation(20)
	var shabby_wall: Material = shell.get_surface_material(HouseShell.SurfaceKind.INSIDE_WALL)
	var cooling_before: float = level.operation.heat.cooling_per_second
	var walls: UpgradeData = config.find_upgrade(Types.UPGRADE_RENOVATE_WALLS)
	var walls_renovation: ShellRenovation = _find_renovation(shell, Types.UPGRADE_RENOVATE_WALLS, HouseShell.SurfaceKind.INSIDE_WALL)
	_buy(office, walls)
	await test.frames(2)
	test.check(walls_renovation != null and shell.get_surface_material(HouseShell.SurfaceKind.INSIDE_WALL) == walls_renovation.get_material(1) and shell.get_surface_material(HouseShell.SurfaceKind.INSIDE_WALL) != shabby_wall, "Patch the Walls plasters the inside walls")
	test.check(level.operation.heat.cooling_per_second > cooling_before, "a renovation makes heat cool faster")
	_buy(office, walls)
	await test.frames(2)
	test.check(shell.get_surface_material(HouseShell.SurfaceKind.INSIDE_WALL) == walls_renovation.get_material(2), "the second level paints them")
	var ceiling_renovation: ShellRenovation = _find_renovation(shell, Types.UPGRADE_RENOVATE_WALLS, HouseShell.SurfaceKind.CEILING)
	test.check(ceiling_renovation != null and shell.get_surface_material(HouseShell.SurfaceKind.CEILING) == ceiling_renovation.get_material(2), "painting the walls paints the ceiling too")
	for upgrade_id: StringName in [Types.UPGRADE_RENOVATE_FLOOR, Types.UPGRADE_RENOVATE_FACADE, Types.UPGRADE_RENOVATE_ROOF]:
		_buy(office, config.find_upgrade(upgrade_id))
	await test.frames(2)
	var renovated_surfaces: int = 0
	for kind: HouseShell.SurfaceKind in [HouseShell.SurfaceKind.FLOOR, HouseShell.SurfaceKind.OUTSIDE_WALL, HouseShell.SurfaceKind.ROOF]:
		var renovation: ShellRenovation = _find_renovation(shell, &"", kind)
		if renovation != null and shell.get_surface_material(kind) == renovation.get_material(1):
			renovated_surfaces += 1
	test.check(renovated_surfaces == 3, "the floor, brickwork and roof renovations change their surfaces")
	var steel_frame: UpgradeLook = level.find_child("SteelDoorFrame", true, false) as UpgradeLook
	test.check(steel_frame != null and not steel_frame.is_shown(), "no steel door frame before it is bought")
	_buy(office, config.find_upgrade(Types.UPGRADE_SECURITY))
	await test.frames(2)
	test.check(steel_frame.is_shown() and steel_frame.visible, "Steel Door Frame shows a steel frame around the front door")
	var shelf: Node3D = level.get_node("%StashShelf") as Node3D
	var wooden_shelf: UpgradeLook = shelf.get_node("WoodenShelf") as UpgradeLook
	var rack: Node3D = shelf.get_node("Rack") as Node3D
	var had_wooden_shelf: bool = wooden_shelf.is_shown()
	if not had_wooden_shelf:
		test.check(rack.visible, "the stash starts on boards and blocks")
		_buy(office, config.find_upgrade(Types.UPGRADE_STORAGE))
		await test.frames(2)
	test.check(wooden_shelf.is_shown() and wooden_shelf.visible and not rack.visible, "Bigger Stash swaps the boards and blocks for a real wooden shelf")
	Profile.operation.add_reputation(reputation_before - Profile.operation.reputation)


## Buys [param upgrade] at the office with cash added for it (the checks
## before may have spent the budget).
static func _buy(office: Office, upgrade: UpgradeData) -> void:
	Profile.wallet.add(Types.CURRENCY_CASH, Profile.upgrades.get_next_cost(upgrade), false)
	office.buy_upgrade(upgrade)


## The shell's renovation for [param kind] (and [param upgrade_id] unless empty).
static func _find_renovation(shell: HouseShell, upgrade_id: StringName, kind: HouseShell.SurfaceKind) -> ShellRenovation:
	for renovation: ShellRenovation in shell.renovations:
		if renovation.surface == kind and (upgrade_id.is_empty() or renovation.upgrade_id == upgrade_id):
			return renovation
	return null


static func _check_crew_wages(test: SmokeTest, level: HouseLevel) -> void:
	var operation: Operation = level.operation
	var hired: Worker = null
	for node: Node in level.get_tree().get_nodes_in_group(Types.GROUP_CREW):
		var worker: Worker = node as Worker
		if worker.is_hired():
			hired = worker
			break
	if hired == null:
		test.check(false, "some crew is hired by now")
		return
	var cash: int = operation.get_cash()
	operation.spend_cash(cash, "test")
	test.check(not hired.pay_wage() and not hired.is_working(), "unpaid crew go on strike")
	Profile.wallet.add(Types.CURRENCY_CASH, cash, false)
	test.check(hired.pay_wage() and hired.is_working(), "paid crew get back to work")


## Day 3 of the cycle: the raid starts, the window closes, the first wave
## comes and is beaten, the second wave comes (the caller then loses the door).
static func _check_raid_waves(test: SmokeTest, level: HouseLevel) -> void:
	var cycle: HouseCycle = level.cycle
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var window: SalesWindow = level.get_front(SalesWindow) as SalesWindow
	for enemy: Raider in garden.yard.get_raiders().duplicate():
		enemy.take_hit(1000000.0)
	Profile.operation.day_number = cycle.get_days_per_cycle()
	test.check(cycle.is_raid_day() and cycle.get_day_in_cycle() == cycle.get_days_per_cycle(), "day 3 of the cycle is the raid day")
	window.flow.is_active = true
	cycle.start_raid()
	await test.frames(2)
	test.check(cycle.is_raid_active() and not cycle.allows_customers() and window.get_queue_size() == 0, "the raid starts and the back window closes")
	window.flow.step(60.0)
	window.flow.is_active = false
	test.check(window.get_queue_size() == 0, "no customers come during a raid")
	test.check(cycle.get_wave_count() == 2 and not cycle.is_wave_active(), "the first raid has two waves and a moment to prepare")
	garden.director.is_active = true
	cycle.skip_wave_break()
	test.check(await test.wait_until(func() -> bool: return cycle.is_wave_active()), "the first wave starts")
	await test.wait_until(func() -> bool: return garden.director.get_pending_spawn_count() == 0)
	test.check(garden.director.get_raiders_left() == 3, "the first wave brings three cops")
	for raider: Raider in garden.yard.get_raiders().duplicate():
		raider.take_hit(1000000.0)
	test.check(await test.wait_until(func() -> bool: return not cycle.is_wave_active() and cycle.is_raid_active()), "beating every officer ends the wave, the raid goes on")
	cycle.skip_wave_break()
	test.check(await test.wait_until(func() -> bool: return cycle.is_wave_active() and cycle.get_wave_number() == 2), "the next wave follows")


## Mid-raid the door breaks: it swings open, the shift goes on, and every
## raider — including the next ones — comes into the house after the player
## (along the floors' routes, through the doorway) and hits them; the gun
## then works anywhere in the house.
static func _check_storming_in(test: SmokeTest, level: HouseLevel) -> void:
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var door: FrontDoor = garden.door
	var rig: XRPlayerRig = level.rig
	var vitals: PlayerVitals = level.player_vitals
	test.check(is_equal_approx(vitals.get_health(), vitals.get_max_health()), "the player starts the shift unhurt")
	test.check(await test.wait_until(func() -> bool: return garden.director.get_pending_spawn_count() == 0 and garden.yard.get_alive_count() > 0), "the second wave is in the yard")
	rig.locomotion.teleport_to(Vector3(0.0, 0.0, -3.0), PI)
	door.set_locked(true)
	door.health_component.damage(1000000.0)
	test.check(await test.wait_until(func() -> bool: return door.is_passable()), "a broken door bursts wide open")
	test.check(level.is_playing() and door.is_broken() and not door.is_locked(), "a broken door doesn't end the shift")
	door.close_fully()
	await test.frames(30)
	test.check(door.is_passable(), "a broken door can't be shut")
	var raiders: Array[Raider] = []
	for raider: Raider in garden.yard.get_raiders():
		if raider.is_alive():
			raiders.append(raider)
	test.check(garden.yard.is_hunting() and raiders.all(func(raider: Raider) -> bool: return raider.is_hunting()), "every raider comes after the players")
	# One of them right off the porch, so the check doesn't wait for a walk across the yard.
	raiders[0].global_position = Vector3(0.0, 0.0, -7.5)
	test.check(await test.wait_until(func() -> bool: return vitals.get_health() < vitals.get_max_health()), "a raider follows the player through the doorway into the house and hits them")
	test.check(raiders[0].global_position.z > door.global_position.z, "it came in through the front door")
	test.check(vitals.is_alive(), "one hit doesn't put the player down")
	rig.locomotion.teleport_to(Vector3(2.4, 0.0, -0.4), 0.0)
	await test.frames(2)
	test.check(not garden.is_in_defense_zone() and garden.can_defend(), "once they stormed in, the gun works anywhere in the house")


## At night the fuses may blow: the power goes out (the lab says so) until
## the lever on the fuse box is flipped back.
static func _check_fuse_box(test: SmokeTest, level: HouseLevel) -> void:
	var fuse_box: FuseBox = level.get_fuse_box()
	var operation: Operation = level.operation
	var lab: Lab = level.get_front(Lab) as Lab
	var chance_before: float = fuse_box.trip_chance_per_night_hour
	fuse_box.trip_chance_per_night_hour = 1.0
	fuse_box.on_hour_passed(true)
	fuse_box.trip_chance_per_night_hour = chance_before
	await test.frames(2)
	test.check(fuse_box.is_tripped() and not operation.has_power, "at night the old wiring can blow the fuses: the power goes out")
	test.check(lab.get_status_line() == TranslationServer.translate("Lab: no power"), "without power the lab stands still")
	level.rig.locomotion.teleport_to(Vector3(-3.9, 0.0, -3.6), -PI * 0.5)
	await test.frames(3)
	level.rig.tap_world_point(fuse_box.get_lever_button().get_press_center())
	await test.frames(3)
	test.check(not fuse_box.is_tripped() and operation.has_power, "flipping the lever on the fuse box brings the power back")


## Skills grow by doing: the day's crafting, harvesting and fighting left
## experience; a level-up widens the green zone and shows on the wrist.
static func _check_skills(test: SmokeTest, level: HouseLevel) -> void:
	var operation: Operation = level.operation
	test.check(Profile.skills.book.get_xp(SkillBook.Skill.FIGHTING) > 0.0, "landing punches and blade hits trains fighting")
	var zone_before: float = operation.get_sweet_zone_multiplier()
	var level_before: int = Profile.skills.get_level(SkillBook.Skill.CRAFTING)
	var level_ups: Array[int] = []
	operation.skill_leveled.connect(func(_skill: int, new_level: int) -> void: level_ups.append(new_level))
	while Profile.skills.get_level(SkillBook.Skill.CRAFTING) == level_before:
		operation.record_craft(1.0)
	test.check(level_ups.size() == 1 and operation.get_sweet_zone_multiplier() > zone_before, "a crafting level-up widens the green zone")
	test.check(level.get_skills_line().contains("%s %d" % [TranslationServer.translate("Craft"), level_before + 1]), "the wrist shows the skill levels")


## In a headset the weapons hang on the body: knife at the hip, axe on the
## back, the gun on the chest. A grip there draws one into that hand; one
## is out at a time; opening the grip puts it back.
static func _check_holsters(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var holsters: WeaponHolsters = level.context.holsters
	var catalog: WeaponCatalog = holsters.weapon_catalog
	test.check(holsters.get_holstered(WalkingBody.HOLSTER_HIP) == catalog.find_weapon(&"knife") and holsters.get_holstered(WalkingBody.HOLSTER_BACK) == catalog.find_weapon(&"axe") and holsters.get_holstered(WalkingBody.HOLSTER_CHEST) != null, "the knife hangs at the hip, the axe on the back, the gun on the chest")
	var chest_gun: WeaponData = holsters.get_holstered(WalkingBody.HOLSTER_CHEST)
	var left_hand: Node3D = rig.get_hand_pointer(Types.Hand.LEFT).get_parent_node_3d()
	var right_hand: Node3D = rig.get_hand_pointer(Types.Hand.RIGHT).get_parent_node_3d()
	await test.frames(2)
	left_hand.global_position = holsters.get_holster_position(WalkingBody.HOLSTER_HIP)
	rig.handle_controller_button(Types.Hand.LEFT, Types.XR_ACTION_GRIP_CLICK, true)
	test.check(holsters.get_drawn(Types.Hand.LEFT) == catalog.find_weapon(&"knife") and rig.get_held_items().is_empty(), "a grip at the hip draws the knife into that hand")
	right_hand.global_position = holsters.get_holster_position(WalkingBody.HOLSTER_CHEST)
	rig.handle_controller_button(Types.Hand.RIGHT, Types.XR_ACTION_GRIP_CLICK, true)
	test.check(holsters.get_drawn(Types.Hand.RIGHT) == chest_gun and holsters.get_drawn(Types.Hand.LEFT) == null, "drawing the gun puts the knife back: one weapon out at a time")
	rig.handle_controller_button(Types.Hand.RIGHT, Types.XR_ACTION_GRIP_CLICK, false)
	rig.handle_controller_button(Types.Hand.LEFT, Types.XR_ACTION_GRIP_CLICK, false)
	test.check(not holsters.has_drawn(), "opening the grip puts the weapon back")


## Without a headset the controller callbacks are the only way to run the XR input mapping.
static func _check_controllers(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var action_counts: Dictionary[StringName, int] = {&"primary": 0, &"secondary": 0}
	rig.primary_action_pressed.connect(func(_pointer: XRPointer) -> void: action_counts[&"primary"] += 1)
	rig.secondary_action_pressed.connect(func(_pointer: XRPointer) -> void: action_counts[&"secondary"] += 1)
	# Beams at the ceiling: a trigger on an item or button would use that instead.
	var head: Vector3 = rig.get_head_transform().origin
	for hand: Types.Hand in [Types.Hand.LEFT, Types.Hand.RIGHT]:
		var pointer: XRPointer = rig.get_hand_pointer(hand)
		pointer.get_parent_node_3d().global_position = head
		pointer.set_ray(head, Vector3.UP)
	rig.call("_on_right_hand_button_pressed", String(Types.XR_ACTION_TRIGGER_CLICK))
	rig.call("_on_right_hand_button_released", String(Types.XR_ACTION_TRIGGER_CLICK))
	rig.call("_on_left_hand_button_pressed", String(Types.XR_ACTION_TRIGGER_CLICK))
	rig.call("_on_left_hand_button_released", String(Types.XR_ACTION_TRIGGER_CLICK))
	test.check(action_counts[&"primary"] == 1 and action_counts[&"secondary"] == 1, "controller triggers map to use (dominant) and blaster (off-hand)")
	var forward_before: Vector3 = -rig.get_head_transform().basis.z
	rig.call("_on_right_hand_input_vector2_changed", String(Types.XR_ACTION_THUMBSTICK), Vector2(0.9, 0.0))
	rig.call("_on_right_hand_input_vector2_changed", String(Types.XR_ACTION_THUMBSTICK), Vector2.ZERO)
	var forward_walk_stick: Vector3 = -rig.get_head_transform().basis.z
	test.check(forward_walk_stick.is_equal_approx(forward_before), "the dominant (walking) stick doesn't turn the player")
	rig.call("_on_left_hand_input_vector2_changed", String(Types.XR_ACTION_THUMBSTICK), Vector2(0.9, 0.0))
	rig.call("_on_left_hand_input_vector2_changed", String(Types.XR_ACTION_THUMBSTICK), Vector2.ZERO)
	var forward_after: Vector3 = -rig.get_head_transform().basis.z
	var turned_degrees: float = rad_to_deg(Vector2(forward_before.x, forward_before.z).angle_to(Vector2(forward_after.x, forward_after.z)))
	test.check(absf(absf(turned_degrees) - rig.locomotion.snap_turn_degrees) < 1.0, "an off-hand stick flick sideways snap-turns the player")
	rig.call("_on_left_hand_button_pressed", String(Types.XR_ACTION_MENU_BUTTON))
	await test.frames(30)
	test.check(level.get_tree().paused and UI.has_open_popup(), "controller menu button pauses")
	rig.call("_on_right_hand_button_pressed", String(Types.XR_ACTION_SECONDARY_BUTTON))
	test.check(await test.wait_until(func() -> bool: return level.is_playing() and not level.get_tree().paused), "controller menu button resumes")


static func _check_world_popup(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	rig.set_world_space_ui(true)
	level.pause_level()
	await test.frames(40)
	var popup_screen: WorldScreen = rig.get_node("%PopupScreen") as WorldScreen
	var resume_button: Button = UI.get_world_viewport().find_child("ResumeButton", true, false) as Button
	test.check(level.get_tree().paused and popup_screen.is_active and resume_button != null, "pause menu opens on the in-world popup screen")
	if resume_button != null:
		rig.tap_world_point(popup_screen.pixel_to_world(resume_button.global_position + resume_button.size * 0.5))
	test.check(await test.wait_until(func() -> bool: return level.is_playing() and not level.get_tree().paused), "pointer presses a popup button on the world screen")
	rig.set_world_space_ui(false)
	test.check(not UI.is_world_space_enabled(), "popups return to the window overlay")
