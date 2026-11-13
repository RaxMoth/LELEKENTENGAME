## The cellar under the stash room and the office (house area). Until
## "Dig the Cellar" is bought, planks are nailed over its opening in the
## stash-room floor and the room below stays hidden. Bought, the planks come
## off: wooden stairs lead down to a brick cellar with grow racks (one per
## "Grow Racks" level, faster under "Grow Lights") and a gantry auto picker
## under the ceiling that harvests them ("Auto Picker"). The picker only
## works during a shift.
##
## Opening it adds the stairs (a WalkableRamp), the cellar floor (a
## WalkableFloor) and the stairwell hole in the main floor to the player's
## WalkableArea, so the player walks down and up again.
##
## Dependencies: HouseFront, GrowRack, AutoPicker, ShroomPlant, Stairs3D, WalkableArea,
##               WalkableFloor, WalkableRamp, RecipeData, Operation, Profile, Types autoloads
class_name Cellar
extends HouseFront

## Height of the cellar floor.
@export var floor_height: float = -2.6
## Opening in the main floor the player can't stand on: the stairwell
## without its top step. West of it a landing about 0.7 m wide (wall to
## railing) leads onto the stairs.
@export var stairwell_hole: Rect2 = Rect2(1.76, 1.62, 2.54, 1.0)
## Where the player can walk on the cellar floor (around the racks, not under the stairs).
@export var floor_regions: Array[Rect2] = []
## What the racks grow (the grown recipe, shrooms).
@export var crop: RecipeData

var _is_open: bool = false
var _has_walkable: bool = false
var _cellar_floor: WalkableFloor = null
var _stairs_ramp: WalkableRamp = null

@onready var _boards: Node3D = %Boards
@onready var _below: Node3D = %Below
@onready var _stairs: Stairs3D = %Stairs
@onready var _racks: Node3D = %Racks
@onready var _picker: AutoPicker = %AutoPicker
@onready var _cellar_shell: HouseShell = %CellarShell
@onready var _stairwell_ground_hole: GroundHole = %StairwellHole


func _on_setup() -> void:
	_cellar_floor = WalkableFloor.create(floor_height, floor_regions)
	_stairs_ramp = _stairs.get_ramp(WalkableArea.BODY_RADIUS)
	for rack: GrowRack in get_racks():
		rack.setup(context.operation, crop)
	_picker.setup(get_plants())
	# A harvesting level-up adds to every hand harvest from now on.
	context.operation.skill_leveled.connect(func(_skill: int, _level: int) -> void: _apply_cellar())
	_apply_cellar()


func apply_upgrades() -> void:
	_apply_cellar()


func on_shift_started() -> void:
	_picker.set_working(true)


func finish_shift(_result: LevelResult) -> void:
	_picker.set_working(false)


func _refresh_displays() -> void:
	for rack: GrowRack in get_racks():
		if rack.is_active():
			rack.refresh_label()

# ============================================
# PUBLIC API
# ============================================

## True once "Dig the Cellar" is bought (the stairs are open).
func is_open() -> bool:
	return _is_open


func get_racks() -> Array[GrowRack]:
	var racks: Array[GrowRack] = []
	for child: Node in _racks.get_children():
		var rack: GrowRack = child as GrowRack
		if rack != null:
			racks.append(rack)
	return racks


## Every plant on every rack (bought or not).
func get_plants() -> Array[ShroomPlant]:
	var plants: Array[ShroomPlant] = []
	for rack: GrowRack in get_racks():
		plants.append_array(rack.get_plants())
	return plants


func get_picker() -> AutoPicker:
	return _picker


func get_stairs() -> Stairs3D:
	return _stairs


## The stairwell opening (x, z) as the ground planes leave it out.
func get_opening() -> Rect2:
	return _stairwell_ground_hole.get_world_rect()


## The cellar's own walls, floor and ceiling (with the stairwell opening).
func get_cellar_shell() -> HouseShell:
	return _cellar_shell

# ============================================
# INTERNALS
# ============================================

func _apply_cellar() -> void:
	var operation: Operation = context.operation
	_set_open(Profile.upgrades.is_owned(Types.UPGRADE_CELLAR))
	var rack_count: int = Profile.upgrades.get_level(Types.UPGRADE_GROW_RACKS) if _is_open else 0
	var racks: Array[GrowRack] = get_racks()
	for rack_index: int in racks.size():
		racks[rack_index].set_active(rack_index < rack_count)
		racks[rack_index].set_growth(operation.get_grow_light_multiplier(), operation.get_hand_harvest_bonus())
	_picker.set_pick_seconds(operation.get_picker_seconds() if rack_count > 0 else 0.0)
	_refresh_displays()


## Shows the cellar (or the planks over its opening) and adds or removes
## its floors from the player's walkable area.
func _set_open(is_open: bool) -> void:
	_is_open = is_open
	_boards.visible = not is_open
	_below.visible = is_open
	var walkable: WalkableArea = context.rig.walkable_area
	if walkable == null or is_open == _has_walkable:
		return
	_has_walkable = is_open
	if is_open:
		_step_off_the_opening()
		walkable.add_hole(stairwell_hole)
		walkable.add_ramp(_stairs_ramp)
		walkable.add_floor(_cellar_floor)
	else:
		walkable.remove_hole(stairwell_hole)
		walkable.remove_ramp(_stairs_ramp)
		walkable.remove_floor(_cellar_floor)


## Someone standing on the planks when they come off steps beside the opening.
func _step_off_the_opening() -> void:
	var feet: Vector3 = context.rig.get_feet_position()
	if absf(feet.y) < WalkableArea.MAX_STEP and stairwell_hole.has_point(Vector2(feet.x, feet.z)):
		context.rig.locomotion.teleport_to(Vector3(feet.x, 0.0, stairwell_hole.end.y + WalkableArea.BODY_RADIUS))
