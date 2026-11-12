## Base class for every playable level. A level is a 3D place the player
## stands in: LevelBase owns the XRPlayerRig (headset and controllers, or the
## flat simulator without one), an in-world Announcer and the level flow
## through a StateChart (Intro -> Playing <-> Paused -> Won | Lost): score,
## time limit, pause menu, results, rewards, progress saving and analytics.
##
## Make a new level: create an inherited scene from LevelBase.tscn, attach a
## script that `extends LevelBase`, build the stage under World, move
## World/XRPlayerRig to where the player stands and override the virtual hooks
## below. Call win() / lose() / add_score() / announce().
##
## There is no screen-space HUD: a headset can't see one. Show status on
## in-world UI (a WorldScreen or a Label3D); popups reach the player through
## the rig's in-world popup screen.
##
## Dependencies: Events, Profile, SceneManager, UI, Ads, Global, Types autoloads,
##               XRPlayerRig, godot_state_charts addon
class_name LevelBase
extends Node3D

signal score_changed(new_score: int)

enum Phase { INTRO, PLAYING, PAUSED, FINISHED }

const PAUSE_POPUP: PackedScene = preload("res://Scenes/UI/Popups/PausePopup/PausePopup.tscn")
const RESULTS_POPUP: PackedScene = preload("res://Scenes/UI/Popups/ResultsPopup/ResultsPopup.tscn")
const AD_PLACEMENT_LEVEL_END: StringName = &"level_end"
## Seconds the announcer text takes to pop in and to fade out.
const ANNOUNCE_POP_SECONDS: float = 0.25
## Announcer scale at the start of its pop-in.
const ANNOUNCE_START_SCALE: float = 0.4
## Opacity of the announcer's outline (keeps the text readable over the world).
const ANNOUNCE_OUTLINE_ALPHA: float = 0.9

## Level definition (set by LevelSelect / Boot through scene params, or in the inspector for F6 testing).
@export var level_data: LevelData
## "Ready?" / "Go!" on the announcer before play starts.
@export var show_intro_countdown: bool = true
## 0 = no limit. When it runs out _on_time_limit_reached() is called (default: lose).
@export var time_limit_seconds: float = 0.0
## Pause when the app goes to the background, the window loses focus or the
## headset is taken off. Unattended tools (screenshots) turn it off.
@export var pause_when_app_paused: bool = true

var score: int = 0
var elapsed_seconds: float = 0.0
var phase: Phase = Phase.INTRO

var _has_started: bool = false
var _announce_tween: Tween

@onready var world: Node3D = %World
@onready var rig: XRPlayerRig = %XRPlayerRig
@onready var announcer: Label3D = %Announcer
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
	announcer.hide()
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
	score_changed.emit(score)
	Events.score_changed.emit(score, score_delta)


## Seconds left of the time limit (INF when the level has none).
func get_remaining_seconds() -> float:
	if time_limit_seconds <= 0.0:
		return INF
	return maxf(0.0, time_limit_seconds - elapsed_seconds)


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


## Leaves the level. Inside a headset the 2D menus can't be seen, so
## SceneManager sends the player to the XR start level (a new run) instead.
func quit_to_menu() -> void:
	if not SceneManager.go_back():
		SceneManager.go_to_main_menu()


func go_to_next_level() -> void:
	var next_level: LevelData = GameConfig.get_default().get_next_level(get_level_id())
	if next_level == null or not start_level(next_level, false):
		quit_to_menu()


## Back button / Esc: pause instead of leaving the level.
func handle_back() -> bool:
	pause_level()
	return true


## Big text in the world ("Wave 2", "Breach!") on the Announcer, which the
## level places where the player is looking. Pops in, holds, fades out.
func announce(message: String, color: Color = Palette.TEXT, hold_seconds: float = 1.0) -> void:
	if _announce_tween != null:
		_announce_tween.kill()
	announcer.text = message
	announcer.modulate = color
	announcer.outline_modulate = Color(Palette.BACKGROUND, ANNOUNCE_OUTLINE_ALPHA)
	announcer.scale = Vector3.ONE * ANNOUNCE_START_SCALE
	announcer.show()
	_announce_tween = create_tween()
	_announce_tween.tween_property(announcer, "scale", Vector3.ONE, ANNOUNCE_POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_announce_tween.tween_interval(hold_seconds)
	# Text and outline fade together, as one step after the hold.
	_announce_tween.tween_property(announcer, "modulate:a", 0.0, ANNOUNCE_POP_SECONDS)
	_announce_tween.parallel().tween_property(announcer, "outline_modulate:a", 0.0, ANNOUNCE_POP_SECONDS)
	_announce_tween.tween_callback(announcer.hide)

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
		announce(tr("Ready?"), Palette.TEXT, 0.3)
		await Global.wait(0.9)
		announce(tr("Go!"), Palette.TEXT, 0.1)
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
	if time_limit_seconds > 0.0 and elapsed_seconds >= time_limit_seconds:
		_on_time_limit_reached()
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

# ============================================
# PLAYER INPUT (connected in LevelBase.tscn)
# ============================================

## Controller menu or B / Y button: toggles the pause menu.
func _on_rig_menu_pressed() -> void:
	if phase == Phase.PAUSED:
		UI.close_top_popup()
	else:
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
	if pause_when_app_paused:
		pause_level()
