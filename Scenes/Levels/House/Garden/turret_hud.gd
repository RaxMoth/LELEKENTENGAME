## The turret goggles' overlay: a status strip at the top of the view (which
## turret, "2 / 5", manual control, its ability and a bar for reload or
## heat) and a control strip at the bottom (previous / next turret, take the
## goggles off). Two small panels on the edges of the view, so the middle —
## where the player aims and fires — stays free. Shows what the TurretSeat
## tells it and emits the buttons; no game logic.
##
## Dependencies: IconLabel
class_name TurretHud
extends Control

## Previous (-1) or next (+1) turret.
signal turret_step_requested(step: int)
## Take the goggles off.
signal exit_requested

@onready var _title: Label = get_node_or_null("%TitleLabel")
@onready var _count: Label = get_node_or_null("%CountLabel")
@onready var _ability: IconLabel = get_node_or_null("%AbilityLabel")
@onready var _bar: ProgressBar = get_node_or_null("%ReadyBar")
@onready var _previous: Button = get_node_or_null("%PreviousButton")
@onready var _next: Button = get_node_or_null("%NextButton")
@onready var _exit: Button = get_node_or_null("%ExitButton")


func _ready() -> void:
	if _previous != null:
		_previous.pressed.connect(func() -> void: turret_step_requested.emit(-1))
	if _next != null:
		_next.pressed.connect(func() -> void: turret_step_requested.emit(1))
	if _exit != null:
		_exit.pressed.connect(func() -> void: exit_requested.emit())


## The status strip: [param title] of turret [param number] of
## [param count], its [param ability] line and [param ready] (0..1).
func show_status(title: String, number: int, count: int, ability: String, ready: float) -> void:
	if _title != null:
		_title.text = title
	if _count != null:
		_count.text = tr("%d / %d") % [number, count]
	if _ability != null:
		_ability.text = ability
	if _bar != null:
		_bar.value = clampf(ready, 0.0, 1.0) * 100.0


## Previous / next only make sense with more than one turret.
func set_can_switch(can_switch: bool) -> void:
	if _previous != null:
		_previous.disabled = not can_switch
	if _next != null:
		_next.disabled = not can_switch


## The "Next turret" button (tests press it).
func get_next_button() -> Button:
	return _next


## The "Take off goggles" button.
func get_exit_button() -> Button:
	return _exit
