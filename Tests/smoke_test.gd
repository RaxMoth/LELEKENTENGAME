## Automated smoke test. Boots every menu and level, plays a few seconds,
## exercises pause / win / lose / results, opens every popup and checks the
## savegame round-trip. Exit code 0 = all good.
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
## The XR level; without a headset it runs in the rig's flat simulator.
const XR_LEVEL_ID: StringName = &"porchlight"
const HUSK_SCENE_PATH: String = "res://Scenes/Levels/Porchlight/Husk.tscn"
const SEED_BOLTBLOOM: int = 1

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
	await _test_xr_level(config.find_level(XR_LEVEL_ID))
	print("\n==== SMOKE TEST: %d checks, %d failures ====" % [_checks, _failures.size()])
	for failure: String in _failures:
		print("  FAIL: " + failure)
	Profile.reset_progress()
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _test_save_roundtrip() -> void:
	Profile.wallet.add(Types.CURRENCY_COINS, 123)
	var expected_coins: int = Profile.wallet.get_amount(Types.CURRENCY_COINS)
	_check(SaveManager.save_now(), "save_now succeeded")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	var saved_coins: int = int(saved["sections"]["wallet"]["coins"]) if saved is Dictionary else -1
	_check(saved_coins == expected_coins, "wallet persisted (%d == %d)" % [saved_coins, expected_coins])
	_check(not Profile.wallet.spend(Types.CURRENCY_COINS, 999999999), "cannot overspend")


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
	var reward_popup: BasePopup = UI.open_popup(load("res://Scenes/UI/Popups/RewardPopup/RewardPopup.tscn") as PackedScene, {"title": "Test", "rewards": {Types.CURRENCY_COINS: 5}})
	await _frames(20)
	reward_popup.close(1)
	var perk: PerkData = PerkData.new()
	perk.title = "Test perk"
	var perk_popup: BasePopup = UI.open_popup(load("res://Scenes/UI/Popups/PerkChoicePopup/PerkChoicePopup.tscn") as PackedScene, {"perks": [perk]})
	await _frames(20)
	_check(get_tree().paused, "perk popup pauses the game")
	perk_popup.close(perk)
	await _frames(30)
	_check(not get_tree().paused, "perk popup unpauses the game")
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


