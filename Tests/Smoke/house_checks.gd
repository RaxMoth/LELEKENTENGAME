## Smoke checks of the house itself: walking and travel, the office (buying
## upgrades, bribes, reputation gates), crew wages and strikes, controller
## mapping, popups on the in-world screen, nightfall and losing the shift.
## Owned by whoever works on the house (level, office, crew, XR).
##
## Dependencies: SmokeTest, HouseLevel, Office, FrontGarden, Worker, DayCycle
class_name HouseSmokeChecks
extends RefCounted


## Before the fronts' checks: the player can move around the house.
static func run_start(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var walkable: WalkableArea = rig.walkable_area
	test.check(not rig.is_xr_active and walkable != null, "rig runs the flat simulator with a walkable area")
	test.check(walkable.contains(rig.get_feet_position()), "the player starts on a walkable floor")
	test.check(not walkable.contains(Vector3(0.0, 0.0, -7.0)), "the garden is not walkable")
	rig.locomotion.travel_to_spot(0)
	var lab_spot: Vector3 = rig.locomotion.travel_spots[0].global_position
	test.check(rig.get_feet_position().distance_to(Vector3(lab_spot.x, rig.global_position.y, lab_spot.z)) < 0.05, "quick travel moves the player to the lab")
	var before: Vector3 = rig.get_feet_position()
	Input.action_press(Types.ACTION_MOVE_FORWARD)
	await test.physics_frames(20)
	Input.action_release(Types.ACTION_MOVE_FORWARD)
	test.check(rig.get_feet_position().distance_to(before) > 0.2 and walkable.contains(rig.get_feet_position()), "walking moves the player and stays on the floor")


## After the fronts' checks: office, crew, controllers, popups, night, losing.
static func run_end(test: SmokeTest, level: HouseLevel) -> void:
	await _check_office(test, level)
	_check_crew_wages(test, level)
	await _check_controllers(test, level)
	await _check_world_popup(test, level)
	var day_cycle: DayCycle = level.day_cycle
	var nights: Array[int] = [0]
	day_cycle.nightfall.connect(func() -> void: nights[0] += 1)
	day_cycle.advance(day_cycle.day_seconds)
	await test.frames(3)
	test.check(day_cycle.is_night() and nights[0] == 1, "the day turns into night")
	test.check(not level.cycle.is_raid_active() and level.cycle.allows_customers(), "the night of a selling day brings no raid")
	await _check_raid_waves(test, level)
	var operation: Operation = level.operation
	operation.add_product(operation.recipes[0], 2, 3)
	(level.get_front(FrontGarden) as FrontGarden).door.health_component.damage(1000000.0)
	test.check(await test.wait_until(func() -> bool: return UI.has_open_popup() and level.phase == LevelBase.Phase.FINISHED), "a broken door ends the shift (mid-raid)")
	test.check(operation.stash.get_total() == 0, "losing the door loses the stash")
	await test.frames(30)
	UI.close_top_popup()


static func _check_office(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var office: Office = level.get_front(Office) as Office
	rig.locomotion.travel_to_spot(3)
	var office_screen: WorldScreen = office.get_screen()
	var office_board: OfficeBoard = office.get_board()
	rig.tap_world_point(office_screen.pixel_to_world(office_board.get_tab(&"defense").get_global_rect().get_center()))
	await test.frames(3)
	var first_row: ShopItemRow = office_board.find_child("Rows", true, false).get_child(0) as ShopItemRow
	var door: FrontDoor = (level.get_front(FrontGarden) as FrontGarden).door
	var max_before: float = door.health_component.max_health
	rig.tap_world_point(office_screen.pixel_to_world(first_row.get_buy_button().get_global_rect().get_center()))
	await test.frames(5)
	test.check(Profile.upgrades.get_level(Types.UPGRADE_DOOR) == 1 and door.health_component.max_health > max_before, "buying Reinforced Door on the office board strengthens the door")
	var operation: Operation = level.operation
	operation.add_heat(30.0)
	var heat_before: float = operation.heat.value
	test.check(operation.bribe() and operation.heat.value < heat_before, "a bribe cools the heat")
	Profile.operation.add_reputation(-Profile.operation.reputation)
	test.check(not Profile.upgrades.can_purchase(GameConfig.get_default().find_upgrade(Types.UPGRADE_VIP)), "upgrades stay locked until the reputation is there")


static func _check_crew_wages(test: SmokeTest, level: HouseLevel) -> void:
	var operation: Operation = level.operation
	var hired: Worker = null
	for node: Node in level.get_tree().get_nodes_in_group(Types.GROUP_CREW):
		var worker: Worker = node as Worker
		if worker.is_hired():
			hired = worker
			break
	if hired == null:
		test.check(false, "some crew is hired by now")
		return
	var cash: int = operation.get_cash()
	operation.spend_cash(cash, "test")
	test.check(not hired.pay_wage() and not hired.is_working(), "unpaid crew go on strike")
	Profile.wallet.add(Types.CURRENCY_CASH, cash, false)
	test.check(hired.pay_wage() and hired.is_working(), "paid crew get back to work")


## Day 3 of the cycle: the raid starts, the window closes, the first wave
## comes and is beaten, the second wave comes (the caller then loses the door).
static func _check_raid_waves(test: SmokeTest, level: HouseLevel) -> void:
	var cycle: HouseCycle = level.cycle
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var window: SalesWindow = level.get_front(SalesWindow) as SalesWindow
	for enemy: LaneEnemy in garden.board.get_enemies().duplicate():
		enemy.take_hit(1000000.0)
	Profile.operation.day_number = cycle.get_days_per_cycle()
	test.check(cycle.is_raid_day() and cycle.get_day_in_cycle() == cycle.get_days_per_cycle(), "day 3 of the cycle is the raid day")
	window.flow.is_active = true
	cycle.start_raid()
	await test.frames(2)
	test.check(cycle.is_raid_active() and not cycle.allows_customers() and window.get_queue_size() == 0, "the raid starts and the back window closes")
	window.flow.step(60.0)
	window.flow.is_active = false
	test.check(window.get_queue_size() == 0, "no customers come during a raid")
	test.check(cycle.get_wave_count() == 2 and not cycle.is_wave_active(), "the first raid has two waves and a moment to prepare")
	garden.director.is_active = true
	cycle.skip_wave_break()
	test.check(await test.wait_until(func() -> bool: return cycle.is_wave_active()), "the first wave starts")
	await test.wait_until(func() -> bool: return garden.director.get_pending_spawn_count() == 0)
	test.check(garden.director.get_raiders_left() == 3, "the first wave brings three cops")
	for raider: LaneEnemy in garden.board.get_enemies().duplicate():
		raider.take_hit(1000000.0)
	test.check(await test.wait_until(func() -> bool: return not cycle.is_wave_active() and cycle.is_raid_active()), "beating every officer ends the wave, the raid goes on")
	cycle.skip_wave_break()
	test.check(await test.wait_until(func() -> bool: return cycle.is_wave_active() and cycle.get_wave_number() == 2), "the next wave follows")


## Without a headset the controller callbacks are the only way to run the XR input mapping.
static func _check_controllers(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var action_counts: Dictionary[StringName, int] = {&"primary": 0, &"secondary": 0}
	rig.primary_action_pressed.connect(func(_pointer: XRPointer) -> void: action_counts[&"primary"] += 1)
	rig.secondary_action_pressed.connect(func(_pointer: XRPointer) -> void: action_counts[&"secondary"] += 1)
	rig.call("_on_right_hand_button_pressed", String(Types.XR_ACTION_TRIGGER_CLICK))
	rig.call("_on_right_hand_button_released", String(Types.XR_ACTION_TRIGGER_CLICK))
	rig.call("_on_left_hand_button_pressed", String(Types.XR_ACTION_TRIGGER_CLICK))
	rig.call("_on_left_hand_button_released", String(Types.XR_ACTION_TRIGGER_CLICK))
	test.check(action_counts[&"primary"] == 1 and action_counts[&"secondary"] == 1, "controller triggers map to use (dominant) and blaster (off-hand)")
	var forward_before: Vector3 = -rig.get_head_transform().basis.z
	rig.call("_on_right_hand_input_vector2_changed", String(Types.XR_ACTION_THUMBSTICK), Vector2(0.9, 0.0))
	rig.call("_on_right_hand_input_vector2_changed", String(Types.XR_ACTION_THUMBSTICK), Vector2.ZERO)
	var forward_after: Vector3 = -rig.get_head_transform().basis.z
	var turned_degrees: float = rad_to_deg(Vector2(forward_before.x, forward_before.z).angle_to(Vector2(forward_after.x, forward_after.z)))
	test.check(absf(absf(turned_degrees) - rig.locomotion.snap_turn_degrees) < 1.0, "a dominant-stick flick snap-turns the player")
	rig.call("_on_left_hand_button_pressed", String(Types.XR_ACTION_MENU_BUTTON))
	await test.frames(30)
	test.check(level.get_tree().paused and UI.has_open_popup(), "controller menu button pauses")
	rig.call("_on_right_hand_button_pressed", String(Types.XR_ACTION_SECONDARY_BUTTON))
	test.check(await test.wait_until(func() -> bool: return level.is_playing() and not level.get_tree().paused), "controller menu button resumes")


static func _check_world_popup(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	rig.set_world_space_ui(true)
	level.pause_level()
	await test.frames(40)
	var popup_screen: WorldScreen = rig.get_node("%PopupScreen") as WorldScreen
	var resume_button: Button = UI.get_world_viewport().find_child("ResumeButton", true, false) as Button
	test.check(level.get_tree().paused and popup_screen.is_active and resume_button != null, "pause menu opens on the in-world popup screen")
	if resume_button != null:
		rig.tap_world_point(popup_screen.pixel_to_world(resume_button.global_position + resume_button.size * 0.5))
	test.check(await test.wait_until(func() -> bool: return level.is_playing() and not level.get_tree().paused), "pointer presses a popup button on the world screen")
	rig.set_world_space_ui(false)
	test.check(not UI.is_world_space_enabled(), "popups return to the window overlay")
