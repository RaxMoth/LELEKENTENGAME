## The persistent state of the player's operation between shifts: which day
## it is, reputation, the stock in the stash and the prices set at the
## window. Cash lives in the Wallet, upgrades in UpgradeLevels.
##
## Dependencies: Events autoload, Stash
class_name OperationProgress
extends ProfileModule

## Reputation never drops below this.
const MIN_REPUTATION: int = 0

## 1-based number of the shift the player is on.
var day_number: int = 1
var reputation: int = 0
## Highest day survived.
var best_day: int = 0
## Stash contents (Stash.to_dict()).
var stash_data: Dictionary = {}
## Asked price per product id.
var prices: Dictionary[StringName, int] = {}
## Products cooked at least once: the lab's recipe book reveals them.
var discovered_recipe_ids: Array[StringName] = []


func get_save_key() -> StringName:
	return &"operation"


func to_dict() -> Dictionary:
	return {
		"day_number": day_number,
		"reputation": reputation,
		"best_day": best_day,
		"stash": stash_data,
		"prices": prices,
		"discovered_recipes": discovered_recipe_ids,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	day_number = maxi(1, int(data.get("day_number", 1)))
	reputation = maxi(MIN_REPUTATION, int(data.get("reputation", 0)))
	best_day = maxi(0, int(data.get("best_day", 0)))
	var stored_stash: Variant = data.get("stash", {})
	stash_data = stored_stash if stored_stash is Dictionary else {}
	prices = to_int_dictionary(data.get("prices", {}))
	var stored_recipes: Variant = data.get("discovered_recipes", [])
	if stored_recipes is Array:
		for stored_id: Variant in stored_recipes:
			var recipe_id: StringName = StringName(str(stored_id))
			if not recipe_id.is_empty() and not discovered_recipe_ids.has(recipe_id):
				discovered_recipe_ids.append(recipe_id)


func reset() -> void:
	day_number = 1
	reputation = 0
	best_day = 0
	stash_data = {}
	prices = {}
	discovered_recipe_ids = []


func add_reputation(amount: int) -> void:
	if amount == 0:
		return
	reputation = maxi(MIN_REPUTATION, reputation + amount)
	Events.reputation_changed.emit(reputation, amount)
	mark_dirty()


func get_price(product_id: StringName, default_price: int) -> int:
	return prices.get(product_id, default_price)


func set_price(product_id: StringName, price: int) -> void:
	prices[product_id] = maxi(1, price)
	mark_dirty()


func save_stash(stash: Stash) -> void:
	stash_data = stash.to_dict()
	mark_dirty()


func is_recipe_discovered(recipe_id: StringName) -> bool:
	return discovered_recipe_ids.has(recipe_id)


## The lab cooked [param recipe_id]. Returns true the first time (a new
## entry in the recipe book).
func discover_recipe(recipe_id: StringName) -> bool:
	if recipe_id.is_empty() or discovered_recipe_ids.has(recipe_id):
		return false
	discovered_recipe_ids.append(recipe_id)
	mark_dirty()
	return true


## A shift was survived: on to the next day.
func complete_day() -> void:
	best_day = maxi(best_day, day_number)
	day_number += 1
	mark_dirty()
