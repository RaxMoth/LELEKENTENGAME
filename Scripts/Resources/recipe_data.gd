## One product the lab can make: which (processed) ingredients go into the
## cooker, what it sells for and how much police attention it draws. Products
## are fictional and stylized.
##
## Dependencies: IngredientData
class_name RecipeData
extends Resource

@export var id: StringName = &""
@export var display_name: String = "Product"
## Tint of batches and bags (a Palette color).
@export var color: Color = Color.WHITE
## Ingredients the cooker needs, each once.
@export var ingredients: Array[IngredientData] = []
## Fair price per standard (tier 2) unit.
@export var base_price: int = 40
## Units per packaged batch before upgrades.
@export var base_batch_size: int = 4
## Heat added per unit sold.
@export var heat_per_unit: float = 1.5
## UpgradeData id that unlocks it (empty = known from the start).
@export var unlock_upgrade_id: StringName = &""
## Grows on the lab's plants (shrooms) instead of being cooked: the cooker
## never makes it, the plants do.
@export var is_grown: bool = false

@export_group("Cooking")
## Needle sweeps per second at the cooker (higher = harder).
@export var cook_sweeps_per_second: float = 0.7
## Sweet zone width at the cooker (smaller = harder).
@export var cook_zone_width: float = 0.2


## True when [param ingredient_ids] is exactly this recipe's ingredient set.
func matches(ingredient_ids: Array[StringName]) -> bool:
	if ingredient_ids.size() != ingredients.size():
		return false
	var remaining: Array[StringName] = ingredient_ids.duplicate()
	for ingredient: IngredientData in ingredients:
		var found_index: int = remaining.find(ingredient.id)
		if found_index < 0:
			return false
		remaining.remove_at(found_index)
	return true


## True when [param ingredient_ids] could still become this recipe.
func accepts_partial(ingredient_ids: Array[StringName]) -> bool:
	var remaining: Array[StringName] = []
	for ingredient: IngredientData in ingredients:
		remaining.append(ingredient.id)
	for ingredient_id: StringName in ingredient_ids:
		var found_index: int = remaining.find(ingredient_id)
		if found_index < 0:
			return false
		remaining.remove_at(found_index)
	return true


## Cash the ingredients of one batch cost.
func get_ingredient_cost() -> int:
	var total: int = 0
	for ingredient: IngredientData in ingredients:
		total += ingredient.cost
	return total
