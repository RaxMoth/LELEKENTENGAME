## The back window: customers queue in the yard, the one at the window
## places an order, and the player sets a price and sells — or declines.
## Hagglers answer a price that is a little high with a counteroffer.
## Dealers (workers) serve through the same calls.
##
## The window's local +Z points out into the yard; the board faces inside.
##
## Dependencies: Customer, CustomerOrder, SalesBoard, Operation, SalesMath,
##               QualityMath, WorldScreen, FloatingText3D, Pools, Profile,
##               Audio, Types autoloads, Palette, SfxSynth
class_name SalesWindow
extends Node3D

signal sale_completed(order: CustomerOrder, cash_earned: int)
## A customer left without buying (refused, declined or tired of waiting).
signal customer_lost(customer: Customer)

const CUSTOMER_SCENE: PackedScene = preload("res://Scenes/Levels/House/Sales/Customer.tscn")

@export var operation: Operation
## Customers that can wait at once before upgrades.
@export var base_capacity: int = 3

var _queue: Array[Customer] = []
## Unit price a haggling customer offered back (0 = no counteroffer pending).
var _counter_offer: int = 0
var _board: SalesBoard = null

@onready var _spots: Node3D = %QueueSpots
@onready var _entry: Marker3D = %Entry
@onready var _exit: Marker3D = %Exit
@onready var _screen: WorldScreen = %SalesScreen


func _ready() -> void:
	_board = _screen.content as SalesBoard
	_board.price_step_requested.connect(_on_price_step_requested)
	_board.sell_pressed.connect(func() -> void: sell_to_front())
	_board.decline_pressed.connect(decline_front)
	_board.accept_counter_pressed.connect(accept_counter)
	operation.stash_changed.connect(_refresh_board)
	_refresh_board()


func _process(_delta: float) -> void:
	var front: Customer = get_front_customer()
	if front != null:
		_board.set_patience(front.get_patience_ratio())

# ============================================
# PUBLIC API
# ============================================

## The board screen inside the window (levels pause its redraws when unseen).
func get_screen() -> WorldScreen:
	return _screen


func get_capacity() -> int:
	return mini(base_capacity + roundi(operation.get_upgrade_value(Types.UPGRADE_QUEUE)), _spots.get_child_count())


func get_queue_size() -> int:
	return _queue.size()


func has_room() -> bool:
	return _queue.size() < get_capacity()


## A new customer walks in with [param order] and joins the back of the queue.
func spawn_customer(order: CustomerOrder) -> Customer:
	var customer: Customer = Pools.spawn(CUSTOMER_SCENE, Global.get_world_root(), _entry.global_position) as Customer
	var patience: float = order.customer_type.patience_seconds * (1.0 + operation.get_upgrade_value(Types.UPGRADE_PATIENCE))
	customer.setup(order, patience, _exit.global_position)
	if not customer.arrived.is_connected(_on_customer_arrived):
		customer.arrived.connect(_on_customer_arrived)
		customer.patience_ran_out.connect(_on_customer_patience_ran_out)
	_queue.append(customer)
	customer.walk_to(_get_spot(_queue.size() - 1))
	customer.set_bubble_visible(_queue.size() == 1)
	_refresh_board()
	return customer


## The customer standing at the window ready to order, or null.
func get_front_customer() -> Customer:
	if _queue.is_empty():
		return null
	var front: Customer = _queue[0]
	var at_window: bool = front.global_position.distance_to(_get_spot(0)) < 0.1
	return front if at_window and not front.is_leaving else null


## True when the stash can fill the front customer's order.
func can_fill_front() -> bool:
	var front: Customer = get_front_customer()
	return front != null and operation.get_deliverable_tier(front.order) > 0


