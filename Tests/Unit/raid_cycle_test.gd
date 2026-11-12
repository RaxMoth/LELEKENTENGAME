## Unit tests for the house's 3-day cycle and its police raids: RaidPlanner
## (day in cycle, raid days, waves per raid, escalation, heat) and RaidWave.
##
## Dependencies: gdUnit4
extends GdUnitTestSuite


func _data() -> RaidData:
	var data: RaidData = RaidData.new()
	data.days_per_cycle = 3
	data.first_raid_waves = 2
	data.extra_waves_per_raid = 1
	data.max_waves = 4
	data.first_wave_cops = 3
	data.cops_per_later_wave = 1
	data.cops_per_later_raid = 1
	data.max_heat_extra_cops = 4
	data.swat_from_raid = 2
	data.swat_per_wave = 1
	data.swat_per_later_raid = 1
	data.health_growth_per_raid = 0.2
	data.last_wave_health_multiplier = 1.0
	return data


func test_days_run_in_cycles_of_three() -> void:
	var data: RaidData = _data()
	var days_in_cycle: Array[int] = []
	for day_number: int in range(1, 8):
		days_in_cycle.append(RaidPlanner.get_day_in_cycle(day_number, data))
	assert_array(days_in_cycle).contains_exactly([1, 2, 3, 1, 2, 3, 1])


func test_the_raid_comes_on_the_last_day_of_each_cycle() -> void:
	var data: RaidData = _data()
	assert_bool(RaidPlanner.is_raid_day(1, data)).is_false()
	assert_bool(RaidPlanner.is_raid_day(2, data)).is_false()
	assert_bool(RaidPlanner.is_raid_day(3, data)).is_true()
	assert_bool(RaidPlanner.is_raid_day(6, data)).is_true()
	assert_int(RaidPlanner.get_days_until_raid(1, data)).is_equal(2)
	assert_int(RaidPlanner.get_days_until_raid(3, data)).is_equal(0)


func test_raid_number_counts_cycles() -> void:
	var data: RaidData = _data()
	assert_int(RaidPlanner.get_raid_number(1, data)).is_equal(1)
	assert_int(RaidPlanner.get_raid_number(3, data)).is_equal(1)
	assert_int(RaidPlanner.get_raid_number(4, data)).is_equal(2)
	assert_int(RaidPlanner.get_raid_number(9, data)).is_equal(3)


func test_bad_input_is_clamped() -> void:
	var data: RaidData = _data()
	data.days_per_cycle = 0
	assert_int(RaidPlanner.get_day_in_cycle(5, data)).is_equal(1)
	assert_bool(RaidPlanner.is_raid_day(5, data)).is_true()
	assert_int(RaidPlanner.get_raid_number(0, _data())).is_equal(1)


func test_first_raid_is_two_waves_of_cops() -> void:
	var waves: Array[RaidWave] = RaidPlanner.build_raid(_data(), 1)
	assert_int(waves.size()).is_equal(2)
	assert_int(waves[0].cop_count).is_equal(3)
	assert_int(waves[1].cop_count).is_equal(4)
	assert_int(waves[0].swat_count + waves[1].swat_count).is_equal(0)
	assert_float(waves[0].health_multiplier).is_equal_approx(1.0, 0.001)


func test_every_raid_gets_harder() -> void:
	var data: RaidData = _data()
	var previous_total: int = 0
	for raid_number: int in range(1, 6):
		var total: int = 0
		for wave: RaidWave in RaidPlanner.build_raid(data, raid_number):
			total += wave.get_total()
		assert_int(total).is_greater(previous_total)
		previous_total = total
	assert_int(RaidPlanner.get_wave_count(10, data)).is_equal(data.max_waves)


func test_swat_join_from_their_raid_on() -> void:
	var data: RaidData = _data()
	var second_raid: Array[RaidWave] = RaidPlanner.build_raid(data, 2)
	assert_int(second_raid[0].swat_count).is_equal(0)
	assert_int(second_raid[1].swat_count).is_equal(1)
	var third_raid: Array[RaidWave] = RaidPlanner.build_raid(data, 3)
	assert_int(third_raid[0].swat_count).is_equal(2)
	assert_float(third_raid[0].health_multiplier).is_equal_approx(1.4, 0.001)


func test_heat_adds_cops_to_the_last_wave() -> void:
	var data: RaidData = _data()
	var cold: Array[RaidWave] = RaidPlanner.build_raid(data, 1, 0.0)
	var hot: Array[RaidWave] = RaidPlanner.build_raid(data, 1, 1.0)
	assert_int(hot[0].cop_count).is_equal(cold[0].cop_count)
	assert_int(hot[1].cop_count - cold[1].cop_count).is_equal(data.max_heat_extra_cops)
	assert_int(RaidPlanner.build_raid(data, 1, 5.0)[1].cop_count).is_equal(hot[1].cop_count)


func test_raid_wave_never_goes_negative() -> void:
	var wave: RaidWave = RaidWave.new(0, -2, -1, 0.0)
	assert_int(wave.get_total()).is_equal(0)
	assert_float(wave.health_multiplier).is_greater(0.0)
