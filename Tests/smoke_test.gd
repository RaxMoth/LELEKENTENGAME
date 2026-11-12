## Automated smoke test. Boots every menu and level (levels run in the XR
## rig's flat simulator), plays a few seconds, exercises pause / win / lose /
## results, plays a whole shift at the house through the pointer paths a
## headset uses (craft, sell, defend, upgrade, crew, night, losing the door),
## opens every popup and checks the savegame round-trip. Exit code 0 = all good.
##
## Run from the project folder:
##   godot --headless --fixed-fps 60 res://Tests/SmokeTest.tscn
##
## Note: uses (and resets) the real user:// savegame of the project.
##
## Dependencies: every autoload
extends Node

## Wall-clock budget per wait: headless frames run unthrottled, so a frame
## count would expire before a background scene load finishes.
const TIMEOUT_MSEC: int = 20000
## The game; without a headset it runs in the rig's flat simulator.
const HOUSE_LEVEL_ID: StringName = &"house"

var _failures: PackedStringArray = []
var _checks: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# Detach from get_tree().current_scene so SceneManager can swap scenes without freeing the test.
	get_tree().current_scene = null
	await _frames(10)
	Profile.reset_progress()
	await _test_save_roundtrip()
	await _test_menus()
	await _test_popups()
	var config: GameConfig = GameConfig.get_default()
	for level_index: int in config.levels.size():
		await _test_level(config.levels[level_index], level_index % 2 == 0)
	await _test_house(config.find_level(HOUSE_LEVEL_ID))
	print("\n==== SMOKE TEST: %d checks, %d failures ====" % [_checks, _failures.size()])
	for failure: String in _failures:
		print("  FAIL: " + failure)
	Profile.reset_progress()
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _test_save_roundtrip() -> void:
	Profile.wallet.add(Types.CURRENCY_CASH, 123)
	Profile.operation.add_reputation(7)
	var expected_cash: int = Profile.wallet.get_amount(Types.CURRENCY_CASH)
	_check(SaveManager.save_now(), "save_now succeeded")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	var saved_cash: int = int(saved["sections"]["wallet"]["cash"]) if saved is Dictionary else -1
	var saved_reputation: int = int(saved["sections"]["operation"]["reputation"]) if saved is Dictionary else -1
	_check(saved_cash == expected_cash, "wallet persisted (%d == %d)" % [saved_cash, expected_cash])
	_check(saved_reputation == 7, "operation progress persisted")
	_check(not Profile.wallet.spend(Types.CURRENCY_CASH, 999999999), "cannot overspend")


func _test_menus() -> void:
	var config: GameConfig = GameConfig.get_default()
	for scene_path: String in [config.main_menu_scene, config.level_select_scene, config.shop_scene]:
		SceneManager.change_scene(scene_path)
		_check(await _wait_for_scene(scene_path), "menu loads: " + scene_path)
	_check(SceneManager.go_back(), "back stack works")
	await _wait_for_transition()


func _test_popups() -> void:
	var popup_paths: PackedStringArray = [
		"res://Scenes/UI/Popups/SettingsPopup/SettingsPopup.tscn",
		"res://Scenes/UI/Popups/AchievementsPopup/AchievementsPopup.tscn",
		"res://Scenes/UI/Popups/PausePopup/PausePopup.tscn",
	]
	for popup_path: String in popup_paths:
		UI.open_popup(load(popup_path) as PackedScene)
		await _frames(20)
		_check(UI.has_open_popup(), "popup opens: " + popup_path.get_file())
		UI.close_top_popup()
		await _frames(30)
		_check(not UI.has_open_popup(), "popup closes: " + popup_path.get_file())
	var reward_popup: BasePopup = UI.open_popup(load("res://Scenes/UI/Popups/RewardPopup/RewardPopup.tscn") as PackedScene, {"title": "Test", "rewards": {Types.CURRENCY_CASH: 5}})
	await _frames(20)
	reward_popup.close(1)
	await _frames(30)
	_check(not UI.has_open_popup(), "reward popup closes")
	var confirm_task: Array[bool] = [false]
	var confirm_coroutine: Callable = func() -> void: confirm_task[0] = await UI.confirm("Test", "Message")
	confirm_coroutine.call()
	await _frames(20)
	UI.close_top_popup()
	await _frames(30)
	_check(not UI.has_open_popup(), "confirm dialog closes via back")


