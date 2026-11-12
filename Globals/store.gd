## In-app purchase facade. Products are defined in GameConfig.products and
## their rewards are granted automatically through Profile.grant_rewards.
##
##   if await Store.purchase(&"gems_small"): ...
##
## Dependencies: Events, Profile autoloads, StoreProvider
extends Node

var _provider: StoreProvider = StoreProvider.new()
var _purchase_in_progress: bool = false


func _ready() -> void:
	_provider.initialize()


func set_provider(provider: StoreProvider) -> void:
	_provider = provider
	_provider.initialize()


func get_products() -> Array[ProductData]:
	return GameConfig.get_default().products


func get_price_text(product: ProductData) -> String:
	var localized_price: String = _provider.get_localized_price(product)
	return localized_price if not localized_price.is_empty() else product.fallback_price_text


func is_owned(product: ProductData) -> bool:
	return product.product_type == Types.ProductType.NON_CONSUMABLE and Profile.inventory.has_item(product.id)


func purchase(product_id: StringName) -> bool:
	var product: ProductData = GameConfig.get_default().find_product(product_id)
	if product == null or _purchase_in_progress or is_owned(product):
		Events.purchase_failed.emit(product_id, "unavailable")
		return false
	_purchase_in_progress = true
	var succeeded: bool = await _provider.purchase(product)
	_purchase_in_progress = false
	if not succeeded:
		Events.purchase_failed.emit(product_id, "cancelled")
		return false
	_grant(product)
	Events.purchase_completed.emit(product_id)
	return true


func restore_purchases() -> int:
	var restored_count: int = 0
	var owned_product_ids: Array[StringName] = await _provider.restore_purchases()
	for product_id: StringName in owned_product_ids:
		var product: ProductData = GameConfig.get_default().find_product(product_id)
		if product != null and not is_owned(product):
			_grant(product)
			restored_count += 1
	return restored_count


func _grant(product: ProductData) -> void:
	if product.product_type == Types.ProductType.NON_CONSUMABLE:
		Profile.inventory.add_item(product.id, 1)
	Profile.grant_rewards(product.rewards)
