## A lab station: the grinder (process), the cooker (combine) or the press
## (package). Put the right items into its sockets and it starts its skill
## check — a needle sweeping over a bar. Press the plunger while the needle
## is in the green zone; the closer to its middle, the better the product.
## A bought motor (set_motorized) stops the needle on its own after
## motor_seconds with motor_accuracy (Good); pressing Stop first can still do better.
## Without power (the fuse box tripped) it stands still; while it burns
## (StationFire, the cooker) it takes nothing and starts nothing.
## State: Idle (waiting for inputs) <-> Running (the gauge sweeps).
##
## Dependencies: TimingGauge, QualityMath, IngredientItem, BatchItem,
##               ItemSocket, PointerButton, Operation, FloatingText3D,
##               PopEffect3D, PlaceholderMesh3D, Palette, Pools, Audio,
##               Types autoloads, SfxSynth
class_name Workstation
extends Node3D

## The press finished: units went into the stash.
signal product_packaged(recipe: RecipeData, tier: int, units: int)
signal step_finished(step: Types.CraftStep, accuracy: float)
## The cooker turned its ingredients into a batch of [param recipe].
signal batch_cooked(recipe: RecipeData)

const BATCH_SCENE: PackedScene = preload("res://Scenes/Levels/House/Lab/BatchItem.tscn")
const GAUGE_LENGTH: float = 0.5
const GAUGE_THICKNESS: float = 0.035

@export var step: Types.CraftStep = Types.CraftStep.PROCESS
@export var station_name: String = "Station"
## Needle sweeps per second (the cooker uses the recipe's own).
@export var sweeps_per_second: float = 0.6
## Width of the sweet zone before equipment upgrades (the cooker uses the recipe's).
@export var zone_width: float = 0.22
@export_group("Motor")
## Seconds a motor lets the needle sweep before it stops it.
@export_range(0.5, 20.0, 0.5) var motor_seconds: float = 4.0
## Accuracy a motor stops the needle at (0.6 = Good, never Perfect).
@export_range(0.0, 1.0, 0.05) var motor_accuracy: float = 0.6

## The house's shared state (handed over by the Lab at setup).
var operation: Operation = null

var _gauge: TimingGauge = null
var _active_recipe: RecipeData = null
var _needle: MeshInstance3D = null
var _zone: MeshInstance3D = null
var _has_motor: bool = false
var _running_seconds: float = 0.0
var _has_power: bool = true
var _is_burning: bool = false

@onready var _inputs: Node3D = %Inputs
@onready var _output: ItemSocket = %Output
@onready var _stop_button: PointerButton = %StopButton
@onready var _status_label: Label3D = %StatusLabel
@onready var _gauge_root: Node3D = %Gauge
@onready var state_chart: StateChart = %StateChart


func _ready() -> void:
	add_to_group(Types.GROUP_NET_NODE)
	for socket: ItemSocket in get_input_sockets():
		socket.accept_rule = _accepts_input
		socket.refusal_reason = _explain_refusal
		socket.shows_empty_marker = true
		socket.item_inserted.connect(func(_item: Grabbable) -> void: _try_start.call_deferred())
		socket.item_removed.connect(func(_item: Grabbable) -> void: _update_idle_status.call_deferred())
		socket.item_refused.connect(_on_input_refused)
	# Only the station itself puts things on its output tray.
	# Only the station puts things on its output tray (and takes its own back).
	_output.accept_rule = func(item: Grabbable) -> bool: return item.home_socket == _output
	_output.item_removed.connect(func(_item: Grabbable) -> void: _try_start.call_deferred())
	_stop_button.pressed.connect(_on_stop_pressed)
	_build_gauge()

# ============================================
# PUBLIC API
# ============================================

## Power off (the fuse box tripped): the needle stops where it is and
## nothing starts until the power is back.
func set_powered(is_powered: bool) -> void:
	if is_powered == _has_power:
		return
	_has_power = is_powered
	_stop_button.is_enabled = is_powered and is_running()
	if is_powered:
		_try_start.call_deferred()
	_update_idle_status()


## On fire (the cooker with a batch left on it): it takes nothing and
## starts nothing until the fire is out.
func set_burning(is_burning: bool) -> void:
	if is_burning == _is_burning:
		return
	_is_burning = is_burning
	if not is_burning:
		_try_start.call_deferred()
	_update_idle_status()


func is_burning() -> bool:
	return _is_burning


## Called by the Lab at the start of a shift.
func setup(house_operation: Operation) -> void:
	operation = house_operation
	# A full stash holds the press back; start as soon as there is room again.
	operation.stash_changed.connect(func() -> void: _try_start.call_deferred())

