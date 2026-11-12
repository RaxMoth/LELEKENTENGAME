## Unit tests for the lab's skill check and quality: TimingGauge and QualityMath.
##
## Dependencies: gdUnit4
extends GdUnitTestSuite


func test_gauge_needle_ping_pongs() -> void:
	var gauge: TimingGauge = TimingGauge.new(1.0, 0.2)
	assert_float(gauge.get_needle()).is_equal_approx(0.0, 0.001)
	gauge.advance(0.25)
	assert_float(gauge.get_needle()).is_equal_approx(0.5, 0.001)
	gauge.advance(0.25)
	assert_float(gauge.get_needle()).is_equal_approx(1.0, 0.001)
	gauge.advance(0.25)
	assert_float(gauge.get_needle()).is_equal_approx(0.5, 0.001)


func test_gauge_accuracy_peaks_in_the_middle_of_the_zone() -> void:
	var gauge: TimingGauge = TimingGauge.new(1.0, 0.2, 0.5)
	assert_float(gauge.get_accuracy_at(0.5)).is_equal_approx(1.0, 0.001)
	assert_float(gauge.get_accuracy_at(0.6)).is_equal_approx(TimingGauge.EDGE_ACCURACY, 0.001)
	assert_float(gauge.get_accuracy_at(0.4)).is_equal_approx(TimingGauge.EDGE_ACCURACY, 0.001)
	assert_float(gauge.get_accuracy_at(0.7)).is_equal_approx(0.0, 0.001)
	assert_float(gauge.get_accuracy_at(0.05)).is_equal(0.0)


func test_gauge_zone_stays_on_the_bar() -> void:
	var gauge: TimingGauge = TimingGauge.new(1.0, 0.3, 0.95)
	assert_float(gauge.get_zone_end()).is_less_equal(1.0)
	assert_float(gauge.get_zone_start()).is_greater_equal(0.0)


func test_quality_combines_steps_and_equipment() -> void:
	var perfect: Array[float] = [1.0, 1.0, 1.0]
	var sloppy: Array[float] = [0.2, 0.0, 0.3]
	assert_float(QualityMath.combine(perfect, 0.0)).is_greater(QualityMath.combine(sloppy, 0.0))
	assert_float(QualityMath.combine(sloppy, 0.1)).is_greater(QualityMath.combine(sloppy, 0.0))
	assert_float(QualityMath.combine(perfect, 0.5)).is_equal(1.0)
	var no_steps: Array[float] = []
	assert_float(QualityMath.combine(no_steps, 0.3)).is_equal(0.0)


func test_quality_tiers_follow_thresholds() -> void:
	assert_int(QualityMath.tier_from_score(0.0)).is_equal(1)
	assert_int(QualityMath.tier_from_score(0.45)).is_equal(2)
	assert_int(QualityMath.tier_from_score(0.7)).is_equal(3)
	assert_int(QualityMath.tier_from_score(0.95)).is_equal(4)
	assert_str(QualityMath.get_tier_name(4)).is_equal("Premium")
	assert_float(QualityMath.get_price_factor(9)).is_equal(QualityMath.get_price_factor(4))
