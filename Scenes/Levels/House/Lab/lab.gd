## The production front: ingredient crates, the grinder, cooker and press,
## the crafters and the recipe book on the wall. Owns the product recipes
## (registered with the Operation at setup, so the sales side knows what
## exists) and hands the operation to its stations, crates and crew.
## Everything it makes goes into the shared stash; the first batch of a new
## product fills in its entry in the recipe book (saved in Profile.operation).
##
## Dependencies: HouseFront, Workstation, IngredientCrate, Worker, RecipeData,
##               RecipeBoard, WorldScreen, Operation, Profile autoload, Palette
class_name Lab
extends HouseFront

## Every product the lab can make, in unlock order (also the recipe book's rows).
@export var recipes: Array[RecipeData] = []

@onready var _crafters: Node3D = %Crafters
@onready var _recipe_screen: WorldScreen = %RecipeScreen


func _on_setup() -> void:
	context.operation.recipes = recipes
	for child: Node in get_children():
		if child is Workstation:
			(child as Workstation).setup(context.operation)
		elif child is IngredientCrate:
			(child as IngredientCrate).operation = context.operation
	for crafter: Node in _crafters.get_children():
		(crafter as Worker).operation = context.operation
	get_station(&"Cooker").batch_cooked.connect(_on_batch_cooked)
	_refresh_recipe_book()


func apply_upgrades() -> void:
	# A recipe upgrade turns its lock into question marks.
	_refresh_recipe_book()


func get_recipe_board() -> RecipeBoard:
	return _recipe_screen.content as RecipeBoard


## The station named [param station_name] (Grinder, Cooker, Press), or null.
func get_station(station_name: StringName) -> Workstation:
	return get_node_or_null(NodePath(String(station_name))) as Workstation


## The crate that hands out [param ingredient_id], or null.
func get_crate(ingredient_id: StringName) -> IngredientCrate:
	for child: Node in get_children():
		var crate: IngredientCrate = child as IngredientCrate
		if crate != null and crate.ingredient != null and crate.ingredient.id == ingredient_id:
			return crate
	return null


func _on_batch_cooked(recipe: RecipeData) -> void:
	if Profile.operation.discover_recipe(recipe.id):
		announcement_requested.emit(tr("New recipe: %s") % tr(recipe.display_name), Palette.TEXT)
		_refresh_recipe_book()


func _refresh_recipe_book() -> void:
	var unlocked_ids: Array[StringName] = []
	for recipe: RecipeData in context.operation.get_unlocked_recipes():
		unlocked_ids.append(recipe.id)
	get_recipe_board().show_recipes(recipes, Profile.operation.discovered_recipe_ids, unlocked_ids)
	# Deferred: the new rows sort themselves first, then the poster is drawn.
	_recipe_screen.request_redraw.call_deferred()
