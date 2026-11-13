## GhostOdds: the ghost comes rarely, never early, never twice in a row.
extends GdUnitTestSuite


func test_never_before_the_first_night() -> void:
	assert_bool(GhostOdds.haunts_tonight(1, 0, 0.0, 0.15, 2, 4)).is_false()
	assert_bool(GhostOdds.haunts_tonight(2, 0, 0.0, 0.15, 2, 4)).is_true()


func test_only_when_the_roll_is_under_the_chance() -> void:
	assert_bool(GhostOdds.haunts_tonight(5, 0, 0.14, 0.15, 2, 4)).is_true()
	assert_bool(GhostOdds.haunts_tonight(5, 0, 0.15, 0.15, 2, 4)).is_false()
	assert_bool(GhostOdds.haunts_tonight(5, 0, 0.9, 0.15, 2, 4)).is_false()


func test_waits_some_nights_after_the_last_one() -> void:
	assert_bool(GhostOdds.haunts_tonight(6, 3, 0.0, 0.15, 2, 4)).is_false()
	assert_bool(GhostOdds.haunts_tonight(7, 3, 0.0, 0.15, 2, 4)).is_true()


func test_rare_over_many_nights() -> void:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 7
	var last_night: int = 0
	var hauntings: int = 0
	for day_number: int in range(1, 101):
		if GhostOdds.haunts_tonight(day_number, last_night, random.randf(), 0.15, 2, 4):
			hauntings += 1
			last_night = day_number
	assert_int(hauntings).is_between(3, 20)
