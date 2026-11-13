## Automated smoke test. Boots the menus, opens every popup, checks the
## savegame round-trip, plays a whole shift at the house through the pointer
## paths a headset uses (craft, sell, defend, upgrade, crew, night, losing
## the door) and a raid night start to finish. Exit code 0 = all good.
##
## Two scopes: `core` (pull requests, Tools/test.sh) plays the core of every
## area — the lab, the window, the defense, the house and the raid; `full`
## (pushes to main, Tools/test.sh full) adds the extras: the cellar, the
## town's streets and the towers. Each section's time is printed at the end.
##
## Run from the project folder:
##   godot --headless --fixed-fps 60 res://Tests/SmokeTest.tscn -- scope=core
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
const ARGUMENT_FULL: String = "scope=full"

## The extras run too (cellar, town, towers): pushes to main.
var is_full: bool = false

var _failures: PackedStringArray = []
var _checks: int = 0
## Section name -> milliseconds it took (printed at the end).
var _section_msec: Dictionary[String, int] = {}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# Detach from get_tree().current_scene so SceneManager can swap scenes without freeing the test.
	get_tree().current_scene = null
	await frames(10)
	# The checks expect default comfort settings (snap turning, stick walking);
	# the developer's own preferences come back at the end.
	var saved_settings: Dictionary[StringName, Variant] = {}
	for setting_key: StringName in Settings.DEFAULTS:
		saved_settings[setting_key] = Settings.get_value(setting_key)
	Settings.reset_to_defaults()
	Profile.reset_progress()
	is_full = ARGUMENT_FULL in OS.get_cmdline_user_args()
	var config: GameConfig = GameConfig.get_default()
	await run_section("save", _test_save_roundtrip)
	await run_section("menus", _test_menus)
	await run_section("popups", _test_popups)
	await _test_house(config.find_level(HOUSE_LEVEL_ID))
	await run_section("raid night", _test_house_raid.bind(config.find_level(HOUSE_LEVEL_ID)))
	var timings: PackedStringArray = []
	for section: String in _section_msec:
		timings.append("%s %.1f s" % [section, _section_msec[section] / 1000.0])
	print("  time " + ", ".join(timings))
	print("\n==== SMOKE TEST (%s): %d checks, %d failures ====" % ["full" if is_full else "core", _checks, _failures.size()])
	for failure: String in _failures:
		print("  FAIL: " + failure)
	Profile.reset_progress()
	for setting_key: StringName in saved_settings:
		Settings.set_value(setting_key, saved_settings[setting_key])
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _test_save_roundtrip() -> void:
	Profile.wallet.add(Types.CURRENCY_CASH, 123)
	Profile.operation.add_reputation(7)
	var expected_cash: int = Profile.wallet.get_amount(Types.CURRENCY_CASH)
	check(SaveManager.save_now(), "save_now succeeded")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	var saved_cash: int = int(saved["sections"]["wallet"]["cash"]) if saved is Dictionary else -1
	var saved_operation: Dictionary = saved["sections"]["operation"] if saved is Dictionary else {}
	var saved_reputation: int = int(saved_operation.get("reputation", -1))
	check(saved_cash == expected_cash, "wallet persisted (%d == %d)" % [saved_cash, expected_cash])
	check(saved_reputation == 7, "operation progress persisted")
	check(not Profile.wallet.spend(Types.CURRENCY_CASH, 999999999), "cannot overspend")


func _test_menus() -> void:
	var config: GameConfig = GameConfig.get_default()
	for scene_path: String in [config.main_menu_scene, config.shop_scene]:
		SceneManager.change_scene(scene_path)
		check(await _wait_for_scene(scene_path), "menu loads: " + scene_path)
		if scene_path == config.main_menu_scene:
			await _check_play_together_button()
	check(SceneManager.go_back(), "back stack works")
	await _wait_for_transition()


