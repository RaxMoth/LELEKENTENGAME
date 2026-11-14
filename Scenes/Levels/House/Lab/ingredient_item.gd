## One piece of an ingredient in the lab: grabbed from its crate, ground at
## the grinder (if it needs it) and cooked. Remembers how well each step went.
## Dropped anywhere else an unused piece goes back into its crate (and the
## cash comes back); a ground piece goes back to its station's tray.
##
## Looks like the real thing (IngredientLook): a mushroom, a root, a bundle
## of leaves or crystal chunks; ground, a pile of powder on a tin dish.
##
## Dependencies: Grabbable, IngredientData, IngredientCrate, IngredientLook, InteractionQuery, Pools autoload
class_name IngredientItem
extends Grabbable

## Height of a piece's middle above its base (where hands grab it).
const GRAB_HEIGHT: float = 0.05
## A worked piece dropped nowhere looks this far (meters) for a free slot.
const RETURN_SEARCH_RADIUS: float = 2.5

var data: IngredientData = null
var is_processed: bool = false
## Accuracy of every lab step this piece went through.
var step_accuracies: Array[float] = []
var crate: IngredientCrate = null

@onready var _body: MeshInstance3D = %Body
@onready var _name_label: Label3D = %NameLabel


## Called by the crate right after spawning it.
func setup(ingredient: IngredientData, source_crate: IngredientCrate) -> void:
	data = ingredient
	crate = source_crate
	is_processed = not ingredient.needs_processing
	step_accuracies.clear()
	_apply_look()


## The grinder finished it with [param accuracy].
func mark_processed(accuracy: float) -> void:
	is_processed = true
	step_accuracies.append(accuracy)
	_apply_look()


func get_grab_center() -> Vector3:
	return _body.global_position + Vector3(0.0, GRAB_HEIGHT, 0.0)


## Nowhere to go: an unused piece returns to its crate; a worked piece goes
## into the nearest free station slot that takes it (its own tray was taken)
## or, with none in reach, stays where it was let go — never destroyed, the
## work is not lost, and it never hangs in the air out of reach.
func _on_released_nowhere() -> void:
	if not step_accuracies.is_empty():
		var nearby_socket: ItemSocket = InteractionQuery.find_socket_within(get_tree(), self, global_position, RETURN_SEARCH_RADIUS)
		if nearby_socket != null:
			nearby_socket.insert(self)
		return
	if crate != null and is_instance_valid(crate):
		crate.take_back(self)
	else:
		Pools.despawn(self)


## Co-op: what the other player needs to draw this piece.
func get_icon() -> Texture2D:
	return preload("res://Assets/Icons/sprout.svg")


func get_net_state() -> Array:
	return [data.resource_path if data != null else "", is_processed]


## Co-op client: look like the host's piece (no crate, no game logic).
func apply_net_state(state: Array) -> void:
	var data_path: String = str(state[0])
	var processed: bool = bool(state[1])
	if data_path.is_empty() or (data != null and data.resource_path == data_path and processed == is_processed):
		return
	data = load(data_path) as IngredientData
	is_processed = processed
	_apply_look()


func _on_pool_spawned() -> void:
	is_processed = false
	step_accuracies.clear()
	crate = null


func _apply_look() -> void:
	if data == null:
		return
	_body.mesh = IngredientLook.get_piece_mesh(data.piece_style, data.color, is_processed and data.needs_processing)
	_name_label.text = data.get_name_for(is_processed)
