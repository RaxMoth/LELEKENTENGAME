## Where the lab keeps one ingredient: an open burlap sack or a wooden
## crate (IngredientData.storage), filled with a heap of it — mushrooms
## on straw, roots in dirt, leaves, a mound of crystals (IngredientLook).
## Grabbing it hands out a fresh piece and charges its price; a piece that
## comes back unused is refunded.
##
## Dependencies: IngredientItem, IngredientData, IngredientLook, SackMesh3D, CrateMesh3D,
##               Operation, InteractionQuery, Pools, Audio, Types autoloads, Palette
class_name IngredientCrate
extends Node3D

const ITEM_SCENE: PackedScene = preload("res://Scenes/Levels/House/Lab/IngredientItem.tscn")
## Space between the container's top and its price label.
const LABEL_GAP: float = 0.22

@export var ingredient: IngredientData

## The house's shared state (handed over by the Lab at setup); pays for pieces.
var operation: Operation = null
## Radius of the sphere hands and pointers grab it with.
@export var grab_radius: float = 0.3

@onready var _contents: MeshInstance3D = %Contents
@onready var _label: Label3D = %Label
@onready var _sack: SackMesh3D = %Sack
@onready var _crate: CrateMesh3D = %Crate


func _ready() -> void:
	add_to_group(Types.GROUP_GRAB_SOURCE)
	if ingredient != null:
		_label.text = "%s\n$%d" % [tr(ingredient.display_name), ingredient.cost]
		_apply_container()


## Shows the sack or the crate and heaps the ingredient in it.
func _apply_container() -> void:
	var is_sack: bool = ingredient.storage == IngredientData.Storage.SACK
	_sack.visible = is_sack
	_crate.visible = not is_sack
	# Varies the heap (and the sack's lumps) between the lab's containers.
	var look_seed: int = hash(ingredient.id)
	_sack.lump_seed = look_seed % 7
	var area: Vector2 = Vector2.ONE * _sack.radius * 1.8 if is_sack else _crate.get_inner_size()
	_contents.position.y = _sack.get_fill_height() if is_sack else _crate.get_fill_height()
	_contents.mesh = IngredientLook.build_heap_mesh(ingredient.piece_style, ingredient.color, area, is_sack, look_seed)
	_label.position.y = (_sack.height if is_sack else _crate.size.y) + LABEL_GAP


## Where hands and pointers grab it: the top of its contents.
func get_grab_center() -> Vector3:
	return _contents.global_position


## Hands out one new piece (InteractionQuery calls this on a grab), or null
## when the operation can't pay for it.
func take_item() -> Grabbable:
	if ingredient == null or operation == null or not operation.spend_cash(ingredient.cost, "ingredients"):
		Audio.play_ui(Audio.UI_ERROR)
		return null
	var item: IngredientItem = Pools.spawn(ITEM_SCENE, Global.get_world_root(), _contents.global_position + Vector3(0.0, 0.12, 0.0)) as IngredientItem
	item.setup(ingredient, self)
	return item


## A piece went back unused: refund it.
func take_back(item: IngredientItem) -> void:
	if operation != null and item.step_accuracies.is_empty():
		operation.refund_cash(ingredient.cost)
	Pools.despawn(item)
