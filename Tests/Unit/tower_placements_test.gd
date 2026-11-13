## Unit tests for the player's towers: TowerPlacements (spacing, upgrades,
## saving) and TowerData (levels).
##
## Dependencies: gdUnit4
extends GdUnitTestSuite


func test_towers_keep_their_distance() -> void:
	var placements: TowerPlacements = TowerPlacements.new()
	assert_int(placements.add(&"sentry", Vector2(0.0, -12.0))).is_equal(0)
	assert_bool(placements.can_place(Vector2(1.0, -12.0))).is_false()
	assert_int(placements.add(&"mortar", Vector2(1.0, -12.0))).is_equal(-1)
	assert_int(placements.add(&"mortar", Vector2(4.0, -12.0), 1.5)).is_equal(1)
	assert_int(placements.get_count()).is_equal(2)
	assert_str(String(placements.get_id(1))).is_equal("mortar")
	assert_float(placements.get_yaw(1)).is_equal_approx(1.5, 0.001)


func test_upgrades_stop_at_the_last_level() -> void:
	var placements: TowerPlacements = TowerPlacements.new()
	placements.add(&"sentry", Vector2.ZERO)
	assert_bool(placements.upgrade(0, 2)).is_true()
	assert_bool(placements.upgrade(0, 2)).is_true()
	assert_bool(placements.upgrade(0, 2)).is_false()
	assert_int(placements.get_level(0)).is_equal(2)
	assert_bool(placements.upgrade(5, 2)).is_false()


func test_towers_survive_saving() -> void:
	var placements: TowerPlacements = TowerPlacements.new()
	placements.add(&"beam", Vector2(30.0, -40.0), 0.5)
	placements.upgrade(0, 3)
	var copy: TowerPlacements = TowerPlacements.new()
	copy.from_dict(placements.to_dict())
	assert_int(copy.get_count()).is_equal(1)
	assert_str(String(copy.get_id(0))).is_equal("beam")
	assert_vector(copy.get_spot(0)).is_equal(Vector2(30.0, -40.0))
	assert_int(copy.get_level(0)).is_equal(1)
	copy.remove(0)
	assert_int(copy.get_count()).is_equal(0)


func test_levels_add_damage_and_range() -> void:
	var tower: TowerData = TowerData.new()
	tower.damage = 20.0
	tower.damage_per_level = 0.5
	tower.range_meters = 20.0
	tower.range_per_level = 4.0
	tower.upgrade_costs = PackedInt32Array([300, 700])
	assert_float(tower.get_damage(2)).is_equal_approx(40.0, 0.001)
	assert_float(tower.get_range(1)).is_equal_approx(24.0, 0.001)
	assert_int(tower.get_max_level()).is_equal(2)
	assert_int(tower.get_upgrade_cost(1)).is_equal(700)
	assert_int(tower.get_upgrade_cost(2)).is_equal(0)
