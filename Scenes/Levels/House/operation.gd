## The house's shared state: the stash, police heat, cash flow, prices and
## everything the upgrades change. Every front reads and writes the
## operation through this one node, so a co-op version can replicate it.
##
## Cash lives in Profile.wallet and reputation in Profile.operation; the
## stash and prices are saved to Profile.operation at the end of a shift.
##
## Dependencies: Stash, HeatMeter, RecipeData, CustomerOrder, QualityMath,
##               Profile, Events, Types autoloads
class_name Operation
extends Node

signal stash_changed
signal heat_changed(heat: float)
## A sale went through at the window.
signal sale_made(order: CustomerOrder, units: int, cash_earned: int)
## Cash paid for upkeep (ingredients, wages, repairs, bribes).
signal cash_spent(amount: int, reason: String)

@export var base_stash_capacity: int = 30

@export_group("Heat")
@export var heat_cooling_per_second: float = 0.3
## Heat levels that each send one police raid.
@export var raid_thresholds: Array[float] = [50.0, 80.0]
## A bribe costs this plus bribe_cost_per_heat for every point of heat.
@export var bribe_base_cost: int = 80
@export var bribe_cost_per_heat: float = 3.0
## Heat a bribe removes.
@export var bribe_heat_reduction: float = 40.0

## Every product the house can make, in unlock order (registered by the Lab).
var recipes: Array[RecipeData] = []
var stash: Stash = Stash.new()
var heat: HeatMeter = null
## This shift's totals (score, results).
var shift_cash_earned: int = 0
var shift_units_sold: int = 0
var shift_units_crafted: int = 0

var _config: GameConfig = null


func _ready() -> void:
	_config = GameConfig.get_default()
	heat = HeatMeter.new(heat_cooling_per_second, raid_thresholds)
	stash.from_dict(Profile.operation.stash_data)
	# Saved on every change (the save itself is debounced), like cash: a
	# quit mid-shift can't bring sold units back.
	stash.changed.connect(func() -> void:
		save()
		stash_changed.emit())
	apply_upgrades()


## Re-reads everything upgrades change (called on setup and after a purchase).
func apply_upgrades() -> void:
	stash.capacity = base_stash_capacity + roundi(get_upgrade_value(Types.UPGRADE_STORAGE))
	heat.cooling_per_second = heat_cooling_per_second * get_heat_cooling_multiplier()
	stash_changed.emit()

# ============================================
# UPGRADES
# ============================================

## Current value of an upgrade (UpgradeData.get_value at its bought level), 0 when unknown.
func get_upgrade_value(upgrade_id: StringName) -> float:
	var upgrade: UpgradeData = _config.find_upgrade(upgrade_id)
	return Profile.upgrades.get_value(upgrade) if upgrade != null else 0.0


func get_upgrade_level(upgrade_id: StringName) -> int:
	return Profile.upgrades.get_level(upgrade_id)


## How much faster heat cools (1 = base rate): a kept-up house draws less
## attention, so every renovation level adds its percent (Types.RENOVATION_UPGRADES).
func get_heat_cooling_multiplier() -> float:
	var bonus_percent: float = 0.0
	for upgrade_id: StringName in Types.RENOVATION_UPGRADES:
		bonus_percent += get_upgrade_value(upgrade_id)
	return 1.0 + bonus_percent / 100.0


## Quality bonus of the lab equipment.
func get_equipment_bonus() -> float:
	return get_upgrade_value(Types.UPGRADE_EQUIPMENT)


## Sweet zones get this much wider with better equipment.
func get_sweet_zone_multiplier() -> float:
	return 1.0 + get_upgrade_level(Types.UPGRADE_EQUIPMENT) * 0.2


func get_batch_size(recipe: RecipeData) -> int:
	return recipe.base_batch_size + roundi(get_upgrade_value(Types.UPGRADE_BATCH))


## Recipes the player can make right now.
func get_unlocked_recipes() -> Array[RecipeData]:
	var unlocked: Array[RecipeData] = []
	for recipe: RecipeData in recipes:
		if Profile.upgrades.is_owned(recipe.unlock_upgrade_id):
			unlocked.append(recipe)
	return unlocked


