## The production front. A new operation starts small: one shroom plant on
## the grow shelf that grows on its own — harvest, sell at the window. The
## office then sells the lab its gadgets one after the other — the grinder
## (with the ingredient crates), the cooker, the press — and more plants;
## each shows up here when bought. Owns the product recipes (registered with
## the Operation at setup, so the sales side knows what exists), hands the
## operation to its plants, stations, crates and crew, and keeps the recipe
## book (every recipe, open, with what it still needs) and the how-to poster
## up to date — both go up on the walls once the grinder and the cooker are
## bought (a real lab to explain). The Automation tab adds motors to the stations (they finish
## their own skill checks), conveyor belts between them and an ingredient
## hopper (LabAutomation); the Green Thumb perk makes hand-picked plants
## yield more.
##
## Dependencies: HouseFront, Workstation, IngredientCrate, ShroomPlant, Worker,
##               LabAutomation, RecipeData, RecipeBoard, LabGuideBoard, WorldScreen,
##               Operation, GameConfig, Profile, Types autoloads
class_name Lab
extends HouseFront

## Every product the lab can make, in unlock order (also the recipe book's rows).
@export var recipes: Array[RecipeData] = []

@onready var _crafters: Node3D = %Crafters
@onready var _plants: Node3D = %Plants
@onready var _recipe_book: Node3D = %RecipeBook
@onready var _guide_poster: Node3D = %GuidePoster
@onready var _recipe_screen: WorldScreen = %RecipeScreen
@onready var _guide_screen: WorldScreen = %GuideScreen
@onready var _automation: LabAutomation = %Automation


func _on_setup() -> void:
	context.operation.recipes = recipes
	var grown_recipe: RecipeData = _find_grown_recipe()
	var crates: Array[IngredientCrate] = []
	for child: Node in get_children():
		if child is Workstation:
			(child as Workstation).setup(context.operation)
		elif child is IngredientCrate:
			(child as IngredientCrate).operation = context.operation
			crates.append(child as IngredientCrate)
	_automation.setup(context.operation, crates)
	for plant: ShroomPlant in get_plants():
		plant.setup(context.operation, grown_recipe)
	for crafter: Node in _crafters.get_children():
		(crafter as Worker).operation = context.operation
	_apply_gadgets()


## Gadgets, plants, the recipe book and the poster follow what was bought.
func apply_upgrades() -> void:
	_apply_gadgets()


## The belts and the hopper only work while the shift runs.
func _shift_process(delta: float) -> void:
	_automation.advance(delta)


func get_recipe_board() -> RecipeBoard:
	return _recipe_screen.content as RecipeBoard


func get_guide_board() -> LabGuideBoard:
	return _guide_screen.content as LabGuideBoard


## True once the recipe book and the how-to poster hang on the walls.
func are_posters_up() -> bool:
	return _recipe_book.visible and _guide_poster.visible


## The belts and the hopper (tests).
func get_automation() -> LabAutomation:
	return _automation


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


## Every plant spot on the grow shelf (bought or not).
func get_plants() -> Array[ShroomPlant]:
	var plants: Array[ShroomPlant] = []
	for child: Node in _plants.get_children():
		var plant: ShroomPlant = child as ShroomPlant
		if plant != null:
			plants.append(plant)
	return plants


# ============================================
# INTERNALS
# ============================================

func _apply_gadgets() -> void:
	var has_grinder: bool = Profile.upgrades.is_owned(Types.UPGRADE_GRINDER)
	var has_cooker: bool = Profile.upgrades.is_owned(Types.UPGRADE_COOKER)
	var has_press: bool = Profile.upgrades.is_owned(Types.UPGRADE_PRESS)
	get_station(&"Grinder").set_active(has_grinder)
	get_station(&"Cooker").set_active(has_cooker)
	get_station(&"Press").set_active(has_press)
	get_station(&"Grinder").set_motorized(Profile.upgrades.is_owned(Types.UPGRADE_GRINDER_MOTOR))
	get_station(&"Cooker").set_motorized(Profile.upgrades.is_owned(Types.UPGRADE_COOKER_MOTOR))
	get_station(&"Press").set_motorized(Profile.upgrades.is_owned(Types.UPGRADE_PRESS_MOTOR))
	_automation.set_parts(Profile.upgrades.is_owned(Types.UPGRADE_CONVEYOR), Profile.upgrades.is_owned(Types.UPGRADE_HOPPER))
	# Ingredients only make sense once there is something to grind them with.
	for child: Node in get_children():
		if child is IngredientCrate:
			(child as IngredientCrate).visible = has_grinder
	var plant_count: int = 1 + Profile.upgrades.get_level(Types.UPGRADE_PLANTS)
	var plants: Array[ShroomPlant] = get_plants()
	var hand_bonus: int = context.operation.get_hand_harvest_bonus()
	for plant_index: int in plants.size():
		plants[plant_index].set_active(plant_index < plant_count)
		plants[plant_index].hand_harvest_bonus = hand_bonus
	# The posters go up with the grinder and the cooker; hidden, their screens don't render.
	var has_posters: bool = has_grinder and has_cooker
	_recipe_book.visible = has_posters
	_guide_poster.visible = has_posters
	_recipe_screen.set_active(has_posters)
	_guide_screen.set_active(has_posters)
	get_guide_board().show_progress(has_grinder, has_cooker, has_press)
	_guide_screen.request_redraw.call_deferred()
	_refresh_recipe_book()


func _refresh_recipe_book() -> void:
	var unlocked_ids: Array[StringName] = []
	for recipe: RecipeData in context.operation.get_unlocked_recipes():
		unlocked_ids.append(recipe.id)
	var unlock_titles: Dictionary[StringName, String] = {}
	var config: GameConfig = GameConfig.get_default()
	for recipe: RecipeData in recipes:
		var unlock: UpgradeData = config.find_upgrade(recipe.unlock_upgrade_id)
		if unlock != null:
			unlock_titles[recipe.id] = unlock.title
	get_recipe_board().show_recipes(recipes, unlocked_ids, unlock_titles)
	# Deferred: the new rows sort themselves first, then the poster is drawn.
	_recipe_screen.request_redraw.call_deferred()


func _find_grown_recipe() -> RecipeData:
	for recipe: RecipeData in recipes:
		if recipe.is_grown:
			return recipe
	return null