func _test_level(level: LevelData, force_win: bool) -> void:
	var attempts_before: int = Profile.levels.get_attempts(level.id)
	LevelBase.start_level(level)
	if not await _wait_for_scene(level.scene_path):
		_check(false, "level loads: " + level.id)
		return
	var active_level: LevelBase = get_tree().current_scene as LevelBase
	_check(active_level != null and active_level.level_data == level, "level receives its LevelData: " + level.id)
	_check(await _wait_until(func() -> bool: return active_level.phase == LevelBase.Phase.PLAYING), "intro finishes: " + level.id)
	await _frames(180)
	if active_level.phase == LevelBase.Phase.PLAYING:
		active_level.pause_level()
		await _frames(20)
		_check(get_tree().paused and UI.has_open_popup(), "pause opens menu: " + level.id)
		UI.close_top_popup()
		_check(await _wait_until(func() -> bool: return active_level.phase == LevelBase.Phase.PLAYING), "resume works: " + level.id)
		await _frames(60)
		if force_win and not level.is_endless:
			active_level.win()
		else:
			active_level.lose()
	_check(await _wait_until(func() -> bool: return UI.has_open_popup() and active_level.phase == LevelBase.Phase.FINISHED), "results popup shows: " + level.id)
	_check(Profile.levels.get_attempts(level.id) == attempts_before + 1, "attempt recorded: " + level.id)
	await _frames(30)
	UI.close_top_popup()
	_check(await _wait_until(func() -> bool: return not (get_tree().current_scene is LevelBase) and not SceneManager.is_transitioning), "left level to menu: " + level.id)
	await _frames(5)


## Plays the house through the same pointer paths a headset uses (in the
## flat simulator): walks, crafts a batch by hand at all three lab stations,
## sells it at the back window, builds and fights in the garden, buys
## upgrades, hires crew, runs the night and loses the door.
func _test_house(level_data: LevelData) -> void:
	if level_data == null:
		return
	LevelBase.start_level(level_data)
	if not await _wait_for_scene(level_data.scene_path):
		_check(false, "house loads")
		return
	var level: LevelBase = get_tree().current_scene as LevelBase
	_check(await _wait_until(func() -> bool: return level.is_playing()), "house starts playing")
	var rig: XRPlayerRig = level.rig
	var operation: Operation = level.get_node("%Operation") as Operation
	var board: LaneBoard = level.get_node("%LaneBoard") as LaneBoard
	var door: FrontDoor = level.get_node("%FrontDoor") as FrontDoor
	var sales_window: SalesWindow = level.get_node("%SalesWindow") as SalesWindow
	var director: PressureDirector = level.get_node("%PressureDirector") as PressureDirector
	var day_cycle: DayCycle = level.get_node("%DayCycle") as DayCycle
	# Keep the director quiet so the checks control what happens.
	director.is_active = false
	Profile.wallet.add(Types.CURRENCY_CASH, 5000)
	_check(not rig.is_xr_active and rig.walkable_area != null, "rig runs the flat simulator with a walkable area")

	await _test_movement(rig)
	await _test_crafting(level, rig, operation)
	await _test_selling(level, rig, operation, sales_window)
	await _test_defense(level, rig, operation, board, door)
	await _test_office(level, rig, operation, director)
	await _test_crew(level, operation, sales_window, board)
	await _test_controllers(level, rig)
	await _test_world_popup(level, rig)

	var nights: Array[int] = [0]
	day_cycle.nightfall.connect(func() -> void: nights[0] += 1)
	day_cycle.advance(day_cycle.day_seconds)
	await _frames(3)
	_check(day_cycle.is_night() and nights[0] == 1, "the day turns into night")
	var pending_before_boss: int = director.get_pending_spawn_count()
	director.start_boss_wave()
	_check(director.get_pending_spawn_count() - pending_before_boss == 4, "the boss wave brings the boss and three escorts")

	operation.add_product(operation.recipes[0], 2, 3)
	door.health_component.damage(1000000.0)
	_check(await _wait_until(func() -> bool: return UI.has_open_popup() and level.phase == LevelBase.Phase.FINISHED), "a broken door ends the shift")
	_check(operation.stash.get_total() == 0, "losing the door loses the stash")
	await _frames(30)
	UI.close_top_popup()
	_check(await _wait_until(func() -> bool: return not (get_tree().current_scene is LevelBase) and not SceneManager.is_transitioning), "left the house to the menu")
	await _frames(5)


