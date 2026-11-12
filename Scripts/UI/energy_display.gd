## Pill showing energy / lives with a refill countdown. Hides itself when the
## energy system is disabled (GameConfig.max_energy == 0).
##
## Dependencies: Events, Profile autoloads
class_name EnergyDisplay
extends PanelContainer

const ENERGY_ICON: Texture2D = preload("res://Assets/Icons/bolt.svg")

var _amount: IconLabel
var _refresh_accumulator: float = 0.0


func _ready() -> void:
	theme_type_variation = &"PillPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_amount = IconLabel.create(ENERGY_ICON, "", 34, Palette.WARNING)
	add_child(_amount)
	visible = Profile.energy.is_enabled()
	Events.energy_changed.connect(func(_current: int, _maximum: int) -> void: _refresh())
	_refresh()


func _process(delta: float) -> void:
	_refresh_accumulator += delta
	if _refresh_accumulator >= 1.0:
		_refresh_accumulator = 0.0
		_refresh()


func _refresh() -> void:
	if not visible:
		return
	var current_energy: int = Profile.energy.get_current()
	var refill_text: String = ""
	if current_energy < Profile.energy.get_max():
		refill_text = "  " + NumberFormat.duration(Profile.energy.seconds_until_next())
	_amount.text = "%d/%d%s" % [current_energy, Profile.energy.get_max(), refill_text]
