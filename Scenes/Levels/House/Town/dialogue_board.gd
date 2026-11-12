## The conversation panel shown next to a person the player talks to in the
## street: who they are, what they just said, and the player's replies as
## buttons (the first one is the primary action). Shown on the Town's
## WorldScreen; emits the chosen reply and runs no game logic.
##
## Dependencies: IconLabel
class_name DialogueBoard
extends Control

## The player picked reply [param reply_index] (in the order given to show_step()).
signal reply_chosen(reply_index: int)

@onready var _speaker: IconLabel = %Speaker
@onready var _line: Label = %Line
@onready var _replies: Array[Button] = [%Reply1, %Reply2, %Reply3]


func _ready() -> void:
	for reply_index: int in _replies.size():
		_replies[reply_index].pressed.connect(func() -> void: reply_chosen.emit(reply_index))


## Shows what [param speaker] said ([param line], spoken German, shown as
## is) and up to three [param replies] (already translated).
func show_step(speaker: String, line: String, replies: PackedStringArray) -> void:
	_speaker.text = speaker
	_line.text = line
	for reply_index: int in _replies.size():
		var button: Button = _replies[reply_index]
		button.visible = reply_index < replies.size()
		if button.visible:
			button.text = replies[reply_index]


## The text of reply [param reply_index] (tests press replies by index).
func get_reply_text(reply_index: int) -> String:
	return _replies[reply_index].text if reply_index < _replies.size() and _replies[reply_index].visible else ""


## How many replies the panel shows now.
func get_reply_count() -> int:
	var count: int = 0
	for button: Button in _replies:
		if button.visible:
			count += 1
	return count
