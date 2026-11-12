## Generic shop row: title, description, detail line and a buy button.
## The Shop scene binds it to upgrades, products or rewarded ads.
##
## Dependencies: none
class_name ShopItemRow
extends PanelContainer

signal buy_pressed

@onready var _title_label: Label = %TitleLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _detail_label: Label = %DetailLabel
@onready var _buy_button: Button = %BuyButton
@onready var _price_label: IconLabel = %PriceLabel


## [param button_icon] goes before the button text (e.g. the currency icon of a price).
func setup(title: String, description: String, detail: String, button_text: String, is_enabled: bool, button_icon: Texture2D = null) -> void:
	_title_label.text = title
	_description_label.text = description
	_description_label.visible = not description.is_empty()
	_detail_label.text = detail
	_detail_label.visible = not detail.is_empty()
	# Icon + text are centered together by an IconLabel; a Button would pin
	# its icon to the left edge.
	_buy_button.text = button_text if button_icon == null else ""
	_price_label.visible = button_icon != null
	_price_label.icon = button_icon
	_price_label.text = button_text
	_price_label.modulate.a = 1.0 if is_enabled else 0.45
	_buy_button.disabled = not is_enabled


func get_buy_button() -> Button:
	return _buy_button


func _on_buy_button_pressed() -> void:
	buy_pressed.emit()