func get_input_sockets() -> Array[ItemSocket]:
	var sockets: Array[ItemSocket] = []
	for child: Node in _inputs.get_children():
		if child is ItemSocket:
			sockets.append(child as ItemSocket)
	return sockets


func get_output_socket() -> ItemSocket:
	return _output


func get_stop_button() -> PointerButton:
	return _stop_button


func is_running() -> bool:
	return _gauge != null


## Bought (or not yet): an inactive station is hidden — its slots take
## nothing and its button can't be pressed — and runs no skill check.
func set_active(is_active: bool) -> void:
	visible = is_active
	process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED


## A bought motor finishes the skill check on its own (motor_accuracy after motor_seconds).
func set_motorized(has_motor: bool) -> void:
	_has_motor = has_motor


func is_motorized() -> bool:
	return _has_motor


## The running skill check (tests and tutorials), or null while idle.
func get_gauge() -> TimingGauge:
	return _gauge


## Co-op: how the station looks right now — [running, needle, zone center,
## zone width, status text].
func get_net_state() -> Array:
	if _gauge == null:
		return [false, 0.0, 0.5, 0.0, _status_label.text]
	return [true, _gauge.get_needle(), _gauge.zone_center, _gauge.zone_width, _status_label.text]


## Co-op client: show the host's station (its gauge, needle and status).
func apply_net_state(state: Array) -> void:
	var is_gauge_running: bool = bool(state[0])
	_gauge_root.visible = is_gauge_running
	_stop_button.visible = is_gauge_running
	_stop_button.is_enabled = is_gauge_running
	if is_gauge_running:
		_needle.position.x = (float(state[1]) - 0.5) * GAUGE_LENGTH
		_zone.scale.x = float(state[3]) * GAUGE_LENGTH
		_zone.position.x = (float(state[2]) - 0.5) * GAUGE_LENGTH
	_status_label.text = str(state[4])

# ============================================
# STATE CHART CALLBACKS (connected in Workstation.tscn)
# ============================================

func _on_idle_state_entered() -> void:
	_gauge = null
	_active_recipe = null
	_stop_button.is_enabled = false
	# Only a running skill check has a button to press.
	_stop_button.visible = false
	_gauge_root.visible = false
	_set_inputs_removable(true)
	_update_idle_status()


func _on_running_state_entered() -> void:
	var sweep_rate: float = _active_recipe.cook_sweeps_per_second if step == Types.CraftStep.COMBINE and _active_recipe != null else sweeps_per_second
	var base_width: float = _active_recipe.cook_zone_width if step == Types.CraftStep.COMBINE and _active_recipe != null else zone_width
	var width: float = minf(0.8, base_width * operation.get_sweet_zone_multiplier())
	sweep_rate *= operation.get_needle_speed_multiplier()
	_running_seconds = 0.0
	_gauge = TimingGauge.new(sweep_rate, width, randf_range(width * 0.5 + 0.1, 1.0 - width * 0.5 - 0.05))
	_zone.scale.x = width * GAUGE_LENGTH
	_zone.position.x = (_gauge.zone_center - 0.5) * GAUGE_LENGTH
	_gauge_root.visible = true
	_stop_button.visible = true
	_stop_button.is_enabled = true
	_set_inputs_removable(false)
	var running_hint: String = tr("Press Stop in the green, or the motor stops it") if _has_motor else tr("Press Stop when the needle is in the green")
	_status_label.text = tr(station_name) + "\n" + running_hint
	Audio.play_sfx_at(SfxSynth.get_preset(&"pop"), global_position, 0.1, -10.0)


func _on_running_state_processing(delta: float) -> void:
	if _gauge == null or not _has_power:
		return
	_gauge.advance(delta)
	_needle.position.x = (_gauge.get_needle() - 0.5) * GAUGE_LENGTH
	_running_seconds += delta
	if _has_motor and _running_seconds >= motor_seconds:
		_finish(motor_accuracy)

# ============================================
# INTERNALS
# ============================================

func _accepts_input(item: Grabbable) -> bool:
	if is_running() or operation == null or _is_burning:
		return false
	match step:
		Types.CraftStep.PROCESS:
			var ingredient: IngredientItem = item as IngredientItem
			return ingredient != null and not ingredient.is_processed
		Types.CraftStep.COMBINE:
			var cook_ingredient: IngredientItem = item as IngredientItem
			if cook_ingredient == null or not cook_ingredient.is_processed:
				return false
			var ingredient_ids: Array[StringName] = _get_input_ingredient_ids()
			ingredient_ids.append(cook_ingredient.data.id)
			for recipe: RecipeData in operation.get_unlocked_recipes():
				if not recipe.is_grown and recipe.accepts_partial(ingredient_ids):
					return true
			return false
		Types.CraftStep.PACKAGE:
			return item is BatchItem
	return false


