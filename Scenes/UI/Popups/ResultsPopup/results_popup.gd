## End-of-level summary: outcome, stars, score, rewards (+ optional rewarded-ad
## doubling) and navigation. Result is one of the RESULT_* constants.
##
## popup_data keys: result (LevelResult), has_next_level (bool)
##
## Dependencies: BasePopup, Ads, Profile, UI, Platform autoloads
class_name ResultsPopup
extends BasePopup

const RESULT_NEXT: StringName = &"next"
const RESULT_RETRY: StringName = &"retry"
const RESULT_MAIN_MENU: StringName = &"main_menu"
const AD_PLACEMENT_DOUBLE: StringName = &"double_level_rewards"

var _level_result: LevelResult

@onready var _title_label: Label = %TitleLabel
@onready var _stars_display: StarsDisplay = %StarsDisplay
@onready var _score_label: Label = %ScoreLabel
@onready var _best_label: Label = %BestLabel
@onready var _new_best_label: Label = %NewBestLabel
@onready var _reward_list: RewardList = %RewardList
@onready var _double_button: Button = %DoubleButton
@onready var _next_button: Button = %NextButton
@onready var _menu_button: Button = %MenuButton


func _on_opened(data: Dictionary) -> void:
	_level_result = data.get("result") as LevelResult
	if _level_result.is_won():
		_title_label.text = tr("Victory!")
	elif _level_result.is_endless:
		_title_label.text = tr("Run Over")
	else:
		_title_label.text = tr("Defeat")
	_stars_display.visible = _level_result.counts_as_completed()
	_stars_display.set_stars.call_deferred(_level_result.stars, true)
	_score_label.text = NumberFormat.with_separators(_level_result.score)
	_best_label.text = "%s: %s" % [tr("Best"), NumberFormat.with_separators(Profile.levels.get_best_score(_level_result.level_id))]
	_new_best_label.visible = _level_result.is_new_best and _level_result.score > 0
	if _new_best_label.visible:
		TweenFX.pulse_loop(_new_best_label)
	_reward_list.set_rewards(_level_result.rewards)
	_reward_list.visible = not _level_result.rewards.is_empty()
	_double_button.visible = not _level_result.rewards.is_empty() and Ads.is_rewarded_ready()
	_next_button.visible = _level_result.is_won() and bool(data.get("has_next_level", false))
	# Inside a headset the 2D main menu can't be seen; "Main Menu" would only restart.
	_menu_button.visible = not Platform.is_xr_active()


func handle_back() -> void:
	close(RESULT_MAIN_MENU)


func _on_double_button_pressed() -> void:
	_double_button.disabled = true
	if await Ads.show_rewarded(AD_PLACEMENT_DOUBLE):
		Profile.grant_rewards(_level_result.rewards)
		var doubled: Dictionary[StringName, int] = {}
		for reward_id: StringName in _level_result.rewards:
			doubled[reward_id] = _level_result.rewards[reward_id] * 2
		_reward_list.set_rewards(doubled)
		TweenFX.pop(_reward_list, 1.3)
		Audio.play_ui(Audio.UI_REWARD)
		_double_button.hide()
	else:
		_double_button.disabled = false


func _on_next_button_pressed() -> void:
	close(RESULT_NEXT)


func _on_retry_button_pressed() -> void:
	close(RESULT_RETRY)


func _on_menu_button_pressed() -> void:
	close(RESULT_MAIN_MENU)
