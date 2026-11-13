## Unit tests for PlayerHealth: hits, going down, and health coming back
## slowly only after a quiet spell.
##
## Dependencies: gdUnit4, PlayerHealth
extends GdUnitTestSuite


func test_hits_take_health_and_the_last_one_puts_the_player_down() -> void:
	var health: PlayerHealth = PlayerHealth.new(100.0, 5.0, 6.0)
	assert_bool(health.take(40.0)).is_false()
	assert_float(health.current).is_equal(60.0)
	assert_bool(health.take(70.0)).is_true()
	assert_bool(health.is_down()).is_true()
	assert_float(health.current).is_equal(0.0)
	# Down stays down: no more hits, no healing.
	assert_bool(health.take(10.0)).is_false()
	health.recover(60.0)
	assert_float(health.current).is_equal(0.0)


func test_health_comes_back_only_after_a_quiet_spell() -> void:
	var health: PlayerHealth = PlayerHealth.new(100.0, 5.0, 6.0)
	health.take(50.0)
	assert_bool(health.recover(4.0)).is_false()
	assert_float(health.current).is_equal(50.0)
	# Past the delay it climbs at regen_per_second.
	health.recover(1.0)
	health.recover(2.0)
	assert_float(health.current).is_equal_approx(50.0 + 6.0 * 3.0, 0.001)
	# A new hit restarts the wait.
	health.take(1.0)
	var before: float = health.current
	health.recover(1.0)
	assert_float(health.current).is_equal(before)


func test_health_never_climbs_past_the_maximum() -> void:
	var health: PlayerHealth = PlayerHealth.new(100.0, 0.0, 50.0)
	health.take(10.0)
	health.recover(5.0)
	assert_float(health.current).is_equal(100.0)
	assert_float(health.get_ratio()).is_equal(1.0)
