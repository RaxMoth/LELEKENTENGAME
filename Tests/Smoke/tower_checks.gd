## Smoke checks of the field towers, the monitor wall, weapon upgrades and
## switching, and fighting in the street: buying a kit at the depot and
## building a tower with it in the street, every tower kind taking officers
## down, upgrading a tower, the towers standing again after a reload of
## their data; the monitor wall showing and steering a tower; a weapon
## upgrade at the armory; switching between owned weapons; shooting an
## officer out in the street and being attacked there.
##
## Dependencies: SmokeTest, HouseLevel, FrontGarden, TowerField, FieldTower,
##               TowerKit, MonitorWall, Armory, Raider, Office
class_name TowerSmokeChecks
extends RefCounted

const COP: String = "res://Scenes/Levels/House/Garden/Cop.tscn"
## A spot in the street in front of the house (outside the garden).
const STREET_SPOT: Vector3 = Vector3(10.0, 0.0, -35.0)


static func run(test: SmokeTest, level: HouseLevel) -> void:
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	Profile.wallet.add(Types.CURRENCY_CASH, 30000)
	await _check_towers(test, level, garden)
	await _check_goggles(test, level, garden)
	await _check_monitor_wall(test, level, garden)
	# Out of the way of the checks that follow (and the raid).
	garden.tower_field.remove_all_towers()
	test.check(garden.tower_field.get_towers().is_empty() and Profile.towers.placements.get_count() == 0, "towers can be taken down again")
	await _check_weapons(test, level, garden)
	await _check_street_fight(test, level, garden)


static func _check_towers(test: SmokeTest, level: HouseLevel, garden: FrontGarden) -> void:
	var field: TowerField = garden.tower_field
	var rig: XRPlayerRig = level.rig
	var board: TowerBoard = field.get_board()
	_place_player(rig, Vector3(3.4, 0.0, -6.4), 0.0)
	await test.frames(3)
	var sentry_row: ShopItemRow = board.get_row(&"sentry")
	var cash_before: int = level.operation.get_cash()
	rig.tap_world_point(field.get_screen().pixel_to_world(sentry_row.get_buy_button().get_global_rect().get_center()))
	await test.frames(3)
	test.check(field.get_kits().size() == 1 and level.operation.get_cash() < cash_before, "buying at the tower depot puts a kit on its table")
	var kit: TowerKit = field.get_kits()[0]
	rig.tap_world_point(kit.get_grab_center())
	await test.frames(2)
	test.check(rig.get_held_items().has(kit), "the kit can be picked up")
	# Out through the gate into the street, then click the ground: the tower goes up there.
	_place_player(rig, STREET_SPOT + Vector3(0.0, 0.0, 3.0), PI)
	await test.frames(2)
	var towers_before: int = field.get_towers().size()
	rig.tap_world_point(STREET_SPOT)
	await test.frames(3)
	test.check(field.get_towers().size() == towers_before + 1 and not rig.get_held_items().has(kit), "pointing at the street with the kit builds the tower there")
	var sentry: FieldTower = field.get_towers()[field.get_towers().size() - 1]
	test.check(sentry.global_position.distance_to(STREET_SPOT) < 0.5 and not level.rig.walkable_area.contains(sentry.global_position), "the tower stands where it was put and can't be walked through")
	test.check(not field.is_valid_spot(Vector3(0.0, 0.0, 0.0)) and not field.is_valid_spot(STREET_SPOT + Vector3(1.0, 0.0, 0.0)), "towers can't go in the house or right next to another")
	# Every kind takes officers down.
	# Far apart down the street in front of the house, so each tower fights alone.
	var spots: Array[Vector3] = [Vector3(-45.0, 0.0, -35.0), Vector3(60.0, 0.0, -35.0), Vector3(-95.0, 0.0, -35.0)]
	var kinds: Array[StringName] = [&"shock", &"mortar", &"heat_lance"]
	var built: Array[FieldTower] = [sentry]
	for kind_index: int in kinds.size():
		var tower: FieldTower = field.build(field.catalog.find_tower(kinds[kind_index]), Vector2(spots[kind_index].x, spots[kind_index].z))
		test.check(tower != null, "a %s can be built" % kinds[kind_index])
		built.append(tower)
	for tower: FieldTower in built:
		var reach: float = 12.0 if tower.data.kind == TowerData.Kind.MORTAR else 8.0
		var target_spot: Vector3 = tower.global_position + Vector3(reach, 0.0, 0.0)
		var cop: Raider = _spawn_cop(garden, target_spot)
		test.check(await test.wait_until(func() -> bool: return not cop.is_alive()), "the %s takes an officer down" % tower.data.id)
	# Upgrading: the button on the post pays and makes it stronger.
	var damage_before: float = sentry.damage
	cash_before = level.operation.get_cash()
	sentry.upgrade_requested.emit(sentry)
	await test.frames(2)
	test.check(sentry.level == 1 and sentry.damage > damage_before and level.operation.get_cash() < cash_before, "the button on a tower's post upgrades it")
	test.check(Profile.towers.placements.get_level(sentry.placement_index) == 1, "the upgrade is remembered")
	var saved: TowerPlacements = TowerPlacements.new()
	saved.from_dict(Profile.towers.placements.to_dict())
	test.check(saved.get_count() == built.size(), "the towers are still there the next day (saved)")


