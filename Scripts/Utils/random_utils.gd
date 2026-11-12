## Weighted random selection helpers.
##
## Dependencies: none
class_name RandomUtils
extends RefCounted


## Returns the index picked proportionally to [param weights], or -1 if all are zero.
static func weighted_index(weights: PackedFloat32Array, random: RandomNumberGenerator = null) -> int:
	var total_weight: float = 0.0
	for weight: float in weights:
		total_weight += maxf(weight, 0.0)
	if total_weight <= 0.0:
		return -1
	var roll: float = random.randf() * total_weight if random != null else randf() * total_weight
	for weight_index: int in weights.size():
		roll -= maxf(weights[weight_index], 0.0)
		if roll <= 0.0:
			return weight_index
	return weights.size() - 1


## Picks [param count] distinct perks, weighted, skipping any rejected by [param is_allowed].
static func pick_weighted_perks(candidates: Array[PerkData], count: int, is_allowed: Callable) -> Array[PerkData]:
	var pool: Array[PerkData] = []
	for candidate: PerkData in candidates:
		if is_allowed.call(candidate):
			pool.append(candidate)
	var picked: Array[PerkData] = []
	while picked.size() < count and not pool.is_empty():
		var weights: PackedFloat32Array = PackedFloat32Array()
		for candidate: PerkData in pool:
			weights.append(candidate.weight)
		var picked_index: int = weighted_index(weights)
		if picked_index < 0:
			break
		picked.append(pool[picked_index])
		pool.remove_at(picked_index)
	return picked


static func chance(probability: float) -> bool:
	return randf() < probability
