## Smoke checks of the production front: crates, grinder, cooker, press,
## quality and the crafters. Owned by whoever works on the Lab.
##
## Dependencies: SmokeTest, HouseLevel, Lab, Office, Workstation, IngredientCrate
class_name LabSmokeChecks
extends RefCounted


const BATCH_SCENE: PackedScene = preload("res://Scenes/Levels/House/Lab/BatchItem.tscn")
const BAG_SCENE: PackedScene = preload("res://Scenes/Levels/House/Lab/ProductBag.tscn")


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
	var glow_recipe: RecipeData = batch.recipe
	await _stop_in_the_middle(test, rig, press)
	var bag: ProductBag = press.get_output_socket().item as ProductBag
	test.check(bag != null and bag.units == operation.get_batch_size(glow_recipe) and operation.stash.get_total() == stash_before, "the press packs a bag on its tray; nothing is in the stash yet")
	await _check_carry_bag_to_stash(test, level, bag, stash_before)
	test.check(operation.stash.count(&"glow", 3) == operation.get_batch_size(glow_recipe), "perfect handwork makes Pure quality or better")
	rig.locomotion.travel_to_spot(0)
	await test.frames(2)

	await _check_vr_hands(test, rig, operation, glowcap_crate, grinder, cooker)

	# Crew: a hired crafter makes product on its own.
	Profile.operation.add_reputation(100)
	(level.get_front(Office) as Office).buy_upgrade(GameConfig.get_default().find_upgrade(Types.UPGRADE_CRAFTER))
	await test.frames(3)
	var crafter: Worker = lab.get_node("%Crafters").get_child(0) as Worker
	var second_crafter: Worker = lab.get_node("%Crafters").get_child(1) as Worker
	test.check(crafter.is_working() and not second_crafter.visible, "a hired crafter shows up, the unhired slot stays empty")
	await _check_crafter_tends_lab(test, level, lab, crafter)
	test.check(Profile.skills.book.get_xp(SkillBook.Skill.CRAFTING) > 0.0 and Profile.skills.book.get_xp(SkillBook.Skill.HARVESTING) > 0.0, "skill checks stopped by hand and hand harvests train crafting and harvesting")
	await _check_cooker_fire(test, level, lab)


## Carried by hand: click the bag on the press, then the drop crate at the
## stash shelf; its units go into the stash.
static func _check_carry_bag_to_stash(test: SmokeTest, level: HouseLevel, bag: ProductBag, stash_before: int) -> void:
	var rig: XRPlayerRig = level.rig
	rig.tap_world_point(bag.get_grab_center())
	await test.frames(2)
	test.check(rig.get_held_items().has(bag), "the packed bag comes off the press into the hand")
	await _put_held_bag_in_stash(test, level, bag, stash_before)


## The bag in hand into the stash shelf's drop crate: its units are stored.
static func _put_held_bag_in_stash(test: SmokeTest, level: HouseLevel, bag: ProductBag, stash_before: int) -> void:
	var rig: XRPlayerRig = level.rig
	var shelf: StashShelf = level.get_tree().get_first_node_in_group(Types.GROUP_STASH_SHELF) as StashShelf
	var units: int = bag.units
	var product_name: String = bag.recipe.display_name if bag.recipe != null else ""
	var drop: ItemSocket = shelf.get_drop_socket()
	var in_front: Vector3 = drop.global_position + shelf.global_basis.z * 1.1
	rig.locomotion.teleport_to(Vector3(in_front.x, 0.0, in_front.z))
	await test.frames(2)
	rig.tap_world_point(drop.global_position)
	await test.frames(4)
	test.check(units > 0 and rig.get_held_items().is_empty() and level.operation.stash.get_total() == stash_before + units, "put in the stash shelf's drop crate, the %s bag's units are stored" % product_name)


