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
## yield more. A finished batch left on the cooker too long catches fire
## (StationFire) — the extinguisher on the wall puts it out; without power
## (the fuse box tripped) the stations and the automation stand still.
##
## Dependencies: HouseFront, Workstation, IngredientCrate, ShroomPlant, Worker,
##               LabAutomation, RecipeData, RecipeBoard, LabGuideBoard, WorldScreen,
##               StationFire, Extinguisher, ItemSocket, Operation, GameConfig,
##               Profile, Palette, Types autoloads
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
@onready var _fire: StationFire = %StationFire
@onready var _extinguisher: Extinguisher = %Extinguisher
@onready var _extinguisher_hook: ItemSocket = %ExtinguisherHook


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
	# A harvesting level-up adds to every hand harvest from now on.
	context.operation.skill_leveled.connect(func(_skill: int, _level: int) -> void: _apply_gadgets())
	context.operation.power_changed.connect(_on_power_changed)
	_fire.setup(context.operation)
	_fire.overheating.connect(func() -> void: announcement_requested.emit(tr("The cooker is smoking: take the batch off"), Palette.WARNING))
	_fire.ignited.connect(func() -> void: warning_requested.emit(tr("Fire in the lab! Grab the extinguisher")))
	_fire.put_out.connect(func() -> void: announcement_requested.emit(tr("The fire is out"), Palette.SUCCESS))
	_extinguisher_hook.accept_rule = func(item: Grabbable) -> bool: return item is Extinguisher
	_extinguisher.home_socket = _extinguisher_hook
	_extinguisher_hook.insert(_extinguisher)
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
	if context.operation.has_power:
		_automation.advance(delta)
	_fire.step(delta)


## The fire, the smoke or the dark: one line for the wrist.
func get_status_line() -> String:
	if _fire.is_burning():
		return tr("Fire in the lab!")
	if _fire.is_overheating():
		return tr("Cooker smoking")
	if not context.operation.has_power:
		return tr("Lab: no power")
	return ""


## The cooker's fire (tests).
func get_fire() -> StationFire:
	return _fire


func get_extinguisher() -> Extinguisher:
	return _extinguisher


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

func _on_power_changed(has_power: bool) -> void:
	for station_name: StringName in [&"Grinder", &"Cooker", &"Press"]:
		get_station(station_name).set_powered(has_power)


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