func _test_movement(rig: XRPlayerRig) -> void:
	var walkable: WalkableArea = rig.walkable_area
	_check(walkable.contains(rig.get_feet_position()), "the player starts on a walkable floor")
	_check(not walkable.contains(Vector3(0.0, 0.0, -7.0)), "the garden is not walkable")
	rig.locomotion.travel_to_spot(0)
	var lab_spot: Vector3 = rig.locomotion.travel_spots[0].global_position
	_check(rig.get_feet_position().distance_to(Vector3(lab_spot.x, rig.global_position.y, lab_spot.z)) < 0.05, "quick travel moves the player to the lab")
	var before: Vector3 = rig.get_feet_position()
	Input.action_press(Types.ACTION_MOVE_FORWARD)
	await _physics_frames(20)
	Input.action_release(Types.ACTION_MOVE_FORWARD)
	_check(rig.get_feet_position().distance_to(before) > 0.2 and walkable.contains(rig.get_feet_position()), "walking moves the player and stays on the floor")
	rig.locomotion.travel_to_spot(0)


func _test_crafting(level: LevelBase, rig: XRPlayerRig, operation: Operation) -> void:
	var grinder: Workstation = level.get_node("%Grinder") as Workstation
	var cooker: Workstation = level.get_node("%Cooker") as Workstation
	var press: Workstation = level.get_node("%Press") as Workstation
	var glowcap_crate: IngredientCrate = level.get_node("World/Stage/Lab/CrateGlowcap") as IngredientCrate
	var sugarsalt_crate: IngredientCrate = level.get_node("World/Stage/Lab/CrateSugarsalt") as IngredientCrate
	var cash_before: int = operation.get_cash()
	rig.tap_world_point(glowcap_crate.get_grab_center())
	await _frames(2)
	_check(rig.get_held_items().size() == 1 and operation.get_cash() == cash_before - glowcap_crate.ingredient.cost, "clicking a crate takes an ingredient and pays for it")
	rig.tap_world_point(sugarsalt_crate.get_grab_center() + Vector3(0.0, 0.5, 0.0))
	await _frames(2)
	_check(rig.get_held_items().is_empty() and operation.get_cash() == cash_before, "an ingredient dropped nowhere goes back and is refunded")

	rig.tap_world_point(glowcap_crate.get_grab_center())
	await _frames(2)
	rig.tap_world_point(grinder.get_input_sockets()[0].global_position)
	await _frames(3)
	_check(grinder.is_running(), "a raw ingredient in the grinder starts its skill check")
	await _stop_in_the_middle(rig, grinder)
	var ground: IngredientItem = grinder.get_output_socket().item as IngredientItem
	_check(ground != null and ground.is_processed, "stopping in the green grinds the ingredient")

	rig.tap_world_point(ground.get_grab_center())
	await _frames(2)
	rig.tap_world_point(cooker.get_input_sockets()[0].global_position)
	await _frames(2)
	rig.tap_world_point(sugarsalt_crate.get_grab_center())
	await _frames(2)
	rig.tap_world_point(cooker.get_input_sockets()[1].global_position)
	await _frames(3)
	_check(cooker.is_running(), "a full recipe in the cooker starts cooking")
	await _stop_in_the_middle(rig, cooker)
	var batch: BatchItem = cooker.get_output_socket().item as BatchItem
	_check(batch != null and batch.recipe.id == &"glow", "cooking makes a batch of the matching product")

	var stash_before: int = operation.stash.get_total()
	rig.tap_world_point(batch.get_grab_center())
	await _frames(2)
	rig.tap_world_point(press.get_input_sockets()[0].global_position)
	await _frames(3)
	_check(press.is_running(), "a batch in the press starts packaging")
	await _stop_in_the_middle(rig, press)
	var units: int = operation.stash.get_total() - stash_before
	_check(units == operation.get_batch_size(batch.recipe), "packaging puts a full batch into the stash")
	_check(operation.stash.count(&"glow", 3) == units, "perfect handwork makes Pure quality or better")