## Plays the XR level through the same pointer path a headset uses: clicks a
## card on the in-world board, plants, fights, catches a spark and presses a
## popup button on the in-world popup screen.
func _test_xr_level(level_data: LevelData) -> void:
	if level_data == null:
		return
	LevelBase.start_level(level_data)
	if not await _wait_for_scene(level_data.scene_path):
		_check(false, "xr level loads")
		return
	var level: LevelBase = get_tree().current_scene as LevelBase
	_check(await _wait_until(func() -> bool: return level.is_playing()), "xr level starts playing")
	var rig: XRPlayerRig = level.get_node("%XRPlayerRig") as XRPlayerRig
	var board: LaneBoard = level.get_node("%LaneBoard") as LaneBoard
	var board_screen: WorldScreen = level.get_node("%BoardScreen") as WorldScreen
	var seed_board: SeedBoard = board_screen.content as SeedBoard
	_check(not rig.is_xr_active and rig.get_tool_pointer() != null, "xr rig falls back to the flat simulator")

	rig.tap_world_point(board_screen.pixel_to_world(seed_board.get_card_center(SEED_BOLTBLOOM)))
	await _frames(3)
	_check(int(level.get("selected_seed")) == SEED_BOLTBLOOM, "pointer clicks a seed card on the world screen")

	var sparks_before: int = int(level.get("sparks"))
	var cell: Vector2i = Vector2i(2, 2)
	rig.tap_world_point(board.grid.cell_to_position(cell))
	await _frames(3)
	_check(not board.can_place(cell) and int(level.get("sparks")) == sparks_before - 100, "tapping a tile plants the selected defender")
	rig.tap_world_point(board.grid.cell_to_position(cell))
	await _frames(3)
	_check(board.get_defender_count() == 1, "an occupied tile can not be planted again")

	var husk_scene: PackedScene = load(HUSK_SCENE_PATH) as PackedScene
	var husk: LaneEnemy = _spawn_in_lane(board, husk_scene, cell.x, board.grid.get_column_z(5))
	_check(await _wait_until(func() -> bool: return husk.health_component.get_health_ratio() < 1.0), "boltbloom shoots the attacker in its lane")
	var health_before_shot: float = husk.health_component.current_health
	rig.tap_world_point(husk.get_hit_center())
	await _frames(3)
	_check(husk.health_component.current_health <= health_before_shot - 12.0, "tapping an attacker fires the blaster at it")

	var defender: LaneDefender = board.get_blocker(cell.x, board.grid.get_column_z(cell.y))
	husk.global_position.z = board.grid.get_column_z(cell.y) - 0.7
	_check(defender != null and await _wait_until(func() -> bool: return defender.health_component.get_health_ratio() < 1.0), "attacker stops at a defender and bites it")

	var lives_before: int = int(level.get("lives"))
	var runner: LaneEnemy = _spawn_in_lane(board, husk_scene, 0, board.get_home_z() - 0.05)
	_check(await _wait_until(func() -> bool: return int(level.get("lives")) == lives_before - 1) and not runner.is_alive(), "an attacker reaching the porch costs a life")

	var sparks_before_catch: int = int(level.get("sparks"))
	var orb: SparkOrb = board.release_spark(board.grid.cell_to_position(Vector2i(4, 1)) + Vector3(0.0, 1.0, 0.0), 25)
	await _frames(30)
	rig.set_flat_cursor(rig.get_viewport().get_camera_3d().unproject_position(orb.global_position))
	_check(await _wait_until(func() -> bool: return int(level.get("sparks")) == sparks_before_catch + 25), "pointing at a spark catches it")

	# Without a headset the controller callbacks are the only way to run the XR input mapping.
	var action_counts: Dictionary[StringName, int] = {&"primary": 0, &"secondary": 0}
	rig.primary_action_pressed.connect(func(_pointer: XRPointer) -> void: action_counts[&"primary"] += 1)
	rig.secondary_action_pressed.connect(func(_pointer: XRPointer) -> void: action_counts[&"secondary"] += 1)
	rig.call("_on_right_hand_button_pressed", String(Types.XR_ACTION_TRIGGER_CLICK))
	rig.call("_on_right_hand_button_released", String(Types.XR_ACTION_TRIGGER_CLICK))
	rig.call("_on_left_hand_button_pressed", String(Types.XR_ACTION_TRIGGER_CLICK))
	_check(action_counts[&"primary"] == 1 and action_counts[&"secondary"] == 1, "controller triggers map to plant (dominant) and blaster (off-hand)")
	var seed_before_flick: int = int(level.get("selected_seed"))
	rig.call("_on_left_hand_input_vector2_changed", String(Types.XR_ACTION_THUMBSTICK), Vector2(0.9, 0.0))
	rig.call("_on_left_hand_input_vector2_changed", String(Types.XR_ACTION_THUMBSTICK), Vector2(1.0, 0.0))
	rig.call("_on_left_hand_input_vector2_changed", String(Types.XR_ACTION_THUMBSTICK), Vector2.ZERO)
	_check(int(level.get("selected_seed")) == (seed_before_flick + 1) % seed_board.get_card_count(), "one thumbstick flick moves the seed selection one step")
	var seed_before_click: int = int(level.get("selected_seed"))
	rig.call("_handle_trackpad_click", Vector2(-0.8, 0.1))
	rig.call("_handle_trackpad_click", Vector2(0.1, 0.9))
	_check(int(level.get("selected_seed")) == posmod(seed_before_click - 1, seed_board.get_card_count()), "a trackpad click on the left half steps back, a click in the middle does nothing")
	rig.call("_on_left_hand_button_pressed", String(Types.XR_ACTION_MENU_BUTTON))
	await _frames(30)
	_check(get_tree().paused and UI.has_open_popup(), "controller menu button pauses")
	rig.call("_on_right_hand_button_pressed", String(Types.XR_ACTION_SECONDARY_BUTTON))
	_check(await _wait_until(func() -> bool: return level.is_playing() and not get_tree().paused), "controller menu button resumes")

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

	level.lose()
	_check(await _wait_until(func() -> bool: return UI.has_open_popup() and level.phase == LevelBase.Phase.FINISHED), "xr level shows results")
	await _frames(30)
	UI.close_top_popup()
	_check(await _wait_until(func() -> bool: return not (get_tree().current_scene is LevelBase) and not SceneManager.is_transitioning), "left xr level to menu")
	await _frames(5)


## Spawns an attacker and moves it into a chosen lane and depth.
func _spawn_in_lane(board: LaneBoard, enemy_scene: PackedScene, lane: int, z: float) -> LaneEnemy:
	var enemy: LaneEnemy = board.spawn_enemy(enemy_scene)
	enemy.enter_lane(board, lane)
	enemy.global_position.x = board.grid.get_lane_x(lane)
	enemy.global_position.z = z
	return enemy


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
