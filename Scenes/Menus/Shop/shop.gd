## Shop: persistent upgrades (soft currency), a rewarded-ad freebie and
## in-app purchases. Rebuilds itself whenever balances change.
##
## Dependencies: Profile, Store, Ads, UI, SceneManager, Events autoloads
extends Control

const ROW_SCENE: PackedScene = preload("res://Scenes/Menus/Shop/ShopItemRow.tscn")
const PLAY_ICON: Texture2D = preload("res://Assets/Icons/play.svg")
const FREE_COINS_AMOUNT: int = 100
const AD_PLACEMENT_FREE_COINS: StringName = &"shop_free_coins"

@onready var _sections: VBoxContainer = %Sections


func _ready() -> void:
	Events.currency_changed.connect(func(_id: StringName, _amount: int, _delta: int) -> void: _rebuild.call_deferred())
	Events.item_changed.connect(func(_id: StringName, _count: int) -> void: _rebuild.call_deferred())
	_rebuild()


func _rebuild() -> void:
	Global.remove_all_children(_sections)
	var config: GameConfig = GameConfig.get_default()
	_add_header(tr("Upgrades"))
	for upgrade: UpgradeData in config.upgrades:
		if upgrade.show_in_shop:
			_add_upgrade_row(upgrade)
	_add_header(tr("Free Coins"))
	var free_row: ShopItemRow = _add_row()
	free_row.setup(tr("Watch an ad"), "", tr("+%d coins") % FREE_COINS_AMOUNT, tr("Free"), Ads.is_rewarded_ready(), PLAY_ICON)
	free_row.buy_pressed.connect(_on_free_coins_pressed)
	_add_header(tr("Store"))
	for product: ProductData in Store.get_products():
		_add_product_row(product)
	var restore_button: Button = Button.new()
	restore_button.text = tr("Restore Purchases")
	restore_button.theme_type_variation = &"SecondaryButton"
	restore_button.custom_minimum_size.y = 80
	restore_button.pressed.connect(_on_restore_pressed)
	_sections.add_child(restore_button)


func _add_header(text: String) -> void:
	var header: Label = Label.new()
	header.theme_type_variation = &"HeaderLabel"
	header.text = text
	_sections.add_child(header)


func _add_row() -> ShopItemRow:
	var row: ShopItemRow = ROW_SCENE.instantiate() as ShopItemRow
	_sections.add_child(row)
	return row


func _add_upgrade_row(upgrade: UpgradeData) -> void:
	var current_level: int = Profile.upgrades.get_level(upgrade.id)
	var row: ShopItemRow = _add_row()
	var currency: CurrencyData = GameConfig.get_default().find_currency(upgrade.currency_id)
	var value_text: String = upgrade.value_format % NumberFormat.compact(upgrade.get_value(current_level))
	var detail: String = tr("Level %d") % current_level + "  ·  " + value_text
	if upgrade.is_maxed(current_level):
		row.setup(upgrade.title, upgrade.description, detail, tr("Max"), false)
		return
	var cost: int = upgrade.get_cost(current_level)
	row.setup(upgrade.title, upgrade.description, detail, NumberFormat.compact(cost), Profile.upgrades.can_purchase(upgrade), currency.icon if currency != null else null)
	row.buy_pressed.connect(func() -> void:
		if Profile.upgrades.purchase(upgrade):
			Audio.play_ui(Audio.UI_CONFIRM)
		else:
			Audio.play_ui(Audio.UI_ERROR))


func _add_product_row(product: ProductData) -> void:
	var row: ShopItemRow = _add_row()
	var is_owned: bool = Store.is_owned(product)
	row.setup(product.title, product.description, "", tr("Owned") if is_owned else Store.get_price_text(product), not is_owned)
	row.buy_pressed.connect(func() -> void:
		if await Store.purchase(product.id):
			Audio.play_ui(Audio.UI_REWARD)
			UI.toast(tr("Purchase complete!")))


func _on_free_coins_pressed() -> void:
	if await Ads.show_rewarded(AD_PLACEMENT_FREE_COINS):
		Profile.wallet.add(Types.CURRENCY_COINS, FREE_COINS_AMOUNT)
		Audio.play_ui(Audio.UI_REWARD)


func _on_restore_pressed() -> void:
	var restored_count: int = await Store.restore_purchases()
	UI.toast("%s: %d" % [tr("Restore Purchases"), restored_count])


func _on_back_button_pressed() -> void:
	if not SceneManager.go_back():
		SceneManager.go_to_main_menu()
