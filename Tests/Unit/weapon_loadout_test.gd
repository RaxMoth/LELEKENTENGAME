## Unit tests for the player's guns: WeaponLoadout (owning, ammo, equipping,
## firing, saving) and WeaponCatalog.
##
## Dependencies: gdUnit4
extends GdUnitTestSuite


func _weapon(weapon_id: StringName, cost: int, unlimited: bool = false) -> WeaponData:
	var weapon: WeaponData = WeaponData.new()
	weapon.id = weapon_id
	weapon.cost = cost
	weapon.has_unlimited_ammo = unlimited
	weapon.starting_ammo = 10
	weapon.ammo_pack_size = 10
	weapon.max_ammo = 25
	return weapon


func _catalog() -> WeaponCatalog:
	var catalog: WeaponCatalog = WeaponCatalog.new()
	catalog.weapons = [_weapon(&"pistol", 0, true), _weapon(&"smg", 300)]
	return catalog


func test_the_starter_is_always_owned_and_never_runs_dry() -> void:
	var loadout: WeaponLoadout = WeaponLoadout.new()
	var pistol: WeaponData = _catalog().find_weapon(&"pistol")
	assert_bool(loadout.owns(pistol)).is_true()
	for shot: int in 100:
		assert_bool(loadout.try_fire(pistol)).is_true()
	assert_bool(loadout.can_add_ammo(pistol)).is_false()


func test_buying_a_gun_gives_its_starting_ammo() -> void:
	var loadout: WeaponLoadout = WeaponLoadout.new()
	var smg: WeaponData = _catalog().find_weapon(&"smg")
	assert_bool(loadout.owns(smg)).is_false()
	assert_bool(loadout.try_fire(smg)).is_false()
	assert_bool(loadout.buy_weapon(smg)).is_true()
	assert_bool(loadout.buy_weapon(smg)).is_false()
	assert_int(loadout.get_ammo(smg)).is_equal(10)


func test_shots_use_ammo_until_empty() -> void:
	var loadout: WeaponLoadout = WeaponLoadout.new()
	var smg: WeaponData = _catalog().find_weapon(&"smg")
	loadout.buy_weapon(smg)
	for shot: int in 10:
		assert_bool(loadout.try_fire(smg)).is_true()
	assert_bool(loadout.has_ammo(smg)).is_false()
	assert_bool(loadout.try_fire(smg)).is_false()


func test_ammo_is_capped() -> void:
	var loadout: WeaponLoadout = WeaponLoadout.new()
	var smg: WeaponData = _catalog().find_weapon(&"smg")
	assert_int(loadout.add_ammo(smg, 10)).is_equal(0)
	loadout.buy_weapon(smg)
	assert_int(loadout.add_ammo(smg, 10)).is_equal(10)
	assert_int(loadout.add_ammo(smg, 10)).is_equal(5)
	assert_bool(loadout.can_add_ammo(smg)).is_false()
	assert_int(loadout.get_ammo(smg)).is_equal(25)


func test_equipped_falls_back_to_the_starter() -> void:
	var catalog: WeaponCatalog = _catalog()
	var loadout: WeaponLoadout = WeaponLoadout.new()
	var smg: WeaponData = catalog.find_weapon(&"smg")
	assert_str(String(loadout.get_equipped(catalog).id)).is_equal("pistol")
	assert_bool(loadout.equip(smg)).is_false()
	loadout.buy_weapon(smg)
	assert_bool(loadout.equip(smg)).is_true()
	assert_str(String(loadout.get_equipped(catalog).id)).is_equal("smg")
	loadout.equipped_id = &"unknown"
	assert_str(String(loadout.get_equipped(catalog).id)).is_equal("pistol")


func test_loadout_survives_a_save_round_trip() -> void:
	var catalog: WeaponCatalog = _catalog()
	var smg: WeaponData = catalog.find_weapon(&"smg")
	var loadout: WeaponLoadout = WeaponLoadout.new()
	loadout.buy_weapon(smg)
	loadout.equip(smg)
	loadout.try_fire(smg)
	var restored: WeaponLoadout = WeaponLoadout.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(loadout.to_dict())) as Dictionary)
	assert_bool(restored.owns(smg)).is_true()
	assert_int(restored.get_ammo(smg)).is_equal(9)
	assert_str(String(restored.get_equipped(catalog).id)).is_equal("smg")


func test_changes_are_signalled() -> void:
	var loadout: WeaponLoadout = WeaponLoadout.new()
	var smg: WeaponData = _catalog().find_weapon(&"smg")
	var change_count: Array[int] = [0]
	loadout.changed.connect(func() -> void: change_count[0] += 1)
	loadout.buy_weapon(smg)
	loadout.try_fire(smg)
	loadout.equip(smg)
	loadout.equip(smg)
	assert_int(change_count[0]).is_equal(3)


func test_catalog_finds_weapons_and_the_starter() -> void:
	var catalog: WeaponCatalog = _catalog()
	assert_object(catalog.find_weapon(&"missing")).is_null()
	assert_str(String(catalog.get_starter().id)).is_equal("pistol")


