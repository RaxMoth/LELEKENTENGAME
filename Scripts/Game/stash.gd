## The operation's stock of finished product: units per product and quality
## tier, with a capacity. What customers buy and what attackers try to steal.
##
##   stash.add(&"glow", 3, 6)
##   var taken: Array[int] = stash.take(&"glow", 2, 4)   # tiers of the units taken
##
## Pure data (serializable with to_dict / from_dict); the level shows it.
##
## Dependencies: QualityMath
class_name Stash
extends RefCounted

signal changed

## Free space reported by an unlimited stash.
const UNLIMITED_SPACE: int = 1_000_000

## Units the stash holds at most (0 = unlimited).
var capacity: int = 30

## product id -> units per tier (index 0 = tier 1).
var _units: Dictionary[StringName, PackedInt32Array] = {}


func _init(max_units: int = 30) -> void:
	capacity = max_units


func get_total() -> int:
	var total: int = 0
	for product_id: StringName in _units:
		for count: int in _units[product_id]:
			total += count
	return total


func get_free_space() -> int:
	return UNLIMITED_SPACE if capacity <= 0 else maxi(0, capacity - get_total())


## Units of a product at [param min_tier] or better.
func count(product_id: StringName, min_tier: int = QualityMath.MIN_TIER) -> int:
	if not _units.has(product_id):
		return 0
	var total: int = 0
	var tiers: PackedInt32Array = _units[product_id]
	for tier_index: int in range(clampi(min_tier, QualityMath.MIN_TIER, QualityMath.MAX_TIER) - 1, tiers.size()):
		total += tiers[tier_index]
	return total


## Units of one exact tier.
func count_tier(product_id: StringName, tier: int) -> int:
	if not _units.has(product_id):
		return 0
	return _units[product_id][clampi(tier, QualityMath.MIN_TIER, QualityMath.MAX_TIER) - 1]


## Adds up to [param amount] units; returns how many fit.
func add(product_id: StringName, tier: int, amount: int) -> int:
	var accepted: int = mini(amount, get_free_space())
	if accepted <= 0:
		return 0
	var tiers: PackedInt32Array = _ensure(product_id)
	tiers[clampi(tier, QualityMath.MIN_TIER, QualityMath.MAX_TIER) - 1] += accepted
	_units[product_id] = tiers
	changed.emit()
	return accepted


## The tiers of the units take() would hand over for an order, without
## taking them (empty when there aren't enough). Prefers one tier that can
## fill the whole order — the lowest such tier — so the best stock stays for
## picky buyers; otherwise mixes, lowest qualifying tier first.
func peek(product_id: StringName, min_tier: int, amount: int) -> Array[int]:
	var picked_tiers: Array[int] = []
	if amount <= 0 or count(product_id, min_tier) < amount:
		return picked_tiers
	var tiers: PackedInt32Array = _units[product_id]
	var first_index: int = clampi(min_tier, QualityMath.MIN_TIER, QualityMath.MAX_TIER) - 1
	for tier_index: int in range(first_index, tiers.size()):
		if tiers[tier_index] >= amount:
			picked_tiers.resize(amount)
			picked_tiers.fill(tier_index + 1)
			return picked_tiers
	for tier_index: int in range(first_index, tiers.size()):
		for unit: int in mini(tiers[tier_index], amount - picked_tiers.size()):
			picked_tiers.append(tier_index + 1)
	return picked_tiers


## Takes [param amount] units of at least [param min_tier] (the same units
## peek() reports). Takes nothing and returns an empty array when there are
## not enough; otherwise the tier of every unit taken.
func take(product_id: StringName, min_tier: int, amount: int) -> Array[int]:
	var taken_tiers: Array[int] = peek(product_id, min_tier, amount)
	if taken_tiers.is_empty():
		return taken_tiers
	var tiers: PackedInt32Array = _units[product_id]
	for tier: int in taken_tiers:
		tiers[tier - 1] -= 1
	_units[product_id] = tiers
	changed.emit()
	return taken_tiers


## Removes up to [param amount] random units of any product (theft, raids).
## Returns how many were removed.
func steal(amount: int, random: RandomNumberGenerator = null) -> int:
	var stolen: int = 0
	while stolen < amount:
		var stocked: Array[Vector2i] = []
		var product_ids: Array[StringName] = []
		for product_id: StringName in _units:
			var tiers: PackedInt32Array = _units[product_id]
			for tier_index: int in tiers.size():
				if tiers[tier_index] > 0:
					stocked.append(Vector2i(product_ids.size(), tier_index))
			product_ids.append(product_id)
		if stocked.is_empty():
			break
		var pick: Vector2i = stocked[random.randi_range(0, stocked.size() - 1) if random != null else randi() % stocked.size()]
		var picked_tiers: PackedInt32Array = _units[product_ids[pick.x]]
		picked_tiers[pick.y] -= 1
		_units[product_ids[pick.x]] = picked_tiers
		stolen += 1
	if stolen > 0:
		changed.emit()
	return stolen


func clear() -> void:
	_units.clear()
	changed.emit()


func get_product_ids() -> Array[StringName]:
	var product_ids: Array[StringName] = []
	for product_id: StringName in _units:
		if count(product_id) > 0:
			product_ids.append(product_id)
	return product_ids


## JSON-friendly: {"glow": [t1, t2, t3, t4], ...}.
func to_dict() -> Dictionary:
	var data: Dictionary = {}
	for product_id: StringName in _units:
		data[String(product_id)] = Array(_units[product_id])
	return data


func from_dict(data: Dictionary) -> void:
	_units.clear()
	for raw_key: Variant in data:
		var raw_tiers: Variant = data[raw_key]
		if raw_tiers is Array:
			var product_id: StringName = StringName(str(raw_key))
			var tiers: PackedInt32Array = _ensure(product_id)
			for tier_index: int in mini((raw_tiers as Array).size(), tiers.size()):
				tiers[tier_index] = maxi(0, int((raw_tiers as Array)[tier_index]))
			_units[product_id] = tiers
	changed.emit()


func _ensure(product_id: StringName) -> PackedInt32Array:
	if not _units.has(product_id):
		var tiers: PackedInt32Array = PackedInt32Array()
		tiers.resize(QualityMath.MAX_TIER)
		_units[product_id] = tiers
	return _units[product_id]
