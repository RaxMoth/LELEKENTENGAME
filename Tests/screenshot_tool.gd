## Captures a screenshot of any scene after a delay — handy for checking
## layouts and for store screenshots. Must run with a window (not headless):
##   godot --path . --resolution 720x1280 res://Tests/ScreenshotTool.tscn -- scene=res://Scenes/Menus/MainMenu/MainMenu.tscn frames=90 out=/tmp/menu.png [popup=res://...tscn] [level=survivor] [showcase=porchlight] [pause=1] [cursor=640,400]
##
## showcase=<name> runs Tests/Showcases/<name>_showcase.gd (static apply(scene))
## once the level is playing, to stage a mid-game moment. pause=1 opens the
## level's pause menu before the shot. cursor=x,y moves the mouse to that
## window pixel first (hover states, 3D pointer rays).
##
## Dependencies: SceneManager, UI autoloads
extends Node


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
	SceneManager.change_scene(str(arguments.get("scene", GameConfig.get_default().main_menu_scene)), scene_params)
	for frame_index: int in 20:
		await get_tree().process_frame
	if arguments.has("popup"):
		UI.open_popup(load(str(arguments["popup"])) as PackedScene)
	if arguments.has("showcase"):
		await _wait_until_playing()
		var showcase: Script = load("res://Tests/Showcases/%s_showcase.gd" % arguments["showcase"]) as Script
		showcase.call("apply", get_tree().current_scene)
	for frame_index: int in int(arguments.get("frames", "90")):
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
	while level != null and not level.is_playing():
		await get_tree().process_frame