## Puts the needle in the middle of the sweet zone and presses the station's button.
func _stop_in_the_middle(rig: XRPlayerRig, station: Workstation) -> void:
	var gauge: TimingGauge = station.get_gauge()
	gauge.elapsed_seconds = gauge.zone_center / (2.0 * gauge.sweeps_per_second)
	rig.tap_world_point(station.get_stop_button().get_press_center())
	await _frames(3)


func _test_selling(level: LevelBase, rig: XRPlayerRig, operation: Operation, sales_window: SalesWindow) -> void:
	rig.locomotion.travel_to_spot(2)
	var recipe: RecipeData = operation.recipes[0]
	var regular: CustomerTypeData = load("res://Ressources/Customers/regular.tres") as CustomerTypeData
	var order: CustomerOrder = CustomerOrder.new()
	order.customer_type = regular
	order.recipe = recipe
	order.quantity = 2
	order.min_tier = 1
	operation.set_price(recipe, recipe.base_price)
	sales_window.spawn_customer(order)
	_check(await _wait_until(func() -> bool: return sales_window.get_front_customer() != null), "a customer walks up to the window")
	var screen: WorldScreen = sales_window.get_node("%SalesScreen") as WorldScreen
	var sell_button: Button = screen.content.find_child("SellButton", true, false) as Button
	var cash_before: int = operation.get_cash()
	var stock_before: int = operation.stash.get_total()
	var reputation_before: int = Profile.operation.reputation
	rig.tap_world_point(screen.pixel_to_world(sell_button.get_global_rect().get_center()))
	await _frames(3)
	_check(operation.stash.get_total() == stock_before - 2 and operation.get_cash() > cash_before, "pressing Sell on the window board sells from the stash")
	_check(Profile.operation.reputation > reputation_before and operation.heat.value > 0.0, "a sale earns reputation and draws heat")

	var haggler: CustomerTypeData = load("res://Ressources/Customers/haggler.tres") as CustomerTypeData
	var haggle_order: CustomerOrder = CustomerOrder.new()
	haggle_order.customer_type = haggler
	haggle_order.recipe = recipe
	haggle_order.quantity = 1
	haggle_order.min_tier = 1
	sales_window.spawn_customer(haggle_order)
	_check(await _wait_until(func() -> bool: return sales_window.get_front_customer() != null), "a haggler walks up")
	var tier: int = operation.get_deliverable_tier(haggle_order)
	operation.set_price(recipe, roundi(haggle_order.get_max_unit_price(tier) * 1.1))
	_check(sales_window.sell_to_front() == SalesMath.Verdict.COUNTER, "a haggler counters a price slightly too high")
	var counter_cash: int = operation.get_cash()
	sales_window.accept_counter()
	_check(operation.get_cash() == counter_cash + haggle_order.get_max_unit_price(tier), "accepting the counteroffer sells at their price")
	operation.set_price(recipe, recipe.base_price)

	var impatient: Customer = sales_window.spawn_customer(order)
	impatient.max_patience = 0.2
	impatient.patience_left = 0.2
	var reputation_before_wait: int = Profile.operation.reputation
	_check(await _wait_until(func() -> bool: return impatient.is_leaving), "a customer left waiting too long walks off")
	_check(Profile.operation.reputation < reputation_before_wait, "losing a customer costs reputation")


