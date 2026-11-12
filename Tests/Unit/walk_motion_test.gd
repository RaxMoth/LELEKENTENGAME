## Unit tests for walking in VR: WalkMotion (arm swing, easing, sprint, footsteps).
##
## Dependencies: gdUnit4
extends GdUnitTestSuite


func test_hands_at_rest_do_not_walk() -> void:
	assert_float(WalkMotion.get_arm_swing_speed(Vector3.ZERO, Vector3.ZERO)).is_equal(0.0)
	assert_float(WalkMotion.get_arm_swing_speed(Vector3(0.0, 0.2, 0.0), Vector3(0.0, -0.2, 0.0))).is_equal(0.0)


func test_faster_swinging_walks_faster_up_to_a_run() -> void:
	var slow: float = WalkMotion.get_arm_swing_speed(Vector3(0.0, 0.8, 0.3), Vector3(0.0, -0.8, -0.3))
	var fast: float = WalkMotion.get_arm_swing_speed(Vector3(0.0, 1.8, 0.6), Vector3(0.0, -1.8, -0.6))
	assert_float(slow).is_greater(0.0)
	assert_float(fast).is_greater(slow)
	assert_float(WalkMotion.get_arm_swing_speed(Vector3(0.0, 20.0, 0.0), Vector3(0.0, -20.0, 0.0))).is_equal(WalkMotion.MAX_SWING_SPEED)


func test_sideways_sweeps_do_not_count() -> void:
	assert_float(WalkMotion.get_arm_swing_speed(Vector3(3.0, 0.0, 0.0), Vector3(-3.0, 0.0, 0.0))).is_equal(0.0)


func test_walking_eases_in_and_stops_quicker() -> void:
	var started: Vector3 = WalkMotion.ease_velocity(Vector3.ZERO, Vector3(0.0, 0.0, -2.0), 0.1)
	assert_float(started.length()).is_equal_approx(WalkMotion.ACCELERATION * 0.1, 0.0001)
	var stopping: Vector3 = WalkMotion.ease_velocity(Vector3(0.0, 0.0, -2.0), Vector3.ZERO, 0.1)
	assert_float(2.0 - stopping.length()).is_equal_approx(WalkMotion.DECELERATION * 0.1, 0.0001)


func test_full_stick_sprints() -> void:
	assert_float(WalkMotion.get_stick_speed(Vector2(0.0, 0.5), 2.0)).is_equal_approx(1.0, 0.0001)
	assert_float(WalkMotion.get_stick_speed(Vector2(0.0, 1.0), 2.0)).is_equal_approx(2.0 * WalkMotion.SPRINT_MULTIPLIER, 0.0001)


func test_footsteps_fall_every_stride() -> void:
	var first: Array[float] = WalkMotion.count_footsteps(0.0, WalkMotion.STRIDE_METERS * 0.6)
	assert_float(first[0]).is_equal(0.0)
	var second: Array[float] = WalkMotion.count_footsteps(first[1], WalkMotion.STRIDE_METERS * 1.6)
	assert_float(second[0]).is_equal(2.0)
	assert_float(second[1]).is_equal_approx(WalkMotion.STRIDE_METERS * 0.2, 0.0001)
