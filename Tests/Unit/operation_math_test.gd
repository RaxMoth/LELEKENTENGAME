## Unit tests for the operation's rules: Stash, SalesMath, CustomerOrder,
## HeatMeter and DayClock.
##
## Dependencies: gdUnit4
extends GdUnitTestSuite


func test_stash_respects_capacity() -> void:
	var stash: Stash = Stash.new(5)
	assert_int(stash.add(&"glow", 2, 4)).is_equal(4)
	assert_int(stash.add(&"glow", 3, 4)).is_equal(1)
	assert_int(stash.get_total()).is_equal(5)
	assert_int(stash.get_free_space()).is_equal(0)


func test_stash_takes_lowest_qualifying_tier_first() -> void:
	var stash: Stash = Stash.new(0)
	stash.add(&"glow", 1, 3)
	stash.add(&"glow", 2, 2)
	stash.add(&"glow", 4, 1)
	assert_int(stash.count(&"glow", 2)).is_equal(3)
	var taken: Array[int] = stash.take(&"glow", 2, 3)
	assert_array(taken).contains_exactly([2, 2, 4])
	assert_int(stash.count(&"glow")).is_equal(3)
	assert_int(stash.count_tier(&"glow", 4)).is_equal(0)


func test_stash_prefers_one_tier_that_fills_the_order() -> void:
	var stash: Stash = Stash.new(0)
	stash.add(&"glow", 1, 1)
	stash.add(&"glow", 3, 2)
	stash.add(&"glow", 4, 3)
	assert_array(stash.peek(&"glow", 1, 2)).contains_exactly([3, 3])
	assert_array(stash.take(&"glow", 1, 3)).contains_exactly([4, 4, 4])
	assert_int(stash.count(&"glow")).is_equal(3)


func test_stash_take_is_all_or_nothing() -> void:
	var stash: Stash = Stash.new(0)
	stash.add(&"fizz", 3, 2)
	assert_array(stash.take(&"fizz", 3, 5)).is_empty()
	assert_int(stash.count(&"fizz")).is_equal(2)


func test_stash_steal_and_round_trip() -> void:
	var stash: Stash = Stash.new(0)
	stash.add(&"glow", 2, 3)
	stash.add(&"fizz", 3, 1)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 7
	assert_int(stash.steal(2, random)).is_equal(2)
	assert_int(stash.get_total()).is_equal(2)
	var restored: Stash = Stash.new(0)
	restored.from_dict(stash.to_dict())
	assert_int(restored.get_total()).is_equal(2)
	assert_int(stash.steal(10, random)).is_equal(2)
	assert_int(stash.get_total()).is_equal(0)


func test_sales_price_rises_with_delivered_quality() -> void:
	var asked_for_street: int = SalesMath.get_max_unit_price(40, 1.0, 2, 2)
	assert_int(asked_for_street).is_equal(40)
	assert_int(SalesMath.get_max_unit_price(40, 1.0, 2, 4)).is_greater(asked_for_street)
	assert_int(SalesMath.get_max_unit_price(40, 1.5, 2, 2)).is_equal(60)


func test_sales_verdicts() -> void:
	assert_int(SalesMath.evaluate(40, 40, false)).is_equal(SalesMath.Verdict.ACCEPT)
	assert_int(SalesMath.evaluate(45, 40, false)).is_equal(SalesMath.Verdict.REFUSE)
	assert_int(SalesMath.evaluate(45, 40, true)).is_equal(SalesMath.Verdict.COUNTER)
	assert_int(SalesMath.evaluate(80, 40, true)).is_equal(SalesMath.Verdict.REFUSE)


func test_sales_demand_reacts_to_price() -> void:
	assert_float(SalesMath.get_demand_multiplier(40, 40)).is_equal_approx(1.0, 0.001)
	assert_float(SalesMath.get_demand_multiplier(20, 40)).is_greater(1.0)
	assert_float(SalesMath.get_demand_multiplier(200, 40)).is_equal(SalesMath.MIN_DEMAND)


