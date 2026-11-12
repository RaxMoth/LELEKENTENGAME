## Base class for every playable level / game mode. Owns the level flow
## through a StateChart (Intro -> Playing <-> Paused -> Won | Lost), score,
## timer, HUD, pause menu, results, rewards, progress saving and analytics.
##
## Make a new level: create an inherited scene from LevelBase.tscn, attach a
## script that `extends LevelBase`, put gameplay nodes under World and
## override the virtual hooks below. Call win() / lose() / add_score().
##
## Dependencies: Events, Profile, SceneManager, UI, Ads, Global, Types autoloads,
##               godot_state_charts addon
class_name LevelBase
extends Node2D

signal score_changed(new_score: int)

enum Phase { INTRO, PLAYING, PAUSED, FINISHED }

const PAUSE_POPUP: PackedScene = preload("res://Scenes/UI/Popups/PausePopup/PausePopup.tscn")
const RESULTS_POPUP: PackedScene = preload("res://Scenes/UI/Popups/ResultsPopup/ResultsPopup.tscn")
const AD_PLACEMENT_LEVEL_END: StringName = &"level_end"

## Level definition (set by LevelSelect through scene params, or in the inspector for F6 testing).
@export var level_data: LevelData
@export var show_intro_countdown: bool = true
## 0 = no limit. When it runs out _on_time_limit_reached() is called (default: lose).
@export var time_limit_seconds: float = 0.0
@export var show_elapsed_time: bool = false
@export var show_score: bool = true

var score: int = 0
var elapsed_seconds: float = 0.0
var phase: Phase = Phase.INTRO

var _has_started: bool = false

@onready var world: Node2D = %World
@onready var camera: GameCamera = %GameCamera
@onready var hud: GameHUD = %HUD
@onready var state_chart: StateChart = %StateChart


## Called by SceneManager before the scene enters the tree.
func receive_scene_params(params: Dictionary) -> void:
	var passed_level: LevelData = params.get(Types.PARAM_LEVEL_DATA) as LevelData
	if passed_level != null:
		level_data = passed_level


## Starts a level from anywhere (level select, "next level"), consuming energy if enabled.
static func start_level(level: LevelData, add_to_history: bool = true) -> bool:
	if not Profile.energy.consume(level.energy_cost):
		UI.toast(TranslationServer.translate("Not enough energy"))
		return false
	SceneManager.change_scene(level.scene_path, {Types.PARAM_LEVEL_DATA: level}, add_to_history)
	return true


func _ready() -> void:
	Events.app_paused.connect(_on_app_paused)
	hud.set_score(0, false)
	hud.set_score_visible(show_score)
	if time_limit_seconds > 0.0:
		hud.set_timer(time_limit_seconds)
	_on_level_setup()

# ============================================
# PUBLIC API
# ============================================

func get_level_id() -> StringName:
	if level_data != null:
		return level_data.id
	return StringName(scene_file_path.get_file().get_basename())


func is_playing() -> bool:
	return phase == Phase.PLAYING


func add_score(points: int) -> void:
	set_score(score + points)


func set_score(new_score: int) -> void:
	var score_delta: int = maxi(0, new_score) - score
	score = maxi(0, new_score)
	hud.set_score(score)
	score_changed.emit(score)
	Events.score_changed.emit(score, score_delta)


func win() -> void:
	if phase == Phase.PLAYING:
		state_chart.send_event(Types.EVENT_WIN)


func lose() -> void:
	if phase == Phase.PLAYING:
		state_chart.send_event(Types.EVENT_LOSE)


## Ends an endless run (counts as completed, stars come from score).
func end_run() -> void:
	lose()


func pause_level() -> void:
	if phase == Phase.PLAYING:
		state_chart.send_event(Types.EVENT_PAUSE)


func resume_level() -> void:
	if phase == Phase.PAUSED:
		state_chart.send_event(Types.EVENT_RESUME)


func restart_level() -> void:
	SceneManager.reload_current_scene()


func quit_to_menu() -> void:
	if not SceneManager.go_back():
		SceneManager.go_to_main_menu()


func go_to_next_level() -> void:
	var next_level: LevelData = GameConfig.get_default().get_next_level(get_level_id())
	if next_level == null or not start_level(next_level, false):
		quit_to_menu()


## Back button: pause instead of leaving the level.
func handle_back() -> bool:
	pause_level()
	return true

# ============================================
# VIRTUAL HOOKS
# ============================================

## @virtual Build / configure the level. Runs in _ready, before the intro.
func _on_level_setup() -> void:
	pass


## @virtual Gameplay begins (after the intro countdown).
func _on_level_started() -> void:
	pass


