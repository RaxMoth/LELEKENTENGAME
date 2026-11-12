## Sends buyers to the back window, day and night. Day brings many (mostly
## regulars, hagglers, bulk buyers), night fewer but richer (connoisseurs,
## VIPs). Reputation brings more of them and unlocks pickier types; high
## prices scare buyers off, low prices draw more.
##
## Dependencies: HouseContext, SalesWindow, CustomerTypeData, SalesMath,
##               DayClock, Profile autoload
class_name CustomerFlow
extends Node

## Every kind of buyer that may show up.
@export var customer_types: Array[CustomerTypeData] = []
@export var day_customer_interval: float = 8.0
@export var night_customer_interval: float = 14.0
## Reputation that halves the time between customers.
@export var reputation_for_double_traffic: float = 150.0

## Off = no customers come on their own (tutorials, tests).
var is_active: bool = true

var _context: HouseContext = null
var _window: SalesWindow = null
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _seconds_until_customer: float = 3.0


func _ready() -> void:
	_random.randomize()


func setup(context: HouseContext, window: SalesWindow) -> void:
	_context = context
	_window = window


## One frame of the flow (called by the SalesWindow while the shift runs).
func step(delta: float) -> void:
	if not is_active or _context == null:
		return
	_seconds_until_customer -= delta
	if _seconds_until_customer <= 0.0:
		_seconds_until_customer = _get_interval()
		if _window.has_room():
			spawn_customer()


## A buyer of a fitting type walks to the window. Returns null when none can come.
func spawn_customer() -> Customer:
	var recipes: Array[RecipeData] = _context.operation.get_unlocked_recipes()
	var customer_type: CustomerTypeData = _pick_customer_type()
	if recipes.is_empty() or customer_type == null:
		return null
	return _window.spawn_customer(customer_type.create_order(recipes, _random))


func _get_interval() -> float:
	var base_interval: float = night_customer_interval if _context.day_cycle.is_night() else day_customer_interval
	var reputation_factor: float = 1.0 + Profile.operation.reputation / reputation_for_double_traffic
	return base_interval / (reputation_factor * _get_average_demand())


## Prices above fair scare buyers off, cheap prices draw more.
func _get_average_demand() -> float:
	var recipes: Array[RecipeData] = _context.operation.get_unlocked_recipes()
	if recipes.is_empty():
		return 1.0
	var total: float = 0.0
	for recipe: RecipeData in recipes:
		total += SalesMath.get_demand_multiplier(_context.operation.get_price(recipe), recipe.base_price)
	return total / recipes.size()


func _pick_customer_type() -> CustomerTypeData:
	var phase: DayClock.Phase = _context.day_cycle.clock.get_phase()
	var candidates: Array[CustomerTypeData] = []
	var weights: PackedFloat32Array = PackedFloat32Array()
	var total_weight: float = 0.0
	for customer_type: CustomerTypeData in customer_types:
		if Profile.operation.reputation < customer_type.min_reputation or not Profile.upgrades.is_owned(customer_type.required_upgrade_id):
			continue
		var weight: float = customer_type.get_weight(phase)
		if weight <= 0.0:
			continue
		candidates.append(customer_type)
		weights.append(weight)
		total_weight += weight
	if candidates.is_empty():
		return null
	var roll: float = _random.randf() * total_weight
	for candidate_index: int in candidates.size():
		roll -= weights[candidate_index]
		if roll <= 0.0:
			return candidates[candidate_index]
	return candidates[candidates.size() - 1]
