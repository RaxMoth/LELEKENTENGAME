## Unit tests for progression data: upgrade cost curves and level stars.
##
## Dependencies: gdUnit4
extends GdUnitTestSuite


func test_upgrade_cost_grows_exponentially() -> void:
	var upgrade: UpgradeData = UpgradeData.new()
	upgrade.base_cost = 10
	upgrade.cost_growth = 1.15
	assert_int(upgrade.get_cost(0)).is_equal(10)
	assert_int(upgrade.get_cost(1)).is_equal(12)
	assert_int(upgrade.get_cost(5)).is_equal(20)


func test_upgrade_value_is_linear() -> void:
	var upgrade: UpgradeData = UpgradeData.new()
	upgrade.base_value = 1.0
	upgrade.value_per_level = 0.5
	assert_float(upgrade.get_value(0)).is_equal(1.0)
	assert_float(upgrade.get_value(4)).is_equal(3.0)


func test_upgrade_max_level_zero_means_unlimited() -> void:
	var upgrade: UpgradeData = UpgradeData.new()
	upgrade.max_level = 0
	assert_bool(upgrade.is_maxed(1000)).is_false()
	upgrade.max_level = 3
	assert_bool(upgrade.is_maxed(2)).is_false()
	assert_bool(upgrade.is_maxed(3)).is_true()


func test_level_stars_follow_thresholds() -> void:
	var level: LevelData = LevelData.new()
	level.star_score_thresholds = [100, 200, 300]
	assert_int(level.get_stars_for_score(99)).is_equal(0)
	assert_int(level.get_stars_for_score(100)).is_equal(1)
	assert_int(level.get_stars_for_score(250)).is_equal(2)
	assert_int(level.get_stars_for_score(5000)).is_equal(3)


func test_level_parameter_falls_back_to_default() -> void:
	var level: LevelData = LevelData.new()
	level.custom_parameters = {&"moves": 20}
	assert_int(level.get_parameter(&"moves", 0)).is_equal(20)
	assert_int(level.get_parameter(&"missing", 7)).is_equal(7)
