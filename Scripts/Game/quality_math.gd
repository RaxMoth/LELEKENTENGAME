## Product quality: lab step accuracies plus equipment become a score 0..1,
## and the score becomes a tier the customers understand (1-4 stars).
##
## Dependencies: none
class_name QualityMath
extends RefCounted

const MIN_TIER: int = 1
const MAX_TIER: int = 4
## Lowest score for tiers 2, 3 and 4.
const TIER_THRESHOLDS: Array[float] = [0.45, 0.7, 0.88]
const TIER_NAMES: Array[String] = ["Cut", "Street", "Pure", "Premium"]
## Price factor of each tier relative to a standard (tier 2) unit.
const TIER_PRICE_FACTORS: Array[float] = [0.7, 1.0, 1.35, 1.8]
## How much of the score comes from the player's hands; the rest is luck-free
## equipment quality.
const HANDS_SHARE: float = 0.85


## Score 0..1 of a batch: the average step accuracy, shifted up by equipment.
## [param equipment_bonus] is 0 for the starting lab and grows with upgrades.
static func combine(step_accuracies: Array[float], equipment_bonus: float) -> float:
	if step_accuracies.is_empty():
		return 0.0
	var total: float = 0.0
	for accuracy: float in step_accuracies:
		total += clampf(accuracy, 0.0, 1.0)
	var hands_score: float = total / step_accuracies.size()
	return clampf(hands_score * HANDS_SHARE + (1.0 - HANDS_SHARE) * 0.5 + equipment_bonus, 0.0, 1.0)


static func tier_from_score(score: float) -> int:
	var tier: int = MIN_TIER
	for threshold: float in TIER_THRESHOLDS:
		if score >= threshold:
			tier += 1
	return tier


static func get_tier_name(tier: int) -> String:
	return TIER_NAMES[clampi(tier, MIN_TIER, MAX_TIER) - 1]


static func get_price_factor(tier: int) -> float:
	return TIER_PRICE_FACTORS[clampi(tier, MIN_TIER, MAX_TIER) - 1]
