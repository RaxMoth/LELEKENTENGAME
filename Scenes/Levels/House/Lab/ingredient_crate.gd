## A crate of one ingredient. Grabbing it hands out a fresh piece and charges
## its price; a piece that comes back unused is refunded.
##
## Dependencies: IngredientItem, IngredientData, Operation, InteractionQuery,
##               Pools, Audio, Types autoloads, Palette
class_name IngredientCrate
extends Node3D

const ITEM_SCENE: PackedScene = preload("res://Scenes/Levels/House/Lab/IngredientItem.tscn")

@export var ingredient: IngredientData
@export var operation: Operation
## Radius of the sphere hands and pointers grab it with.
@export var grab_radius: float = 0.3

@onready var _contents: PlaceholderMesh3D = %Contents
@onready var _label: Label3D = %Label


func _ready() -> void:
	add_to_group(Types.GROUP_GRAB_SOURCE)
	if ingredient != null:
		_contents.color = ingredient.color
		_label.text = "%s\n$%d" % [tr(ingredient.display_name), ingredient.cost]


## Where hands and pointers grab it: the top of the crate.
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
