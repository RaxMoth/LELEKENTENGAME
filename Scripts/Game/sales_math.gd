## The rules of a sale at the back window: what a customer is willing to pay
## for the quality you hand over, how they answer your price, and how prices
## change how many people show up.
##
## Dependencies: QualityMath
class_name SalesMath
extends RefCounted

## How a customer answers the asked price.
enum Verdict { ACCEPT, COUNTER, REFUSE }

## A haggler counters prices up to this much above what they want to pay.
const HAGGLE_REACH: float = 1.25
## Extra a customer pays per tier above what they asked for.
const QUALITY_BONUS_PER_TIER: float = 0.15
## Demand multiplier bounds (cheap prices draw more buyers, high prices fewer).
const MIN_DEMAND: float = 0.35
const MAX_DEMAND: float = 1.6


## Highest unit price a customer accepts for product of [param delivered_tier]
## when they asked for at least [param wanted_tier].
static func get_max_unit_price(base_price: int, price_tolerance: float, wanted_tier: int, delivered_tier: int) -> int:
	var quality_bonus: float = 1.0 + QUALITY_BONUS_PER_TIER * maxi(0, delivered_tier - wanted_tier)
	return maxi(1, roundi(base_price * price_tolerance * QualityMath.get_price_factor(delivered_tier) * quality_bonus))


## How a customer answers [param asked_price] per unit.
static func evaluate(asked_price: int, max_price: int, haggles: bool) -> Verdict:
	if asked_price <= max_price:
		return Verdict.ACCEPT
	if haggles and asked_price <= roundi(max_price * HAGGLE_REACH):
		return Verdict.COUNTER
	return Verdict.REFUSE


## Multiplier on customer arrivals for a price relative to the product's base
## price: at base price 1, cheaper draws more, dearer scares buyers off.
static func get_demand_multiplier(price: int, base_price: int) -> float:
	if base_price <= 0:
		return 1.0
	var price_ratio: float = float(price) / base_price
	return clampf(2.0 - price_ratio, MIN_DEMAND, MAX_DEMAND)
