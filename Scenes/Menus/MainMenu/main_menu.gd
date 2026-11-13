## Main menu (flat-screen flow, shown when no headset is active): play —
## straight into the house, the game's one world, on the day you're on —
## play together (host or join a friend, CoopPopup), shop, achievements,
## daily reward and settings.
##
## Dependencies: Profile, SceneManager, UI, Platform, Audio autoloads, LevelBase
extends Control

const SETTINGS_POPUP: PackedScene = preload("res://Scenes/UI/Popups/SettingsPopup/SettingsPopup.tscn")
const ACHIEVEMENTS_POPUP: PackedScene = preload("res://Scenes/UI/Popups/AchievementsPopup/AchievementsPopup.tscn")
const REWARD_POPUP: PackedScene = preload("res://Scenes/UI/Popups/RewardPopup/RewardPopup.tscn")
const COOP_POPUP: PackedScene = preload("res://Scenes/UI/Popups/CoopPopup/CoopPopup.tscn")

@onready var _title_label: Label = %TitleLabel
@onready var _day_progress: IconLabel = %DayProgress
@onready var _daily_button: Button = %DailyRewardButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	var config: GameConfig = GameConfig.get_default()
	_title_label.text = config.game_title
	_day_progress.text = tr("Day %d") % Profile.operation.day_number
	_quit_button.visible = Platform.can_quit_app()
	_refresh_daily_button()


func _refresh_daily_button() -> void:
	var can_claim: bool = Profile.daily_rewards.can_claim()
	_daily_button.visible = not GameConfig.get_default().daily_rewards.is_empty()
	_daily_button.disabled = not can_claim
	_daily_button.text = tr("Daily Reward") if can_claim else tr("Come back tomorrow!")
	_daily_button.theme_type_variation = &"SuccessButton" if can_claim else &"SecondaryButton"


func _on_play_button_pressed() -> void:
	var house: LevelData = GameConfig.get_default().get_xr_start_level()
	if house != null:
		LevelBase.start_level(house)


## Host a game (it starts the house) or join one on the same Wi-Fi.
func _on_play_together_button_pressed() -> void:
	UI.open_popup(COOP_POPUP)


func _on_shop_button_pressed() -> void:
	SceneManager.change_scene(GameConfig.get_default().shop_scene)


func _on_achievements_button_pressed() -> void:
	UI.open_popup(ACHIEVEMENTS_POPUP)


func _on_settings_button_pressed() -> void:
	UI.open_popup(SETTINGS_POPUP)


func _on_daily_reward_button_pressed() -> void:
	var reward_index: int = Profile.daily_rewards.get_next_reward_index()
	if reward_index < 0:
		return
	var bundle: RewardBundle = GameConfig.get_default().daily_rewards[reward_index]
	var popup: BasePopup = UI.open_popup(REWARD_POPUP, {
		"title": tr("Daily Reward"),
		"subtitle": tr("Day %d") % (reward_index + 1),
		"rewards": bundle.rewards,
		"allow_double": true,
	})
	var multiplier: int = await popup.closed
	var granted: Dictionary[StringName, int] = Profile.daily_rewards.claim()
	for extra_claim: int in multiplier - 1:
		Profile.grant_rewards(granted)
	_refresh_daily_button()


func _on_quit_button_pressed() -> void:
	if await UI.confirm(tr("Quit the game?"), "", tr("Quit"), tr("Cancel")):
		get_tree().quit()
