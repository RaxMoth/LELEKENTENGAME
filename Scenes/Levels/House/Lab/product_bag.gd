## A sealed bag of product: packed by the press, or shrooms picked off a
## plant by hand. It is not in the stash yet: somebody has to put it there —
## the player carries it to the drop crate on the stash shelf (StashShelf),
## or a hired crafter takes one from the press. Let go anywhere else it goes
## back on the press tray (its home socket), else to its rest_position (a
## picked bag: beside its pot), else stays where it was let go.
##
## Dependencies: Grabbable, RecipeData, QualityMath, PlaceholderMesh3D, Pools autoload
class_name ProductBag
extends Grabbable

var recipe: RecipeData = null
var tier: int = 0
var units: int = 0
## Where it goes when let go away from any socket and it has no free home
## socket (NAN: stays where it was let go).
var rest_position: Vector3 = Vector3(NAN, NAN, NAN)

@onready var _bag: PlaceholderMesh3D = %Bag
@onready var _name_label: Label3D = %NameLabel


## Called by the press right after spawning it.
func setup(bag_recipe: RecipeData, bag_tier: int, bag_units: int) -> void:
	recipe = bag_recipe
	tier = bag_tier
	units = bag_units
	_apply_look()


func get_display_name() -> String:
	if recipe == null:
		return ""
	return "%s ×%d · %s" % [tr(recipe.display_name), units, tr(QualityMath.get_tier_name(tier))]


## Co-op: what the other player needs to draw this bag.
func get_net_state() -> Array:
	return [recipe.resource_path if recipe != null else "", tier, units]


## Co-op client: look like the host's bag (no game logic).
func apply_net_state(state: Array) -> void:
	var recipe_path: String = str(state[0])
	if recipe_path.is_empty() or (recipe != null and recipe.resource_path == recipe_path and tier == int(state[1]) and units == int(state[2])):
		return
	setup(load(recipe_path) as RecipeData, int(state[1]), int(state[2]))


func _on_pool_spawned() -> void:
	recipe = null
	tier = 0
	units = 0
	rest_position = Vector3(NAN, NAN, NAN)


func _on_released_nowhere() -> void:
	if not is_nan(rest_position.x):
		global_transform = Transform3D(Basis.IDENTITY, rest_position)


func _apply_look() -> void:
	if recipe == null:
		return
	_bag.color = recipe.color
	_name_label.text = "%s ×%d\n%s" % [tr(recipe.display_name), units, tr(QualityMath.get_tier_name(tier))]
