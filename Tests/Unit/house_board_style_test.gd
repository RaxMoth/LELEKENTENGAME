## Unit tests for HouseBoardStyle: the app's colors become the house
## boards' worn wood, cream ink and brass; other colors stay.
##
## Dependencies: gdUnit4, HouseBoardStyle, Palette
extends GdUnitTestSuite


func test_app_colors_become_house_colors() -> void:
	assert_bool(HouseBoardStyle.to_house_color(Palette.PRIMARY).is_equal_approx(Palette.BRASS)).is_true()
	assert_bool(HouseBoardStyle.to_house_color(Palette.TEXT).is_equal_approx(Palette.BOARD_INK)).is_true()
	assert_bool(HouseBoardStyle.to_house_color(Palette.SURFACE).is_equal_approx(Palette.BOARD_SURFACE)).is_true()


func test_a_lighter_shade_stays_a_lighter_shade() -> void:
	var hovered: Color = Palette.PRIMARY.lightened(0.08)
	var house_hovered: Color = HouseBoardStyle.to_house_color(hovered)
	assert_float(house_hovered.get_luminance()).is_greater(Palette.BRASS.get_luminance())
	assert_float(house_hovered.a).is_equal(hovered.a)


func test_any_other_blue_turns_warm() -> void:
	var light_blue: Color = Color(0.518, 0.615, 0.985)
	var warm: Color = HouseBoardStyle.to_house_color(light_blue)
	assert_float(warm.h).is_equal_approx(Palette.BRASS.h, 0.01)
	assert_float(warm.v).is_equal_approx(light_blue.v, 0.01)


func test_other_colors_and_alpha_are_kept() -> void:
	assert_bool(HouseBoardStyle.to_house_color(Palette.GEM).is_equal_approx(Palette.GEM)).is_true()
	var see_through: Color = Color(Palette.BACKGROUND, 0.5)
	assert_float(HouseBoardStyle.to_house_color(see_through).a).is_equal_approx(0.5, 0.001)


func test_the_theme_is_rebuilt_in_house_colors() -> void:
	var source: Theme = Theme.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Palette.PRIMARY
	source.set_stylebox(&"normal", &"Button", box)
	source.set_color(&"font_color", &"Label", Palette.TEXT)
	var house: Theme = HouseBoardStyle.build_theme(source)
	assert_bool((house.get_stylebox(&"normal", &"Button") as StyleBoxFlat).bg_color.is_equal_approx(Palette.BRASS)).is_true()
	assert_bool(house.get_color(&"font_color", &"Label").is_equal_approx(Palette.BOARD_INK)).is_true()
	# The source theme is untouched.
	assert_bool(box.bg_color.is_equal_approx(Palette.PRIMARY)).is_true()
