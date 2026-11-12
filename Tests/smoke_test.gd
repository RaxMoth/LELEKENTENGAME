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
class_name SmokeTest
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
	await frames(10)
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
	check(SaveManager.save_now(), "save_now succeeded")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	var saved_cash: int = int(saved["sections"]["wallet"]["cash"]) if saved is Dictionary else -1
	var saved_reputation: int = int(saved["sections"]["operation"]["reputation"]) if saved is Dictionary else -1
	check(saved_cash == expected_cash, "wallet persisted (%d == %d)" % [saved_cash, expected_cash])
	check(saved_reputation == 7, "operation progress persisted")
	check(not Profile.wallet.spend(Types.CURRENCY_CASH, 999999999), "cannot overspend")


func _test_menus() -> void:
	var config: GameConfig = GameConfig.get_default()
	for scene_path: String in [config.main_menu_scene, config.level_select_scene, config.shop_scene]:
		SceneManager.change_scene(scene_path)
		check(await _wait_for_scene(scene_path), "menu loads: " + scene_path)
	check(SceneManager.go_back(), "back stack works")
	await _wait_for_transition()


func _test_popups() -> void:
	var popup_paths: PackedStringArray = [
		"res://Scenes/UI/Popups/SettingsPopup/SettingsPopup.tscn",
		"res://Scenes/UI/Popups/AchievementsPopup/AchievementsPopup.tscn",
		"res://Scenes/UI/Popups/PausePopup/PausePopup.tscn",
	]
	for popup_path: String in popup_paths:
		UI.open_popup(load(popup_path) as PackedScene)
		await frames(20)
		check(UI.has_open_popup(), "popup opens: " + popup_path.get_file())
		UI.close_top_popup()
		await frames(30)
		check(not UI.has_open_popup(), "popup closes: " + popup_path.get_file())
	var reward_popup: BasePopup = UI.open_popup(load("res://Scenes/UI/Popups/RewardPopup/RewardPopup.tscn") as PackedScene, {"title": "Test", "rewards": {Types.CURRENCY_CASH: 5}})
	await frames(20)
	reward_popup.close(1)
	await frames(30)
	check(not UI.has_open_popup(), "reward popup closes")
	var confirm_task: Array[bool] = [false]
	var confirm_coroutine: Callable = func() -> void: confirm_task[0] = await UI.confirm("Test", "Message")
	confirm_coroutine.call()
	await frames(20)
	UI.close_top_popup()
	await frames(30)
	check(not UI.has_open_popup(), "confirm dialog closes via back")


func _test_level(level: LevelData, force_win: bool) -> void:
	var attempts_before: int = Profile.levels.get_attempts(level.id)
	LevelBase.start_level(level)
	if not await _wait_for_scene(level.scene_path):
		check(false, "level loads: " + level.id)
		return
	var active_level: LevelBase = get_tree().current_scene as LevelBase
	check(active_level != null and active_level.level_data == level, "level receives its LevelData: " + level.id)
	check(await wait_until(func() -> bool: return active_level.phase == LevelBase.Phase.PLAYING), "intro finishes: " + level.id)
	await frames(180)
	if active_level.phase == LevelBase.Phase.PLAYING:
		active_level.pause_level()
		await frames(20)
		check(get_tree().paused and UI.has_open_popup(), "pause opens menu: " + level.id)
		UI.close_top_popup()
		check(await wait_until(func() -> bool: return active_level.phase == LevelBase.Phase.PLAYING), "resume works: " + level.id)
		await frames(60)
		if force_win and not level.is_endless:
			active_level.win()
		else:
			active_level.lose()
	check(await wait_until(func() -> bool: return UI.has_open_popup() and active_level.phase == LevelBase.Phase.FINISHED), "results popup shows: " + level.id)
	check(Profile.levels.get_attempts(level.id) == attempts_before + 1, "attempt recorded: " + level.id)
	await frames(30)
	UI.close_top_popup()
	check(await wait_until(func() -> bool: return not (get_tree().current_scene is LevelBase) and not SceneManager.is_transitioning), "left level to menu: " + level.id)
	await frames(5)


## Plays a whole shift at the house through the pointer paths a headset uses
## (in the flat simulator). Each area keeps its own checks in Tests/Smoke/,
## so the developers of different areas never edit the same test file.
func _test_house(level_data: LevelData) -> void:
	if level_data == null:
		return
	LevelBase.start_level(level_data)
	if not await _wait_for_scene(level_data.scene_path):
		check(false, "house loads")
		return
	var level: HouseLevel = get_tree().current_scene as HouseLevel
	check(await wait_until(func() -> bool: return level.is_playing()), "house starts playing")
	# Keep customers and attackers from arriving on their own; the checks decide.
	(level.get_front(SalesWindow) as SalesWindow).flow.is_active = false
	(level.get_front(FrontGarden) as FrontGarden).director.is_active = false
	Profile.wallet.add(Types.CURRENCY_CASH, 5000)
	await HouseSmokeChecks.run_start(self, level)
	await LabSmokeChecks.run(self, level)
	await SalesSmokeChecks.run(self, level)
	await DefenseSmokeChecks.run(self, level)
	await HouseSmokeChecks.run_end(self, level)
	check(await wait_until(func() -> bool: return not (get_tree().current_scene is LevelBase) and not SceneManager.is_transitioning), "left the house to the menu")
	await frames(5)

# ============================================
# HELPERS FOR THE AREA CHECKS (Tests/Smoke/*.gd)
# ============================================

func check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  ok   " + description)
	else:
		print("  FAIL " + description)
		_failures.append(description)


func frames(count: int) -> void:
	for frame_index: int in count:
		await get_tree().process_frame


func physics_frames(count: int) -> void:
	for frame_index: int in count:
		await get_tree().physics_frame


func wait_until(condition: Callable) -> bool:
	var deadline_msec: int = Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline_msec:
		if condition.call():
			return true
		await get_tree().process_frame
	return condition.call()


func _wait_for_scene(scene_path: String) -> bool:
	var loaded: bool = await wait_until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == scene_path and not SceneManager.is_transitioning)
	await frames(5)
	return loaded


func _wait_for_transition() -> void:
	await frames(5)
	await wait_until(func() -> bool: return not SceneManager.is_transitioning)
	await frames(5)
