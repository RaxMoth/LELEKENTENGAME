## A shroom plant on the lab's grow shelf: the first thing the operation
## has. It grows its crop on its own; once ripe, grab it (grip, or the
## trigger, or a click) and the shrooms come off as a bag in the hand
## (ProductBag) — carried to the drop crate on the stash shelf they are in
## the stash; let go anywhere else the bag goes back next to the pot. Then
## it grows the next. More plants come with the "More Plants" upgrade; the
## grinder, cooker and press come later. The cellar's grow racks use the
## same plant (grow lights speed it up, the auto picker harvests it straight
## into the stash).
## State: Growing (the cap swells) <-> Ripe (waiting for the harvest).
## While ripe it is a grab source (InteractionQuery: take_item()).
##
##   plant.setup(operation, shroom_recipe)
##   plant.set_active(Profile.upgrades.get_level(Types.UPGRADE_PLANTS) >= 1)
##   plant.growth_multiplier = 1.5          # grow lights
##   plant.hand_harvest_bonus = 1           # Green Thumb: +1 when picked by hand
##   var bag: ProductBag = plant.pick()     # by hand: a bag to carry
##   plant.harvest()                        # a machine: into the stash (no bonus)
##
## Dependencies: ProductBag, Operation, RecipeData, QualityMath, FloatingText3D,
##               PlaceholderMesh3D, Palette, Audio, Global, Pools, Types autoloads, SfxSynth
class_name ShroomPlant
extends Node3D

## The ripe crop came off: [param units] picked by hand into a bag, or by a
## machine into the stash.
signal harvested(units: int)

const BAG_SCENE: PackedScene = preload("res://Scenes/Levels/House/Lab/ProductBag.tscn")
## Where a picked bag waits when it is let go away from the stash crate
## (beside the pot, relative to the plant).
const BAG_REST_OFFSET: Vector3 = Vector3(0.17, 0.0, 0.06)

## Seconds from harvest to the next ripe crop.
@export var grow_seconds: float = 45.0
## The smallest the crop starts at (share of its full size).
@export_range(0.1, 1.0, 0.05) var seedling_scale: float = 0.45
## Shows its own "Growing / Ripe" label (a rack shows one for all its plants instead).
@export var shows_status: bool = true
## Hands and pointers grab the ripe crop within this radius of its cap (InteractionQuery).
@export var grab_radius: float = 0.15

## Grows this many times faster (grow lights).
var growth_multiplier: float = 1.0
## Extra units when the player harvests it by hand (Green Thumb).
var hand_harvest_bonus: int = 0

## The house's shared state (handed over by the Lab); takes the harvest.
var operation: Operation = null
## The product it grows (a RecipeData with is_grown).
var crop: RecipeData = null

var _growth: float = 0.0
## The growth percent the label last showed (-1 = not yet).
var _shown_percent: int = -1
var _is_ripe: bool = false
var _is_active: bool = true

@onready var _crop_root: Node3D = %Crop
@onready var _cap: PlaceholderMesh3D = %Cap
@onready var _status_label: Label3D = %StatusLabel
@onready var state_chart: StateChart = %StateChart


func _ready() -> void:
	add_to_group(Types.GROUP_NET_NODE)

# ============================================
# PUBLIC API
# ============================================

## Called by the Lab at setup: where the harvest goes and what grows.
func setup(house_operation: Operation, grown_recipe: RecipeData) -> void:
	operation = house_operation
	crop = grown_recipe
	if crop != null:
		_cap.color = crop.color
	_show_growth()


## Bought (or not yet): a spot not bought yet is hidden (pot and all) and
## grows nothing; More Plants puts the next pot on the shelf.
func set_active(is_active: bool) -> void:
	_is_active = is_active
	process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED
	visible = is_active
	_show_growth()


func is_active() -> bool:
	return _is_active


## Where hands and pointers grab the ripe crop: its cap.
func get_grab_center() -> Vector3:
	return _cap.global_position


func is_ripe() -> bool:
	return _is_ripe


## True when a machine's harvest now would fit into the stash.
func can_store_harvest() -> bool:
	return operation != null and crop != null and operation.stash.get_free_space() >= operation.get_batch_size(crop)


## How far the current crop is (0..1).
func get_growth() -> float:
	return _growth


## Lets the crop grow [param seconds] at once (tests, showcases).
func grow(seconds: float) -> void:
	_advance(seconds)