func find_recipe(recipe_id: StringName) -> RecipeData:
	for recipe: RecipeData in recipes:
		if recipe.id == recipe_id:
			return recipe
	return null

# ============================================
# CASH
# ============================================

func get_cash() -> int:
	return Profile.wallet.get_amount(Types.CURRENCY_CASH)


func can_afford(amount: int) -> bool:
	return Profile.wallet.can_afford(Types.CURRENCY_CASH, amount)


## Pays an upkeep cost. Returns false (and pays nothing) when broke.
func spend_cash(amount: int, reason: String) -> bool:
	if amount <= 0:
		return true
	if not Profile.wallet.spend(Types.CURRENCY_CASH, amount):
		return false
	cash_spent.emit(amount, reason)
	return true


## Gives back an upkeep cost (not counted as earned cash).
func refund_cash(amount: int) -> void:
	Profile.wallet.add(Types.CURRENCY_CASH, amount, false)

# ============================================
# PRODUCTION & STASH
# ============================================

## Adds packaged units to the stash; returns how many fit.
func add_product(recipe: RecipeData, tier: int, units: int) -> int:
	var stored: int = stash.add(recipe.id, tier, units)
	shift_units_crafted += stored
	if stored > 0:
		Profile.stats.increment(Types.STAT_UNITS_CRAFTED, stored)
	return stored


## Thieves and raids: removes random stock; returns units lost.
func lose_stock(units: int) -> int:
	return stash.steal(units)

# ============================================
# SALES
# ============================================

func get_price(recipe: RecipeData) -> int:
	return Profile.operation.get_price(recipe.id, recipe.base_price)


func set_price(recipe: RecipeData, price: int) -> void:
	Profile.operation.set_price(recipe.id, price)


## Quality the customer would get — the lowest tier among the units the
## stash would hand over (Stash.peek), which also sets their price — or 0
## when the stash can't fill the order.
func get_deliverable_tier(order: CustomerOrder) -> int:
	var tiers: Array[int] = stash.peek(order.recipe.id, order.min_tier, order.quantity)
	return tiers.min() if not tiers.is_empty() else 0


## Hands the order over at [param unit_price]. Returns the cash earned, or
## -1 when the stash can't fill it.
func complete_sale(order: CustomerOrder, unit_price: int) -> int:
	var taken_tiers: Array[int] = stash.take(order.recipe.id, order.min_tier, order.quantity)
	if taken_tiers.is_empty():
		return -1
	var cash_earned: int = unit_price * order.quantity
	Profile.wallet.add(Types.CURRENCY_CASH, cash_earned)
	shift_cash_earned += cash_earned
	shift_units_sold += order.quantity
	Profile.stats.increment(Types.STAT_UNITS_SOLD, order.quantity)
	Profile.operation.add_reputation(order.customer_type.reputation_gain)
	add_heat(order.recipe.heat_per_unit * order.quantity)
	sale_made.emit(order, order.quantity, cash_earned)
	return cash_earned

# ============================================
# HEAT
# ============================================

func add_heat(amount: float) -> void:
	heat.add(amount)
	heat_changed.emit(heat.value)


func cool_heat(delta: float) -> void:
	var before: float = heat.value
	heat.cool(delta)
	if not is_equal_approx(before, heat.value):
		heat_changed.emit(heat.value)


## The raid is over: the police lose track of the house and heat starts at 0.
func clear_heat() -> void:
	heat.set_value(0.0)
	heat_changed.emit(heat.value)


func get_bribe_cost() -> int:
	return bribe_base_cost + roundi(heat.value * bribe_cost_per_heat)


## Pays the police off. Returns false when broke or there is no heat.
func bribe() -> bool:
	if heat.value <= 0.0 or not spend_cash(get_bribe_cost(), "bribe"):
		return false
	heat.set_value(heat.value - bribe_heat_reduction)
	heat_changed.emit(heat.value)
	return true

# ============================================
# PERSISTENCE
# ============================================

func save() -> void:
	Profile.operation.save_stash(stash)
