## Central, designer-editable game definition: scenes, economy, levels,
## achievements, daily rewards, store products and monetization tuning.
##
## Edit res://Ressources/game_config.tres in the inspector to reconfigure a
## new game without touching code. Access anywhere with GameConfig.get_default().
##
## Dependencies: none
class_name GameConfig
extends Resource

const DEFAULT_PATH: String = "res://Ressources/game_config.tres"

static var _default_instance: GameConfig = null

@export_group("Identity")
@export var game_title: String = "Porchlight VR"

@export_group("Scenes")
@export_file("*.tscn") var main_menu_scene: String = "res://Scenes/Menus/MainMenu/MainMenu.tscn"
@export_file("*.tscn") var level_select_scene: String = "res://Scenes/Menus/LevelSelect/LevelSelect.tscn"
@export_file("*.tscn") var shop_scene: String = "res://Scenes/Menus/Shop/Shop.tscn"
## Minimum time the boot splash stays visible.
@export var boot_splash_seconds: float = 0.8

@export_group("Economy")
@export var currencies: Array[CurrencyData] = []
@export var upgrades: Array[UpgradeData] = []
@export var products: Array[ProductData] = []

@export_group("Progression")
## Ordered list of levels / game modes. A level unlocks when the previous one is completed.
@export var levels: Array[LevelData] = []
@export var achievements: Array[AchievementData] = []
## Reward per consecutive login day; loops after the last entry.
@export var daily_rewards: Array[RewardBundle] = []

@export_group("XR")
## Where a headset player starts and returns to: Boot starts it right away and
## "Main Menu" leads back to it, because the 2D menus are not visible inside a
## headset. The menus are the flat-screen (no headset) flow.
@export var xr_start_level_id: StringName = &""

@export_group("Energy")
## 0 disables the energy/lives system entirely.
@export var max_energy: int = 0
@export var energy_regen_seconds: int = 600

@export_group("Ads")
@export var ads_enabled: bool = true
@export var interstitial_min_interval_seconds: float = 90.0
## Show an interstitial every N finished levels (0 = never).
@export var interstitial_every_n_levels: int = 3

@export_group("Links")
@export var android_store_url: String = ""
@export var ios_store_url: String = ""
@export var privacy_policy_url: String = ""


static func get_default() -> GameConfig:
	if _default_instance == null:
		_default_instance = load(DEFAULT_PATH) as GameConfig
		if _default_instance == null:
			push_error("GameConfig: missing %s, using empty config." % DEFAULT_PATH)
			_default_instance = GameConfig.new()
	return _default_instance


## Drops the cached instance (called on shutdown so no resources leak at exit).
static func clear_cache() -> void:
	_default_instance = null


func find_level(level_id: StringName) -> LevelData:
	for level: LevelData in levels:
		if level.id == level_id:
			return level
	return null


func get_level_index(level_id: StringName) -> int:
	for level_index: int in levels.size():
		if levels[level_index].id == level_id:
			return level_index
	return -1


func get_next_level(level_id: StringName) -> LevelData:
	var next_index: int = get_level_index(level_id) + 1
	return levels[next_index] if next_index > 0 and next_index < levels.size() else null


## The level a headset player starts in (null when none is configured).
func get_xr_start_level() -> LevelData:
	return find_level(xr_start_level_id) if not xr_start_level_id.is_empty() else null


func find_currency(currency_id: StringName) -> CurrencyData:
	for currency: CurrencyData in currencies:
		if currency.id == currency_id:
			return currency
	return null


func find_upgrade(upgrade_id: StringName) -> UpgradeData:
	for upgrade: UpgradeData in upgrades:
		if upgrade.id == upgrade_id:
			return upgrade
	return null


func find_product(product_id: StringName) -> ProductData:
	for product: ProductData in products:
		if product.id == product_id:
			return product
	return null


func is_currency(reward_id: StringName) -> bool:
	return find_currency(reward_id) != null
