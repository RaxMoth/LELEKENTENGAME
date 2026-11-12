## Scene navigation with fade transitions, background (threaded) loading,
## parameter passing, a back stack and Android back-button routing.
##
##   SceneManager.change_scene(level.scene_path, {Types.PARAM_LEVEL_DATA: level})
##   SceneManager.go_back()
##   SceneManager.go_to_main_menu()
##
## The target scene receives params before entering the tree through an
## optional `receive_scene_params(params: Dictionary)` method.
##
## Back button order: top popup -> scene's handle_back() -> history -> quit dialog.
##
## Dependencies: Events, Pools, Platform, Types, UI autoloads
extends CanvasLayer

const FADE_SECONDS: float = 0.18
## Background loading keeps the fade animating while very large scenes load.
## Off by default: on Godot 4.7.2 a rare race in threaded loading (about 1 in
## 40 smoke-test runs) failed a dependency load and then crashed the engine.
## Loading behind the black fade is invisible to the player. If you enable it,
## a failed background load falls back to a normal load.
const USE_THREADED_LOADING: bool = false
const KEY_PATH: String = "path"
const KEY_PARAMS: String = "params"

var current_scene_path: String = ""
var current_params: Dictionary = {}
var is_transitioning: bool = false

var _history: Array[Dictionary] = []

@onready var _fade_rect: ColorRect = %FadeRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_rect.modulate.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.back_requested.connect(_on_back_requested)
	_capture_initial_scene.call_deferred()


func change_scene(scene_path: String, params: Dictionary = {}, add_to_history: bool = true) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	Events.scene_change_started.emit(scene_path)
	if USE_THREADED_LOADING:
		ResourceLoader.load_threaded_request(scene_path)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0)
	var packed_scene: PackedScene = await _wait_for_threaded_load(scene_path) if USE_THREADED_LOADING else load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("SceneManager: failed to load %s" % scene_path)
	else:
		if add_to_history and not current_scene_path.is_empty():
			_history.append({KEY_PATH: current_scene_path, KEY_PARAMS: current_params})
		_swap_scene(packed_scene, params)
		current_scene_path = scene_path
		current_params = params
		Events.scene_changed.emit(scene_path)
	await _fade_to(0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false


func reload_current_scene() -> void:
	change_scene(current_scene_path, current_params, false)


## Returns false when there is nothing to go back to.
func go_back() -> bool:
	if _history.is_empty() or is_transitioning:
		return false
	var previous_entry: Dictionary = _history.pop_back()
	change_scene(previous_entry[KEY_PATH], previous_entry[KEY_PARAMS], false)
	return true


## Returns to the main menu. Inside a headset the 2D menu can't be seen, so
## "home" is the XR start level (GameConfig.xr_start_level_id) instead.
func go_to_main_menu() -> void:
	_history.clear()
	var config: GameConfig = GameConfig.get_default()
	var xr_home_level: LevelData = config.get_xr_start_level()
	if Platform.is_xr_active() and xr_home_level != null:
		change_scene(xr_home_level.scene_path, {Types.PARAM_LEVEL_DATA: xr_home_level}, false)
		return
	change_scene(config.main_menu_scene, {}, false)


func clear_history() -> void:
	_history.clear()


func _swap_scene(packed_scene: PackedScene, params: Dictionary) -> void:
	var tree: SceneTree = get_tree()
	UI.close_all_popups()
	tree.paused = false
	var new_scene: Node = packed_scene.instantiate()
	if new_scene.has_method(Types.METHOD_RECEIVE_SCENE_PARAMS):
		new_scene.call(Types.METHOD_RECEIVE_SCENE_PARAMS, params)
	var old_scene: Node = tree.current_scene
	if old_scene != null:
		tree.root.remove_child(old_scene)
		old_scene.queue_free()
	Pools.clear_all()
	tree.root.add_child(new_scene)
	tree.current_scene = new_scene


func _wait_for_threaded_load(scene_path: String) -> PackedScene:
	while true:
		match ResourceLoader.load_threaded_get_status(scene_path):
			ResourceLoader.THREAD_LOAD_LOADED:
				return ResourceLoader.load_threaded_get(scene_path) as PackedScene
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_warning("SceneManager: background load of %s failed, loading normally" % scene_path)
				return load(scene_path) as PackedScene
		await get_tree().process_frame
	return null


func _fade_to(target_alpha: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "modulate:a", target_alpha, FADE_SECONDS)
	await tween.finished


func _capture_initial_scene() -> void:
	var initial_scene: Node = get_tree().current_scene
	if initial_scene != null:
		current_scene_path = initial_scene.scene_file_path


func _on_back_requested() -> void:
	if is_transitioning or UI.close_top_popup():
		return
	var active_scene: Node = get_tree().current_scene
	if active_scene != null and active_scene.has_method(Types.METHOD_HANDLE_BACK) and bool(active_scene.call(Types.METHOD_HANDLE_BACK)):
		return
	if go_back():
		return
	if Platform.can_quit_app() and await UI.confirm(tr("Quit the game?"), "", tr("Quit"), tr("Cancel")):
		get_tree().quit()
