## The stash room shelves: one bag per unit in stock (up to what fits),
## tinted by product, plus a count. Shows what attackers come for.
##
## Dependencies: Operation, Stash, PlaceholderMesh3D, Palette
class_name StashShelf
extends Node3D

const BAG_SIZE: Vector3 = Vector3(0.14, 0.18, 0.12)

@export var operation: Operation
@export var columns: int = 8
@export var rows: int = 4
## Bag spacing along the shelf and between shelves.
@export var spacing: Vector2 = Vector2(0.2, 0.42)
@export var first_bag_offset: Vector3 = Vector3(-0.7, 0.62, 0.0)

var _bags: Array[PlaceholderMesh3D] = []

@onready var _count_label: Label3D = %CountLabel


func _ready() -> void:
	for row: int in rows:
		for column: int in columns:
			var bag: PlaceholderMesh3D = PlaceholderMesh3D.new()
			bag.shape_kind = PlaceholderMesh3D.ShapeKind.BOX
			bag.size = BAG_SIZE
			bag.position = first_bag_offset + Vector3(column * spacing.x, row * spacing.y, 0.0)
			bag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bag.visible = false
			add_child(bag)
			_bags.append(bag)
	operation.stash_changed.connect(refresh)
	refresh()


func refresh() -> void:
	var stash: Stash = operation.stash
	var bag_index: int = 0
	for product_id: StringName in stash.get_product_ids():
		var recipe: RecipeData = operation.find_recipe(product_id)
		var units: int = stash.count(product_id)
		for unit: int in units:
			if bag_index >= _bags.size():
				break
			_bags[bag_index].color = recipe.color if recipe != null else Palette.TEXT_MUTED
			_bags[bag_index].visible = true
			bag_index += 1
	for hidden_index: int in range(bag_index, _bags.size()):
		_bags[hidden_index].visible = false
	_count_label.text = tr("Stash %d / %d") % [stash.get_total(), stash.capacity]