## The main menu's Play Together opens host / join (CoopPopup).
func _check_play_together_button() -> void:
	var button: Button = get_tree().current_scene.find_child("PlayTogetherButton", true, false) as Button
	check(button != null and button.is_visible_in_tree(), "the main menu offers Play Together")
	if button == null:
		return
	button.pressed.emit()
	await frames(20)
	check(UI.has_open_popup() and UI.get_top_popup() is CoopPopup, "Play Together opens host / join")
	UI.close_top_popup()
	await frames(30)


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
	await run_section("house start", HouseSmokeChecks.run_start.bind(self, level))
	await run_section("lab", LabSmokeChecks.run.bind(self, level))
	if is_full:
		await run_section("cellar", CellarSmokeChecks.run.bind(self, level))
	await run_section("sales", SalesSmokeChecks.run.bind(self, level))
	if is_full:
		await run_section("town", TownSmokeChecks.run.bind(self, level))
	await run_section("defense", DefenseSmokeChecks.run.bind(self, level))
	if is_full:
		await run_section("towers", TowerSmokeChecks.run.bind(self, level))
	await run_section("house end", HouseSmokeChecks.run_end.bind(self, level))
	# run_end loses the shift (the door breaks): no day is counted as done.
	var lost_day: int = Profile.operation.day_number
	check(await _wait_for_next_day(level) and Profile.operation.day_number == lost_day, "a lost day starts over in the house")
	await _leave_to_menu()


## The raid night of a 3-day cycle, start to finish: night falls on day 3,
## the raid starts by itself, every wave is beaten, the shift is won and the
## next cycle begins at day 1 with the police heat gone.
func _test_house_raid(level_data: LevelData) -> void:
	if level_data == null:
		return
	Profile.operation.day_number = 3
	LevelBase.start_level(level_data)
	if not await _wait_for_scene(level_data.scene_path):
		check(false, "house loads for the raid")
		return
	var level: HouseLevel = get_tree().current_scene as HouseLevel
	check(await wait_until(func() -> bool: return level.is_playing()), "the raid day starts playing")
	(level.get_front(SalesWindow) as SalesWindow).flow.is_active = false
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	level.operation.add_heat(40.0)
	level.day_cycle.advance(level.day_cycle.day_seconds)
	check(await wait_until(func() -> bool: return level.cycle.is_raid_active()), "night falls on day 3 and the raid starts by itself")
	var clock_before: float = level.day_cycle.clock.elapsed_seconds
	await frames(30)
	check(is_equal_approx(level.day_cycle.clock.elapsed_seconds, clock_before), "the clock stops during the raid")
	for wave_number: int in range(1, level.cycle.get_wave_count() + 1):
		level.cycle.skip_wave_break()
		await wait_until(func() -> bool: return level.cycle.is_wave_active() and garden.director.get_pending_spawn_count() == 0)
		for raider: Raider in garden.yard.get_raiders().duplicate():
			raider.take_hit(1000000.0)
		await wait_until(func() -> bool: return not level.cycle.is_wave_active())
	check(await wait_until(func() -> bool: return level.cycle.phase == HouseCycle.Phase.CLEARED), "every wave beaten ends the raid")
	check(await wait_until(func() -> bool: return UI.has_open_popup() and level.phase == LevelBase.Phase.FINISHED), "a beaten raid wins the shift")
	check(Profile.operation.day_number == 4 and level.cycle.get_day_in_cycle() == 1, "the next cycle of selling begins at day 1")
	check(level.operation.heat.value == 0.0, "the police heat is gone after the raid")
	await frames(30)
	UI.close_top_popup()
	check(await _wait_for_next_day(level), "the morning after the raid starts in the house")
	await _leave_to_menu()

# ============================================
# HELPERS FOR THE AREA CHECKS (Tests/Smoke/*.gd)
# ============================================

## Runs one part of the test (an awaitable [param section]) and notes how
## long it took under [param label].
func run_section(label: String, section: Callable) -> void:
	var started_msec: int = Time.get_ticks_msec()
	await section.call()
	_section_msec[label] = Time.get_ticks_msec() - started_msec


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


## The house is the only world: after the day's summary it reloads as the
## next morning (or the same day after a loss) instead of leaving.
func _wait_for_next_day(previous_level: LevelBase) -> bool:
	# By id: the old level is freed during the reload, and a check may not hold on to it.
	var previous_id: int = previous_level.get_instance_id()
	var reloaded: bool = await wait_until(func() -> bool:
		var scene: LevelBase = get_tree().current_scene as LevelBase
		return scene != null and scene.get_instance_id() != previous_id and not SceneManager.is_transitioning)
	await frames(5)
	return reloaded


func _leave_to_menu() -> void:
	SceneManager.go_to_main_menu()
	check(await wait_until(func() -> bool: return not (get_tree().current_scene is LevelBase) and not SceneManager.is_transitioning), "back to the main menu")
	await frames(5)


func _wait_for_scene(scene_path: String) -> bool:
	var loaded: bool = await wait_until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == scene_path and not SceneManager.is_transitioning)
	await frames(5)
	return loaded


func _wait_for_transition() -> void:
	await frames(5)
	await wait_until(func() -> bool: return not SceneManager.is_transitioning)
	await frames(5)
