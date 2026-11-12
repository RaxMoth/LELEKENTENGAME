## Base class for every modal popup opened through the UI autoload.
## Handles the dimmed backdrop, open/close animation, optional game pausing
## and back-button behavior. Subclasses override _on_opened(popup_data).
##
## Required scene layout (see any popup in Scenes/UI/Popups/):
##   Root (Control, this script, full rect)
##   ├── %Backdrop (ColorRect, full rect)
##   └── CenterContainer (full rect, mouse_filter IGNORE)
##       └── %Panel (PanelContainer) — content goes inside
##
## Usage: var result: Variant = await UI.open_popup(SCENE, {"title": "Hi"}).closed
##
## Dependencies: none
class_name BasePopup
extends Control

## Emitted once when the popup has finished closing. [param result] is popup specific.
signal closed(result: Variant)

@export var close_on_backdrop_tap: bool = true
## Pause the scene tree while this popup is open (level-up choices, revive offers...).
@export var pause_game: bool = false
@export var animation_seconds: float = 0.18

var popup_data: Dictionary = {}

var _is_closing: bool = false
var _did_pause_tree: bool = false

@onready var _backdrop: ColorRect = %Backdrop
@onready var _panel: Control = %Panel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_backdrop.gui_input.connect(_on_backdrop_gui_input)
	_panel.resized.connect(func() -> void: _panel.pivot_offset = _panel.size * 0.5)


## Called by UI.open_popup right after the popup entered the tree.
func open(data: Dictionary) -> void:
	popup_data = data
	if pause_game and not get_tree().paused:
		get_tree().paused = true
		_did_pause_tree = true
	_on_opened(data)
	_backdrop.modulate.a = 0.0
	_panel.scale = Vector2.ONE * 0.85
	_panel.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_backdrop, "modulate:a", 1.0, animation_seconds)
	tween.tween_property(_panel, "modulate:a", 1.0, animation_seconds)
	tween.tween_property(_panel, "scale", Vector2.ONE, animation_seconds * 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close(result: Variant = null) -> void:
	if _is_closing:
		return
	_is_closing = true
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_backdrop, "modulate:a", 0.0, animation_seconds)
	tween.tween_property(_panel, "modulate:a", 0.0, animation_seconds)
	tween.tween_property(_panel, "scale", Vector2.ONE * 0.9, animation_seconds)
	await tween.finished
	if _did_pause_tree:
		get_tree().paused = false
	closed.emit(result)
	queue_free()


func is_closing() -> bool:
	return _is_closing


## @virtual Back button / backdrop tap. Default closes with a null result.
func handle_back() -> void:
	close(null)


## @virtual Fill the popup's content from [param data].
func _on_opened(_data: Dictionary) -> void:
	pass


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if not close_on_backdrop_tap or _is_closing:
		return
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null and mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		handle_back()
