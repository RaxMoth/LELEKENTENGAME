## A shroom plant on the lab's grow shelf: the first thing the operation
## has. It grows its crop on its own; once ripe, point at it and pull the
## trigger (or click) to harvest the shrooms straight into the stash, then
## it grows the next. Sell them at the back window. More plants come with
## the "More Plants" upgrade; the grinder, cooker and press come later.
## The cellar's grow racks use the same plant (grow lights speed it up, the
## auto picker harvests it).
## State: Growing (the cap swells) <-> Ripe (waiting for the harvest).
##
##   plant.setup(operation, shroom_recipe)
##   plant.set_active(Profile.upgrades.get_level(Types.UPGRADE_PLANTS) >= 1)
##   plant.growth_multiplier = 1.5          # grow lights
##   plant.hand_harvest_bonus = 1           # Green Thumb: +1 when picked by hand
##   plant.harvest(false)                   # a machine picks it (no bonus)
##
## Dependencies: PointerButton, Operation, RecipeData, FloatingText3D,
##               PlaceholderMesh3D, Palette, Audio, Global, Types autoloads, SfxSynth
class_name ShroomPlant
extends Node3D

## Shrooms went into the stash.
signal harvested(units: int)

## Seconds from harvest to the next ripe crop.
@export var grow_seconds: float = 45.0
## The smallest the crop starts at (share of its full size).
@export_range(0.1, 1.0, 0.05) var seedling_scale: float = 0.45
## Shows its own "Growing / Ripe" label (a rack shows one for all its plants instead).
@export var shows_status: bool = true

## Grows this many times faster (grow lights).
var growth_multiplier: float = 1.0
## Extra units when the player harvests it by hand (Green Thumb).
var hand_harvest_bonus: int = 0

## The house's shared state (handed over by the Lab); takes the harvest.
var operation: Operation = null
## The product it grows (a RecipeData with is_grown).
var crop: RecipeData = null

var _growth: float = 0.0
var _is_ripe: bool = false
var _is_active: bool = true

@onready var _crop_root: Node3D = %Crop
@onready var _cap: PlaceholderMesh3D = %Cap
@onready var _harvest_button: PointerButton = %HarvestButton
@onready var _status_label: Label3D = %StatusLabel
@onready var state_chart: StateChart = %StateChart


func _ready() -> void:
	add_to_group(Types.GROUP_NET_NODE)
	_harvest_button.pressed.connect(func(_button: PointerButton) -> void: harvest())

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


## Bought (or not yet): a spot not bought yet shows an empty pot (a hint
## that the office sells more plants) and grows nothing.
func set_active(is_active: bool) -> void:
	_is_active = is_active
	process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED
	_show_growth()


func is_active() -> bool:
	return _is_active


func get_harvest_button() -> PointerButton:
	return _harvest_button


func is_ripe() -> bool:
	return _is_ripe


## True when a harvest now would fit into the stash.
func can_store_harvest() -> bool:
	return operation != null and crop != null and operation.stash.get_free_space() >= operation.get_batch_size(crop)


## How far the current crop is (0..1).
func get_growth() -> float:
	return _growth


## Lets the crop grow [param seconds] at once (tests, showcases).
func grow(seconds: float) -> void:
	_advance(seconds)


## Picks the ripe crop: its units go into the stash, plus the
## hand_harvest_bonus when [param is_by_hand]. False when there is nothing
## ripe or the stash has no room.
func harvest(is_by_hand: bool = true) -> bool:
	if not _is_active or not _is_ripe or operation == null or crop == null:
		return false
	var units: int = operation.get_batch_size(crop) + (hand_harvest_bonus if is_by_hand else 0)
	if operation.stash.get_free_space() < units:
		FloatingText3D.spawn(tr("Stash is full"), _harvest_button.get_press_center() + Vector3(0.0, 0.2, 0.0), Palette.DANGER, Global.get_world_root())
		Audio.play_ui(Audio.UI_ERROR)
		return false
	var stored: int = operation.add_product(crop, QualityMath.MIN_TIER + 1, units)
	FloatingText3D.spawn("+%d %s" % [stored, tr(crop.display_name)], _harvest_button.get_press_center() + Vector3(0.0, 0.2, 0.0), Palette.GOLD, Global.get_world_root())
	Audio.play_sfx_at(SfxSynth.get_preset(&"pop"), global_position, 0.05, -4.0)
	state_chart.send_event(Types.EVENT_PLANT_HARVESTED)
	if is_by_hand:
		operation.record_hand_harvest()
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

func _advance(seconds: float) -> void:
	if _is_ripe:
		return
	_growth = minf(1.0, _growth + seconds * growth_multiplier / maxf(1.0, grow_seconds))
	_show_growth()
	if _growth >= 1.0:
		state_chart.send_event(Types.EVENT_PLANT_RIPE)


func _show_growth() -> void:
	if _crop_root == null:
		return
	_crop_root.visible = _is_active
	_status_label.visible = _is_active and shows_status
	_crop_root.scale = Vector3.ONE * lerpf(seedling_scale, 1.0, _growth)
	_cap.glow = 0.5 if _is_ripe else 0.0
	_harvest_button.is_enabled = _is_active and _is_ripe
	var crop_name: String = tr(crop.display_name) if crop != null else ""
	_status_label.text = (crop_name + "\n" + tr("Ripe: harvest")) if _is_ripe else (crop_name + "\n" + tr("Growing %d%%") % roundi(_growth * 100.0))
	_status_label.modulate = Palette.GOLD if _is_ripe else Palette.TEXT_MUTED
