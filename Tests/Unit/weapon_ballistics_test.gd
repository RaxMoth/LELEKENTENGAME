## Unit tests for how guns shoot: WeaponBallistics (pellets, spread cone,
## bloom, damage falloff).
##
## Dependencies: gdUnit4
extends GdUnitTestSuite


func _weapon(pellets: int, spread: float) -> WeaponData:
	var weapon: WeaponData = WeaponData.new()
	weapon.damage = 20.0
	weapon.pellets = pellets
	weapon.spread_degrees = spread
	return weapon


func _seeded() -> RandomNumberGenerator:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 7
	return random


func test_an_accurate_gun_fires_straight() -> void:
	var directions: Array[Vector3] = WeaponBallistics.get_shot_directions(Vector3.FORWARD, _weapon(1, 0.0))
	assert_int(directions.size()).is_equal(1)
	assert_vector(directions[0]).is_equal_approx(Vector3.FORWARD, Vector3(0.0001, 0.0001, 0.0001))


func test_a_shotgun_fires_every_pellet_inside_its_cone() -> void:
	var weapon: WeaponData = _weapon(9, 6.0)
	var directions: Array[Vector3] = WeaponBallistics.get_shot_directions(Vector3(0.3, -0.1, -1.0), weapon, 0.0, _seeded())
	assert_int(directions.size()).is_equal(9)
	var aim: Vector3 = Vector3(0.3, -0.1, -1.0).normalized()
	var spread_out: int = 0
	for direction: Vector3 in directions:
		assert_float(direction.length()).is_equal_approx(1.0, 0.0001)
		assert_float(rad_to_deg(direction.angle_to(aim))).is_less_equal(6.0001)
		if rad_to_deg(direction.angle_to(aim)) > 0.5:
			spread_out += 1
	assert_int(spread_out).is_greater(4)


func test_bloom_widens_the_cone_up_to_its_cap() -> void:
	var weapon: WeaponData = _weapon(1, 1.0)
	weapon.bloom_per_shot_degrees = 0.5
	weapon.max_bloom_degrees = 3.0
	assert_float(WeaponBallistics.get_bloom(weapon, 0)).is_equal(0.0)
	assert_float(WeaponBallistics.get_bloom(weapon, 4)).is_equal_approx(2.0, 0.0001)
	assert_float(WeaponBallistics.get_bloom(weapon, 40)).is_equal_approx(3.0, 0.0001)
	for direction: Vector3 in WeaponBallistics.get_shot_directions(Vector3.FORWARD, weapon, 3.0, _seeded()):
		assert_float(rad_to_deg(direction.angle_to(Vector3.FORWARD))).is_less_equal(4.0001)


func test_damage_falls_off_with_distance() -> void:
	var weapon: WeaponData = _weapon(1, 0.0)
	weapon.falloff_start_meters = 5.0
	weapon.falloff_end_meters = 15.0
	weapon.falloff_min_multiplier = 0.2
	assert_float(WeaponBallistics.get_damage_at(weapon, 2.0)).is_equal_approx(20.0, 0.0001)
	assert_float(WeaponBallistics.get_damage_at(weapon, 10.0)).is_equal_approx(12.0, 0.0001)
	assert_float(WeaponBallistics.get_damage_at(weapon, 40.0)).is_equal_approx(4.0, 0.0001)


func test_no_falloff_when_the_range_is_unset() -> void:
	var weapon: WeaponData = _weapon(1, 0.0)
	assert_float(WeaponBallistics.get_damage_at(weapon, 500.0)).is_equal(20.0)
