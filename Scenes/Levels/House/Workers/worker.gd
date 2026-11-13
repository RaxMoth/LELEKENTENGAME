## A hired crew member. Crafters are the lab's hands: they free a jammed
## motor, stop a skill check nobody is running (a station without a motor)
## and carry packed bags from the press to the stash — automation still
## needs them. Before the lab has a press they make standard product from
## cash. Dealers serve the regular customers at the window, guards shoot
## attackers near the front door. Each works inside its own front's scene (crafters in the Lab,
## dealers at the SalesWindow, guards in the FrontGarden), which hands it the
## operation at setup. Each draws a wage every in-game hour (the House level
## pays everyone in Types.GROUP_CREW) and goes on strike while the operation
## can't pay. The player stays better: crew make lower quality,
## can't serve VIPs or bulk buyers and are weaker against bosses.
## State: Absent (not hired) -> Working <-> Striking.
##
## Dependencies: Operation, Lab, Workstation, ProductBag, StashShelf, AutomationMath,
##               SalesWindow, Yard, Raider, BeamTracer, FloatingText3D,
##               QualityMath, Pools, Profile, Types autoloads, Palette
class_name Worker
extends Node3D

const TRACER_SCENE: PackedScene = preload("res://Scenes/Levels/House/Garden/BeamTracer.tscn")
## Crew never stop a needle as well as the best hands: at most Good.
const CREW_ACCURACY_CAP: float = 0.7

@export var role: Types.WorkerRole = Types.WorkerRole.CRAFTER
## Hired once the role's hire upgrade reaches this level.
@export var slot: int = 1
@export var wage_per_hour: int = 12
@export var work_interval_seconds: float = 18.0
## Each training level makes work this much faster.
@export var training_speedup: float = 0.15
## Crew Training level at which crafters make Pure instead of Street.
@export_range(0, 10) var skilled_training_level: int = 2

@export_group("Crafter")
## Seconds between looks for lab work (a jam, a waiting gauge, a bag).
@export var lab_task_seconds: float = 3.0
## A skill check without a motor runs this long before a crafter stops it
## (the player gets the first go).
@export var hand_wait_seconds: float = 3.0
## How well a crafter stops a needle (0.5 = Fine); each training level adds a little.
@export_range(0.0, 1.0, 0.05) var crew_accuracy: float = 0.5
@export_range(0.0, 0.2, 0.01) var training_accuracy_bonus: float = 0.05

@export_group("Guard")
@export var guard_damage: float = 16.0
@export var guard_range: float = 10.0

@export_group("Links")
## Dealers: the window they serve at (same scene).
@export var sales_window: SalesWindow
## Guards: the garden they defend (same scene).
@export var yard: Yard
## Crafters: the lab they tend (same scene).
@export var lab: Lab

## The house's shared state; set by the worker's front at setup.
var operation: Operation = null

var _seconds_until_work: float = 0.0
var _seconds_until_lab_task: float = 0.0
var _is_striking: bool = false

@onready var state_chart: StateChart = %StateChart
@onready var _role_label: Label3D = %RoleLabel
@onready var _muzzle: Marker3D = %Muzzle


func _ready() -> void:
	add_to_group(Types.GROUP_CREW)
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


## A crafter's look around the lab: frees a jam, stops a waiting needle or
## carries a packed bag to the stash (the most urgent one). Returns the
## task done (AutomationMath.CrewTask.NONE when there was nothing to do).
func tend_lab() -> AutomationMath.CrewTask:
	if lab == null or operation == null or not is_working():
		return AutomationMath.CrewTask.NONE
	var jammed_station: Workstation = null
	var waiting_station: Workstation = null
	for station_name: StringName in [&"Grinder", &"Cooker", &"Press"]:
		var station: Workstation = lab.get_station(station_name)
		if station == null or not station.visible:
			continue
		if jammed_station == null and station.is_jammed():
			jammed_station = station
		if waiting_station == null and station.is_waiting_for_hand(hand_wait_seconds):
			waiting_station = station
	var press: Workstation = lab.get_station(&"Press")
	var bag: ProductBag = press.get_output_socket().item as ProductBag if press != null and press.visible else null
	var shelf: StashShelf = get_tree().get_first_node_in_group(Types.GROUP_STASH_SHELF) as StashShelf
	var has_room: bool = shelf != null and bag != null and operation.stash.get_free_space() >= bag.units
	var task: AutomationMath.CrewTask = AutomationMath.pick_crew_task(jammed_station != null, waiting_station != null, bag != null, has_room)
	match task:
		AutomationMath.CrewTask.UNJAM:
			jammed_station.clear_jam()
			_say(tr("Freed the %s") % tr(jammed_station.station_name))
		AutomationMath.CrewTask.STOP_GAUGE:
			waiting_station.stop_by_crew(_get_crew_accuracy())
		AutomationMath.CrewTask.CARRY_BAG:
			shelf.take_bag(bag)
			_say(tr("Took a bag to the stash"))
	return task

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
	if role == Types.WorkerRole.CRAFTER:
		_seconds_until_lab_task -= delta
		if _seconds_until_lab_task <= 0.0:
			_seconds_until_lab_task = lab_task_seconds
			tend_lab()
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
	# With a press the crafter works the lab's line instead (tend_lab()).
	if lab != null and lab.get_station(&"Press") != null and lab.get_station(&"Press").visible:
		return
	var recipes: Array[RecipeData] = operation.get_unlocked_recipes()
	if recipes.is_empty() or operation.stash.get_free_space() <= 0:
		return
	var recipe: RecipeData = recipes[0]
	if not operation.spend_cash(recipe.get_ingredient_cost(), "ingredients"):
		return
	var tier: int = 3 if operation.get_upgrade_level(Types.UPGRADE_TRAINING) >= skilled_training_level else 2
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
	var enemy: Raider = yard.find_raider_nearest_door(_muzzle.global_position, guard_range)
	if enemy == null:
		_seconds_until_work = 0.4
		return
	enemy.take_hit(guard_damage, self, true)
	var tracer: BeamTracer = Pools.spawn(TRACER_SCENE, yard.get_effects_root(), _muzzle.global_position) as BeamTracer
	tracer.fire(_muzzle.global_position, enemy.get_hit_center())


func _get_crew_accuracy() -> float:
	var training_level: int = operation.get_upgrade_level(Types.UPGRADE_TRAINING)
	return minf(CREW_ACCURACY_CAP, crew_accuracy + training_accuracy_bonus * training_level)


func _say(message: String) -> void:
	FloatingText3D.spawn(message, global_position + Vector3(0.0, 2.1, 0.0), Palette.TEXT, Global.get_world_root())


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