func _try_start() -> void:
	if operation == null or not _has_power or _is_burning:
		_update_idle_status()
		return
	if is_running() or not _output.is_empty():
		_update_idle_status()
		return
	match step:
		Types.CraftStep.PROCESS, Types.CraftStep.PACKAGE:
			if _get_input_items().is_empty():
				_update_idle_status()
				return
			if step == Types.CraftStep.PACKAGE:
				_active_recipe = (_get_input_items()[0] as BatchItem).recipe
				if operation.stash.get_free_space() < operation.get_batch_size(_active_recipe):
					_status_label.text = tr("Stash is full")
					return
		Types.CraftStep.COMBINE:
			_active_recipe = _find_matching_recipe()
			if _active_recipe == null:
				_update_idle_status()
				return
	state_chart.send_event(Types.EVENT_STATION_START)


func _on_stop_pressed(_button: PointerButton) -> void:
	if _gauge == null:
		return
	var accuracy: float = _gauge.stop()
	# Stopped by hand (not by the motor): the player's crafting grows.
	if operation != null:
		operation.record_craft(accuracy)
	_finish(accuracy)


## The skill check ended with [param accuracy] (the player's press or the motor).
func _finish(accuracy: float) -> void:
	if _gauge == null:
		return
	# Over: a motor must not finish it a second time before the state changes.
	_gauge = null
	_complete(accuracy)
	step_finished.emit(step, accuracy)
	state_chart.send_event(Types.EVENT_STATION_DONE)
	_try_start.call_deferred()


func _complete(accuracy: float) -> void:
	var feedback_position: Vector3 = _output.global_position + Vector3(0.0, 0.3, 0.0)
	FloatingText3D.spawn(_describe_accuracy(accuracy), feedback_position, _accuracy_color(accuracy), Global.get_world_root())
	match step:
		Types.CraftStep.PROCESS:
			var ingredient: IngredientItem = _get_input_items()[0] as IngredientItem
			ingredient.socket.remove_item()
			ingredient.mark_processed(accuracy)
			ingredient.home_socket = _output
			_output.insert(ingredient)
		Types.CraftStep.COMBINE:
			var accuracies: Array[float] = []
			for item: Grabbable in _get_input_items():
				var ingredient: IngredientItem = item as IngredientItem
				accuracies.append_array(ingredient.step_accuracies)
				item.socket.remove_item()
				Pools.despawn(item)
			accuracies.append(accuracy)
			var batch: BatchItem = Pools.spawn(BATCH_SCENE, Global.get_world_root(), _output.global_position) as BatchItem
			batch.setup(_active_recipe, accuracies)
			batch.home_socket = _output
			_output.insert(batch)
			PopEffect3D.spawn(_output.global_position, _active_recipe.color, 0.5, Global.get_world_root())
			batch_cooked.emit(_active_recipe)
		Types.CraftStep.PACKAGE:
			var batch_item: BatchItem = _get_input_items()[0] as BatchItem
			if operation.stash.get_free_space() < operation.get_batch_size(batch_item.recipe):
				# The stash filled up during the skill check: keep the batch for later.
				_status_label.text = tr("Stash is full")
				return
			var accuracies_so_far: Array[float] = batch_item.step_accuracies.duplicate()
			accuracies_so_far.append(accuracy)
			var tier: int = QualityMath.tier_from_score(QualityMath.combine(accuracies_so_far, operation.get_equipment_bonus()))
			var units: int = operation.add_product(batch_item.recipe, tier, operation.get_batch_size(batch_item.recipe))
			batch_item.socket.remove_item()
			Pools.despawn(batch_item)
			FloatingText3D.spawn("%s ×%d" % [tr(QualityMath.get_tier_name(tier)), units], feedback_position + Vector3(0.0, 0.25, 0.0), Palette.GOLD, Global.get_world_root())
			Audio.play_sfx_at(SfxSynth.get_preset(&"coin"), global_position, 0.05)
			product_packaged.emit(batch_item.recipe, tier, units)


func _get_input_items() -> Array[Grabbable]:
	var items: Array[Grabbable] = []
	for socket: ItemSocket in get_input_sockets():
		if socket.item != null:
			items.append(socket.item)
	return items


