## Ads facade with frequency capping and "remove ads" support.
##
##   if await Ads.show_rewarded(&"double_coins"):
##       Profile.wallet.add(Types.CURRENCY_COINS, bonus)
##   Ads.maybe_show_interstitial(&"level_end")   # respects caps & no-ads
##
## Dependencies: Events, Profile, Types autoloads, AdsProvider
extends Node

var _provider: AdsProvider = AdsProvider.new()
var _last_interstitial_msec: int = -1
var _levels_since_interstitial: int = 0


func _ready() -> void:
	_provider.initialize()


func set_provider(provider: AdsProvider) -> void:
	_provider = provider
	_provider.initialize()


## True when the player bought "remove ads" (rewarded ads stay available — they are opt-in).
func are_ads_removed() -> bool:
	return Profile.inventory.has_item(Types.ITEM_NO_ADS)


func is_rewarded_ready() -> bool:
	return GameConfig.get_default().ads_enabled and _provider.is_rewarded_ready()


func show_rewarded(placement: StringName) -> bool:
	if not is_rewarded_ready():
		return false
	var was_rewarded: bool = await _provider.show_rewarded(placement)
	Events.rewarded_ad_finished.emit(placement, was_rewarded)
	return was_rewarded


## Call after every finished level; shows an interstitial when the configured
## cadence and minimum interval allow it.
func maybe_show_interstitial(placement: StringName) -> void:
	var config: GameConfig = GameConfig.get_default()
	if not config.ads_enabled or are_ads_removed() or config.interstitial_every_n_levels <= 0:
		return
	_levels_since_interstitial += 1
	if _levels_since_interstitial < config.interstitial_every_n_levels:
		return
	var elapsed_seconds: float = (Time.get_ticks_msec() - _last_interstitial_msec) / 1000.0
	if _last_interstitial_msec >= 0 and elapsed_seconds < config.interstitial_min_interval_seconds:
		return
	_levels_since_interstitial = 0
	_last_interstitial_msec = Time.get_ticks_msec()
	await _provider.show_interstitial(placement)


func show_banner() -> void:
	if GameConfig.get_default().ads_enabled and not are_ads_removed():
		_provider.show_banner()


func hide_banner() -> void:
	_provider.hide_banner()
