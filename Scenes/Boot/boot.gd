## First scene: shows the splash while autoloads finish booting (settings,
## savegame, profile), then routes to the main menu — or straight into the
## XR level when a headset is active, where the 2D menus could not be seen.
## Add first-launch work here (consent dialogs, tutorial routing, SDK init).
##
## Dependencies: SceneManager, Profile, UI, Types autoloads, LevelBase
extends Control

@onready var _title_label: Label = %TitleLabel
@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	var config: GameConfig = GameConfig.get_default()
	_title_label.text = config.game_title
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.1.0")
	TweenFX.bounce_in(_title_label, 0.5)
	var xr_level: LevelData = _get_xr_start_level(config)
	if xr_level != null:
		LevelBase.start_level(xr_level, false)
		return
	if _is_headset_missing(config):
		UI.toast(tr("No VR headset found. Playing on the flat screen."))
	await get_tree().create_timer(config.boot_splash_seconds).timeout
	SceneManager.change_scene(config.main_menu_scene, {}, false)


## True when this build expects a headset (OpenXR is enabled for the platform
## and an XR level is configured) but no session started, e.g. SteamVR is
## not the active OpenXR runtime. The game then runs its normal 2D flow.
func _is_headset_missing(config: GameConfig) -> bool:
	return bool(ProjectSettings.get_setting_with_override(&"xr/openxr/enabled")) and not config.xr_start_level_id.is_empty()


## The configured XR level when a headset session is running, otherwise null.
func _get_xr_start_level(config: GameConfig) -> LevelData:
	var xr_interface: XRInterface = XRServer.find_interface(Types.XR_INTERFACE_OPENXR)
	if xr_interface == null or not xr_interface.is_initialized() or config.xr_start_level_id.is_empty():
		return null
	return config.find_level(config.xr_start_level_id)
