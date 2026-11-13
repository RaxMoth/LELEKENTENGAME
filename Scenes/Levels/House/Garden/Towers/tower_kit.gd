## A tower in a box, bought at the tower depot in the garden. Pick it up,
## carry it outside, point at the ground where the tower should stand and
## pull the trigger: it is built there (TowerField checks the spot — outside,
## on open ground, not too close to another tower). Let go of it anywhere
## and it goes back onto the depot's table. Pooled.
##
## Dependencies: Grabbable, TowerData, TowerField, XRPointer, Palette
class_name TowerKit
extends Grabbable

## The tower inside.
var data: TowerData = null
## The field that builds it (set when the kit is bought).
var field: TowerField = null
## Where it rests until it is picked up (the depot's table).
var rest_position: Vector3 = Vector3.ZERO

@onready var _box: PlaceholderMesh3D = %Box
@onready var _stripe: PlaceholderMesh3D = %Stripe
@onready var _label: Label3D = %KitLabel


## Fills the box with a [param tower_data] tower for [param tower_field],
## resting at [param resting_at].
func setup(tower_data: TowerData, tower_field: TowerField, resting_at: Vector3) -> void:
	data = tower_data
	field = tower_field
	rest_position = resting_at
	global_position = resting_at
	_stripe.color = data.color
	_label.text = tr(data.display_name)


## The trigger builds the tower (the grip puts the kit down).
func get_display_name() -> String:
	return tr(data.display_name) if data != null else ""


func is_usable() -> bool:
	return true


func use(is_pressed: bool, pointer: XRPointer) -> void:
	if is_pressed and field != null:
		field.build_from_kit(self, pointer)


func _on_released_nowhere() -> void:
	global_position = rest_position
	rotation = Vector3.ZERO