func _test_defense(level: LevelBase, rig: XRPlayerRig, operation: Operation, board: LaneBoard, door: FrontDoor) -> void:
	rig.locomotion.travel_to_spot(1)
	_check(bool(level.call("is_in_defense_zone")), "the front room is the defense position")
	var build_screen: WorldScreen = level.get_node("%BuildScreen") as WorldScreen
	var build_board: BuildBoard = build_screen.content as BuildBoard
	rig.tap_world_point(build_screen.pixel_to_world(build_board.get_card_center(0)))
	await _frames(3)
	_check(int(level.get("selected_tower")) == 0, "pointer picks a tower card on the board above the gate")
	var cash_before: int = operation.get_cash()
	var cell: Vector2i = Vector2i(1, 2)
	rig.tap_world_point(board.grid.cell_to_position(cell))
	await _frames(3)
	_check(not board.can_place(cell) and operation.get_cash() < cash_before, "clicking a garden tile builds the tower for cash")

	var junkie: LaneEnemy = _spawn_in_lane(board, load("res://Scenes/Levels/House/Garden/Junkie.tscn") as PackedScene, cell.x, board.grid.get_column_z(5))
	_check(await _wait_until(func() -> bool: return junkie.health_component.get_health_ratio() < 1.0 or not junkie.is_alive()), "the turret shoots the attacker in its lane")
	var cop: LaneEnemy = _spawn_in_lane(board, load("res://Scenes/Levels/House/Garden/Cop.tscn") as PackedScene, 0, board.grid.get_column_z(4))
	var cop_health: float = cop.health_component.current_health
	level.set("_blaster_cooldown", 0.0)
	rig.tap_world_point(cop.get_hit_center())
	await _frames(3)
	_check(cop.health_component.current_health < cop_health, "clicking an attacker fires the blaster")
	cop.global_position.z = board.get_home_z() - 0.5
	var door_health: float = door.health_component.current_health
	_check(await _wait_until(func() -> bool: return door.health_component.current_health < door_health), "an attacker at the door breaks it down")

	operation.add_product(operation.recipes[0], 2, 4)
	var stock_before: int = operation.stash.get_total()
	_spawn_in_lane(board, load("res://Scenes/Levels/House/Garden/Junkie.tscn") as PackedScene, 2, board.get_home_z() - 0.4)
	_check(await _wait_until(func() -> bool: return operation.stash.get_total() < stock_before), "a junkie reaching the door steals stock")
	cop.take_hit(100000.0)
	door.health_component.heal(100000.0)


