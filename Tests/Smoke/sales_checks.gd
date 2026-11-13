## Smoke checks of the customer front: the queue, selling on the window
## board, haggling, impatience and dealers. Owned by whoever works on Sales.
##
## Dependencies: SmokeTest, HouseLevel, SalesWindow, Office, CustomerOrder
class_name SalesSmokeChecks
extends RefCounted


static func run(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var operation: Operation = level.operation
	var window: SalesWindow = level.get_front(SalesWindow) as SalesWindow
	var recipe: RecipeData = operation.recipes[0]
	rig.locomotion.travel_to_spot(2)
	operation.set_price(recipe, recipe.base_price)

	window.spawn_customer(_order(&"regular", recipe, 2, 1))
	test.check(await test.wait_until(func() -> bool: return window.get_front_customer() != null), "a customer walks up to the window")
	var screen: WorldScreen = window.get_node("%SalesScreen") as WorldScreen
	var sell_button: Button = screen.content.find_child("SellButton", true, false) as Button
	var cash_before: int = operation.get_cash()
	# Units sold, not the stash total: the lab's automation may add product meanwhile.
	var sold_before: int = operation.shift_units_sold
	var reputation_before: int = Profile.operation.reputation
	rig.tap_world_point(screen.pixel_to_world(sell_button.get_global_rect().get_center()))
	await test.frames(3)
	test.check(operation.shift_units_sold == sold_before + 2 and operation.get_cash() > cash_before, "pressing Sell on the window board sells from the stash")
	test.check(Profile.operation.reputation > reputation_before and operation.heat.value > 0.0, "a sale earns reputation and draws heat")

	var haggle_order: CustomerOrder = _order(&"haggler", recipe, 1, 1)
	window.spawn_customer(haggle_order)
	test.check(await test.wait_until(func() -> bool: return window.get_front_customer() != null), "a haggler walks up")
	var tier: int = operation.get_deliverable_tier(haggle_order)
	operation.set_price(recipe, roundi(haggle_order.get_max_unit_price(tier) * 1.1))
	test.check(window.sell_to_front() == SalesMath.Verdict.COUNTER, "a haggler counters a price slightly too high")
	var counter_cash: int = operation.get_cash()
	window.accept_counter()
	test.check(operation.get_cash() == counter_cash + haggle_order.get_max_unit_price(tier), "accepting the counteroffer sells at their price")
	operation.set_price(recipe, recipe.base_price)

	var impatient: Customer = window.spawn_customer(_order(&"regular", recipe, 2, 1))
	impatient.max_patience = 0.2
	impatient.patience_left = 0.2
	var reputation_before_wait: int = Profile.operation.reputation
	test.check(await test.wait_until(func() -> bool: return impatient.is_leaving), "a customer left waiting too long walks off")
	test.check(Profile.operation.reputation < reputation_before_wait, "losing a customer costs reputation")

	# Crew: a hired dealer serves a regular on its own.
	Profile.operation.add_reputation(100)
	operation.add_product(recipe, 2, 2)
	(level.get_front(Office) as Office).buy_upgrade(GameConfig.get_default().find_upgrade(Types.UPGRADE_DEALER))
	await test.frames(3)
	var dealer: Worker = window.get_node("%Dealers").get_child(0) as Worker
	window.spawn_customer(_order(&"regular", recipe, 1, 1))
	await test.wait_until(func() -> bool: return window.get_front_customer() != null)
	var cash_before_dealer: int = operation.get_cash()
	dealer.work_now()
	test.check(dealer.is_working() and operation.get_cash() > cash_before_dealer, "a hired dealer serves a regular customer")


static func _order(type_name: StringName, recipe: RecipeData, quantity: int, min_tier: int) -> CustomerOrder:
	var order: CustomerOrder = CustomerOrder.new()
	order.customer_type = load("res://Ressources/Customers/%s.tres" % type_name) as CustomerTypeData
	order.recipe = recipe
	order.quantity = quantity
	order.min_tier = min_tier
	return order
