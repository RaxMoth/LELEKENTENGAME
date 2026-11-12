## Smoke checks of the defense front: the build board, building, turrets,
## the gun, attackers at the door, theft, raid waves (cops and SWAT), guards,
## the armory terminal (guns, ammo) and the front door (open, walk through,
## close, bolt from both sides). Owned by whoever works on the FrontGarden.
##
## Dependencies: SmokeTest, HouseLevel, FrontGarden, FrontDoor, Armory, Office,
##               LaneBoard, LaneEnemy, RaidWave, WeaponCatalog, WalkableArea
class_name DefenseSmokeChecks
extends RefCounted

const JUNKIE: String = "res://Scenes/Levels/House/Garden/Junkie.tscn"
const COP: String = "res://Scenes/Levels/House/Garden/Cop.tscn"
const GOON: String = "res://Scenes/Levels/House/Garden/Goon.tscn"


static func run(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var operation: Operation = level.operation
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var board: LaneBoard = garden.board
	var door: FrontDoor = garden.door
	rig.locomotion.travel_to_spot(1)
	test.check(garden.is_in_defense_zone(), "the front room is the defense position")

	var build_screen: WorldScreen = garden.get_build_screen()
	rig.tap_world_point(build_screen.pixel_to_world(garden.get_build_board().get_card_center(0)))
	await test.frames(3)
	test.check(garden.selected_tower == 0, "pointer picks a tower card on the board above the gate")
	var cash_before: int = operation.get_cash()
	var cell: Vector2i = Vector2i(1, 2)
	rig.tap_world_point(board.grid.cell_to_position(cell))
	await test.frames(3)
	test.check(not board.can_place(cell) and operation.get_cash() < cash_before, "clicking a garden tile builds the tower for cash")

	var junkie: LaneEnemy = _spawn_in_lane(board, JUNKIE, cell.x, board.grid.get_column_z(5))
	test.check(await test.wait_until(func() -> bool: return junkie.health_component.get_health_ratio() < 1.0 or not junkie.is_alive()), "the turret shoots the attacker in its lane")
	var cop: LaneEnemy = _spawn_in_lane(board, COP, 0, board.grid.get_column_z(4))
	var cop_health: float = cop.health_component.current_health
	await test.frames(20)
	rig.tap_world_point(cop.get_hit_center())
	await test.frames(3)
	test.check(cop.health_component.current_health < cop_health, "clicking an attacker fires the gun")
	cop.global_position.z = board.get_home_z() - 0.5
	var door_health: float = door.health_component.current_health
	test.check(await test.wait_until(func() -> bool: return door.health_component.current_health < door_health), "an attacker at the door breaks it down")

	operation.add_product(operation.recipes[0], 2, 4)
	var stock_before: int = operation.stash.get_total()
	_spawn_in_lane(board, JUNKIE, 2, board.get_home_z() - 0.4)
	test.check(await test.wait_until(func() -> bool: return operation.stash.get_total() < stock_before), "a junkie reaching the door steals stock")
	cop.take_hit(100000.0)
	door.health_component.heal(100000.0)

	for leftover: LaneEnemy in board.get_enemies().duplicate():
		leftover.take_hit(100000.0)
	garden.director.is_active = true
	garden.director.step(60.0)
	garden.director.is_active = false
	test.check(garden.director.get_pending_spawn_count() == 0 and garden.director.get_raiders_left() == 0, "selling days send no attackers on their own")
	garden.director.queue_wave(RaidWave.new(0, 2, 1, 1.0), 0.0)
	test.check(garden.director.get_pending_spawn_count() == 3, "a raid wave queues its cops and SWAT")
	garden.director.is_active = true
	garden.director.step(0.01)
	garden.director.is_active = false
	var raiders: Array[LaneEnemy] = board.get_enemies().duplicate()
	var swat_count: int = raiders.filter(func(enemy: LaneEnemy) -> bool: return enemy.faction_name == "SWAT").size()
	test.check(garden.director.get_raiders_left() == 3 and swat_count == 1, "the wave's officers enter the garden")
	for raider: LaneEnemy in raiders:
		raider.take_hit(100000.0)
	test.check(garden.director.get_raiders_left() == 0, "a wave is beaten when every officer is down")

	# Crew: a hired guard shoots attackers near the door.
	Profile.operation.add_reputation(100)
	(level.get_front(Office) as Office).buy_upgrade(GameConfig.get_default().find_upgrade(Types.UPGRADE_GUARD))
	await test.frames(3)
	var guard: Worker = garden.get_node("%Guards").get_child(0) as Worker
	var goon: LaneEnemy = _spawn_in_lane(board, GOON, 0, board.get_home_z() - 2.0)
	var goon_health: float = goon.health_component.current_health
	guard.work_now()
	test.check(guard.is_working() and goon.health_component.current_health < goon_health, "a hired guard shoots attackers near the door")
	goon.take_hit(100000.0)
	await _check_armory(test, level)
	await _check_front_door(test, level)


## Buying guns and ammo at the armory terminal and firing them.
static func _check_armory(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var armory: Armory = level.get_front(Armory) as Armory
	var operation: Operation = level.operation
	var catalog: WeaponCatalog = armory.weapon_catalog
	var smg: WeaponData = catalog.find_weapon(&"smg")
	test.check(garden.get_equipped_weapon() == catalog.get_starter(), "the player starts with the free pistol")
	rig.locomotion.teleport_to(Vector3(-3.0, 0.0, -3.4), PI)
	await test.frames(3)
	var screen: WorldScreen = armory.get_screen()
	var board: ArmoryBoard = armory.get_board()
	var cash_before: int = operation.get_cash()
	rig.tap_world_point(screen.pixel_to_world(board.get_row("weapon", &"smg").get_buy_button().get_global_rect().get_center()))
	await test.frames(3)
	test.check(Profile.armory.loadout.owns(smg) and garden.get_equipped_weapon() == smg and operation.get_cash() == cash_before - smg.cost, "buying the SMG at the armory pays for it and puts it in hand")
	var ammo_before: int = Profile.armory.loadout.get_ammo(smg)
	# Make room for one box, then buy it on the board.
	for shot: int in smg.ammo_pack_size:
		Profile.armory.loadout.try_fire(smg)
	await test.frames(2)
	board.refresh()
	await test.frames(2)
	rig.tap_world_point(screen.pixel_to_world(board.get_row("ammo", &"smg").get_buy_button().get_global_rect().get_center()))
	await test.frames(3)
	test.check(Profile.armory.loadout.get_ammo(smg) == ammo_before, "an ammo box refills the SMG")
	rig.locomotion.travel_to_spot(1)
	var cop: LaneEnemy = _spawn_in_lane(garden.board, COP, 1, garden.board.grid.get_column_z(3))
	await test.frames(5)
	var rounds_before: int = Profile.armory.loadout.get_ammo(smg)
	var health_before: float = cop.health_component.current_health
	garden.fire_weapon(_aim(rig, cop))
	test.check(Profile.armory.loadout.get_ammo(smg) == rounds_before - 1 and cop.health_component.current_health < health_before, "every shot of the SMG uses a round")
	while Profile.armory.loadout.try_fire(smg):
		pass
	await test.frames(10)
	var empty_health: float = cop.health_component.current_health
	garden.fire_weapon(_aim(rig, cop))
	test.check(cop.health_component.current_health == empty_health, "an empty gun does not fire")
	Profile.armory.loadout.equip(catalog.get_starter())
	await test.frames(20)
	garden.fire_weapon(_aim(rig, cop))
	test.check(cop.health_component.current_health < empty_health, "the pistol never runs dry")
	cop.take_hit(100000.0)


## Opening, walking through, closing and bolting the front door from both sides.
static func _check_front_door(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var door: FrontDoor = garden.door
	var walkable: WalkableArea = rig.walkable_area
	var threshold: Vector3 = Vector3(0.0, 0.0, -5.0)
	test.check(not door.is_open() and not door.is_locked() and not walkable.contains(threshold), "the front door starts shut and the doorway is blocked")
	_place_player(rig, Vector3(0.0, 0.0, -4.2), 0.0)
	rig.tap_world_point(door.get_inside_handle().get_grab_center())
	test.check(await test.wait_until(func() -> bool: return door.is_passable()), "using the inside handle swings the door open")
	test.check(walkable.contains(threshold), "an open door makes the doorway walkable")
	test.check(rig.get_held_items().is_empty(), "the flat cursor lets go of the handle right away")
	Input.action_press(Types.ACTION_MOVE_FORWARD)
	var walked_out: bool = await test.wait_until(func() -> bool: return rig.get_feet_position().z < -5.4)
	Input.action_release(Types.ACTION_MOVE_FORWARD)
	test.check(walked_out and garden.is_in_defense_zone(), "the player walks through the doorway onto the porch")
	rig.tap_world_point(door.get_outside_handle().get_grab_center())
	test.check(await test.wait_until(func() -> bool: return not door.is_open()), "the outside handle swings it shut")
	test.check(not walkable.contains(threshold), "a shut door blocks the doorway again")
	rig.tap_world_point(door.get_outside_lock().get_press_center())
	await test.frames(3)
	test.check(door.is_locked(), "the bolt locks the door from outside")
	rig.tap_world_point(door.get_outside_handle().get_grab_center())
	await test.frames(30)
	test.check(not door.is_open(), "a bolted door does not open")
	rig.tap_world_point(door.get_outside_lock().get_press_center())
	await test.frames(3)
	rig.tap_world_point(door.get_outside_handle().get_grab_center())
	await test.wait_until(func() -> bool: return door.is_passable())
	test.check(not door.set_locked(true), "an open door cannot be bolted")
	test.check(door.get_damage_multiplier() > door.unlocked_damage_multiplier, "an open door gives way fastest in a raid")
	_place_player(rig, Vector3(0.0, 0.0, -4.2), PI)
	door.close_fully()
	await test.wait_until(func() -> bool: return not door.is_open())
	rig.tap_world_point(door.get_inside_lock().get_press_center())
	await test.frames(3)
	test.check(door.is_locked() and door.get_damage_multiplier() < door.unlocked_damage_multiplier, "bolted from inside, the door holds best")
	door.set_locked(false)


## Points the flat cursor at an attacker and returns the cursor's pointer.
static func _aim(rig: XRPlayerRig, enemy: LaneEnemy) -> XRPointer:
	rig.aim_at_world_point(enemy.get_hit_center())
	return rig.get_tool_pointer()


static func _place_player(rig: XRPlayerRig, feet: Vector3, yaw: float) -> void:
	rig.move_origin_by(feet - rig.get_feet_position())
	rig.face_yaw(yaw)


## Spawns an attacker and moves it into a chosen lane and depth.
static func _spawn_in_lane(board: LaneBoard, scene_path: String, lane: int, z: float) -> LaneEnemy:
	var enemy: LaneEnemy = board.spawn_enemy(load(scene_path) as PackedScene)
	enemy.enter_lane(board, lane)
	enemy.global_position.x = board.grid.get_lane_x(lane)
	enemy.global_position.z = z
	return enemy
