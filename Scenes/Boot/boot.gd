## First scene: shows the splash while autoloads finish booting (settings,
## savegame, profile), then starts the game. With a headset that is the XR
## start level right away (the 2D menus can't be seen inside a headset);
## without one it is the main menu, and the level runs in the flat simulator.
## Add first-launch work here (consent dialogs, tutorial routing, SDK init).
##
## Dependencies: SceneManager, Platform, UI autoloads, LevelBase
extends Control

@onready var _title_label: Label = %TitleLabel
@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	var config: GameConfig = GameConfig.get_default()
	_title_label.text = config.game_title
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.1.0")
	TweenFX.bounce_in(_title_label, 0.5)
	var xr_level: LevelData = config.get_xr_start_level()
	if Platform.is_xr_active() and xr_level != null:
		LevelBase.start_level(xr_level, false)
		return
	if _is_headset_missing(config):
		UI.toast(tr("No VR headset found. Playing on the flat screen."))
	await get_tree().create_timer(config.boot_splash_seconds).timeout
	SceneManager.change_scene(config.main_menu_scene, {}, false)


## True when this build expects a headset (OpenXR is enabled for the platform
## and an XR level is configured) but no session started, e.g. SteamVR is
## not the active OpenXR runtime. The game then runs its flat-screen flow.
func _is_headset_missing(config: GameConfig) -> bool:
	return bool(ProjectSettings.get_setting_with_override(&"xr/openxr/enabled")) and config.get_xr_start_level() != null
