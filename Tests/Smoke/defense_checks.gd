## Smoke checks of the defense front: the open yard and its cover, fists
## and blades (a new player has only fists; knife, axe, then guns), the gun
## in hand, raiders at the door and turning on a player out in the yard, raid waves (cops, SWAT, a battering ram) in
## squads that take cover and rush, guards, roof turrets and the Security
## PC, the armory terminal (guns, ammo) and the front door (open, walk
## through, close, bolt from both sides). Owned by whoever works on the
## FrontGarden.
##
## Dependencies: SmokeTest, HouseLevel, FrontGarden, FrontDoor, Yard, Raider,
##               RaidSquad, HouseTurret, SecurityPc, Armory, Office, RaidWave,
##               WeaponCatalog, WeaponLoadout, ArmoryBoard, PlayerVitals, WalkableArea
class_name DefenseSmokeChecks
extends RefCounted

const COP: String = "res://Scenes/Levels/House/Garden/Cop.tscn"
## Right behind the parked car, as seen from the house.
const BEHIND_CAR: Vector2 = Vector2(4.5, -14.3)


static func run(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var yard: Yard = garden.yard
	var door: FrontDoor = garden.door
	rig.locomotion.travel_to_spot(1)
	test.check(garden.is_in_defense_zone(), "the front room is the defense position")
	test.check(yard.get_obstacle_circles().size() >= 10, "the yard is open ground with trees, rocks and a car for cover")
	await _check_fists_and_blades(test, level)
	rig.locomotion.travel_to_spot(1)
	await test.frames(3)

	var cop: Raider = _spawn_at(garden, Vector2(0.0, -8.5))
	var cop_health: float = cop.health_component.current_health
	rig.tap_world_point(cop.get_hit_center())
	await test.frames(3)
	test.check(cop.health_component.current_health < cop_health, "clicking a raider fires the gun")
	test.check(garden.get_shown_weapon() != null and garden.get_shown_weapon().is_visible_in_tree(), "the gun shows in hand while defending")
	var hidden: Raider = _spawn_at(garden, BEHIND_CAR)
	var head: Vector3 = rig.get_head_transform().origin
	test.check(yard.pick_raider(head, (hidden.get_hit_center() - head).normalized(), 40.0) == null, "the parked car hides a raider from shots")
	hidden.take_hit(100000.0)
	cop.global_position = Vector3(0.3, 0.0, -7.0)
	cop.freeze(false)
	cop.on_squad_rush()
	var door_health: float = door.health_component.current_health
	test.check(await test.wait_until(func() -> bool: return door.health_component.current_health < door_health), "a raider runs to the door and breaks it down")
	cop.take_hit(100000.0)
	door.health_component.heal(100000.0)

	# Guns first: guards and turrets would otherwise hit the test targets too.
	await _check_armory(test, level)
	await _check_front_door(test, level)
	await _check_raid_squads(test, garden)

	# Crew: a hired guard shoots raiders in the yard.
	Profile.operation.add_reputation(100)
	(level.get_front(Office) as Office).buy_upgrade(GameConfig.get_default().find_upgrade(Types.UPGRADE_GUARD))
	await test.frames(3)
	var guard: Worker = garden.get_node("%Guards").get_child(0) as Worker
	var target: Raider = _spawn_at(garden, Vector2(-2.0, -8.0))
	var target_health: float = target.health_component.current_health
	guard.work_now()
	test.check(guard.is_working() and target.health_component.current_health < target_health, "a hired guard shoots raiders in the yard")
	target.take_hit(100000.0)
	await _check_turrets(test, level)


## A raid wave: squads, cover, the rush and the battering ram.
static func _check_raid_squads(test: SmokeTest, garden: FrontGarden) -> void:
	var director: AttackerDirector = garden.director
	director.is_active = true
	director.step(60.0)
	test.check(director.get_pending_spawn_count() == 0 and director.get_raiders_left() == 0, "selling days send no attackers on their own")
	director.queue_wave(RaidWave.new(0, 2, 1, 1.0, 1), null, 0.0)
	test.check(director.get_pending_spawn_count() == 4, "a raid wave queues its cops, SWAT and a battering ram")
	director.step(0.01)
	var raiders: Array[Raider] = garden.yard.get_raiders().duplicate()
	var swat: int = raiders.filter(func(raider: Raider) -> bool: return raider.faction_name == "SWAT").size()
	var rams: int = raiders.filter(func(raider: Raider) -> bool: return raider.is_battering_ram).size()
	test.check(director.get_raiders_left() == 4 and swat == 1 and rams == 1 and director.get_squads().size() == 1, "the wave enters the yard as one squad")
	test.check(await test.wait_until(func() -> bool: return raiders.any(func(raider: Raider) -> bool: return not raider.is_battering_ram and not raider.is_moving())), "raiders take cover in the yard")
	var squad: RaidSquad = director.get_squads()[0]
	squad.start_rush()
	test.check(await test.wait_until(func() -> bool: return raiders.any(func(raider: Raider) -> bool: return raider.is_at_door())), "the squad rushes the door together")
	for raider: Raider in raiders:
		raider.take_hit(100000.0)
	test.check(director.get_raiders_left() == 0, "a wave is beaten when every raider is down")
	garden.door.health_component.heal(100000.0)
	director.is_active = false


## Roof turrets (a house upgrade) and taking one over at the Security PC.
static func _check_turrets(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var office: Office = level.get_front(Office) as Office
	var config: GameConfig = GameConfig.get_default()
	var turret: HouseTurret = garden.get_turrets()[0]
	test.check(not turret.is_mounted() and not garden.security_pc.is_available(), "no turrets or PC before they are bought")
	office.buy_upgrade(config.find_upgrade(Types.UPGRADE_TURRETS))
	await test.frames(3)
	test.check(turret.is_mounted(), "buying Roof Turrets mounts a turret on the house")
	var in_open: Raider = _spawn_at(garden, Vector2(0.0, -10.0))
	var open_health: float = in_open.health_component.current_health
	test.check(await test.wait_until(func() -> bool: return in_open.health_component.current_health < open_health), "the roof turret shoots raiders in the open")
	in_open.take_hit(100000.0)
	var covered: Raider = _spawn_at(garden, BEHIND_CAR)
	var covered_health: float = covered.health_component.current_health
	await test.frames(90)
	test.check(covered.health_component.current_health == covered_health, "cover hides raiders from the turret")
	covered.take_hit(100000.0)

	Profile.operation.add_reputation(50)
	office.buy_upgrade(config.find_upgrade(Types.UPGRADE_SECURITY_PC))
	await test.frames(3)
	var pc: SecurityPc = garden.security_pc
	test.check(pc.is_available() and pc.get_selected_turret() == turret, "the Security PC shows the turret")
	rig.locomotion.teleport_to(Vector3(3.4, 0.0, -0.6), 0.0)
	await test.frames(3)
	var console: TurretConsole = pc.get_console()
	rig.tap_world_point(pc.get_screen().pixel_to_world(console.get_control_button().get_global_rect().get_center()))
	await test.frames(3)
	test.check(turret.is_manual, "pointing at Take control hands the turret over")
	var target: Raider = _spawn_at(garden, Vector2(-1.0, -9.0))
	var target_health: float = target.health_component.current_health
	turret.set_manual_aim(target.get_hit_center())
	await test.frames(60)
	console.fire_pressed.emit()
	test.check(await test.wait_until(func() -> bool: return target.health_component.current_health < target_health), "the PC fires the turret by hand")
	console.fire_released.emit()
	pc.release_control()
	test.check(not turret.is_manual, "released, the turret aims on its own again")
	target.take_hit(100000.0)
	await _check_turret_seat(test, level, turret)
	rig.locomotion.travel_to_spot(1)


## Buying guns and ammo at the armory terminal and firing them.
static func _check_armory(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var armory: Armory = level.get_front(Armory) as Armory
	var operation: Operation = level.operation
	var catalog: WeaponCatalog = armory.weapon_catalog
	var smg: WeaponData = catalog.find_weapon(&"smg")
	var pistol: WeaponData = catalog.find_weapon(&"pistol")
	test.check(garden.get_equipped_weapon() == pistol, "the bought pistol is in hand")
	rig.locomotion.teleport_to(Vector3(-3.0, 0.0, -3.4), PI)
	await test.frames(3)
	var screen: WorldScreen = armory.get_screen()
	var board: ArmoryBoard = armory.get_board()
	# Count what the armory charges (a dealer may sell at the window meanwhile).
	var weapon_spending: Array[int] = [0]
	var on_spent: Callable = func(amount: int, reason: String) -> void:
		if reason == "weapons":
			weapon_spending[0] += amount
	operation.cash_spent.connect(on_spent)
	rig.tap_world_point(screen.pixel_to_world(board.get_row("weapon", &"smg").get_buy_button().get_global_rect().get_center()))
	await test.frames(3)
	operation.cash_spent.disconnect(on_spent)
	test.check(Profile.armory.loadout.owns(smg) and garden.get_equipped_weapon() == smg and weapon_spending[0] == smg.cost, "buying the SMG at the armory pays for it and puts it in hand")
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
	var cop: Raider = _spawn_at(garden, Vector2(1.0, -9.0))
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
	Profile.armory.loadout.equip(pistol)
	await test.frames(20)
	garden.fire_weapon(_aim(rig, cop))
	test.check(cop.health_component.current_health < empty_health, "the pistol never runs dry")
	cop.take_hit(100000.0)
	await _check_weapon_types(test, level)


## Opening, walking through, closing and bolting the front door from both sides.
static func _check_front_door(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var door: FrontDoor = garden.door
	var walkable: WalkableArea = rig.walkable_area
	var threshold: Vector3 = Vector3(0.0, 0.0, -5.0)
	test.check(not door.is_open() and not walkable.contains(threshold), "the front door starts shut and the doorway is blocked")
	_place_player(rig, Vector3(0.0, 0.0, -4.2), 0.0)
	rig.tap_world_point(door.get_inside_handle().get_grab_center())
	test.check(await test.wait_until(func() -> bool: return door.is_passable()), "using the inside handle swings the door open")
	test.check(walkable.contains(threshold), "an open door makes the doorway walkable")
	test.check(rig.get_held_items().is_empty(), "the flat cursor lets go of the handle right away")
	Input.action_press(Types.ACTION_MOVE_FORWARD)
	var walked_out: bool = await test.wait_until(func() -> bool: return rig.get_feet_position().z < -5.4)
	Input.action_release(Types.ACTION_MOVE_FORWARD)
	test.check(walked_out and garden.is_in_defense_zone(), "the player walks through the doorway onto the porch")
	Input.action_press(Types.ACTION_MOVE_FORWARD)
	var reached_garden: bool = await test.wait_until(func() -> bool: return rig.get_feet_position().z < -8.0)
	Input.action_release(Types.ACTION_MOVE_FORWARD)
	test.check(reached_garden and walkable.contains(rig.get_feet_position()) and garden.is_in_defense_zone(), "the player walks on out into the garden and can defend from there")
	var obstacle: Vector3 = garden.yard.get_obstacle_circles()[0]
	test.check(not walkable.contains(Vector3(obstacle.x, 0.0, obstacle.y)), "trees, rocks and the car in the garden can't be walked into")
	var fence_z: float = garden.yard.bounds.position.y
	test.check(not walkable.contains(Vector3(-8.0, 0.0, fence_z)) and walkable.clamp_move(Vector3(-8.0, 0.0, fence_z + 0.5), Vector3(-8.0, 0.0, fence_z + 0.2)).z > fence_z, "the garden's fence can't be walked through")
	test.check(walkable.contains(Vector3(door.global_position.x, 0.0, fence_z)), "the gate in the fence leads out into the street")
	_place_player(rig, Vector3(0.0, 0.0, -5.8), 0.0)
	rig.tap_world_point(door.get_outside_handle().get_grab_center())
	test.check(await test.wait_until(func() -> bool: return not door.is_open()), "the outside handle swings it shut")
	test.check(not walkable.contains(threshold), "a shut door blocks the doorway again")
	rig.tap_world_point(door.get_outside_handle().get_grab_center())
	test.check(await test.wait_until(func() -> bool: return door.is_passable()), "there is no bolt: the shut door just opens again")
	_place_player(rig, Vector3(0.0, 0.0, -4.2), PI)
	door.close_fully()
	await test.wait_until(func() -> bool: return not door.is_open())
	await _check_door_with_tracked_hand(test, rig, door)


## The headset path: a tracked hand grips the handle and swings the door
## around its hinge, lets go, and the door stays where it was pulled to.
static func _check_door_with_tracked_hand(test: SmokeTest, rig: XRPlayerRig, door: FrontDoor) -> void:
	var hand: XRController3D = rig.get_node("LeftHand") as XRController3D
	var hand_transform: Transform3D = hand.global_transform
	hand.global_position = door.get_inside_handle().global_position
	await test.frames(1)
	rig.call("_on_left_hand_button_pressed", String(Types.XR_ACTION_GRIP_CLICK))
	await test.frames(1)
	var hinge: Vector3 = door.global_position + Vector3(-0.55, 1.0, 0.0)
	for step: int in 30:
		var angle: float = deg_to_rad(step * 3.0)
		hand.global_position = hinge + Vector3(cos(angle), 0.0, sin(angle)) * 0.95
		await test.frames(1)
	rig.call("_on_left_hand_button_released", String(Types.XR_ACTION_GRIP_CLICK))
	await test.frames(2)
	test.check(door.get_open_angle() > 60.0 and door.is_passable(), "a tracked hand gripping the handle swings the door open")
	hand.global_transform = hand_transform
	door.close_fully()
	await test.wait_until(func() -> bool: return not door.is_open())


## Points the flat cursor at an attacker and returns the cursor's pointer.
## A new player fights with bare fists: a click on a raider in reach
## punches it, one further off isn't hit. The armory sells the knife first,
## then the axe, then the pistol; a blade hits harder than a fist. A raider
## out in the yard turns on a player who comes close and hits them — and
## goes back to the door once they are inside again. Ends with the pistol in hand.
static func _check_fists_and_blades(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var armory: Armory = level.get_front(Armory) as Armory
	var catalog: WeaponCatalog = armory.weapon_catalog
	var loadout: WeaponLoadout = Profile.armory.loadout
	var knife: WeaponData = catalog.find_weapon(&"knife")
	var axe: WeaponData = catalog.find_weapon(&"axe")
	var pistol: WeaponData = catalog.find_weapon(&"pistol")
	var fists: WeaponData = garden.get_equipped_weapon()
	test.check(fists != null and fists == catalog.get_starter() and fists.is_melee() and garden.get_shown_weapon() == null, "a new player fights with bare fists")
	var near_cop: Raider = _spawn_at(garden, Vector2(0.0, -4.2))
	_place_player(rig, Vector3(0.0, 0.0, -3.2), 0.0)
	await test.frames(3)
	var health_before: float = near_cop.health_component.current_health
	rig.tap_world_point(near_cop.get_hit_center())
	await test.frames(3)
	test.check(is_equal_approx(health_before - near_cop.health_component.current_health, fists.damage - near_cop.armor), "a click on a raider in reach punches it")
	var far_cop: Raider = _spawn_at(garden, Vector2(0.0, -8.5))
	await test.frames(40)
	var far_health: float = far_cop.health_component.current_health
	rig.tap_world_point(far_cop.get_hit_center())
	await test.frames(3)
	test.check(far_cop.health_component.current_health == far_health, "a raider out of reach isn't hit by a fist")
	far_cop.take_hit(100000.0)

	# The armory's order: knife, then axe, then the pistol.
	Profile.wallet.add(Types.CURRENCY_CASH, knife.cost + axe.cost + pistol.cost, false)
	rig.locomotion.teleport_to(Vector3(-3.0, 0.0, -3.4), PI)
	await test.frames(3)
	var board: ArmoryBoard = armory.get_board()
	board.refresh()
	# New rows lay themselves out in the next frames.
	await test.frames(2)
	test.check(board.get_row("weapon", &"fists") == null and board.get_row("weapon", &"knife") != null, "the armory lists the knife first (fists aren't for sale)")
	test.check(board.get_row("weapon", &"axe").get_buy_button().disabled and board.get_row("weapon", &"pistol").get_buy_button().disabled, "the axe and the pistol are locked at first")
	test.check(not armory.buy_weapon(axe) and not armory.buy_weapon(pistol), "nothing is sold before the knife")
	rig.tap_world_point(armory.get_screen().pixel_to_world(board.get_row("weapon", &"knife").get_buy_button().get_global_rect().get_center()))
	await test.frames(3)
	test.check(loadout.owns(knife) and garden.get_equipped_weapon() == knife, "buying the knife puts it in hand")
	await test.frames(2)
	test.check(not board.get_row("weapon", &"axe").get_buy_button().disabled and board.get_row("weapon", &"pistol").get_buy_button().disabled, "the knife unlocks the axe, not yet the guns")
	_place_player(rig, Vector3(0.0, 0.0, -3.2), 0.0)
	await test.frames(30)
	test.check(garden.get_shown_weapon() != null and garden.get_shown_weapon().is_visible_in_tree(), "the knife shows in hand")
	health_before = near_cop.health_component.current_health
	rig.tap_world_point(near_cop.get_hit_center())
	await test.frames(3)
	test.check(health_before - near_cop.health_component.current_health > fists.damage, "the knife cuts harder than a fist")
	near_cop.take_hit(100000.0)
	test.check(armory.buy_weapon(axe) and armory.buy_weapon(pistol), "then the axe, then the pistol")

	# Out in the yard a raider turns on the player, hits them, and goes back to the door once they are inside.
	var vitals: PlayerVitals = level.player_vitals
	var yard_cop: Raider = _spawn_at(garden, Vector2(0.0, -10.0))
	_place_player(rig, Vector3(0.0, 0.0, -8.4), 0.0)
	var player_health: float = vitals.get_health()
	yard_cop.freeze(false)
	test.check(await test.wait_until(func() -> bool: return yard_cop.is_hunting()), "a raider in the yard turns on a player who comes close")
	test.check(await test.wait_until(func() -> bool: return vitals.get_health() < player_health), "and hits them")
	_place_player(rig, Vector3(0.0, 0.0, -3.2), 0.0)
	test.check(await test.wait_until(func() -> bool: return not yard_cop.is_hunting()), "back inside behind the shut door, it goes for the door again")
	yard_cop.take_hit(100000.0)
	loadout.equip(pistol)


static func _aim(rig: XRPlayerRig, enemy: Raider) -> XRPointer:
	rig.aim_at_world_point(enemy.get_hit_center())
	return rig.get_tool_pointer()


static func _place_player(rig: XRPlayerRig, feet: Vector3, yaw: float) -> void:
	rig.move_origin_by(feet - rig.get_feet_position())
	rig.face_yaw(yaw)


## Puts a cop at [param point] in the yard, standing still (frozen) so the
## check decides what happens to it.
static func _spawn_at(garden: FrontGarden, point: Vector2) -> Raider:
	var raider: Raider = garden.director.spawn_raider(load(COP) as PackedScene)
	raider.global_position = Vector3(point.x, 0.0, point.y)
	raider.freeze()
	return raider


## Each gun shoots its own way: shotgun pellets, rifle rounds that go
## through, the SMG firing on while the trigger is held.
static func _check_weapon_types(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var armory: Armory = level.get_front(Armory) as Armory
	var catalog: WeaponCatalog = armory.weapon_catalog
	var shotgun: WeaponData = catalog.find_weapon(&"shotgun")
	var rifle: WeaponData = catalog.find_weapon(&"rifle")
	var smg: WeaponData = catalog.find_weapon(&"smg")
	Profile.wallet.add(Types.CURRENCY_CASH, 5000, false)
	armory.buy_weapon(shotgun)
	armory.buy_weapon(rifle)
	await test.frames(60)
	var target: Raider = _spawn_at(garden, Vector2(0.8, -7.4))
	var health_before: float = target.health_component.current_health
	garden.fire_weapon(_aim(rig, target))
	var one_pellet: float = shotgun.damage - target.armor
	test.check(health_before - target.health_component.current_health > one_pellet * 2.0, "the shotgun's pellets hit together")
	target.take_hit(100000.0)

	Profile.armory.loadout.equip(rifle)
	await test.frames(60)
	var head: Vector3 = rig.get_head_transform().origin
	var first: Raider = _spawn_at(garden, Vector2(0.6, -8.5))
	var direction: Vector3 = (first.get_hit_center() - head).normalized()
	var beyond: Vector3 = head + direction * (head.distance_to(first.get_hit_center()) + 2.5)
	var second: Raider = _spawn_at(garden, Vector2(beyond.x, beyond.z))
	var first_health: float = first.health_component.current_health
	var second_health: float = second.health_component.current_health
	garden.fire_weapon(_aim(rig, first))
	test.check(first.health_component.current_health < first_health and second.health_component.current_health < second_health, "a rifle round goes through one raider into the next")
	first.take_hit(100000.0)
	second.take_hit(100000.0)

	Profile.armory.loadout.equip(smg)
	Profile.armory.loadout.add_ammo(smg, smg.max_ammo)
	await test.frames(30)
	var burst_target: Raider = _spawn_at(garden, Vector2(-0.4, -9.0))
	var rounds_before: int = Profile.armory.loadout.get_ammo(smg)
	rig.secondary_action_pressed.emit(_aim(rig, burst_target))
	await test.frames(40)
	rig.secondary_action_released.emit(rig.get_tool_pointer())
	var fired: int = rounds_before - Profile.armory.loadout.get_ammo(smg)
	await test.frames(10)
	test.check(fired >= 4 and Profile.armory.loadout.get_ammo(smg) == rounds_before - fired, "holding the trigger keeps the SMG firing; letting go stops it")
	burst_target.take_hit(100000.0)
	Profile.armory.loadout.equip(catalog.find_weapon(&"pistol"))


## "VR in VR": the goggles at the Security PC put the player into the turret.
static func _check_turret_seat(test: SmokeTest, level: HouseLevel, turret: HouseTurret) -> void:
	var rig: XRPlayerRig = level.rig
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var seat: TurretSeat = garden.turret_seat
	var desk_feet: Vector3 = rig.get_feet_position()
	rig.tap_world_point(garden.security_pc.get_goggles_button().get_press_center())
	await test.frames(3)
	var head: Vector3 = rig.get_head_transform().origin
	test.check(seat.is_active() and head.distance_to(turret.get_camera_mount().global_position) < 0.35 and rig.locomotion.is_locked, "putting on the goggles puts the player in the turret")
	var target: Raider = _spawn_at(garden, Vector2(0.0, -10.5))
	var target_health: float = target.health_component.current_health
	rig.aim_at_world_point(target.get_hit_center())
	await test.frames(60)
	seat.set_firing(true)
	test.check(await test.wait_until(func() -> bool: return target.health_component.current_health < target_health), "the turret fires where the player aims")
	seat.set_firing(false)
	target.take_hit(100000.0)
	rig.tap_point_in_view(seat.get_exit_point())
	await test.frames(3)
	test.check(not seat.is_active() and rig.get_feet_position().distance_to(desk_feet) < 0.05 and not rig.locomotion.is_locked, "taking the goggles off brings the player back to the desk")
