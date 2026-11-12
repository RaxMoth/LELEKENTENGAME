## The production front: ingredient crates, the grinder, cooker and press,
## and the crafters. Owns the product recipes (registered with the Operation
## at setup, so the sales side knows what exists) and hands the operation to
## its stations, crates and crew. Reports nothing on its own: everything it
## makes goes into the shared stash.
##
## Dependencies: HouseFront, Workstation, IngredientCrate, Worker, RecipeData, Operation
class_name Lab
extends HouseFront

## Every product the lab can make, in unlock order.
@export var recipes: Array[RecipeData] = []

@onready var _crafters: Node3D = %Crafters


func _on_setup() -> void:
	context.operation.recipes = recipes
	for child: Node in get_children():
		if child is Workstation:
			(child as Workstation).setup(context.operation)
		elif child is IngredientCrate:
			(child as IngredientCrate).operation = context.operation
	for crafter: Node in _crafters.get_children():
		(crafter as Worker).operation = context.operation


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