## Picks the ripe crop by hand: a bag of its units plus the
## hand_harvest_bonus, not in the stash yet (somebody carries it to the
## drop crate). Null when nothing is ripe.
func pick() -> ProductBag:
	if not _can_harvest():
		return null
	var units: int = operation.get_batch_size(crop) + hand_harvest_bonus
	var bag: ProductBag = Pools.spawn(BAG_SCENE, Global.get_world_root(), get_grab_center()) as ProductBag
	bag.setup(crop, QualityMath.MIN_TIER + 1, units)
	bag.rest_position = global_transform * BAG_REST_OFFSET
	Audio.play_sfx_at(SfxSynth.get_preset(&"pop"), global_position, 0.05, -4.0)
	state_chart.send_event(Types.EVENT_PLANT_HARVESTED)
	operation.record_hand_harvest()
	harvested.emit(units)
	return bag


## Grab source (InteractionQuery): a hand that grabs the ripe crop gets its bag.
func take_item() -> Grabbable:
	return pick()


## A machine (the auto picker) harvests the ripe crop straight into the
## stash, without the hand bonus. False when there is nothing ripe or the
## stash has no room.
func harvest() -> bool:
	if not _can_harvest():
		return false
	var units: int = operation.get_batch_size(crop)
	if operation.stash.get_free_space() < units:
		FloatingText3D.spawn(tr("Stash is full"), get_grab_center() + Vector3(0.0, 0.2, 0.0), Palette.DANGER, Global.get_world_root())
		return false
	var stored: int = operation.add_product(crop, QualityMath.MIN_TIER + 1, units)
	FloatingText3D.spawn("+%d %s" % [stored, tr(crop.display_name)], get_grab_center() + Vector3(0.0, 0.2, 0.0), Palette.GOLD, Global.get_world_root())
	Audio.play_sfx_at(SfxSynth.get_preset(&"pop"), global_position, 0.05, -4.0)
	state_chart.send_event(Types.EVENT_PLANT_HARVESTED)
	harvested.emit(stored)
	return true


## Co-op: how the plant looks — [growth, ripe].
func get_net_state() -> Array:
	return [_growth, _is_ripe]


## Co-op guest: show the host's plant.
func apply_net_state(state: Array) -> void:
	_growth = float(state[0])
	_is_ripe = bool(state[1])
	_show_growth()

# ============================================
# STATE CHART CALLBACKS (connected in ShroomPlant.tscn)
# ============================================

func _on_growing_state_entered() -> void:
	_is_ripe = false
	_growth = 0.0
	_show_growth()


func _on_growing_state_processing(delta: float) -> void:
	_advance(delta)


func _on_ripe_state_entered() -> void:
	_is_ripe = true
	_growth = 1.0
	_show_growth()

# ============================================
# INTERNALS
# ============================================

func _can_harvest() -> bool:
	return _is_active and _is_ripe and operation != null and crop != null


func _advance(seconds: float) -> void:
	if _is_ripe:
		return
	_growth = minf(1.0, _growth + seconds * growth_multiplier / maxf(1.0, grow_seconds))
	# The label shows whole percents: redraw only when that changes.
	if roundi(_growth * 100.0) != _shown_percent:
		_show_growth()
	if _growth >= 1.0:
		state_chart.send_event(Types.EVENT_PLANT_RIPE)


func _show_growth() -> void:
	if _crop_root == null:
		return
	_shown_percent = roundi(_growth * 100.0)
	_crop_root.visible = _is_active
	_status_label.visible = _is_active and shows_status
	_crop_root.scale = Vector3.ONE * lerpf(seedling_scale, 1.0, _growth)
	_cap.glow = 0.5 if _is_ripe else 0.0
	# Only a ripe crop can be grabbed.
	if _is_active and _is_ripe:
		add_to_group(Types.GROUP_GRAB_SOURCE)
	elif is_in_group(Types.GROUP_GRAB_SOURCE):
		remove_from_group(Types.GROUP_GRAB_SOURCE)
	var crop_name: String = tr(crop.display_name) if crop != null else ""
	_status_label.text = (crop_name + "\n" + tr("Ripe: grab to pick")) if _is_ripe else (crop_name + "\n" + tr("Growing %d%%") % roundi(_growth * 100.0))
	_status_label.modulate = Palette.GOLD if _is_ripe else Palette.TEXT_MUTED