func _get_input_ingredient_ids() -> Array[StringName]:
	var ingredient_ids: Array[StringName] = []
	for item: Grabbable in _get_input_items():
		var ingredient: IngredientItem = item as IngredientItem
		if ingredient != null:
			ingredient_ids.append(ingredient.data.id)
	return ingredient_ids


func _find_matching_recipe() -> RecipeData:
	var ingredient_ids: Array[StringName] = _get_input_ingredient_ids()
	# Grown products (shrooms) come from the plants, never from an empty pot.
	for recipe: RecipeData in operation.get_unlocked_recipes():
		if not recipe.is_grown and recipe.matches(ingredient_ids):
			return recipe
	return null


func _set_inputs_removable(is_removable: bool) -> void:
	for socket: ItemSocket in get_input_sockets():
		socket.allows_removal = is_removable


func _update_idle_status() -> void:
	if _is_burning:
		_status_label.text = tr(station_name) + "\n" + tr("On fire! Put it out")
		return
	if not _has_power:
		_status_label.text = tr(station_name) + "\n" + tr("No power: reset the fuse box")
		return
	if is_running():
		return
	if not _output.is_empty():
		_status_label.text = tr(station_name) + "\n" + tr("Done: take the result")
		return
	var hint: String = ""
	match step:
		Types.CraftStep.PROCESS:
			hint = tr("Put in a raw ingredient to grind")
		Types.CraftStep.COMBINE:
			var inside: int = _get_input_items().size()
			if inside == 0:
				hint = tr("Put in ground ingredients (2 or 3)")
			else:
				hint = tr("%d in: add the rest of the recipe") % inside
		Types.CraftStep.PACKAGE:
			hint = tr("Put in a cooked batch")
	_status_label.text = tr(station_name) + "\n" + hint


## Why [param item] can't go into this station right now (shown to the player).
func _explain_refusal(item: Grabbable) -> String:
	if _is_burning:
		return tr("On fire! Put it out")
	if is_running():
		return tr("Busy: finish the skill check first")
	var ingredient: IngredientItem = item as IngredientItem
	match step:
		Types.CraftStep.PROCESS:
			if ingredient == null:
				return tr("Only raw ingredients go in the grinder")
			if not ingredient.data.needs_processing:
				return tr("%s needs no grinding: take it to the cooker") % tr(ingredient.data.display_name)
			return tr("Already ground: take it to the cooker")
		Types.CraftStep.COMBINE:
			if ingredient == null:
				return tr("Batches go in the press")
			if not ingredient.is_processed:
				return tr("Grind it first")
			return tr("No unlocked recipe uses this mix")
		Types.CraftStep.PACKAGE:
			return tr("Only cooked batches go in the press")
	return ""


func _on_input_refused(item: Grabbable, reason: String) -> void:
	if reason.is_empty():
		return
	FloatingText3D.spawn(reason, item.global_position + Vector3(0.0, 0.2, 0.0), Palette.DANGER, Global.get_world_root())
	Audio.play_ui(Audio.UI_ERROR)


func _describe_accuracy(accuracy: float) -> String:
	if accuracy >= 0.85:
		return tr("Perfect")
	if accuracy >= 0.5:
		return tr("Good")
	if accuracy > 0.0:
		return tr("Sloppy")
	return tr("Ruined")


func _accuracy_color(accuracy: float) -> Color:
	if accuracy >= 0.85:
		return Palette.SUCCESS
	if accuracy >= 0.5:
		return Palette.TEXT
	return Palette.DANGER


func _build_gauge() -> void:
	var bar: MeshInstance3D = _create_gauge_part(Vector3(1.0, GAUGE_THICKNESS, 0.02), Palette.BACKGROUND_RAISED, Vector3.ZERO, 0.0)
	bar.scale.x = GAUGE_LENGTH
	_zone = _create_gauge_part(Vector3(1.0, GAUGE_THICKNESS * 1.1, 0.022), Palette.SUCCESS, Vector3(0.0, 0.0, 0.004), 0.4)
	_needle = _create_gauge_part(Vector3(0.012, GAUGE_THICKNESS * 2.2, 0.026), Palette.TEXT, Vector3(0.0, 0.0, 0.01), 0.0)
	_gauge_root.visible = false


func _create_gauge_part(box_size: Vector3, color: Color, offset: Vector3, glow: float) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = box_size
	part.mesh = box
	part.position = offset
	part.material_override = PlaceholderMesh3D.get_shared_material(color, glow, true)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gauge_root.add_child(part)
	return part
