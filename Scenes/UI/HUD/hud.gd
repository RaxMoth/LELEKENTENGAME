## In-game heads-up display used by LevelBase: pause button, score, timer,
## currency, a progress bar (XP / wave / level progress), center messages and
## a bottom action bar games can fill with buttons.
## The HUD never runs game logic — it only emits signals.
##
## Dependencies: TweenFX, NumberFormat, CurrencyDisplay
class_name GameHUD
extends CanvasLayer

signal pause_pressed

@onready var _score_box: Control = %ScoreBox
@onready var _score_label: Label = %ScoreLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _currency_display: CurrencyDisplay = %CurrencyDisplay
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _progress_label: Label = %ProgressLabel
@onready var _center_message: Label = %CenterMessage
@onready var _action_bar: HBoxContainer = %ActionBar

var _displayed_score: int = 0
var _message_tween: Tween


func _ready() -> void:
	_timer_label.hide()
	hide_progress()
	_center_message.hide()
	_action_bar.visible = _action_bar.get_child_count() > 0


func set_score(new_score: int, animate: bool = true) -> void:
	if animate and new_score != _displayed_score:
		TweenFX.count_label(_score_label, _displayed_score, new_score, 0.25, func(value: float) -> String: return NumberFormat.with_separators(int(value)))
		TweenFX.pop(_score_label, 1.12, 0.18)
	else:
		_score_label.text = NumberFormat.with_separators(new_score)
	_displayed_score = new_score


func set_score_visible(should_show: bool) -> void:
	_score_box.visible = should_show


func set_currency_visible(should_show: bool) -> void:
	_currency_display.visible = should_show


func set_timer(seconds: float) -> void:
	_timer_label.show()
	_timer_label.text = NumberFormat.duration(ceilf(seconds))


func hide_timer() -> void:
	_timer_label.hide()


## Shows the progress bar (XP, wave or level progress). Pass an empty label to hide the caption.
func set_progress(current_value: float, max_value: float, caption: String = "") -> void:
	_progress_bar.show()
	_progress_bar.max_value = maxf(max_value, 0.0001)
	_progress_bar.value = current_value
	_progress_label.text = caption
	_progress_label.visible = not caption.is_empty()


func hide_progress() -> void:
	_progress_bar.hide()
	_progress_label.hide()


## Big centered text such as "Ready?", "Wave 3" or "Combo x5".
func show_message(message: String, duration_seconds: float = 1.0) -> void:
	if _message_tween != null:
		_message_tween.kill()
	_center_message.text = message
	_center_message.show()
	_center_message.modulate.a = 1.0
	_center_message.pivot_offset = _center_message.size * 0.5
	_center_message.scale = Vector2.ONE * 0.4
	_message_tween = create_tween()
	_message_tween.tween_property(_center_message, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_message_tween.tween_interval(maxf(0.0, duration_seconds - 0.45))
	_message_tween.tween_property(_center_message, "modulate:a", 0.0, 0.2)
	_message_tween.tween_callback(_center_message.hide)


## Adds a button to the bottom action bar and returns it so the caller can connect it.
func add_action_button(button_text: String, type_variation: StringName = &"") -> Button:
	var action_button: Button = Button.new()
	action_button.text = button_text
	action_button.custom_minimum_size = Vector2(150, 110)
	action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not type_variation.is_empty():
		action_button.theme_type_variation = type_variation
	_action_bar.add_child(action_button)
	_action_bar.show()
	return action_button


## Adds any control (e.g. a CooldownButton) to the action bar.
func add_action_control(control: Control) -> void:
	_action_bar.add_child(control)
	_action_bar.show()


func _on_pause_button_pressed() -> void:
	pause_pressed.emit()