## The turret goggles on a field tower: the overlay says which tower, the
## goggles switch tower to tower, and a mortar steered from them lobs its
## shell where the hand points.
static func _check_goggles(test: SmokeTest, level: HouseLevel, garden: FrontGarden) -> void:
	var seat: TurretSeat = garden.turret_seat
	var field: TowerField = garden.tower_field
	var mortar: FieldTower = null
	for tower: FieldTower in field.get_towers():
		if tower.data.kind == TowerData.Kind.MORTAR:
			mortar = tower
	test.check(seat.enter(mortar) and seat.get_turret() == mortar, "the goggles put the player into a field tower")
	await test.frames(8)
	var status: TurretHud = seat.get_hud_status()
	test.check(status.find_child("TitleLabel", true, false).text.contains(TranslationServer.translate(mortar.data.display_name)), "the goggles' overlay names the tower")
	var cop: Raider = _spawn_cop(garden, mortar.global_position + Vector3(14.0, 0.0, 0.0))
	level.rig.aim_at_world_point(cop.global_position)
	seat.set_firing(true)
	test.check(await test.wait_until(func() -> bool: return not cop.is_alive()), "a mortar steered from the goggles lobs its shell where the hand points")
	seat.set_firing(false)
	test.check(seat.switch_turret(1) and seat.get_turret() != mortar and seat.is_active(), "the goggles switch from tower to tower")
	level.rig.next_weapon_pressed.emit()
	await test.frames(2)
	test.check(seat.is_active(), "A / X in the goggles switches turrets, not weapons")
	seat.leave()
	test.check(not seat.is_active() and not mortar.is_manual, "taking the goggles off hands every tower back")


static func _check_monitor_wall(test: SmokeTest, level: HouseLevel, garden: FrontGarden) -> void:
	var wall: MonitorWall = garden.monitor_wall
	test.check(not wall.is_available() and not wall.visible, "no monitor wall before it is bought")
	var office: Office = level.get_front(Office) as Office
	var config: GameConfig = GameConfig.get_default()
	Profile.operation.add_reputation(100)
	for upgrade_id: StringName in [&"house_extension", Types.UPGRADE_SECURITY_PC, Types.UPGRADE_MONITOR_WALL]:
		if not Profile.upgrades.is_owned(upgrade_id):
			office.buy_upgrade(config.find_upgrade(upgrade_id))
	await test.frames(3)
	test.check(wall.is_available() and wall.visible and wall.get_monitors().size() == 4, "the Monitor Wall puts four big screens in the office")
	var monitor: TurretMonitor = wall.get_monitors()[0]
	test.check(monitor.get_selected_turret() != null, "each screen shows a turret or tower")
	monitor.toggle_control()
	var turret: HouseTurret = monitor.get_selected_turret()
	test.check(turret.is_manual, "a screen takes its turret over")
	monitor.aim_at_view(Vector2(0.5, 0.6))
	monitor.release_control()
	test.check(not turret.is_manual, "and hands it back")


