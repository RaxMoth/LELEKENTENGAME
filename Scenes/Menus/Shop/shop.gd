## Shop (flat-screen menu): the operation's upgrades by branch (the same ones
## the in-world office sells), a rewarded-ad freebie and in-app purchases.
## Rebuilds itself whenever balances change.
##
## Dependencies: Profile, Store, Ads, UI, SceneManager, Events autoloads
extends Control

const ROW_SCENE: PackedScene = preload("res://Scenes/Menus/Shop/ShopItemRow.tscn")
const PLAY_ICON: Texture2D = preload("res://Assets/Icons/play.svg")
const FREE_CASH_AMOUNT: int = 100
const AD_PLACEMENT_FREE_CASH: StringName = &"shop_free_cash"

@onready var _sections: VBoxContainer = %Sections


func _ready() -> void:
	Events.currency_changed.connect(func(_id: StringName, _amount: int, _delta: int) -> void: _rebuild.call_deferred())
	Events.item_changed.connect(func(_id: StringName, _count: int) -> void: _rebuild.call_deferred())
	_rebuild()


func _rebuild() -> void:
	Global.remove_all_children(_sections)
	var config: GameConfig = GameConfig.get_default()
	for branch: StringName in UpgradeData.BRANCHES:
		var branch_upgrades: Array[UpgradeData] = []
		for upgrade: UpgradeData in config.get_upgrades():
			if upgrade.show_in_shop and upgrade.branch == branch:
				branch_upgrades.append(upgrade)
		if branch_upgrades.is_empty():
			continue
		_add_header(tr(UpgradeData.get_branch_title(branch)))
		for upgrade: UpgradeData in branch_upgrades:
			_add_upgrade_row(upgrade)
	_add_header(tr("Free Cash"))
	var free_row: ShopItemRow = _add_row()
	free_row.setup(tr("Watch an ad"), "", tr("+$%d") % FREE_CASH_AMOUNT, tr("Free"), Ads.is_rewarded_ready(), PLAY_ICON)
	free_row.buy_pressed.connect(_on_free_cash_pressed)
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
	var row: ShopItemRow = _add_row()
	row.setup_upgrade(upgrade)
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


func _on_free_cash_pressed() -> void:
	if await Ads.show_rewarded(AD_PLACEMENT_FREE_CASH):
		Profile.wallet.add(Types.CURRENCY_CASH, FREE_CASH_AMOUNT)
		Audio.play_ui(Audio.UI_REWARD)


func _on_restore_pressed() -> void:
	var restored_count: int = await Store.restore_purchases()
	UI.toast("%s: %d" % [tr("Restore Purchases"), restored_count])


func _on_back_button_pressed() -> void:
	if not SceneManager.go_back():
		SceneManager.go_to_main_menu()
