## A buyer at the back window. Walks in, queues, waits as long as their
## patience lasts and leaves — happy with their order or annoyed. Shows what
## they want in a bubble over their head and how long they will still wait.
## Pooled. State: Walking <-> Waiting, then Leaving.
##
## Dependencies: CustomerOrder, CustomerTypeData, QualityMath, PlaceholderMesh3D,
##               Pools, Types autoloads, Palette
class_name Customer
extends Node3D

## Reached its spot in the queue.
signal arrived(customer: Customer)
## Ran out of patience while waiting.
signal patience_ran_out(customer: Customer)

const PATIENCE_BAR_WIDTH: float = 0.5

@export var walk_speed: float = 1.4

var order: CustomerOrder = null
var patience_left: float = 0.0
var max_patience: float = 1.0
var is_leaving: bool = false

var _target: Vector3 = Vector3.ZERO
var _exit_point: Vector3 = Vector3.ZERO
var _walk_phase: float = 0.0
var _has_been_used: bool = false

@onready var _body: PlaceholderMesh3D = %Body
@onready var _head: PlaceholderMesh3D = %Head
@onready var _visual: Node3D = %Visual
@onready var _bubble: Label3D = %Bubble
@onready var _patience_fill: MeshInstance3D = %PatienceFill
@onready var _patience_back: MeshInstance3D = %PatienceBack
@onready var state_chart: StateChart = %StateChart


func _ready() -> void:
	_patience_back.material_override = PlaceholderMesh3D.get_shared_material(Palette.BACKGROUND, 0.0, true)


## Called right after spawning: what they want and how long they wait.
func setup(customer_order: CustomerOrder, patience_seconds: float, exit_point: Vector3) -> void:
	order = customer_order
	max_patience = maxf(1.0, patience_seconds)
	patience_left = max_patience
	_exit_point = exit_point
	is_leaving = false
	_body.color = order.customer_type.color
	_head.color = order.customer_type.color
	_bubble.text = "%s\n%s ×%d · %s+" % [tr(order.customer_type.display_name), tr(order.recipe.display_name), order.quantity, tr(QualityMath.get_tier_name(order.min_tier))]
	_bubble.modulate = Palette.TEXT
	_update_patience_bar()


## Walks to a new spot in the queue.
func walk_to(target: Vector3) -> void:
	_target = target
	if not is_leaving:
		state_chart.send_event(Types.EVENT_WALK)


## Done here (served or not): walk off and disappear.
func leave(was_served: bool) -> void:
	if is_leaving:
		return
	is_leaving = true
	_bubble.visible = true
	_bubble.text = tr("Thanks") if was_served else tr("Forget it")
	_bubble.modulate = Palette.SUCCESS if was_served else Palette.DANGER
	_target = _exit_point
	state_chart.send_event(Types.EVENT_LEAVE)


## Only the customer at the window shows the order bubble (a queue of
## bubbles would pile up into an unreadable stack).
func set_bubble_visible(is_visible_now: bool) -> void:
	_bubble.visible = is_visible_now or is_leaving


func get_patience_ratio() -> float:
	return patience_left / max_patience


func _on_pool_spawned() -> void:
	is_leaving = false
	_visual.rotation = Vector3.ZERO
	if _has_been_used:
		state_chart.send_event(Types.EVENT_WALK)
	_has_been_used = true

# ============================================
# STATE CHART CALLBACKS (connected in Customer.tscn)
# ============================================

func _on_walking_state_physics_processing(delta: float) -> void:
	if _step_toward(_target, delta):
		state_chart.send_event(Types.EVENT_ARRIVED)
		arrived.emit(self)


func _on_waiting_state_processing(delta: float) -> void:
	patience_left = maxf(0.0, patience_left - delta)
	_update_patience_bar()
	_visual.position.y = 0.0
	if patience_left <= 0.0:
		patience_ran_out.emit(self)


func _on_leaving_state_physics_processing(delta: float) -> void:
	if _step_toward(_exit_point, delta):
		Pools.despawn(self)

# ============================================
# INTERNALS
# ============================================

## Moves toward [param point]; true once there.
func _step_toward(point: Vector3, delta: float) -> bool:
	var to_point: Vector3 = Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	var distance: float = to_point.length()
	if distance < 0.05:
		global_position = Vector3(point.x, global_position.y, point.z)
		_visual.position.y = 0.0
		return true
	var step_length: float = minf(distance, walk_speed * delta)
	global_position += to_point / distance * step_length
	_visual.rotation.y = atan2(to_point.x, to_point.z)
	_walk_phase += delta * 9.0
	_visual.position.y = absf(sin(_walk_phase)) * 0.05
	return false


func _update_patience_bar() -> void:
	var ratio: float = get_patience_ratio()
	_patience_fill.scale.x = maxf(0.001, ratio)
	_patience_fill.position.x = -PATIENCE_BAR_WIDTH * 0.5 * (1.0 - ratio)
	_patience_fill.material_override = PlaceholderMesh3D.get_shared_material(Palette.SUCCESS if ratio > 0.5 else (Palette.WARNING if ratio > 0.25 else Palette.DANGER), 0.5, true)
