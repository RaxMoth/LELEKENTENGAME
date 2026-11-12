## Pill showing a currency balance that updates (with a count-up) whenever the
## wallet changes. Drop it anywhere: Add Node > CurrencyDisplay, set currency_id.
##
## Dependencies: Events, Profile autoloads
class_name CurrencyDisplay
extends PanelContainer

## Emitted when tapped (e.g. open the shop).
signal tapped(currency_id: StringName)

@export var currency_id: StringName = &"coins":
	set(value):
		currency_id = value
		if is_node_ready():
			_refresh_definition()

var _amount: IconLabel
var _displayed_amount: int = 0


func _ready() -> void:
	theme_type_variation = &"PillPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_amount = IconLabel.create(null, "", 38)
	add_child(_amount)
	Events.currency_changed.connect(_on_currency_changed)
	_refresh_definition()


func _gui_input(event: InputEvent) -> void:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null and mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(currency_id)


func _refresh_definition() -> void:
	var currency: CurrencyData = GameConfig.get_default().find_currency(currency_id)
	_amount.icon = currency.icon if currency != null else null
	_displayed_amount = Profile.wallet.get_amount(currency_id)
	_amount.text = NumberFormat.compact(_displayed_amount)
	if currency != null and currency.icon == null:
		_amount.text = "%s %s" % [currency.fallback_symbol, _amount.text]


func _on_currency_changed(changed_currency_id: StringName, new_amount: int, _amount_delta: int) -> void:
	if changed_currency_id != currency_id:
		return
	TweenFX.count_label(_amount.get_label(), _displayed_amount, new_amount, 0.35)
	_displayed_amount = new_amount
	TweenFX.pop(self, 1.08, 0.2)
