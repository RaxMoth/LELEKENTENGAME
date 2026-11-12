## Base ad backend. Every method is awaitable. This default implementation is a
## mock that simulates ads with a short loading overlay, so ad-gated flows
## (rewarded "double coins", revive...) are fully testable without an SDK.
##
## Real SDK: subclass, call the plugin (e.g. AdMob) and assign it with
## Ads.set_provider(MyAdMobProvider.new()).
##
## Dependencies: UI autoload (mock overlay only)
class_name AdsProvider
extends RefCounted

const MOCK_AD_SECONDS: float = 1.2


## @virtual
func initialize() -> void:
	pass


## @virtual Returns true when the player earned the reward.
func show_rewarded(_placement: StringName) -> bool:
	UI.show_loading(tr("Playing ad…"))
	await Engine.get_main_loop().create_timer(MOCK_AD_SECONDS, true).timeout
	UI.hide_loading()
	return true


## @virtual
func show_interstitial(_placement: StringName) -> void:
	UI.show_loading(tr("Advertisement"))
	await Engine.get_main_loop().create_timer(MOCK_AD_SECONDS * 0.5, true).timeout
	UI.hide_loading()


## @virtual
func show_banner() -> void:
	pass


## @virtual
func hide_banner() -> void:
	pass


## @virtual
func is_rewarded_ready() -> bool:
	return true
