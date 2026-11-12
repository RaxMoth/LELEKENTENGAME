## The "How to cook" poster above the grinder and cooker: the plant first,
## then grinder, cooker and press. A gadget the lab doesn't have yet is
## dimmed and says where to get it, so the poster always shows the next step.
## Lives on a static WorldScreen; the Lab redraws it after upgrades.
##
##   board.show_progress(has_grinder, has_cooker, has_press)
##
## Dependencies: none
class_name LabGuideBoard
extends Control

## Opacity of a step whose gadget isn't bought yet.
const LOCKED_OPACITY: float = 0.6

@onready var _grind_card: Control = %Grind
@onready var _cook_card: Control = %Cook
@onready var _press_card: Control = %Press
@onready var _grind_note: Label = %GrindNote
@onready var _cook_note: Label = %CookNote
@onready var _press_note: Label = %PressNote


## Shows which gadgets the lab has: owned steps carry their tip, the rest
## point to the office.
func show_progress(has_grinder: bool, has_cooker: bool, has_press: bool) -> void:
	_show_step(_grind_card, _grind_note, has_grinder, tr("Sugarsalt needs no grinding."), tr("Buy the Grinder in the office."))
	_show_step(_cook_card, _cook_note, has_cooker, tr("Which mix? See the recipe book."), tr("Buy the Cooker in the office."))
	_show_step(_press_card, _press_note, has_press, tr("The press is behind you."), tr("Buy the Press in the office."))


## True when the step for [param step_name] (Grind, Cook, Press) shows as owned (tests).
func is_step_unlocked(step_name: StringName) -> bool:
	var card: Control = get_node_or_null("%" + String(step_name)) as Control
	return card != null and is_equal_approx(card.modulate.a, 1.0)


func _show_step(card: Control, note: Label, is_owned: bool, owned_tip: String, locked_tip: String) -> void:
	card.modulate.a = 1.0 if is_owned else LOCKED_OPACITY
	note.text = owned_tip if is_owned else locked_tip
