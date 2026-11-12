## A cooked tray of product on its way to the press. Carries the recipe and
## the accuracy of every step so far; the press turns it into stash units.
## Let go away from a socket, it returns to the cooker's tray (its home
## socket) or, when that is taken, stays where it was let go.
##
## Dependencies: Grabbable, RecipeData, PlaceholderMesh3D, Pools autoload
class_name BatchItem
extends Grabbable

var recipe: RecipeData = null
var step_accuracies: Array[float] = []

@onready var _mix: PlaceholderMesh3D = %Mix
@onready var _name_label: Label3D = %NameLabel


func setup(batch_recipe: RecipeData, accuracies: Array[float]) -> void:
	recipe = batch_recipe
	step_accuracies = accuracies.duplicate()
	_mix.color = batch_recipe.color
	_name_label.text = tr("%s batch") % tr(batch_recipe.display_name)


func _on_pool_spawned() -> void:
	recipe = null
	step_accuracies.clear()
