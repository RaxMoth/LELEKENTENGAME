## The player's persistent profile. Owns one ProfileModule per data domain and
## registers each with SaveManager. Access modules directly:
##   Profile.wallet.add(Types.CURRENCY_COINS, 50)
##   Profile.levels.get_stars(&"level_1")
##   Profile.meta.set_flag(&"tutorial_done")
##
## Add a module: create a ProfileModule subclass in Scripts/Profile/, add a
## var here and append it in _create_modules().
##
## Dependencies: SaveManager, Events autoloads, GameConfig resource
extends Node

var config: GameConfig
var meta: ProfileMeta
var wallet: Wallet
var inventory: Inventory
var levels: LevelProgress
var upgrades: UpgradeLevels
var stats: Statistics
var achievements: AchievementTracker
var daily_rewards: DailyRewards
var energy: Energy

var _modules: Array[ProfileModule] = []


func _ready() -> void:
	config = GameConfig.get_default()
	_create_modules()
	for module: ProfileModule in _modules:
		SaveManager.register_section(module.get_save_key(), module.to_dict, module.from_dict)
	Events.progress_reset.connect(_on_progress_reset)
	meta.begin_session()


func _exit_tree() -> void:
	GameConfig.clear_cache()


func _process(delta: float) -> void:
	meta.total_play_seconds += delta


func _create_modules() -> void:
	meta = ProfileMeta.new(config)
	wallet = Wallet.new(config)
	inventory = Inventory.new(config)
	levels = LevelProgress.new(config)
	upgrades = UpgradeLevels.new(config)
	stats = Statistics.new(config)
	achievements = AchievementTracker.new(config)
	daily_rewards = DailyRewards.new(config)
	energy = Energy.new(config)
	_modules = [meta, wallet, inventory, levels, upgrades, stats, achievements, daily_rewards, energy]


## Grants a reward dictionary. Ids matching a CurrencyData go to the wallet,
## everything else is treated as an inventory item.
func grant_rewards(rewards: Dictionary[StringName, int]) -> void:
	for reward_id: StringName in rewards:
		if config.is_currency(reward_id):
			wallet.add(reward_id, rewards[reward_id])
		else:
			inventory.add_item(reward_id, rewards[reward_id])


## Erases all progress (keeps settings). Asks nothing — confirm in UI first.
func reset_progress() -> void:
	SaveManager.delete_save()


func _on_progress_reset() -> void:
	for module: ProfileModule in _modules:
		module.reset()
	for currency: CurrencyData in config.currencies:
		Events.currency_changed.emit(currency.id, wallet.get_amount(currency.id), 0)
