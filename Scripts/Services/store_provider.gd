## Base in-app purchase backend. The default implementation is a mock that
## approves every purchase in debug builds and rejects them in release builds,
## so a forgotten provider can never hand out free premium goods.
##
## Real store: subclass and wrap GodotGooglePlayBilling / StoreKit, then call
## Store.set_provider(MyBillingProvider.new()).
##
## Dependencies: UI autoload (mock overlay only)
class_name StoreProvider
extends RefCounted


## @virtual
func initialize() -> void:
	pass


## @virtual Returns true when the purchase succeeded and should be granted.
func purchase(_product: ProductData) -> bool:
	UI.show_loading(tr("Connecting to store…"))
	await Engine.get_main_loop().create_timer(0.8, true).timeout
	UI.hide_loading()
	return OS.is_debug_build()


## @virtual Returns ids of non-consumables the player owns.
func restore_purchases() -> Array[StringName]:
	return []


## @virtual Localized price string, empty if unknown.
func get_localized_price(_product: ProductData) -> String:
	return ""
