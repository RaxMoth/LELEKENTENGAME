## The stash room shelves: one bag per unit in stock (up to what fits),
## tinted by product, plus a count. Shows what attackers come for.
## Packed product gets in through the drop crate in front: put a bag from
## the press into it (or a crafter does, take_bag()) and its units are
## stored — a full stash refuses it.
##
## Dependencies: Operation, Stash, ProductBag, ItemSocket, FloatingText3D, PlaceholderMesh3D,
##               Pools, Audio, Types autoloads, Palette, SfxSynth
class_name StashShelf
extends Node3D

const BAG_SIZE: Vector3 = Vector3(0.14, 0.18, 0.12)
## Bags farther than this from the camera aren't drawn (32 small boxes).
const BAG_DRAW_DISTANCE: float = 12.0

@export var operation: Operation
@export var columns: int = 8
@export var rows: int = 4
## Bag spacing along the shelf and between shelves.
@export var spacing: Vector2 = Vector2(0.2, 0.42)
@export var first_bag_offset: Vector3 = Vector3(-0.7, 0.62, 0.0)

var _bags: Array[PlaceholderMesh3D] = []

@onready var _count_label: Label3D = %CountLabel
@onready var _drop: ItemSocket = %Drop


func _ready() -> void:
	add_to_group(Types.GROUP_STASH_SHELF)
	_drop.accept_rule = _accepts_bag
	_drop.refusal_reason = _explain_refusal
	_drop.item_inserted.connect(func(item: Grabbable) -> void: _store_dropped.call_deferred(item as ProductBag))
	for row: int in rows:
		for column: int in columns:
			var bag: PlaceholderMesh3D = PlaceholderMesh3D.new()
			bag.shape_kind = PlaceholderMesh3D.ShapeKind.BOX
			bag.size = BAG_SIZE
			bag.position = first_bag_offset + Vector3(column * spacing.x, row * spacing.y, 0.0)
			bag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bag.visibility_range_end = BAG_DRAW_DISTANCE
			bag.visible = false
			add_child(bag)
			_bags.append(bag)
	operation.stash_changed.connect(refresh)
	refresh()


## Puts [param bag]'s units into the stash and the bag away. False (and
## nothing happens) when the stash has no room for it.
func take_bag(bag: ProductBag) -> bool:
	if bag == null or bag.recipe == null or operation.stash.get_free_space() < bag.units:
		return false
	var stored: int = operation.add_product(bag.recipe, bag.tier, bag.units)
	FloatingText3D.spawn("+%d %s" % [stored, tr(bag.recipe.display_name)], _drop.global_position + Vector3(0.0, 0.35, 0.0), Palette.GOLD, Global.get_world_root())
	Audio.play_sfx_at(SfxSynth.get_preset(&"coin"), _drop.global_position, 0.05)
	Pools.despawn(bag)
	return true


## Where bags go in (tests, crew).
func get_drop_socket() -> ItemSocket:
	return _drop


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


func _accepts_bag(item: Grabbable) -> bool:
	var bag: ProductBag = item as ProductBag
	return bag != null and operation.stash.get_free_space() >= bag.units


func _explain_refusal(item: Grabbable) -> String:
	if not item is ProductBag:
		return tr("Only packed bags go into the stash")
	return tr("Stash is full")


func _store_dropped(bag: ProductBag) -> void:
	if bag != null and bag.socket == _drop:
		take_bag(bag)
