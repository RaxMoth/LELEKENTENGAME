## The lab's automation from the office's Automation tab. Conveyor belts
## carry a finished result on to the next station (the grinder's ground
## ingredient along a belt into the cooker, the cooker's batch over an
## overhead rail into the press); the ingredient hopper buys the ingredients
## of the last recipe cooked from the crates and feeds them in (into the
## grinder, or straight into the cooker when they need no grinding), one at
## a time, again and again. With motors on every station the lab then runs
## itself into the stash. Items glide along waypoints, then drop into the
## next station's slot; a hand can still grab one on the way.
##
## A stateless helper the Lab advances during a shift (so nothing runs or
## spends cash outside one); it looks for work a few times a second.
##
##   automation.setup(operation, crates)
##   automation.set_parts(has_conveyor, has_hopper)   # Lab.apply_upgrades()
##   automation.advance(delta)                          # Lab._shift_process()
##
## Dependencies: Workstation, IngredientCrate, ItemSocket, Grabbable, RecipeData,
##               AutomationMath, Operation, Pools, Audio autoloads, SfxSynth
class_name LabAutomation
extends Node3D

## Seconds between looks for work (moving items needs no per-frame check).
const CHECK_SECONDS: float = 0.25

@export var grinder: Workstation
@export var cooker: Workstation
@export var press: Workstation
## Waypoints from the grinder's tray along the belt to the cooker.
@export var belt_waypoints: Array[Node3D] = []
## Waypoints from the cooker's tray up over the room and down behind the press.
@export var rail_waypoints: Array[Node3D] = []
## Top of the hopper's bin: ingredients for the grinder drop in here.
@export var hopper_drop: Node3D
## Meters per second an item travels.
@export var travel_speed: float = 1.4
## Height the hopper lifts ingredients to on their way from the crates.
@export var hopper_lift_height: float = 1.8

var operation: Operation = null
var crates: Array[IngredientCrate] = []
var has_conveyor: bool = false
var has_hopper: bool = false
## The recipe the hopper feeds: the last one cooked (null until then).
var hopper_recipe: RecipeData = null

var _seconds_until_check: float = 0.0
## Items on their way (by instance id), and the slot each is headed for.
var _in_transit: Dictionary[int, ItemSocket] = {}
## The glide of each item on its way (by instance id).
var _glides: Dictionary[int, Tween] = {}

# ============================================
# PUBLIC API
# ============================================

## Called by the Lab at setup: the shared cash and where ingredients come from.
func setup(house_operation: Operation, ingredient_crates: Array[IngredientCrate]) -> void:
	operation = house_operation
	crates = ingredient_crates
	cooker.batch_cooked.connect(func(recipe: RecipeData) -> void: hopper_recipe = recipe)


## Which parts are bought (Lab.apply_upgrades()).
func set_parts(conveyor_bought: bool, hopper_bought: bool) -> void:
	has_conveyor = conveyor_bought
	has_hopper = hopper_bought


## True while an item is on its way somewhere.
func is_moving() -> bool:
	return not _in_transit.is_empty()


## Called every frame while the shift runs.
func advance(delta: float) -> void:
	_seconds_until_check -= delta
	if _seconds_until_check <= 0.0:
		_seconds_until_check = CHECK_SECONDS
		step()


## One look for work right now (also tests): moves finished results on and
## lets the hopper feed the next ingredient.
func step() -> void:
	if operation == null:
		return
	if has_conveyor:
		_carry_on(grinder, cooker, belt_waypoints)
		_carry_on(cooker, press, rail_waypoints)
	if has_hopper and has_conveyor:
		_feed_hopper()

# ============================================
# INTERNALS
# ============================================

## Sends the result on [param from]'s tray into a free slot of [param to].
func _carry_on(from: Workstation, to: Workstation, waypoints: Array[Node3D]) -> void:
	if not from.visible or not to.visible or _is_heading_to(to):
		return
	var item: Grabbable = from.get_output_socket().item
	if item == null:
		return
	var target: ItemSocket = _find_free_slot(to, item)
	if target == null:
		return
	from.get_output_socket().remove_item()
	var path: Array[Vector3] = []
	for waypoint: Node3D in waypoints:
		path.append(waypoint.global_position)
	_send(item, target, path)


