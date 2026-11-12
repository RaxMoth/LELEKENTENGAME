## One piece of an ingredient in the lab: grabbed from its crate, ground at
## the grinder (if it needs it) and cooked. Remembers how well each step went.
## Dropped anywhere else an unused piece goes back into its crate (and the
## cash comes back); a ground piece goes back to its station's tray.
##
## Dependencies: Grabbable, IngredientData, IngredientCrate, PlaceholderMesh3D, Pools autoload
class_name IngredientItem
extends Grabbable

const RAW_SIZE: float = 0.12
const POWDER_SIZE: Vector3 = Vector3(0.12, 0.06, 0.12)

var data: IngredientData = null
var is_processed: bool = false
## Accuracy of every lab step this piece went through.
var step_accuracies: Array[float] = []
var crate: IngredientCrate = null

@onready var _body: PlaceholderMesh3D = %Body
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
	return _body.global_position


## Nowhere to go: an unused piece returns to its crate; worked pieces stay
## where they were let go (never destroyed, the work is not lost).
func _on_released_nowhere() -> void:
	if not step_accuracies.is_empty():
		return
	if crate != null and is_instance_valid(crate):
		crate.take_back(self)
	else:
		Pools.despawn(self)


func _on_pool_spawned() -> void:
	is_processed = false
	step_accuracies.clear()
	crate = null


func _apply_look() -> void:
	if data == null:
		return
	_body.color = data.color
	if is_processed and data.needs_processing:
		_body.shape_kind = PlaceholderMesh3D.ShapeKind.CYLINDER
		_body.size = POWDER_SIZE
	else:
		_body.shape_kind = data.shape_kind
		_body.size = Vector3.ONE * RAW_SIZE
	_name_label.text = data.get_name_for(is_processed)
