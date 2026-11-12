## Generic shop row: title, description, detail line and a buy button.
## The Shop scene and the in-world office bind it to upgrades, products or
## rewarded ads.
##
## Dependencies: UpgradeData, NumberFormat, Profile, GameConfig
class_name ShopItemRow
extends PanelContainer

signal buy_pressed

const LOCK_ICON: Texture2D = preload("res://Assets/Icons/lock.svg")

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


## Shows an upgrade: level, value and price; locked until what it builds on
## is bought and the operation has the reputation it needs.
func setup_upgrade(upgrade: UpgradeData) -> void:
	var current_level: int = Profile.upgrades.get_level(upgrade.id)
	var detail: String = tr("Level %d") % current_level
	if not upgrade.value_format.is_empty():
		detail += "  ·  " + upgrade.value_format % NumberFormat.compact(upgrade.get_value(current_level))
	if upgrade.is_maxed(current_level):
		setup(tr(upgrade.title), tr(upgrade.description), detail, tr("Max"), false)
		return
	if not Profile.upgrades.is_requirement_met(upgrade):
		var required: UpgradeData = GameConfig.get_default().find_upgrade(upgrade.required_upgrade_id)
		var required_title: String = tr(required.title) if required != null else String(upgrade.required_upgrade_id)
		setup(tr(upgrade.title), tr(upgrade.description), tr("Needs %s first") % required_title, "", false, LOCK_ICON)
		return
	if not Profile.upgrades.is_reputation_met(upgrade):
		setup(tr(upgrade.title), tr(upgrade.description), tr("Needs %d reputation") % upgrade.required_reputation, str(upgrade.required_reputation), false, LOCK_ICON)
		return
	var currency: CurrencyData = GameConfig.get_default().find_currency(upgrade.currency_id)
	setup(tr(upgrade.title), tr(upgrade.description), detail, NumberFormat.compact(upgrade.get_cost(current_level)), Profile.upgrades.can_purchase(upgrade), currency.icon if currency != null else null)


func get_buy_button() -> Button:
	return _buy_button


func _on_buy_button_pressed() -> void:
	buy_pressed.emit()
