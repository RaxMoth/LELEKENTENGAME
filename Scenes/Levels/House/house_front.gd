## Base for one front of the house: the Lab, the FrontGarden (defense), the
## SalesWindow (customers) or the Office. Each front is its own scene and
## script, owned by one developer: it gets a HouseContext at setup, keeps
## its own nodes, data and logic, and reports back to the House level only
## through the signals below. Fronts never reference each other — shared
## state goes through context.operation (stash, heat, cash, upgrades).
##
##   class_name FrontGarden extends HouseFront
##   func _on_setup() -> void: context.rig.secondary_action_pressed.connect(_fire)
##   func _shift_process(delta: float) -> void: ...
##   warning_requested.emit(tr("Police raid!"))
##
## The House level finds every front through Types.GROUP_HOUSE_FRONT.
##
## Dependencies: HouseContext, WorldScreen, LevelResult, Palette, Types autoload
class_name HouseFront
extends Node3D

## Show a message in front of the player.
signal announcement_requested(message: String, color: Color)
## Something needs the player now: message plus alarm sound and rumble.
signal warning_requested(message: String)
## Points for the shift's score (cash earned, attackers stopped).
signal score_earned(points: int)
## The shift is lost (e.g. the front door broke).
signal shift_lost(reason: String)

## Seconds between refreshes of this front's in-world displays.
const DISPLAY_REFRESH_SECONDS: float = 0.25

## In-world screens farther than this from the head, or behind it, stop redrawing.
@export var screen_render_distance: float = 7.0

var context: HouseContext = null

var _seconds_until_display_refresh: float = 0.0


# _notification runs for every class in the chain, so subclasses may override
# _ready() without calling super() and still register.
func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		add_to_group(Types.GROUP_HOUSE_FRONT)


## Called by the House level once, before the shift starts.
func setup(shift_context: HouseContext) -> void:
	context = shift_context
	_on_setup()
	_refresh_displays()


## Called by the House level every frame while the shift runs.
func process_shift(delta: float) -> void:
	_shift_process(delta)
	_seconds_until_display_refresh -= delta
	if _seconds_until_display_refresh <= 0.0:
		_seconds_until_display_refresh = DISPLAY_REFRESH_SECONDS
		_refresh_displays()

# ============================================
# VIRTUAL HOOKS
# ============================================

## @virtual Wire the front to the context (connect rig signals, hand the
## operation to stations and crew, fill boards).
func _on_setup() -> void:
	pass


## @virtual The shift begins (after the intro).
func on_shift_started() -> void:
	pass


## @virtual Per frame while the shift runs.
func _shift_process(_delta: float) -> void:
	pass


## @virtual A few times a second: update this front's boards and labels.
func _refresh_displays() -> void:
	pass


## @virtual Night falls.
func on_nightfall() -> void:
	pass


## @virtual An upgrade was bought: re-read what upgrades change here.
func apply_upgrades() -> void:
	pass


## @virtual The shift is over (won or lost): stop what is moving.
func finish_shift(_result: LevelResult) -> void:
	pass


## @virtual One short line for the wrist status ("Door 80%"), or "" for none.
func get_status_line() -> String:
	return ""

# ============================================
# HELPERS
# ============================================

## Lets [param screen] redraw only while the player is near it and facing it.
func update_screen_rendering(screen: WorldScreen) -> void:
	var head: Transform3D = context.rig.get_head_transform()
	var to_screen: Vector3 = screen.global_position - head.origin
	screen.set_rendering(to_screen.length() <= screen_render_distance and to_screen.dot(-head.basis.z) > 0.0)