static func _check_weapons(test: SmokeTest, level: HouseLevel, garden: FrontGarden) -> void:
	var armory: Armory = level.get_front(Armory) as Armory
	var catalog: WeaponCatalog = armory.weapon_catalog
	var loadout: WeaponLoadout = Profile.armory.loadout
	var pistol: WeaponData = catalog.find_weapon(&"pistol")
	var smg: WeaponData = catalog.find_weapon(&"smg")
	for weapon: WeaponData in [catalog.find_weapon(&"knife"), catalog.find_weapon(&"axe"), pistol, smg]:
		if not loadout.owns(weapon):
			loadout.buy_weapon(weapon)
	loadout.equip(smg)
	armory.get_board().refresh()
	var level_before: int = loadout.get_upgrade_level(smg)
	var upgrade_row: ShopItemRow = armory.get_board().get_row("upgrade", &"smg")
	test.check(upgrade_row != null, "the armory offers an upgrade for the weapon in hand")
	test.check(armory.upgrade_weapon(smg) and loadout.get_upgrade_level(smg) == level_before + 1, "buying it raises the weapon's level")
	test.check(smg.get_damage(loadout.get_upgrade_level(smg)) > smg.damage, "an upgraded weapon hits harder")
	var before: WeaponData = garden.get_equipped_weapon()
	var switched: WeaponData = garden.switch_weapon()
	test.check(switched != null and switched != before and garden.get_equipped_weapon() == switched, "A / X (Q) switches to the next owned weapon")
	level.rig.next_weapon_pressed.emit()
	await test.frames(1)
	test.check(garden.get_equipped_weapon() != switched, "the button keeps switching through the weapons")
	loadout.equip(pistol)


static func _check_street_fight(test: SmokeTest, level: HouseLevel, garden: FrontGarden) -> void:
	var rig: XRPlayerRig = level.rig
	var player: PlayerVitals = level.player_vitals
	_place_player(rig, Vector3(-40.0, 0.0, -35.0), 0.0)
	await test.frames(2)
	test.check(garden.can_defend(), "out in the street the gun works")
	# An officer jogging down the street toward the player.
	var route: PackedVector2Array = PackedVector2Array([Vector2(-71.0, -35.0), Vector2(-24.0, -35.0), garden.yard.get_spawn_point()])
	var cop: Raider = garden.director.spawn_raider(load(COP) as PackedScene, 1.0, null, 0, route)
	var health_before: float = player.get_health()
	test.check(await test.wait_until(func() -> bool: return cop.is_hunting()), "an officer passing in the street goes after the player")
	test.check(await test.wait_until(func() -> bool: return player.get_health() < health_before), "and hits them right there")
	var shot: Raider = garden.fire_weapon(_aim(rig, cop))
	test.check(shot == cop, "the player's shots hit officers in the street")
	cop.take_hit(1000000.0)
	await test.frames(2)
	# Back to full health for the checks that follow.
	player.apply_net_health(player.get_max_health(), player.get_max_health())
	_place_player(rig, Vector3(2.2, 0.0, -3.6), 0.0)
	await test.frames(2)


static func _spawn_cop(garden: FrontGarden, point: Vector3) -> Raider:
	var cop: Raider = garden.director.spawn_raider(load(COP) as PackedScene)
	cop.global_position = Vector3(point.x, 0.0, point.z)
	cop.freeze()
	return cop


static func _aim(rig: XRPlayerRig, enemy: Raider) -> XRPointer:
	rig.aim_at_world_point(enemy.get_hit_center())
	return rig.get_tool_pointer()


static func _place_player(rig: XRPlayerRig, feet: Vector3, yaw: float) -> void:
	rig.move_origin_by(feet - rig.get_feet_position())
	rig.face_yaw(yaw)
