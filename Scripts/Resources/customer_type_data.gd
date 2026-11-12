## A kind of buyer at the back window. Each mixes the attributes differently,
## so selling is a decision: what they want, how much, how good, what they
## pay, whether they haggle and how long they wait.
##
## Dependencies: CustomerOrder, RecipeData
class_name CustomerTypeData
extends Resource

@export var id: StringName = &""
@export var display_name: String = "Customer"
## Body tint (a Palette color).
@export var color: Color = Color.WHITE
## Units per visit, x = min, y = max.
@export var quantity_range: Vector2i = Vector2i(1, 2)
## Minimum quality tier they accept, x = min, y = max (1-4).
@export var min_tier_range: Vector2i = Vector2i(1, 2)
## Multiplier on the fair price they are willing to pay.
@export var price_tolerance: float = 1.15
@export var haggles: bool = false
@export var patience_seconds: float = 45.0
## Reputation for a good sale / lost when they leave unserved or refused.
@export var reputation_gain: int = 1
@export var reputation_loss: int = 1
## Workers (dealers) may serve this type.
@export var dealer_can_serve: bool = true

@export_group("Arrival")
## Relative chance among the types that may show up, by day and by night.
@export var day_weight: float = 1.0
@export var night_weight: float = 0.5
## Reputation needed before this type shows up.
@export var min_reputation: int = 0
## UpgradeData id needed before this type shows up (empty = none).
@export var required_upgrade_id: StringName = &""


## Rolls one visit's order for a product from [param recipes].
func create_order(recipes: Array[RecipeData], random: RandomNumberGenerator) -> CustomerOrder:
	var order: CustomerOrder = CustomerOrder.new()
	order.customer_type = self
	order.recipe = recipes[random.randi_range(0, recipes.size() - 1)]
	order.quantity = random.randi_range(quantity_range.x, maxi(quantity_range.x, quantity_range.y))
	order.min_tier = random.randi_range(min_tier_range.x, maxi(min_tier_range.x, min_tier_range.y))
	return order


func get_weight(phase: DayClock.Phase) -> float:
	return day_weight if phase == DayClock.Phase.DAY else night_weight
