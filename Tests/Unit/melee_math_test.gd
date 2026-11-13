## Unit tests for MeleeMath: swing speed and how close a fist or blade
## comes to a standing body.
##
## Dependencies: gdUnit4, MeleeMath
extends GdUnitTestSuite


func test_speed_is_distance_over_time() -> void:
	assert_float(MeleeMath.get_speed(Vector3.ZERO, Vector3(0.0, 0.0, 0.1), 0.05)).is_equal_approx(2.0, 0.001)
	# No time passed: no division by zero.
	assert_float(MeleeMath.get_speed(Vector3.ZERO, Vector3.ZERO, 0.0)).is_equal(0.0)


func test_a_fist_at_chest_height_is_measured_across() -> void:
	var feet: Vector3 = Vector3(0.0, 0.0, -1.0)
	var fist: Vector3 = Vector3(0.0, 1.2, -0.6)
	assert_float(MeleeMath.get_distance_to_body(fist, fist, feet, 1.6)).is_equal_approx(0.4, 0.001)


func test_above_the_head_counts_the_height_too() -> void:
	var feet: Vector3 = Vector3.ZERO
	var fist: Vector3 = Vector3(0.0, 2.0, 0.3)
	assert_float(MeleeMath.get_distance_to_body(fist, fist, feet, 1.6)).is_equal_approx(0.5, 0.001)


func test_a_blade_reaches_further_than_the_hand() -> void:
	var feet: Vector3 = Vector3(0.0, 0.0, -1.0)
	var hand: Vector3 = Vector3(0.0, 1.0, 0.0)
	var axe_head: Vector3 = Vector3(0.0, 1.0, -0.6)
	assert_float(MeleeMath.get_distance_to_body(hand, hand, feet, 1.6)).is_equal_approx(1.0, 0.001)
	assert_float(MeleeMath.get_distance_to_body(hand, axe_head, feet, 1.6)).is_equal_approx(0.4, 0.001)
