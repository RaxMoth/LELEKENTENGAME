## Settings dialog reachable from the main menu and the pause menu (inside a
## headset it shows on the in-world popup screen). Every control writes
## straight into the Settings autoload.
##
## Dependencies: Settings, Platform, Profile, SceneManager, UI autoloads
class_name SettingsPopup
extends BasePopup

const LOCALE_OPTIONS: PackedStringArray = ["", "en", "de"]

@onready var _master_slider: HSlider = %MasterSlider
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _haptics_toggle: CheckButton = %HapticsToggle
@onready var _smooth_move_toggle: CheckButton = %SmoothMoveToggle
@onready var _smooth_turn_toggle: CheckButton = %SmoothTurnToggle
@onready var _standing_view_toggle: CheckButton = %StandingViewToggle
@onready var _fresh_start_toggle: CheckButton = %FreshStartToggle
@onready var _fps_toggle: CheckButton = %FpsToggle
@onready var _language_option: OptionButton = %LanguageOption
@onready var _privacy_button: Button = %PrivacyButton


func _on_opened(_data: Dictionary) -> void:
	_master_slider.value = Settings.get_float(Settings.KEY_MASTER_VOLUME)
	_music_slider.value = Settings.get_float(Settings.KEY_MUSIC_VOLUME)
	_sfx_slider.value = Settings.get_float(Settings.KEY_SFX_VOLUME)
	_haptics_toggle.button_pressed = Settings.get_bool(Settings.KEY_HAPTICS_ENABLED)
	_smooth_move_toggle.button_pressed = Settings.get_bool(Settings.KEY_SMOOTH_MOVEMENT)
	_smooth_turn_toggle.button_pressed = Settings.get_bool(Settings.KEY_SMOOTH_TURNING)
	_standing_view_toggle.button_pressed = Settings.get_bool(Settings.KEY_STANDING_VIEW)
	# A development switch: exported release builds always load the save.
	_fresh_start_toggle.visible = OS.is_debug_build()
	_fresh_start_toggle.button_pressed = Settings.get_bool(Settings.KEY_FRESH_START_IN_DEV)
	_fps_toggle.button_pressed = Settings.get_bool(Settings.KEY_SHOW_FPS)
	_language_option.clear()
	_language_option.add_item(tr("System"))
	_language_option.add_item("English")
	_language_option.add_item("Deutsch")
	_language_option.selected = maxi(0, LOCALE_OPTIONS.find(str(Settings.get_value(Settings.KEY_LOCALE))))
	_privacy_button.visible = not GameConfig.get_default().privacy_policy_url.is_empty()
	# Connect after initializing so setting the initial values doesn't write back.
	_master_slider.value_changed.connect(func(value: float) -> void: Settings.set_value(Settings.KEY_MASTER_VOLUME, value))
	_music_slider.value_changed.connect(func(value: float) -> void: Settings.set_value(Settings.KEY_MUSIC_VOLUME, value))
	_sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	_haptics_toggle.toggled.connect(func(enabled: bool) -> void: Settings.set_value(Settings.KEY_HAPTICS_ENABLED, enabled))
	_smooth_move_toggle.toggled.connect(func(enabled: bool) -> void: Settings.set_value(Settings.KEY_SMOOTH_MOVEMENT, enabled))
	_smooth_turn_toggle.toggled.connect(func(enabled: bool) -> void: Settings.set_value(Settings.KEY_SMOOTH_TURNING, enabled))
	_standing_view_toggle.toggled.connect(func(enabled: bool) -> void: Settings.set_value(Settings.KEY_STANDING_VIEW, enabled))
	_fresh_start_toggle.toggled.connect(func(enabled: bool) -> void: Settings.set_value(Settings.KEY_FRESH_START_IN_DEV, enabled))
	_fps_toggle.toggled.connect(func(enabled: bool) -> void: Settings.set_value(Settings.KEY_SHOW_FPS, enabled))
	_language_option.item_selected.connect(func(index: int) -> void: Settings.set_value(Settings.KEY_LOCALE, LOCALE_OPTIONS[index]))


func _on_sfx_slider_changed(value: float) -> void:
	Settings.set_value(Settings.KEY_SFX_VOLUME, value)
	Audio.play_ui(Audio.UI_CLICK)


func _on_privacy_button_pressed() -> void:
	Platform.open_privacy_policy()


func _on_reset_button_pressed() -> void:
	if await UI.confirm(tr("Reset Progress"), tr("Reset all progress? This cannot be undone."), tr("Confirm"), tr("Cancel")):
		Profile.reset_progress()
		close(null)
		SceneManager.go_to_main_menu()


func _on_close_button_pressed() -> void:
	close(null)