func test_customer_order_rolls_within_type_ranges() -> void:
	var customer_type: CustomerTypeData = CustomerTypeData.new()
	customer_type.quantity_range = Vector2i(2, 4)
	customer_type.min_tier_range = Vector2i(3, 3)
	customer_type.price_tolerance = 1.0
	var recipe: RecipeData = RecipeData.new()
	recipe.base_price = 50
	var recipes: Array[RecipeData] = [recipe]
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 3
	for roll: int in 20:
		var order: CustomerOrder = customer_type.create_order(recipes, random)
		assert_int(order.quantity).is_between(2, 4)
		assert_int(order.min_tier).is_equal(3)
	var sample: CustomerOrder = customer_type.create_order(recipes, random)
	assert_int(sample.evaluate(sample.get_max_unit_price(3), 3)).is_equal(SalesMath.Verdict.ACCEPT)


func test_recipe_matches_ingredient_sets() -> void:
	var leaf: IngredientData = IngredientData.new()
	leaf.id = &"leaf"
	var salt: IngredientData = IngredientData.new()
	salt.id = &"salt"
	var recipe: RecipeData = RecipeData.new()
	recipe.ingredients = [leaf, salt]
	assert_bool(recipe.matches([&"salt", &"leaf"])).is_true()
	assert_bool(recipe.matches([&"leaf"])).is_false()
	assert_bool(recipe.accepts_partial([&"leaf"])).is_true()
	assert_bool(recipe.accepts_partial([&"leaf", &"leaf"])).is_false()


func test_heat_triggers_each_raid_once() -> void:
	var heat: HeatMeter = HeatMeter.new(1.0, [50.0, 80.0])
	heat.add(55.0)
	assert_int(heat.take_pending_raid()).is_equal(1)
	assert_int(heat.take_pending_raid()).is_equal(0)
	heat.add(30.0)
	assert_int(heat.take_pending_raid()).is_equal(2)
	heat.cool(10.0)
	heat.add(10.0)
	assert_int(heat.take_pending_raid()).is_equal(0)
	heat.set_value(10.0)
	heat.add(45.0)
	assert_int(heat.take_pending_raid()).is_equal(1)
	heat.add(1000.0)
	assert_float(heat.value).is_equal(HeatMeter.MAX_HEAT)


func test_day_clock_runs_day_then_night() -> void:
	var clock: DayClock = DayClock.new(140.0, 100.0, 6.0)
	assert_float(clock.get_hour()).is_equal_approx(6.0, 0.001)
	assert_int(clock.get_phase()).is_equal(DayClock.Phase.DAY)
	clock.advance(70.0)
	assert_float(clock.get_hour()).is_equal_approx(13.0, 0.001)
	clock.advance(70.0)
	assert_int(clock.get_phase()).is_equal(DayClock.Phase.NIGHT)
	clock.advance(50.0)
	assert_float(clock.get_clock_hour()).is_equal_approx(1.0, 0.001)
	assert_str(clock.format_time()).is_equal("01:00")
	assert_bool(clock.is_shift_over()).is_false()
	clock.advance(1000.0)
	assert_bool(clock.is_shift_over()).is_true()


func test_day_clock_reports_scheduled_hours_once() -> void:
	var clock: DayClock = DayClock.new(140.0, 100.0, 6.0)
	clock.advance(185.0)
	assert_bool(clock.just_passed_hour(25.0, 0.5)).is_false()
	clock.advance(10.0)
	assert_bool(clock.just_passed_hour(25.0, 10.0)).is_true()
	clock.advance(1.0)
	assert_bool(clock.just_passed_hour(25.0, 1.0)).is_false()
	var late_start: DayClock = DayClock.new(140.0, 100.0, 8.0)
	assert_float(late_start.get_hour()).is_equal_approx(8.0, 0.001)
