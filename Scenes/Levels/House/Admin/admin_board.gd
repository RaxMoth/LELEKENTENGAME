## The admin terminal's screen (debug builds only): buttons to give cash and
## reputation, move the day, start the raid, skip or clear waves, win the
## shift and speed time up — for testing the 3-day cycle without playing it
## through. Displays what it is told and emits one signal per button; the
## AdminPanel front does the work.
##
## Dependencies: Palette
class_name AdminBoard
extends Control

## A button was pressed; [param action_id] is one of the ACTION_* constants.
signal action_requested(action_id: StringName)

const ACTION_CASH_SMALL: StringName = &"cash_small"
const ACTION_CASH_LARGE: StringName = &"cash_large"
const ACTION_REPUTATION: StringName = &"reputation"
const ACTION_DAY_BACK: StringName = &"day_back"
const ACTION_DAY_FORWARD: StringName = &"day_forward"
const ACTION_RAID_NOW: StringName = &"raid_now"
const ACTION_NEXT_WAVE: StringName = &"next_wave"
const ACTION_CLEAR_WAVE: StringName = &"clear_wave"
const ACTION_WIN_SHIFT: StringName = &"win_shift"
const ACTION_TIME_SCALE: StringName = &"time_scale"
## During a raid: send police in now (Events.admin_spawn_requested).
const ACTION_SPAWN_COP: StringName = &"spawn_cop"
const ACTION_SPAWN_SQUAD: StringName = &"spawn_squad"
const ACTION_SPAWN_SWAT: StringName = &"spawn_swat"
const ACTION_SPAWN_RAM: StringName = &"spawn_ram"
const ACTION_SPAWN_CAR: StringName = &"spawn_car"
const ACTION_SPAWN_TANK: StringName = &"spawn_tank"
const ACTION_SPAWN_HELICOPTER: StringName = &"spawn_helicopter"

## Button captions in grid order (three columns).
const BUTTONS: Array[Array] = [
	[ACTION_CASH_SMALL, "+$1,000"],
	[ACTION_CASH_LARGE, "+$10,000"],
	[ACTION_DAY_BACK, "Day -1"],
	[ACTION_DAY_FORWARD, "Day +1"],
	[ACTION_RAID_NOW, "Start raid now"],
	[ACTION_NEXT_WAVE, "Next wave now"],
	[ACTION_CLEAR_WAVE, "Clear wave"],
	[ACTION_REPUTATION, "+50 reputation"],
	[ACTION_TIME_SCALE, "Time x1 / x3"],
	[ACTION_WIN_SHIFT, "Win shift"],
	[ACTION_SPAWN_COP, "Spawn cop"],
	[ACTION_SPAWN_SQUAD, "Spawn squad"],
	[ACTION_SPAWN_SWAT, "Spawn SWAT"],
	[ACTION_SPAWN_RAM, "Spawn ram team"],
	[ACTION_SPAWN_CAR, "Spawn squad car"],
	[ACTION_SPAWN_TANK, "Spawn armored vehicle"],
	[ACTION_SPAWN_HELICOPTER, "Spawn helicopter"],
]

var _buttons: Dictionary[StringName, Button] = {}

@onready var _status_label: Label = %StatusLabel
@onready var _grid: GridContainer = %Grid


func _ready() -> void:
	for entry: Array in BUTTONS:
		var action_id: StringName = entry[0]
		var button: Button = Button.new()
		button.text = tr(str(entry[1]))
		button.custom_minimum_size = Vector2(0, 88)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.theme_type_variation = &"DangerButton" if action_id == ACTION_WIN_SHIFT else &"SecondaryButton"
		button.pressed.connect(func() -> void: action_requested.emit(action_id))
		_grid.add_child(button)
		_buttons[action_id] = button


## The status block: day, cycle, phase, cash, time scale.
func show_status(status_text: String) -> void:
	_status_label.text = status_text


## A button by action id (tests).
func get_button(action_id: StringName) -> Button:
	return _buttons.get(action_id)