## Fists → knife → axe → pistol: each is for sale only once the one before is owned.
func _ladder() -> WeaponCatalog:
	var fists: WeaponData = _weapon(&"fists", 0, true)
	fists.kind = WeaponData.Kind.MELEE
	var knife: WeaponData = _weapon(&"knife", 60, true)
	knife.kind = WeaponData.Kind.MELEE
	var axe: WeaponData = _weapon(&"axe", 160, true)
	axe.kind = WeaponData.Kind.MELEE
	axe.required_weapon_id = &"knife"
	var pistol: WeaponData = _weapon(&"pistol", 200, true)
	pistol.required_weapon_id = &"axe"
	var catalog: WeaponCatalog = WeaponCatalog.new()
	catalog.weapons = [fists, knife, axe, pistol]
	return catalog


func test_a_new_player_has_only_fists() -> void:
	var catalog: WeaponCatalog = _ladder()
	var loadout: WeaponLoadout = WeaponLoadout.new()
	var in_hand: WeaponData = loadout.get_equipped(catalog)
	assert_str(String(in_hand.id)).is_equal("fists")
	assert_bool(in_hand.is_melee()).is_true()
	assert_bool(loadout.owns(catalog.find_weapon(&"knife"))).is_false()


func test_weapons_unlock_one_after_the_other() -> void:
	var catalog: WeaponCatalog = _ladder()
	var loadout: WeaponLoadout = WeaponLoadout.new()
	var knife: WeaponData = catalog.find_weapon(&"knife")
	var axe: WeaponData = catalog.find_weapon(&"axe")
	var pistol: WeaponData = catalog.find_weapon(&"pistol")
	assert_bool(loadout.can_buy(knife, catalog)).is_true()
	assert_bool(loadout.can_buy(axe, catalog)).is_false()
	assert_bool(loadout.can_buy(pistol, catalog)).is_false()
	loadout.buy_weapon(knife)
	assert_bool(loadout.can_buy(knife, catalog)).is_false()
	assert_bool(loadout.can_buy(axe, catalog)).is_true()
	assert_bool(loadout.can_buy(pistol, catalog)).is_false()
	loadout.buy_weapon(axe)
	assert_bool(loadout.can_buy(pistol, catalog)).is_true()


func test_a_missing_requirement_keeps_it_locked() -> void:
	var catalog: WeaponCatalog = _ladder()
	catalog.find_weapon(&"axe").required_weapon_id = &"unknown"
	assert_bool(WeaponLoadout.new().is_unlocked(catalog.find_weapon(&"axe"), catalog)).is_false()


func test_owned_weapons_can_be_upgraded_to_their_last_level() -> void:
	var loadout: WeaponLoadout = WeaponLoadout.new()
	var smg: WeaponData = _catalog().find_weapon(&"smg")
	smg.upgrade_costs = PackedInt32Array([200, 450])
	assert_bool(loadout.can_upgrade(smg)).is_false()
	loadout.buy_weapon(smg)
	assert_int(loadout.get_upgrade_cost(smg)).is_equal(200)
	assert_bool(loadout.upgrade(smg)).is_true()
	assert_int(loadout.get_upgrade_cost(smg)).is_equal(450)
	assert_bool(loadout.upgrade(smg)).is_true()
	assert_bool(loadout.upgrade(smg)).is_false()
	assert_int(loadout.get_upgrade_level(smg)).is_equal(2)
	assert_int(loadout.get_upgrade_cost(smg)).is_equal(0)


func test_upgrades_raise_damage_fire_rate_and_ammo() -> void:
	var smg: WeaponData = _catalog().find_weapon(&"smg")
	smg.damage = 20.0
	smg.fire_interval_seconds = 0.2
	smg.damage_per_level = 0.25
	smg.fire_rate_per_level = 0.25
	smg.ammo_per_level = 10
	assert_float(smg.get_damage(2)).is_equal_approx(30.0, 0.001)
	assert_float(smg.get_fire_interval(2)).is_less(0.2)
	assert_int(smg.get_max_ammo(2)).is_equal(45)
	var loadout: WeaponLoadout = WeaponLoadout.new()
	smg.upgrade_costs = PackedInt32Array([1, 1])
	loadout.buy_weapon(smg)
	loadout.upgrade(smg)
	assert_int(loadout.get_ammo_space(smg)).is_equal(35 - loadout.get_ammo(smg))


func test_upgrades_survive_saving() -> void:
	var loadout: WeaponLoadout = WeaponLoadout.new()
	var smg: WeaponData = _catalog().find_weapon(&"smg")
	smg.upgrade_costs = PackedInt32Array([1, 1])
	loadout.buy_weapon(smg)
	loadout.upgrade(smg)
	var copy: WeaponLoadout = WeaponLoadout.new()
	copy.from_dict(loadout.to_dict())
	assert_int(copy.get_upgrade_level(smg)).is_equal(1)


func test_switching_cycles_through_the_owned_weapons() -> void:
	var catalog: WeaponCatalog = _catalog()
	catalog.weapons.append(_weapon(&"shotgun", 500))
	var loadout: WeaponLoadout = WeaponLoadout.new()
	assert_str(String(loadout.equip_next(catalog).id)).is_equal("pistol")
	loadout.buy_weapon(catalog.find_weapon(&"smg"))
	loadout.buy_weapon(catalog.find_weapon(&"shotgun"))
	loadout.equip(catalog.find_weapon(&"pistol"))
	assert_str(String(loadout.equip_next(catalog).id)).is_equal("smg")
	assert_str(String(loadout.equip_next(catalog).id)).is_equal("shotgun")
	assert_str(String(loadout.equip_next(catalog).id)).is_equal("pistol")
	assert_str(String(loadout.equip_next(catalog, -1).id)).is_equal("shotgun")
