## Unit tests for StandingView: lifting a seated player to standing height.
##
## Dependencies: gdUnit4
extends GdUnitTestSuite


func test_a_seated_player_is_lifted_to_standing_height() -> void:
	assert_float(StandingView.get_lift(1.15, 1.65)).is_equal_approx(0.5, 0.001)


func test_a_standing_player_is_left_alone() -> void:
	assert_float(StandingView.get_lift(1.65, 1.65)).is_equal(0.0)
	assert_float(StandingView.get_lift(1.82, 1.65)).is_equal(0.0)


func test_a_head_without_floor_reference_is_not_trusted() -> void:
	assert_float(StandingView.get_lift(0.0, 1.65)).is_equal(0.0)
	assert_float(StandingView.get_lift(0.1, 1.65)).is_equal(0.0)
