## Smoke checks of the production front: crates, grinder, cooker, press,
## quality and the crafters. Owned by whoever works on the Lab.
##
## Dependencies: SmokeTest, HouseLevel, Lab, Office, Workstation, IngredientCrate
class_name LabSmokeChecks
extends RefCounted


static func run(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var operation: Operation = level.operation
	var lab: Lab = level.get_front(Lab) as Lab
	var grinder: Workstation = lab.get_station(&"Grinder")
	var cooker: Workstation = lab.get_station(&"Cooker")
	var press: Workstation = lab.get_station(&"Press")
	var glowcap_crate: IngredientCrate = lab.get_crate(&"glowcap")
	var sugarsalt_crate: IngredientCrate = lab.get_crate(&"sugarsalt")
	rig.locomotion.travel_to_spot(0)
	await _check_start_and_gadgets(test, level, lab)

	var cash_before: int = operation.get_cash()
	rig.tap_world_point(glowcap_crate.get_grab_center())
	await test.frames(2)
	test.check(rig.get_held_items().size() == 1 and operation.get_cash() == cash_before - glowcap_crate.ingredient.cost, "clicking a crate takes an ingredient and pays for it")
	rig.tap_world_point(sugarsalt_crate.get_grab_center() + Vector3(0.0, 0.5, 0.0))
	await test.frames(2)
	test.check(rig.get_held_items().is_empty() and operation.get_cash() == cash_before, "an ingredient dropped nowhere goes back and is refunded")

	# Wrong station: the cooker says why instead of silently bouncing it.
	var refusals: Array[String] = []
	for slot: ItemSocket in cooker.get_input_sockets():
		test.check(slot.shows_empty_marker, "empty cooker slots show their ring")
		slot.item_refused.connect(func(_item: Grabbable, reason: String) -> void: refusals.append(reason))
	rig.tap_world_point(glowcap_crate.get_grab_center())
	await test.frames(2)
	rig.tap_world_point(cooker.get_input_sockets()[0].global_position)
	await test.frames(2)
	test.check(cooker.get_input_sockets()[0].is_empty() and refusals.size() == 1 and refusals[0] == TranslationServer.translate("Grind it first"), "a raw ingredient in the cooker is refused with a reason")
	test.check(rig.get_held_items().is_empty() and operation.get_cash() == cash_before, "the refused ingredient goes back to its crate")
	test.check(not grinder.get_stop_button().visible, "an idle station shows no Stop button")

	rig.tap_world_point(glowcap_crate.get_grab_center())
	await test.frames(2)
	rig.tap_world_point(grinder.get_input_sockets()[0].global_position)
	await test.frames(3)
	test.check(grinder.is_running(), "a raw ingredient in the grinder starts its skill check")
	await _stop_in_the_middle(test, rig, grinder)
	var ground: IngredientItem = grinder.get_output_socket().item as IngredientItem
	test.check(ground != null and ground.is_processed, "stopping in the green grinds the ingredient")

	rig.tap_world_point(ground.get_grab_center())
	await test.frames(2)
	rig.tap_world_point(cooker.get_input_sockets()[0].global_position)
	await test.frames(2)
	rig.tap_world_point(sugarsalt_crate.get_grab_center())
	await test.frames(2)
	rig.tap_world_point(cooker.get_input_sockets()[1].global_position)
	await test.frames(3)
	test.check(cooker.is_running(), "a full recipe in the cooker starts cooking")
	await _stop_in_the_middle(test, rig, cooker)
	var batch: BatchItem = cooker.get_output_socket().item as BatchItem
	test.check(batch != null and batch.recipe.id == &"glow", "cooking makes a batch of the matching product")

	var stash_before: int = operation.stash.get_total()
	rig.tap_world_point(batch.get_grab_center())
	await test.frames(2)
	rig.tap_world_point(press.get_input_sockets()[0].global_position)
	await test.frames(3)
	test.check(press.is_running(), "a batch in the press starts packaging")
	await _stop_in_the_middle(test, rig, press)
	var units: int = operation.stash.get_total() - stash_before
	test.check(units == operation.get_batch_size(batch.recipe), "packaging puts a full batch into the stash")
	test.check(operation.stash.count(&"glow", 3) == units, "perfect handwork makes Pure quality or better")

	await _check_vr_hands(test, rig, operation, glowcap_crate, grinder, cooker)

	# Crew: a hired crafter makes product on its own.
	Profile.operation.add_reputation(100)
	(level.get_front(Office) as Office).buy_upgrade(GameConfig.get_default().find_upgrade(Types.UPGRADE_CRAFTER))
	await test.frames(3)
	var crafter: Worker = lab.get_node("%Crafters").get_child(0) as Worker
	var second_crafter: Worker = lab.get_node("%Crafters").get_child(1) as Worker
	test.check(crafter.is_working() and not second_crafter.visible, "a hired crafter shows up, the unhired slot stays empty")
	var stock_before: int = operation.stash.get_total()
	crafter.work_now()
	test.check(operation.stash.get_total() > stock_before, "a crafter makes product")


## The VR hand path (as a headset would drive it): point at a crate and pull
## the trigger to buy into the hand, point at the grinder and pull again to
## put it in; a quick grip click keeps holding until the next click.
static func _check_vr_hands(test: SmokeTest, rig: XRPlayerRig, operation: Operation, crate: IngredientCrate, grinder: Workstation, cooker: Workstation) -> void:
	var hand: Types.Hand = rig.dominant_hand
	var off_hand: Types.Hand = Types.Hand.LEFT if hand == Types.Hand.RIGHT else Types.Hand.RIGHT
	var cash_before: int = operation.get_cash()
	_point_hand(rig, off_hand, crate.get_grab_center())
	_click(rig, off_hand, Types.XR_ACTION_TRIGGER_CLICK)
	await test.frames(2)
	test.check(rig.get_held_items().is_empty() and operation.get_cash() == cash_before, "the off-hand trigger (the gun) never picks anything up")
	_point_hand(rig, hand, crate.get_grab_center())
	_click(rig, hand, Types.XR_ACTION_TRIGGER_CLICK)
	await test.frames(2)
	test.check(rig.get_held_items().size() == 1 and operation.get_cash() == cash_before - crate.ingredient.cost, "a VR trigger at a crate buys an ingredient into the hand")
	_point_hand(rig, hand, grinder.get_input_sockets()[0].global_position)
	_click(rig, hand, Types.XR_ACTION_TRIGGER_CLICK)
	await test.frames(3)
	test.check(grinder.is_running() and rig.get_held_items().is_empty(), "a VR trigger at the grinder puts the ingredient in")
	await _stop_in_the_middle(test, rig, grinder)
	var ground: Grabbable = grinder.get_output_socket().item
	_point_hand(rig, hand, ground.get_grab_center())
	_click(rig, hand, Types.XR_ACTION_GRIP_CLICK)
	await test.frames(2)
	var held_items: Array[Grabbable] = rig.get_held_items()
	test.check(held_items.size() == 1 and held_items[0] == ground, "a quick VR grip click keeps holding the item")
	var cooker_slot: ItemSocket = cooker.get_input_sockets()[0]
	_point_hand(rig, hand, cooker_slot.global_position)
	_click(rig, hand, Types.XR_ACTION_GRIP_CLICK)
	await test.frames(2)
	test.check(cooker_slot.item == ground and rig.get_held_items().is_empty(), "the next grip click puts it where the beam points")


## Puts a VR hand at eye height and points its beam at [param target].
static func _point_hand(rig: XRPlayerRig, hand: Types.Hand, target: Vector3) -> void:
	var pointer: XRPointer = rig.get_hand_pointer(hand)
	var head: Vector3 = rig.get_head_transform().origin
	pointer.get_parent_node_3d().global_position = head
	pointer.set_ray(head, (target - head).normalized())


## Presses and lets go of a controller button in the same frame.
static func _click(rig: XRPlayerRig, hand: Types.Hand, action_name: StringName) -> void:
	rig.handle_controller_button(hand, action_name, true)
	rig.handle_controller_button(hand, action_name, false)


## A new operation: one shroom plant that grows on its own, no gadgets; the
## office sells the grinder, cooker and press in order and each shows up.
static func _check_start_and_gadgets(test: SmokeTest, level: HouseLevel, lab: Lab) -> void:
	var rig: XRPlayerRig = level.rig
	var operation: Operation = level.operation
	var plants: Array[ShroomPlant] = lab.get_plants()
	var grinder: Workstation = lab.get_station(&"Grinder")
	var cooker: Workstation = lab.get_station(&"Cooker")
	var press: Workstation = lab.get_station(&"Press")
	test.check(plants[0].is_active() and not plants[1].is_active() and not grinder.visible and not cooker.visible and not press.visible and not lab.get_crate(&"glowcap").visible, "a new lab has one shroom plant and no gadgets yet")
	var recipe_board: RecipeBoard = lab.get_recipe_board()
	test.check(recipe_board.get_row_count() == lab.recipes.size() and recipe_board.get_unlocked_count() == 1, "the recipe book shows every recipe, open; only shrooms are unlocked")
	test.check(not lab.get_guide_board().is_step_unlocked(&"Grind"), "the poster points to the office for the grinder")
	var plant: ShroomPlant = plants[0]
	test.check(not plant.is_ripe(), "the plant starts growing")
	plant.grow(plant.grow_seconds)
	test.check(plant.is_ripe(), "the plant grows shrooms by itself")
	var shrooms_before: int = operation.stash.count(&"shroom")
	rig.tap_world_point(plant.get_harvest_button().get_press_center())
	await test.frames(3)
	test.check(operation.stash.count(&"shroom") > shrooms_before and not plant.is_ripe(), "harvesting puts shrooms into the stash, then it grows again")
	var config: GameConfig = GameConfig.get_default()
	# Bring the money these purchases cost, so the other areas' checks keep their budget.
	for upgrade_id: StringName in [Types.UPGRADE_GRINDER, Types.UPGRADE_COOKER, Types.UPGRADE_PRESS, Types.UPGRADE_PLANTS]:
		Profile.wallet.add(Types.CURRENCY_CASH, config.find_upgrade(upgrade_id).get_cost(0))
	test.check(not Profile.upgrades.can_purchase(config.find_upgrade(Types.UPGRADE_COOKER)), "the cooker needs the grinder first")
	for gadget_id: StringName in [Types.UPGRADE_GRINDER, Types.UPGRADE_COOKER, Types.UPGRADE_PRESS]:
		test.check(Profile.upgrades.purchase(config.find_upgrade(gadget_id)), "the office sells the %s" % gadget_id)
	level.apply_upgrades()
	await test.frames(2)
	test.check(grinder.visible and cooker.visible and press.visible and lab.get_crate(&"glowcap").visible, "bought gadgets and the ingredient crates show up in the lab")
	test.check(recipe_board.get_unlocked_count() == 2 and lab.get_guide_board().is_step_unlocked(&"Press"), "the press unlocks Glow; the poster shows every step")
	Profile.upgrades.purchase(config.find_upgrade(Types.UPGRADE_PLANTS))
	level.apply_upgrades()
	test.check(plants[1].is_active() and not plants[2].is_active(), "More Plants adds a plant to the shelf")


## Puts the needle in the middle of the sweet zone and presses the station's button.
static func _stop_in_the_middle(test: SmokeTest, rig: XRPlayerRig, station: Workstation) -> void:
	var gauge: TimingGauge = station.get_gauge()
	gauge.elapsed_seconds = gauge.zone_center / (2.0 * gauge.sweeps_per_second)
	rig.tap_world_point(station.get_stop_button().get_press_center())
	await test.frames(3)