## Buys the next missing ingredient of hopper_recipe and drops it into the
## grinder (or straight into the cooker when it needs no grinding).
func _feed_hopper() -> void:
	if hopper_recipe == null or not grinder.visible or not cooker.visible:
		return
	# One ingredient at a time, and none while the last batch still waits to move on.
	if _is_heading_to(grinder) or _is_heading_to(cooker) or cooker.is_running() or not cooker.get_output_socket().is_empty():
		return
	var recipe_ids: Array[StringName] = []
	for ingredient: IngredientData in hopper_recipe.ingredients:
		recipe_ids.append(ingredient.id)
	var missing: Array[StringName] = AutomationMath.get_missing_ingredients(recipe_ids, _get_ingredients_on_the_way())
	if missing.is_empty():
		return
	var crate: IngredientCrate = _find_crate(missing[0])
	if crate == null:
		return
	var station: Workstation = grinder if crate.ingredient.needs_processing else cooker
	if station.is_running() or not station.get_output_socket().is_empty():
		return
	var item: Grabbable = crate.take_item()
	if item == null:
		return
	var target: ItemSocket = _find_free_slot(station, item)
	if target == null:
		crate.take_back(item as IngredientItem)
		return
	var start: Vector3 = item.global_position
	var above_target: Vector3 = Vector3(target.global_position.x, hopper_lift_height, target.global_position.z)
	var via: Vector3 = hopper_drop.global_position if station == grinder and hopper_drop != null else above_target
	_send(item, target, [Vector3(start.x, hopper_lift_height, start.z), via])


## Ingredient ids already in the grinder or cooker, on the grinder's tray
## or travelling to either.
func _get_ingredients_on_the_way() -> Array[StringName]:
	var items: Array[Grabbable] = []
	for socket: ItemSocket in grinder.get_input_sockets() + cooker.get_input_sockets():
		if socket.item != null:
			items.append(socket.item)
	if grinder.get_output_socket().item != null:
		items.append(grinder.get_output_socket().item)
	for item_id: int in _in_transit:
		var moving: Grabbable = instance_from_id(item_id) as Grabbable
		if moving != null:
			items.append(moving)
	var ids: Array[StringName] = []
	for item: Grabbable in items:
		var ingredient: IngredientItem = item as IngredientItem
		if ingredient != null and ingredient.data != null:
			ids.append(ingredient.data.id)
	return ids


## Glides [param item] through [param waypoints] into [param target].
func _send(item: Grabbable, target: ItemSocket, waypoints: Array[Vector3]) -> void:
	var item_id: int = item.get_instance_id()
	_in_transit[item_id] = target
	var points: Array[Vector3] = [item.global_position]
	points.append_array(waypoints)
	points.append(target.global_position)
	var tween: Tween = create_tween()
	_glides[item_id] = tween
	for point_index: int in range(1, points.size()):
		var seconds: float = maxf(0.05, points[point_index - 1].distance_to(points[point_index]) / travel_speed)
		tween.tween_method(_glide.bind(item_id), points[point_index - 1], points[point_index], seconds)
	tween.tween_callback(_arrive.bind(item_id, target))
	Audio.play_sfx_at(SfxSynth.get_preset(&"machine"), item.global_position, 0.1, -12.0)


## One step of the glide. An item a hand grabbed on the way (or that went
## back into its pool) is no longer this belt's: its glide stops.
func _glide(point: Vector3, item_id: int) -> void:
	var item: Grabbable = instance_from_id(item_id) as Grabbable
	if item == null or item.is_held() or Pools.is_in_pool(item):
		_cancel(item_id)
		return
	item.global_position = point


## Drops an item's glide and its place on the way.
func _cancel(item_id: int) -> void:
	if _glides.has(item_id):
		_glides[item_id].kill()
	_glides.erase(item_id)
	_in_transit.erase(item_id)


func _arrive(item_id: int, target: ItemSocket) -> void:
	_in_transit.erase(item_id)
	_glides.erase(item_id)
	var item: Grabbable = instance_from_id(item_id) as Grabbable
	if item == null or item.is_held() or Pools.is_in_pool(item):
		return
	if target.can_accept(item):
		target.insert(item)
	else:
		# The slot was taken meanwhile: it finds another one nearby, or rests where it is.
		item.drop_nowhere()


func _find_free_slot(station: Workstation, item: Grabbable) -> ItemSocket:
	for socket: ItemSocket in station.get_input_sockets():
		if socket.can_accept(item):
			return socket
	return null


func _is_heading_to(station: Workstation) -> bool:
	for socket: ItemSocket in station.get_input_sockets():
		if _in_transit.values().has(socket):
			return true
	return false


func _find_crate(ingredient_id: StringName) -> IngredientCrate:
	for crate: IngredientCrate in crates:
		if crate.ingredient != null and crate.ingredient.id == ingredient_id:
			return crate
	return null
