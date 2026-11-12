## Pause menu shown by LevelBase. Result is one of the RESULT_* constants.
##
## Dependencies: BasePopup, UI autoload
class_name PausePopup
extends BasePopup

const RESULT_RESUME: StringName = &"resume"
const RESULT_RESTART: StringName = &"restart"
const RESULT_MAIN_MENU: StringName = &"main_menu"
const SETTINGS_POPUP: PackedScene = preload("res://Scenes/UI/Popups/SettingsPopup/SettingsPopup.tscn")


func handle_back() -> void:
	close(RESULT_RESUME)


func _on_resume_button_pressed() -> void:
	close(RESULT_RESUME)


func _on_restart_button_pressed() -> void:
	close(RESULT_RESTART)


func _on_settings_button_pressed() -> void:
	UI.open_popup(SETTINGS_POPUP)


func _on_menu_button_pressed() -> void:
	close(RESULT_MAIN_MENU)