func _test_office(level: LevelBase, rig: XRPlayerRig, operation: Operation, director: PressureDirector) -> void:
	rig.locomotion.travel_to_spot(3)
	var office_screen: WorldScreen = level.get_node("%OfficeScreen") as WorldScreen
	var office_board: OfficeBoard = office_screen.content as OfficeBoard
	var defense_tab: Button = office_board.get_tab(&"defense")
	rig.tap_world_point(office_screen.pixel_to_world(defense_tab.get_global_rect().get_center()))
	await _frames(3)
	var first_row: ShopItemRow = office_board.find_child("Rows", true, false).get_child(0) as ShopItemRow
	var door: FrontDoor = level.get_node("%FrontDoor") as FrontDoor
	var max_before: float = door.health_component.max_health
	rig.tap_world_point(office_screen.pixel_to_world(first_row.get_buy_button().get_global_rect().get_center()))
	await _frames(5)
	_check(Profile.upgrades.get_level(Types.UPGRADE_DOOR) == 1 and door.health_component.max_health > max_before, "buying Reinforced Door on the office board strengthens the door")

	operation.add_heat(60.0)
	director.is_active = true
	director.step(0.01)
	director.is_active = false
	_check(director.get_pending_spawn_count() > 0, "high heat sends a police raid")
	var heat_before: float = operation.heat.value
	_check(operation.bribe() and operation.heat.value < heat_before, "a bribe cools the heat")
	Profile.operation.add_reputation(-Profile.operation.reputation)
	var gated: UpgradeData = GameConfig.get_default().find_upgrade(Types.UPGRADE_VIP)
	_check(not Profile.upgrades.can_purchase(gated), "upgrades stay locked until the reputation is there")


func _test_crew(level: LevelBase, operation: Operation, sales_window: SalesWindow, board: LaneBoard) -> void:
	Profile.operation.add_reputation(100)
	var config: GameConfig = GameConfig.get_default()
	for upgrade_id: StringName in [Types.UPGRADE_CRAFTER, Types.UPGRADE_DEALER, Types.UPGRADE_GUARD]:
		level.call("buy_upgrade", config.find_upgrade(upgrade_id))
	await _frames(3)
	var crafter: Worker = level.get_node("World/Stage/Workers/CrafterA") as Worker
	var dealer: Worker = level.get_node("World/Stage/Workers/DealerA") as Worker
	var guard: Worker = level.get_node("World/Stage/Workers/GuardA") as Worker
	var second_crafter: Worker = level.get_node("World/Stage/Workers/CrafterB") as Worker
	_check(crafter.is_working() and dealer.is_working() and guard.is_working() and not second_crafter.visible, "hired crew show up for work, unhired slots stay empty")
	var stock_before: int = operation.stash.get_total()
	crafter.work_now()
	_check(operation.stash.get_total() > stock_before, "a crafter makes product")

	var order: CustomerOrder = CustomerOrder.new()
	order.customer_type = load("res://Ressources/Customers/regular.tres") as CustomerTypeData
	order.recipe = operation.recipes[0]
	order.quantity = 1
	order.min_tier = 1
	sales_window.spawn_customer(order)
	await _wait_until(func() -> bool: return sales_window.get_front_customer() != null)
	var cash_before: int = operation.get_cash()
	dealer.work_now()
	_check(operation.get_cash() > cash_before, "a dealer serves a regular customer")

	var goon: LaneEnemy = _spawn_in_lane(board, load("res://Scenes/Levels/House/Garden/Goon.tscn") as PackedScene, 0, board.get_home_z() - 2.0)
	var goon_health: float = goon.health_component.current_health
	guard.work_now()
	_check(goon.health_component.current_health < goon_health, "a guard shoots attackers near the door")
	goon.take_hit(100000.0)
	var broke_cash: int = operation.get_cash()
	operation.spend_cash(broke_cash, "test")
	_check(not guard.pay_wage() and not guard.is_working(), "unpaid crew go on strike")
	Profile.wallet.add(Types.CURRENCY_CASH, broke_cash)
	_check(guard.pay_wage() and guard.is_working(), "paid crew get back to work")


