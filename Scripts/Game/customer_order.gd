## What one customer wants on this visit: a product, an amount and a minimum
## quality tier. Created by CustomerTypeData.create_order().
##
## Dependencies: CustomerTypeData, RecipeData, SalesMath
class_name CustomerOrder
extends RefCounted

var customer_type: CustomerTypeData = null
var recipe: RecipeData = null
var quantity: int = 1
var min_tier: int = 1


## Highest unit price they accept for product of [param delivered_tier].
func get_max_unit_price(delivered_tier: int) -> int:
	return SalesMath.get_max_unit_price(recipe.base_price, customer_type.price_tolerance, min_tier, delivered_tier)


## How they answer [param asked_price] per unit for [param delivered_tier].
func evaluate(asked_price: int, delivered_tier: int) -> SalesMath.Verdict:
	return SalesMath.evaluate(asked_price, get_max_unit_price(delivered_tier), customer_type.haggles)
