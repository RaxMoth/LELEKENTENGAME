## Unit tests for AutomationMath (what the hopper still feeds, which ripe
## plant the picker takes next, motor jams, the crafter's next job) and SightMath (the ghost's view cone).
##
## Dependencies: gdUnit4, AutomationMath, SightMath
extends GdUnitTestSuite


func test_missing_ingredients_skip_what_is_already_there() -> void:
	var recipe: Array[StringName] = [&"duskleaf", &"glowcap", &"fizzroot"]
	assert_array(AutomationMath.get_missing_ingredients(recipe, [])).is_equal(recipe)
	assert_array(AutomationMath.get_missing_ingredients(recipe, [&"glowcap"])).is_equal([&"duskleaf", &"fizzroot"])
	assert_array(AutomationMath.get_missing_ingredients(recipe, [&"fizzroot", &"duskleaf", &"glowcap"])).is_empty()


func test_each_present_ingredient_covers_one_entry() -> void:
	var recipe: Array[StringName] = [&"glowcap", &"glowcap", &"sugarsalt"]
	assert_array(AutomationMath.get_missing_ingredients(recipe, [&"glowcap"])).is_equal([&"glowcap", &"sugarsalt"])
	# Something the recipe doesn't use covers nothing.
	assert_array(AutomationMath.get_missing_ingredients(recipe, [&"duskleaf"])).is_equal(recipe)


func test_nearest_ready_candidate_wins() -> void:
	var positions: PackedVector3Array = PackedVector3Array([Vector3(1.0, 0.0, 0.0), Vector3(5.0, 0.0, 0.0), Vector3(3.0, 0.0, 0.0)])
	assert_int(AutomationMath.find_nearest(Vector3.ZERO, positions, [true, true, true])).is_equal(0)
	assert_int(AutomationMath.find_nearest(Vector3.ZERO, positions, [false, true, true])).is_equal(2)
	assert_int(AutomationMath.find_nearest(Vector3.ZERO, positions, [false, false, false])).is_equal(-1)


func test_a_point_straight_ahead_is_in_view() -> void:
	var eye: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.7, 0.0))
	assert_float(SightMath.get_view_angle(eye, Vector3(0.0, 1.7, -5.0))).is_equal_approx(0.0, 0.01)
	assert_bool(SightMath.is_in_view(eye, Vector3(0.5, 1.7, -5.0), 20.0, 10.0)).is_true()


func test_points_aside_behind_or_too_far_are_not() -> void:
	var eye: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.7, 0.0))
	assert_bool(SightMath.is_in_view(eye, Vector3(5.0, 1.7, -1.0), 20.0, 10.0)).is_false()
	assert_bool(SightMath.is_in_view(eye, Vector3(0.0, 1.7, 5.0), 20.0, 10.0)).is_false()
	assert_bool(SightMath.is_in_view(eye, Vector3(0.0, 1.7, -15.0), 20.0, 10.0)).is_false()
	# Turned around, the point behind is straight ahead.
	var turned: Transform3D = eye.rotated_local(Vector3.UP, PI)
	assert_bool(SightMath.is_in_view(turned, Vector3(0.0, 1.7, 5.0), 20.0, 10.0)).is_true()


func test_a_motor_jams_only_now_and_then() -> void:
	assert_bool(AutomationMath.rolls_jam(0.05, 0.15, 3, 2)).is_true()
	assert_bool(AutomationMath.rolls_jam(0.5, 0.15, 3, 2)).is_false()
	# Never right after the last jam.
	assert_bool(AutomationMath.rolls_jam(0.0, 1.0, 1, 2)).is_false()
	assert_bool(AutomationMath.rolls_jam(0.0, 0.0, 9, 2)).is_false()


func test_a_crafter_frees_jams_first_then_runs_gauges_then_carries() -> void:
	assert_int(AutomationMath.pick_crew_task(true, true, true, true)).is_equal(AutomationMath.CrewTask.UNJAM)
	assert_int(AutomationMath.pick_crew_task(false, true, true, true)).is_equal(AutomationMath.CrewTask.STOP_GAUGE)
	assert_int(AutomationMath.pick_crew_task(false, false, true, true)).is_equal(AutomationMath.CrewTask.CARRY_BAG)
	# A full stash: the bag waits on the press.
	assert_int(AutomationMath.pick_crew_task(false, false, true, false)).is_equal(AutomationMath.CrewTask.NONE)
	assert_int(AutomationMath.pick_crew_task(false, false, false, true)).is_equal(AutomationMath.CrewTask.NONE)
