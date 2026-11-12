## Captures a screenshot of any scene after a delay — handy for checking
## layouts and for store screenshots. Must run with a window (not headless):
##   godot --path . --resolution 720x1280 res://Tests/ScreenshotTool.tscn -- scene=res://Scenes/Menus/MainMenu/MainMenu.tscn frames=90 out=/tmp/menu.png [popup=res://...tscn] [level=house] [showcase=house] [spot=2] [pause=1] [cursor=640,400]
##
## showcase=<name> runs Tests/Showcases/<name>_showcase.gd (static apply(scene))
## once the level is playing, to stage a mid-game moment. spot=N moves the
## player to the level's N-th travel spot (1-based). pause=1 opens the
## level's pause menu before the shot. cursor=x,y moves the mouse to that
## window pixel first (hover states, 3D pointer rays).
##
## Dependencies: SceneManager, UI, Events autoloads
extends Node

## Wall-clock limit for waiting on a level to start playing.
const PLAYING_TIMEOUT_MSEC: int = 30000


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().current_scene = null
	var arguments: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.split("=", true, 1)
		if parts.size() == 2:
			arguments[parts[0]] = parts[1]
	var scene_params: Dictionary = {}
	if arguments.has("level"):
		var level: LevelData = GameConfig.get_default().find_level(StringName(arguments["level"]))
		scene_params[Types.PARAM_LEVEL_DATA] = level
		arguments["scene"] = level.scene_path
	Events.scene_changed.connect(_on_scene_changed)
	SceneManager.change_scene(str(arguments.get("scene", GameConfig.get_default().main_menu_scene)), scene_params)
	for frame_index: int in 20:
		await get_tree().process_frame
	# A scene swap still running would close the popup again.
	while SceneManager.is_transitioning:
		await get_tree().process_frame
	if arguments.has("popup"):
		UI.open_popup(load(str(arguments["popup"])) as PackedScene)
	if arguments.has("showcase"):
		await _wait_until_playing()
		var showcase: Script = load("res://Tests/Showcases/%s_showcase.gd" % arguments["showcase"]) as Script
		showcase.call("apply", get_tree().current_scene)
	if arguments.has("spot"):
		var level: LevelBase = get_tree().current_scene as LevelBase
		if level != null:
			level.rig.locomotion.travel_to_spot(int(arguments["spot"]) - 1)
	# stand=x,z puts the player's feet there; look=x,y,z turns the view to a point.
	var shot_level: LevelBase = get_tree().current_scene as LevelBase
	if shot_level != null and arguments.has("stand"):
		var stand: PackedStringArray = str(arguments["stand"]).split(",")
		var feet: Vector3 = shot_level.rig.get_feet_position()
		shot_level.rig.move_origin_by(Vector3(float(stand[0]), feet.y, float(stand[1])) - feet)
	for frame_index: int in int(arguments.get("frames", "90")):
		await get_tree().process_frame
	if shot_level != null and arguments.has("look"):
		var look: PackedStringArray = str(arguments["look"]).split(",")
		shot_level.rig.aim_at_world_point(Vector3(float(look[0]), float(look[1]), float(look[2])))
		for frame_index: int in 10:
			await get_tree().process_frame
	if arguments.has("cursor"):
		var coordinates: PackedStringArray = str(arguments["cursor"]).split(",")
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = Vector2(float(coordinates[0]), float(coordinates[1]))
		motion.global_position = motion.position
		Input.parse_input_event(motion)
		for frame_index: int in 10:
			await get_tree().process_frame
	if arguments.has("pause"):
		(get_tree().current_scene as LevelBase).pause_level()
		for frame_index: int in 40:
			await get_tree().process_frame
	var output_path: String = str(arguments.get("out", "user://screenshot.png"))
	get_viewport().get_texture().get_image().save_png(output_path)
	print("Saved screenshot: " + output_path)
	get_tree().quit()


func _wait_until_playing() -> void:
	var level: LevelBase = get_tree().current_scene as LevelBase
	var deadline_msec: int = Time.get_ticks_msec() + PLAYING_TIMEOUT_MSEC
	while level != null and not level.is_playing():
		if Time.get_ticks_msec() > deadline_msec:
			push_warning("ScreenshotTool: level never started playing; capturing anyway.")
			return
		await get_tree().process_frame


## A capture window that opens behind other apps loses focus, which would
## pause the level like a phone going to the background.
func _on_scene_changed(_scene_path: String) -> void:
	var level: LevelBase = get_tree().current_scene as LevelBase
	if level != null:
		level.pause_when_app_paused = false