## Automation still needs hands: a hired crafter frees a jammed motor, stops
## a needle nobody stops (no motor), and carries packed bags to the stash.
static func _check_crafter_tends_lab(test: SmokeTest, level: HouseLevel, lab: Lab, crafter: Worker) -> void:
	var operation: Operation = level.operation
	var grinder: Workstation = lab.get_station(&"Grinder")
	var press: Workstation = lab.get_station(&"Press")
	# A needle nobody stops (no motor): the crafter steps in.
	crafter.hand_wait_seconds = 0.0
	grinder.get_input_sockets()[0].insert(lab.get_crate(&"glowcap").take_item())
	await test.frames(3)
	test.check(grinder.is_running() and crafter.tend_lab() == AutomationMath.CrewTask.STOP_GAUGE and not grinder.get_output_socket().is_empty(), "a crafter stops a skill check nobody runs")
	_clear(grinder)
	# A jammed motor: the crafter frees it, the step finishes.
	grinder.set_motorized(true)
	grinder.motor_seconds = 0.1
	grinder.jam_chance = 1.0
	grinder.min_runs_between_jams = 0
	grinder.get_input_sockets()[0].insert(lab.get_crate(&"glowcap").take_item())
	test.check(await test.wait_until(func() -> bool: return grinder.is_jammed()), "now and then a motor jams and the needle sticks")
	test.check(crafter.tend_lab() == AutomationMath.CrewTask.UNJAM and not grinder.is_jammed() and not grinder.get_output_socket().is_empty(), "a crafter frees the jammed motor")
	grinder.jam_chance = 0.0
	grinder.set_motorized(Profile.upgrades.is_owned(Types.UPGRADE_GRINDER_MOTOR))
	_clear(grinder)
	# A packed bag on the press: the crafter takes it to the stash.
	var bag: ProductBag = Pools.spawn(BAG_SCENE, Global.get_world_root(), press.get_output_socket().global_position) as ProductBag
	bag.setup(operation.find_recipe(&"glow"), 2, 3)
	bag.home_socket = press.get_output_socket()
	press.get_output_socket().insert(bag)
	var stock_before: int = operation.stash.get_total()
	test.check(crafter.tend_lab() == AutomationMath.CrewTask.CARRY_BAG and operation.stash.get_total() == stock_before + 3 and press.get_output_socket().is_empty(), "a crafter carries the packed bag to the stash")
	crafter.hand_wait_seconds = 3.0


## Empties a station's slots and tray (items back into their pools).
static func _clear(station: Workstation) -> void:
	var sockets: Array[ItemSocket] = station.get_input_sockets()
	sockets.append(station.get_output_socket())
	for socket: ItemSocket in sockets:
		var item: Grabbable = socket.remove_item()
		if item != null:
			Pools.despawn(item)