## Offers the order to the front customer at the current price. Returns how
## they answered (REFUSE also when there is no one or not enough stock).
func sell_to_front() -> SalesMath.Verdict:
	var front: Customer = get_front_customer()
	if front == null or not can_fill_front():
		Audio.play_ui(Audio.UI_ERROR)
		return SalesMath.Verdict.REFUSE
	var tier: int = operation.get_deliverable_tier(front.order)
	var asked_price: int = operation.get_price(front.order.recipe)
	var verdict: SalesMath.Verdict = front.order.evaluate(asked_price, tier)
	match verdict:
		SalesMath.Verdict.ACCEPT:
			_complete(front, asked_price)
		SalesMath.Verdict.COUNTER:
			_counter_offer = front.order.get_max_unit_price(tier)
			Audio.play_ui(Audio.UI_CLICK)
			_refresh_board()
		SalesMath.Verdict.REFUSE:
			FloatingText3D.spawn(tr("Too expensive"), front.global_position + Vector3(0.0, 2.4, 0.0), Palette.DANGER, Global.get_world_root())
			_lose(front)
	return verdict


## Takes the haggler's counteroffer.
func accept_counter() -> void:
	var front: Customer = get_front_customer()
	if front == null or _counter_offer <= 0 or not can_fill_front():
		return
	_complete(front, _counter_offer)


## Sends the front customer away.
func decline_front() -> void:
	var front: Customer = get_front_customer()
	if front != null:
		_lose(front)


## Everyone in the queue leaves (end of shift).
func clear_queue() -> void:
	for customer: Customer in _queue.duplicate():
		customer.leave(false)
	_queue.clear()
	_counter_offer = 0
	_refresh_board()

# ============================================
# INTERNALS
# ============================================

func _complete(customer: Customer, unit_price: int) -> void:
	var cash_earned: int = operation.complete_sale(customer.order, unit_price)
	if cash_earned < 0:
		return
	FloatingText3D.spawn("+$%d" % cash_earned, global_position + Vector3(0.0, 1.9, 0.2), Palette.SUCCESS, Global.get_world_root())
	Audio.play_sfx_at(SfxSynth.get_preset(&"coin"), global_position + Vector3(0.0, 1.2, 0.0), 0.05)
	sale_completed.emit(customer.order, cash_earned)
	_remove(customer, true)


func _lose(customer: Customer) -> void:
	Profile.operation.add_reputation(-customer.order.customer_type.reputation_loss)
	customer_lost.emit(customer)
	_remove(customer, false)


func _remove(customer: Customer, was_served: bool) -> void:
	if not _queue.is_empty() and _queue[0] == customer:
		_counter_offer = 0
	_queue.erase(customer)
	customer.leave(was_served)
	for queue_index: int in _queue.size():
		_queue[queue_index].walk_to(_get_spot(queue_index))
		_queue[queue_index].set_bubble_visible(queue_index == 0)
	_refresh_board()


func _get_spot(queue_index: int) -> Vector3:
	var spot_index: int = clampi(queue_index, 0, _spots.get_child_count() - 1)
	return (_spots.get_child(spot_index) as Node3D).global_position


func _refresh_board() -> void:
	if _board == null:
		return
	var front: Customer = get_front_customer()
	if front == null:
		_board.show_waiting(_queue.size(), get_capacity())
		return
	var order: CustomerOrder = front.order
	var tier: int = operation.get_deliverable_tier(order)
	_board.show_order(order, operation.get_price(order.recipe), tier, operation.stash.count(order.recipe.id, order.min_tier), _counter_offer, _queue.size(), get_capacity())


func _on_customer_arrived(customer: Customer) -> void:
	if not _queue.is_empty() and customer == _queue[0]:
		_refresh_board()


func _on_customer_patience_ran_out(customer: Customer) -> void:
	if _queue.has(customer) and not customer.is_leaving:
		FloatingText3D.spawn(tr("Too slow"), customer.global_position + Vector3(0.0, 2.4, 0.0), Palette.DANGER, Global.get_world_root())
		_lose(customer)


func _on_price_step_requested(step: int) -> void:
	var front: Customer = get_front_customer()
	if front == null:
		return
	var recipe: RecipeData = front.order.recipe
	var price_step: int = maxi(1, roundi(recipe.base_price * 0.1))
	operation.set_price(recipe, maxi(price_step, operation.get_price(recipe) + step * price_step))
	_counter_offer = 0
	_refresh_board()
