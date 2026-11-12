## Example: idle / clicker. Tap the big coin, buy upgrades that increase tap
## power and passive income, and collect offline earnings when you return.
## Press "Finish" to bank the session score (endless level).
##
## Shows: TapArea, persistent UpgradeData + Profile.upgrades, Wallet,
## NumberFormat, FloatingText, offline progress + RewardPopup with rewarded-ad
## doubling, ShopItemRow reuse.
##
## Dependencies: LevelBase, Profile, UI, Audio autoloads
extends LevelBase

const ROW_SCENE: PackedScene = preload("res://Scenes/Menus/Shop/ShopItemRow.tscn")
const REWARD_POPUP: PackedScene = preload("res://Scenes/UI/Popups/RewardPopup/RewardPopup.tscn")
const UPGRADE_TAP_POWER: StringName = &"idle_tap_power"
const UPGRADE_AUTO_INCOME: StringName = &"idle_auto_income"
## Offline earnings are paid only once per app session.
static var offline_earnings_claimed: bool = false

@export var offline_efficiency: float = 0.5
@export var max_offline_hours: float = 8.0

var _income_accumulator: float = 0.0
var _tap_upgrade: UpgradeData
var _income_upgrade: UpgradeData
var _rows: Dictionary[StringName, ShopItemRow] = {}

@onready var _tap_area: TapArea = %TapArea
@onready var _coin_visual: Node2D = %CoinVisual
@onready var _income_label: Label = %IncomeLabel
@onready var _upgrade_list: VBoxContainer = %UpgradeList


func _on_level_setup() -> void:
	var config: GameConfig = GameConfig.get_default()
	_tap_upgrade = config.find_upgrade(UPGRADE_TAP_POWER)
	_income_upgrade = config.find_upgrade(UPGRADE_AUTO_INCOME)
	_tap_area.tapped.connect(_on_coin_tapped)
	hud.add_action_button(tr("Finish"), &"SecondaryButton").pressed.connect(end_run)
	for upgrade: UpgradeData in [_tap_upgrade, _income_upgrade]:
		if upgrade == null:
			continue
		var row: ShopItemRow = ROW_SCENE.instantiate() as ShopItemRow
		_upgrade_list.add_child(row)
		row.buy_pressed.connect(_on_upgrade_buy_pressed.bind(upgrade))
		_rows[upgrade.id] = row
	Events.currency_changed.connect(func(_id: StringName, _amount: int, _delta: int) -> void: _refresh_rows())
	_refresh_rows()


func _on_level_started() -> void:
	_offer_offline_earnings()


func _level_process(delta: float) -> void:
	var income_per_second: float = _get_income_per_second()
	if income_per_second <= 0.0:
		return
	_income_accumulator += income_per_second * delta
	if _income_accumulator >= 1.0:
		var whole_coins: int = int(_income_accumulator)
		_income_accumulator -= whole_coins
		_earn(whole_coins)


func _get_tap_power() -> int:
	return maxi(1, int(Profile.upgrades.get_value(_tap_upgrade))) if _tap_upgrade != null else 1


func _get_income_per_second() -> float:
	return Profile.upgrades.get_value(_income_upgrade) if _income_upgrade != null else 0.0


func _earn(amount: int) -> void:
	Profile.wallet.add(Types.CURRENCY_COINS, amount)
	add_score(amount)


func _on_coin_tapped(_area: TapArea) -> void:
	if not is_playing():
		return
	var tap_power: int = _get_tap_power()
	_earn(tap_power)
	Profile.stats.increment(Types.STAT_TAPS)
	Audio.play_sfx(SfxSynth.get_preset(&"coin"), 0.2, -8.0)
	Platform.vibrate(Types.HapticStrength.LIGHT)
	TweenFX.punch_scale(_coin_visual, 1.12, 0.12)
	var tap_position: Vector2 = Global.screen_to_world(self, get_viewport().get_mouse_position())
	FloatingText.spawn("+%s" % NumberFormat.compact(tap_power), tap_position, Palette.GOLD, 40)


func _on_upgrade_buy_pressed(upgrade: UpgradeData) -> void:
	if Profile.upgrades.purchase(upgrade):
		Audio.play_ui(Audio.UI_CONFIRM)
		TweenFX.pop(_rows[upgrade.id], 1.05)
	else:
		Audio.play_ui(Audio.UI_ERROR)
		TweenFX.shake(_rows[upgrade.id])
	_refresh_rows()


func _refresh_rows() -> void:
	for upgrade_id: StringName in _rows:
		var upgrade: UpgradeData = GameConfig.get_default().find_upgrade(upgrade_id)
		var current_level: int = Profile.upgrades.get_level(upgrade_id)
		var detail: String = tr("Level %d") % current_level + "  ·  " + upgrade.value_format % NumberFormat.compact(upgrade.get_value(current_level))
		var is_maxed: bool = upgrade.is_maxed(current_level)
		var cost_text: String = tr("Max") if is_maxed else NumberFormat.compact(upgrade.get_cost(current_level))
		var currency: CurrencyData = GameConfig.get_default().find_currency(upgrade.currency_id)
		var cost_icon: Texture2D = currency.icon if currency != null and not is_maxed else null
		_rows[upgrade_id].setup(upgrade.title, upgrade.description, detail, cost_text, Profile.upgrades.can_purchase(upgrade), cost_icon)
	_income_label.text = "%s / tap   ·   %s / s" % [NumberFormat.compact(_get_tap_power()), NumberFormat.compact(_get_income_per_second())]


func _offer_offline_earnings() -> void:
	if offline_earnings_claimed:
		return
	offline_earnings_claimed = true
	var offline_seconds: float = minf(Profile.meta.offline_seconds, max_offline_hours * 3600.0)
	var earned: int = int(_get_income_per_second() * offline_seconds * offline_efficiency)
	if earned <= 0:
		return
	var popup: BasePopup = UI.open_popup(REWARD_POPUP, {
		"title": tr("Welcome back!"),
		"subtitle": tr("You earned %s while away.") % NumberFormat.compact(earned),
		"rewards": {Types.CURRENCY_COINS: earned},
		"allow_double": true,
	})
	var multiplier: int = await popup.closed
	_earn(earned * multiplier)