## A batch left on the cooker smokes, then catches fire and burns; the
## extinguisher from the wall (click it, click the fire) puts it out, and a
## click on its hook hangs it back.
static func _check_cooker_fire(test: SmokeTest, level: HouseLevel, lab: Lab) -> void:
	var rig: XRPlayerRig = level.rig
	var cooker: Workstation = lab.get_station(&"Cooker")
	var fire: StationFire = lab.get_fire()
	var tray: ItemSocket = cooker.get_output_socket()
	var batch: BatchItem = Pools.spawn(BATCH_SCENE, Global.get_world_root(), tray.global_position) as BatchItem
	var accuracies: Array[float] = [0.9]
	batch.setup(level.operation.find_recipe(&"glow"), accuracies)
	batch.home_socket = tray
	tray.insert(batch)
	fire.step(fire.warn_seconds + 0.1)
	await test.frames(2)
	test.check(fire.is_overheating() and not fire.is_burning(), "a batch left on the cooker starts to smoke")
	fire.step(fire.ignite_seconds)
	await test.frames(2)
	test.check(fire.is_burning() and tray.is_empty() and cooker.is_burning(), "left longer, the cooker catches fire and the batch burns")
	test.check(lab.get_status_line() == TranslationServer.translate("Fire in the lab!"), "the wrist says the lab is on fire")
	rig.locomotion.teleport_to(Vector3(-2.0, 0.0, -0.2), 0.0)
	await test.frames(2)
	var extinguisher: Extinguisher = lab.get_extinguisher()
	rig.tap_world_point(extinguisher.get_grab_center())
	await test.frames(2)
	test.check(rig.get_held_items().has(extinguisher), "the extinguisher comes off the wall")
	for burst: int in 6:
		if not fire.is_burning():
			break
		rig.tap_world_point(fire.get_target_position())
		await test.frames(70)
	test.check(not fire.is_burning() and not cooker.is_burning(), "foam sprayed at the fire puts it out")
	rig.tap_world_point(extinguisher.home_socket.global_position)
	await test.frames(2)
	test.check(rig.get_held_items().is_empty() and extinguisher.socket == extinguisher.home_socket, "a click on its hook hangs the extinguisher back")


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
	test.check(held_items.size() == 1 and held_items[0] == ground, "a VR grip press picks the item up and the hand keeps it")
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
	test.check(plants[0].is_active() and plants[0].visible and not plants[1].is_active() and not plants[1].visible, "a new lab shows only the one pot it has, no empty ones")
	test.check(plants[0].is_active() and not plants[1].is_active() and not grinder.visible and not cooker.visible and not press.visible and not lab.get_crate(&"glowcap").visible, "a new lab has one shroom plant and no gadgets yet")
	var recipe_board: RecipeBoard = lab.get_recipe_board()
	test.check(recipe_board.get_row_count() == lab.recipes.size() and recipe_board.get_unlocked_count() == 1, "the recipe book shows every recipe, open; only shrooms are unlocked")
	test.check(not lab.get_guide_board().is_step_unlocked(&"Grind"), "the poster points to the office for the grinder")
	test.check(not lab.are_posters_up(), "no recipe book or how-to poster in a lab without gadgets")
	var plant: ShroomPlant = plants[0]
	test.check(not plant.is_ripe(), "the plant starts growing")
	plant.grow(plant.grow_seconds)
	test.check(plant.is_ripe(), "the plant grows shrooms by itself")
	var stash_before: int = operation.stash.get_total()
	rig.tap_world_point(plant.get_grab_center())
	await test.frames(3)
	var held: Array[Grabbable] = rig.get_held_items()
	var picked: ProductBag = held[0] as ProductBag if held.size() == 1 else null
	test.check(picked != null and picked.recipe == plant.crop and not plant.is_ripe() and operation.stash.get_total() == stash_before, "picking a ripe plant puts a bag of shrooms in the hand, not in the stash; then it grows again")
	var view_status: ViewStatus = level.get_view_status()
	test.check(picked != null and await test.wait_until(func() -> bool: return view_status.get_hand_icon(rig.dominant_hand) == picked.get_icon()), "the hand's box under the view shows the bag's icon")
	if picked != null:
		var standing_at: Vector3 = rig.get_feet_position()
		await _put_held_bag_in_stash(test, level, picked, stash_before)
		rig.locomotion.teleport_to(standing_at)
		test.check(await test.wait_until(func() -> bool: return view_status.get_hand_icon(rig.dominant_hand) == null), "with the bag in the stash the hand's box is empty again")
	var config: GameConfig = GameConfig.get_default()
	# Bring the money these purchases cost, so the other areas' checks keep their budget.
	for upgrade_id: StringName in [Types.UPGRADE_GRINDER, Types.UPGRADE_COOKER, Types.UPGRADE_PRESS, Types.UPGRADE_PLANTS]:
		Profile.wallet.add(Types.CURRENCY_CASH, config.find_upgrade(upgrade_id).get_cost(0))
	test.check(not Profile.upgrades.can_purchase(config.find_upgrade(Types.UPGRADE_COOKER)), "the cooker needs the grinder first")
	var grinder_floor: Vector3 = Vector3(grinder.global_position.x, 0.0, grinder.global_position.z)
	test.check(level.rig.walkable_area.contains(grinder_floor), "a station not bought yet takes no room")
	test.check(Profile.upgrades.purchase(config.find_upgrade(Types.UPGRADE_GRINDER)), "the office sells the grinder")
	level.apply_upgrades()
	test.check(not lab.are_posters_up(), "the grinder alone doesn't put the posters up")
	for gadget_id: StringName in [Types.UPGRADE_COOKER, Types.UPGRADE_PRESS]:
		test.check(Profile.upgrades.purchase(config.find_upgrade(gadget_id)), "the office sells the %s" % gadget_id)
	level.apply_upgrades()
	test.check(lab.are_posters_up(), "with the grinder and the cooker the recipe book and the how-to poster go up")
	await test.frames(2)
	test.check(not level.rig.walkable_area.contains(grinder_floor), "a bought station can't be walked through")
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
