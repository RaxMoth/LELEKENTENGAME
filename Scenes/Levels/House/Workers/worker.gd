## A hired crew member. Crafters turn cash into standard product, dealers
## serve the regular customers at the window, guards shoot attackers near the
## front door. Each draws a wage every in-game hour and goes on strike while
## the operation can't pay. The player stays better: crew make lower quality,
## can't serve VIPs or bulk buyers and are weaker against bosses.
## State: Absent (not hired) -> Working <-> Striking.
##
## Dependencies: Operation, SalesWindow, LaneBoard, BeamTracer, FloatingText3D,
##               QualityMath, Pools, Profile, Types autoloads, Palette
class_name Worker
extends Node3D

const TRACER_SCENE: PackedScene = preload("res://Scenes/Levels/House/Garden/BeamTracer.tscn")
## Skill (training level) at which crafters make Pure instead of Street.
const SKILLED_TRAINING_LEVEL: int = 2

@export var role: Types.WorkerRole = Types.WorkerRole.CRAFTER
## Hired once the role's hire upgrade reaches this level.
@export var slot: int = 1
@export var wage_per_hour: int = 12
@export var work_interval_seconds: float = 18.0
## Each training level makes work this much faster.
@export var training_speedup: float = 0.15

@export_group("Guard")
@export var guard_damage: float = 16.0
@export var guard_range: float = 10.0

@export_group("Links")
@export var operation: Operation
@export var sales_window: SalesWindow
@export var board: LaneBoard

var _seconds_until_work: float = 0.0
var _is_striking: bool = false

@onready var state_chart: StateChart = %StateChart
@onready var _role_label: Label3D = %RoleLabel
@onready var _muzzle: Marker3D = %Muzzle


func _ready() -> void:
	visible = false
	_role_label.text = tr(get_role_name())


## Shows / hides the worker after the hire upgrades changed.
func refresh_hired() -> void:
	if is_hired():
		state_chart.send_event(Types.EVENT_HIRED)


func is_hired() -> bool:
	return operation != null and operation.get_upgrade_level(_get_hire_upgrade_id()) >= slot


func is_working() -> bool:
	return visible and not _is_striking


func get_role_name() -> String:
	match role:
		Types.WorkerRole.DEALER:
			return "Dealer"
		Types.WorkerRole.GUARD:
			return "Guard"
	return "Crafter"


## Pays this hour's wage. Returns false (and goes on strike) when broke.
func pay_wage() -> bool:
	if not is_hired():
		return true
	if operation.spend_cash(wage_per_hour, "wages"):
		state_chart.send_event(Types.EVENT_WAGE_PAID)
		return true
	state_chart.send_event(Types.EVENT_WAGE_MISSED)
	return false


## Does one unit of work right away (tests).
func work_now() -> void:
	_do_work()

# ============================================
# STATE CHART CALLBACKS (connected in Worker.tscn)
# ============================================

func _on_absent_state_entered() -> void:
	visible = false


func _on_working_state_entered() -> void:
	visible = true
	_is_striking = false
	_role_label.modulate = Palette.TEXT
	_role_label.text = tr(get_role_name())
	_seconds_until_work = _get_interval()


func _on_working_state_processing(delta: float) -> void:
	_seconds_until_work -= delta
	if _seconds_until_work > 0.0:
		return
	_seconds_until_work = _get_interval()
	_do_work()


func _on_striking_state_entered() -> void:
	_is_striking = true
	_role_label.modulate = Palette.DANGER
	_role_label.text = tr("%s (unpaid)") % tr(get_role_name())

# ============================================
# INTERNALS
# ============================================

func _do_work() -> void:
	match role:
		Types.WorkerRole.CRAFTER:
			_craft()
		Types.WorkerRole.DEALER:
			_deal()
		Types.WorkerRole.GUARD:
			_guard()


func _craft() -> void:
	var recipes: Array[RecipeData] = operation.get_unlocked_recipes()
	if recipes.is_empty() or operation.stash.get_free_space() <= 0:
		return
	var recipe: RecipeData = recipes[0]
	if not operation.spend_cash(recipe.get_ingredient_cost(), "ingredients"):
		return
	var tier: int = 3 if operation.get_upgrade_level(Types.UPGRADE_TRAINING) >= SKILLED_TRAINING_LEVEL else 2
	var units: int = operation.add_product(recipe, tier, recipe.base_batch_size)
	FloatingText3D.spawn("%s ×%d" % [tr(QualityMath.get_tier_name(tier)), units], global_position + Vector3(0.0, 2.1, 0.0), Palette.GOLD, Global.get_world_root())


func _deal() -> void:
	var front: Customer = sales_window.get_front_customer()
	if front == null or not front.order.customer_type.dealer_can_serve or not sales_window.can_fill_front():
		return
	if sales_window.sell_to_front() == SalesMath.Verdict.COUNTER:
		# Crew don't haggle: they take what is offered.
		sales_window.accept_counter()


func _guard() -> void:
	var enemy: LaneEnemy = board.find_enemy_nearest_door(_muzzle.global_position, guard_range)
	if enemy == null:
		_seconds_until_work = 0.4
		return
	enemy.take_hit(guard_damage, self, true)
	var tracer: BeamTracer = Pools.spawn(TRACER_SCENE, board.get_effects_root(), _muzzle.global_position) as BeamTracer
	tracer.fire(_muzzle.global_position, enemy.get_hit_center())


func _get_interval() -> float:
	var training_level: int = operation.get_upgrade_level(Types.UPGRADE_TRAINING) if operation != null else 0
	return work_interval_seconds * maxf(0.3, 1.0 - training_speedup * training_level)


func _get_hire_upgrade_id() -> StringName:
	match role:
		Types.WorkerRole.DEALER:
			return Types.UPGRADE_DEALER
		Types.WorkerRole.GUARD:
			return Types.UPGRADE_GUARD
	return Types.UPGRADE_CRAFTER
