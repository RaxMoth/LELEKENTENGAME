## The board inside the back window: who is at the window, what they want,
## your price, and Sell / Decline (or Accept / Decline a counteroffer).
## Shown in the world on a WorldScreen. It only displays and emits signals.
##
## Dependencies: CustomerOrder, QualityMath, IconLabel, NumberFormat, Palette
class_name SalesBoard
extends Control

signal price_step_requested(step: int)
signal sell_pressed
signal decline_pressed
signal accept_counter_pressed

@onready var _queue_label: IconLabel = %QueueLabel
@onready var _empty_box: Control = %EmptyBox
@onready var _empty_label: Label = %EmptyLabel
@onready var _order_box: Control = %OrderBox
@onready var _customer_label: Label = %CustomerLabel
@onready var _patience_bar: ProgressBar = %PatienceBar
@onready var _wants_label: Label = %WantsLabel
@onready var _stock_label: Label = %StockLabel
@onready var _price_label: Label = %PriceLabel
@onready var _total_label: Label = %TotalLabel
@onready var _price_row: Control = %PriceRow
@onready var _counter_label: Label = %CounterLabel
@onready var _sell_button: Button = %SellButton
@onready var _accept_button: Button = %AcceptButton
@onready var _decline_button: Button = %DeclineButton


func show_waiting(queue_size: int, capacity: int) -> void:
	_queue_label.text = "%d / %d" % [queue_size, capacity]
	_empty_box.show()
	_order_box.hide()
	_empty_label.text = tr("Nobody at the window") if queue_size == 0 else tr("Next customer is coming up")


## [param deliverable_tier] 0 = the stash can't fill the order;
## [param counter_offer] > 0 = a haggler offered that much per unit.
func show_order(order: CustomerOrder, unit_price: int, deliverable_tier: int, units_in_stock: int, counter_offer: int, queue_size: int, capacity: int) -> void:
	_queue_label.text = "%d / %d" % [queue_size, capacity]
	_empty_box.hide()
	_order_box.show()
	_customer_label.text = tr(order.customer_type.display_name)
	_wants_label.text = tr("%s ×%d, %s or better") % [tr(order.recipe.display_name), order.quantity, tr(QualityMath.get_tier_name(order.min_tier))]
	if deliverable_tier > 0:
		_stock_label.text = tr("In stash: %d · you hand over %s") % [units_in_stock, tr(QualityMath.get_tier_name(deliverable_tier))]
		_stock_label.self_modulate = Palette.TEXT_MUTED
	else:
		_stock_label.text = tr("Not enough in the stash (%d of %d)") % [units_in_stock, order.quantity]
		_stock_label.self_modulate = Palette.DANGER
	_price_label.text = "$%s" % NumberFormat.with_separators(unit_price)
	_total_label.text = tr("Total $%s") % NumberFormat.with_separators(unit_price * order.quantity)
	var has_counter: bool = counter_offer > 0
	_counter_label.visible = has_counter
	_counter_label.text = tr("They offer $%d per unit") % counter_offer
	_price_row.visible = not has_counter
	_sell_button.visible = not has_counter
	_accept_button.visible = has_counter
	_sell_button.disabled = deliverable_tier == 0
	_accept_button.disabled = deliverable_tier == 0


func set_patience(ratio: float) -> void:
	_patience_bar.value = ratio * 100.0


func _on_price_down_pressed() -> void:
	price_step_requested.emit(-1)


func _on_price_up_pressed() -> void:
	price_step_requested.emit(1)


func _on_sell_button_pressed() -> void:
	sell_pressed.emit()


func _on_accept_button_pressed() -> void:
	accept_counter_pressed.emit()


func _on_decline_button_pressed() -> void:
	decline_pressed.emit()
