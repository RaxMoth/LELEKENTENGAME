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

	var cash_before: int = operation.get_cash()
	rig.tap_world_point(glowcap_crate.get_grab_center())
	await test.frames(2)
	test.check(rig.get_held_items().size() == 1 and operation.get_cash() == cash_before - glowcap_crate.ingredient.cost, "clicking a crate takes an ingredient and pays for it")
	rig.tap_world_point(sugarsalt_crate.get_grab_center() + Vector3(0.0, 0.5, 0.0))
	await test.frames(2)
	test.check(rig.get_held_items().is_empty() and operation.get_cash() == cash_before, "an ingredient dropped nowhere goes back and is refunded")

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


## Puts the needle in the middle of the sweet zone and presses the station's button.
static func _stop_in_the_middle(test: SmokeTest, rig: XRPlayerRig, station: Workstation) -> void:
	var gauge: TimingGauge = station.get_gauge()
	gauge.elapsed_seconds = gauge.zone_center / (2.0 * gauge.sweeps_per_second)
	rig.tap_world_point(station.get_stop_button().get_press_center())
	await test.frames(3)