## Without a headset the controller callbacks are the only way to run the XR input mapping.
func _test_controllers(level: LevelBase, rig: XRPlayerRig) -> void:
	var action_counts: Dictionary[StringName, int] = {&"primary": 0, &"secondary": 0}
	rig.primary_action_pressed.connect(func(_pointer: XRPointer) -> void: action_counts[&"primary"] += 1)
	rig.secondary_action_pressed.connect(func(_pointer: XRPointer) -> void: action_counts[&"secondary"] += 1)
	rig.call("_on_right_hand_button_pressed", String(Types.XR_ACTION_TRIGGER_CLICK))
	rig.call("_on_right_hand_button_released", String(Types.XR_ACTION_TRIGGER_CLICK))
	rig.call("_on_left_hand_button_pressed", String(Types.XR_ACTION_TRIGGER_CLICK))
	rig.call("_on_left_hand_button_released", String(Types.XR_ACTION_TRIGGER_CLICK))
	_check(action_counts[&"primary"] == 1 and action_counts[&"secondary"] == 1, "controller triggers map to use (dominant) and blaster (off-hand)")
	var forward_before: Vector3 = -rig.get_head_transform().basis.z
	rig.call("_on_right_hand_input_vector2_changed", String(Types.XR_ACTION_THUMBSTICK), Vector2(0.9, 0.0))
	rig.call("_on_right_hand_input_vector2_changed", String(Types.XR_ACTION_THUMBSTICK), Vector2.ZERO)
	var forward_after: Vector3 = -rig.get_head_transform().basis.z
	var turned_degrees: float = rad_to_deg(Vector2(forward_before.x, forward_before.z).angle_to(Vector2(forward_after.x, forward_after.z)))
	_check(absf(absf(turned_degrees) - rig.locomotion.snap_turn_degrees) < 1.0, "a dominant-stick flick snap-turns the player")
	rig.call("_on_left_hand_button_pressed", String(Types.XR_ACTION_MENU_BUTTON))
	await _frames(30)
	_check(get_tree().paused and UI.has_open_popup(), "controller menu button pauses")
	rig.call("_on_right_hand_button_pressed", String(Types.XR_ACTION_SECONDARY_BUTTON))
	_check(await _wait_until(func() -> bool: return level.is_playing() and not get_tree().paused), "controller menu button resumes")


func _test_world_popup(level: LevelBase, rig: XRPlayerRig) -> void:
	rig.set_world_space_ui(true)
	level.pause_level()
	await _frames(40)
	var popup_screen: WorldScreen = rig.get_node("%PopupScreen") as WorldScreen
	var resume_button: Button = UI.get_world_viewport().find_child("ResumeButton", true, false) as Button
	_check(get_tree().paused and popup_screen.is_active and resume_button != null, "pause menu opens on the in-world popup screen")
	if resume_button != null:
		rig.tap_world_point(popup_screen.pixel_to_world(resume_button.global_position + resume_button.size * 0.5))
	_check(await _wait_until(func() -> bool: return level.is_playing() and not get_tree().paused), "pointer presses a popup button on the world screen")
	rig.set_world_space_ui(false)
	_check(not UI.is_world_space_enabled(), "popups return to the window overlay")


## Spawns an attacker and moves it into a chosen lane and depth.
func _spawn_in_lane(board: LaneBoard, enemy_scene: PackedScene, lane: int, z: float) -> LaneEnemy:
	var enemy: LaneEnemy = board.spawn_enemy(enemy_scene)
	enemy.enter_lane(board, lane)
	enemy.global_position.x = board.grid.get_lane_x(lane)
	enemy.global_position.z = z
	return enemy


func _physics_frames(count: int) -> void:
	for frame_index: int in count:
		await get_tree().physics_frame


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  ok   " + description)
	else:
		print("  FAIL " + description)
		_failures.append(description)


func _frames(count: int) -> void:
	for frame_index: int in count:
		await get_tree().process_frame


func _wait_until(condition: Callable) -> bool:
	var deadline_msec: int = Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline_msec:
		if condition.call():
			return true
		await get_tree().process_frame
	return condition.call()


func _wait_for_scene(scene_path: String) -> bool:
	var loaded: bool = await _wait_until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == scene_path and not SceneManager.is_transitioning)
	await _frames(5)
	return loaded


func _wait_for_transition() -> void:
	await _frames(5)
	await _wait_until(func() -> bool: return not SceneManager.is_transitioning)
	await _frames(5)
