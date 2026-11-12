## A cooked tray of product on its way to the press. Carries the recipe and
## the accuracy of every step so far; the press turns it into stash units.
## Let go away from a socket, it returns to the cooker's tray (its home
## socket) or, when that is taken, to the nearest free press or tray in reach.
##
## Dependencies: Grabbable, RecipeData, InteractionQuery, PlaceholderMesh3D, Pools autoload
class_name BatchItem
extends Grabbable

## A batch dropped nowhere looks this far (meters) for a free slot.
const RETURN_SEARCH_RADIUS: float = 2.5

var recipe: RecipeData = null
var step_accuracies: Array[float] = []

@onready var _mix: PlaceholderMesh3D = %Mix
@onready var _name_label: Label3D = %NameLabel


func setup(batch_recipe: RecipeData, accuracies: Array[float]) -> void:
	recipe = batch_recipe
	step_accuracies = accuracies.duplicate()
	_mix.color = batch_recipe.color
	_name_label.text = tr("%s batch") % tr(batch_recipe.display_name)


## Its cooker tray was taken: into the nearest free press (or tray) in
## reach instead of hanging in the air; with none, it stays where it was let go.
func _on_released_nowhere() -> void:
	var nearby_socket: ItemSocket = InteractionQuery.find_socket_within(get_tree(), self, global_position, RETURN_SEARCH_RADIUS)
	if nearby_socket != null:
		nearby_socket.insert(self)


## Co-op: what the other player needs to draw this batch.
func get_net_state() -> Array:
	return [recipe.resource_path if recipe != null else ""]


## Co-op client: look like the host's batch (no game logic).
func apply_net_state(state: Array) -> void:
	var recipe_path: String = str(state[0])
	if recipe_path.is_empty() or (recipe != null and recipe.resource_path == recipe_path):
		return
	setup(load(recipe_path) as RecipeData, [])


func _on_pool_spawned() -> void:
	recipe = null
	step_accuracies.clear()