## @virtual Per-frame logic, only while playing.
func _level_process(_delta: float) -> void:
	pass


## @virtual Per-physics-frame logic, only while playing.
func _level_physics_process(_delta: float) -> void:
	pass


## @virtual Default: running out of time loses the level.
func _on_time_limit_reached() -> void:
	lose()


## @virtual Stars for a finished attempt.
func _calculate_stars(result: LevelResult) -> int:
	if not result.counts_as_completed():
		return 0
	if level_data == null:
		return 3 if result.is_won() else 0
	return maxi(1 if result.is_won() else 0, level_data.get_stars_for_score(result.score))


## @virtual Rewards for a finished attempt (granted automatically).
func _calculate_rewards(result: LevelResult) -> Dictionary[StringName, int]:
	var rewards: Dictionary[StringName, int] = {}
	if level_data != null and result.counts_as_completed():
		rewards = level_data.completion_rewards.duplicate()
	return rewards


## @virtual Called after the result was recorded, before the results popup.
func _on_level_finished(_result: LevelResult) -> void:
	pass

# ============================================
# STATE CHART CALLBACKS (connected in LevelBase.tscn)
# ============================================

func _on_intro_state_entered() -> void:
	phase = Phase.INTRO
	if show_intro_countdown:
		hud.show_message(tr("Ready?"), 0.8)
		await Global.wait(0.9)
		hud.show_message(tr("Go!"), 0.6)
	state_chart.send_event(Types.EVENT_LEVEL_START)


func _on_playing_state_entered() -> void:
	phase = Phase.PLAYING
	get_tree().paused = false
	if _has_started:
		Events.level_paused.emit(false)
		return
	_has_started = true
	Profile.stats.increment(Types.STAT_LEVELS_PLAYED)
	Events.level_started.emit(get_level_id())
	_on_level_started()


func _on_playing_state_processing(delta: float) -> void:
	elapsed_seconds += delta
	if time_limit_seconds > 0.0:
		var remaining_seconds: float = time_limit_seconds - elapsed_seconds
		hud.set_timer(maxf(0.0, remaining_seconds))
		if remaining_seconds <= 0.0:
			_on_time_limit_reached()
	elif show_elapsed_time:
		hud.set_timer(elapsed_seconds)
	_level_process(delta)


func _on_playing_state_physics_processing(delta: float) -> void:
	_level_physics_process(delta)


func _on_paused_state_entered() -> void:
	phase = Phase.PAUSED
	get_tree().paused = true
	Events.level_paused.emit(true)
	var choice: Variant = await UI.open_popup(PAUSE_POPUP).closed
	match choice:
		PausePopup.RESULT_RESTART:
			restart_level()
		PausePopup.RESULT_MAIN_MENU:
			quit_to_menu()
		_:
			resume_level()


func _on_won_state_entered() -> void:
	_finish(Types.LevelOutcome.WON)


func _on_lost_state_entered() -> void:
	_finish(Types.LevelOutcome.LOST)


func _on_hud_pause_pressed() -> void:
	pause_level()

# ============================================
# INTERNALS
# ============================================

func _finish(outcome: Types.LevelOutcome) -> void:
	phase = Phase.FINISHED
	var result: LevelResult = LevelResult.new()
	result.level_id = get_level_id()
	result.outcome = outcome
	result.score = score
	result.duration_seconds = elapsed_seconds
	result.is_endless = level_data != null and level_data.is_endless
	result.stars = _calculate_stars(result)
	result.rewards = _calculate_rewards(result)
	if level_data != null and result.counts_as_completed() and not Profile.levels.is_completed(result.level_id):
		for reward_id: StringName in level_data.first_clear_rewards:
			result.rewards[reward_id] = result.rewards.get(reward_id, 0) + level_data.first_clear_rewards[reward_id]
	result.is_new_best = Profile.levels.record_result(result)
	Profile.grant_rewards(result.rewards)
	if result.is_won():
		Profile.stats.increment(Types.STAT_LEVELS_WON)
	Events.level_finished.emit(result)
	_on_level_finished(result)
	await Global.wait(0.7, false)
	await Ads.maybe_show_interstitial(AD_PLACEMENT_LEVEL_END)
	var has_next_level: bool = GameConfig.get_default().get_next_level(result.level_id) != null
	var choice: Variant = await UI.open_popup(RESULTS_POPUP, {"result": result, "has_next_level": has_next_level}).closed
	match choice:
		ResultsPopup.RESULT_NEXT:
			go_to_next_level()
		ResultsPopup.RESULT_RETRY:
			restart_level()
		_:
			quit_to_menu()


func _on_app_paused() -> void:
	pause_level()
