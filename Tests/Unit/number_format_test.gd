## Unit tests for NumberFormat (compact numbers, separators, durations).
## Run with Tools/unit_tests.sh or the gdUnit4 panel in the editor.
##
## Dependencies: gdUnit4
extends GdUnitTestSuite


func test_compact_keeps_small_whole_numbers() -> void:
	assert_str(NumberFormat.compact(0)).is_equal("0")
	assert_str(NumberFormat.compact(999)).is_equal("999")


func test_compact_shortens_large_numbers_with_stable_width() -> void:
	assert_str(NumberFormat.compact(1234)).is_equal("1.23K")
	assert_str(NumberFormat.compact(12345)).is_equal("12.3K")
	assert_str(NumberFormat.compact(123456)).is_equal("123K")
	assert_str(NumberFormat.compact(1500000)).is_equal("1.5M")


func test_with_separators_groups_thousands() -> void:
	assert_str(NumberFormat.with_separators(999)).is_equal("999")
	assert_str(NumberFormat.with_separators(1234567)).is_equal("1,234,567")
	assert_str(NumberFormat.with_separators(-1000)).is_equal("-1,000")


func test_duration_formats_minutes_and_hours() -> void:
	assert_str(NumberFormat.duration(125)).is_equal("2:05")
	assert_str(NumberFormat.duration(3725)).is_equal("1:02:05")
	assert_str(NumberFormat.duration(-5)).is_equal("0:00")


func test_duration_short_uses_the_largest_unit() -> void:
	assert_str(NumberFormat.duration_short(45)).is_equal("45s")
	assert_str(NumberFormat.duration_short(125)).is_equal("2m 5s")
	assert_str(NumberFormat.duration_short(7500)).is_equal("2h 5m")
