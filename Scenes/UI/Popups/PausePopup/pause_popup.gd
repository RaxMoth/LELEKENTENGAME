## Pause menu shown by LevelBase. Result is one of the RESULT_* constants.
## Inside a headset there is no 2D main menu to return to, so "Main Menu" is
## hidden there (Restart covers it). "Play Together" opens co-op; a guest
## in someone else's house can't restart it or leave to the menu from here
## (they leave the game in Play Together).
##
## Dependencies: BasePopup, UI, Platform, Coop autoloads
class_name PausePopup
extends BasePopup

const RESULT_RESUME: StringName = &"resume"
const RESULT_RESTART: StringName = &"restart"
const RESULT_MAIN_MENU: StringName = &"main_menu"
const SETTINGS_POPUP: PackedScene = preload("res://Scenes/UI/Popups/SettingsPopup/SettingsPopup.tscn")
const COOP_POPUP: PackedScene = preload("res://Scenes/UI/Popups/CoopPopup/CoopPopup.tscn")

@onready var _menu_button: Button = %MenuButton
@onready var _restart_button: Button = %RestartButton


func _on_opened(_data: Dictionary) -> void:
	_menu_button.visible = not Platform.is_xr_active() and not Coop.is_client()
	_restart_button.visible = not Coop.is_client()


func handle_back() -> void:
	close(RESULT_RESUME)


func _on_resume_button_pressed() -> void:
	close(RESULT_RESUME)


func _on_restart_button_pressed() -> void:
	close(RESULT_RESTART)


func _on_coop_button_pressed() -> void:
	UI.open_popup(COOP_POPUP)


func _on_settings_button_pressed() -> void:
	UI.open_popup(SETTINGS_POPUP)


func _on_menu_button_pressed() -> void:
	close(RESULT_MAIN_MENU)
