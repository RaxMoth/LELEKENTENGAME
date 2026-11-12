## Hit points for any entity. Owners react to its signals (play animation,
## drop loot, send Types.EVENT_DIED to their StateChart...).
##
## Dependencies: DamageInfo
class_name HealthComponent
extends Node

signal health_changed(current_health: float, max_health: float)
signal damaged(damage_info: DamageInfo)
signal healed(heal_amount: float)
signal died

@export var max_health: float = 100.0
## Seconds of immunity after taking a hit (0 = none). Classic "i-frames".
@export var invulnerability_seconds: float = 0.0

var current_health: float = 0.0
var is_dead: bool = false

var _invulnerable_until_msec: int = 0


func _ready() -> void:
	current_health = max_health


func apply_damage(damage_info: DamageInfo) -> void:
	if is_dead or is_invulnerable() or damage_info.amount <= 0.0:
		return
	current_health = maxf(0.0, current_health - damage_info.amount)
	if invulnerability_seconds > 0.0:
		_invulnerable_until_msec = Time.get_ticks_msec() + int(invulnerability_seconds * 1000.0)
	damaged.emit(damage_info)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		is_dead = true
		died.emit()


## Convenience for damage without a hitbox (traps, poison ticks, debug).
func damage(amount: float, source: Node = null) -> void:
	apply_damage(DamageInfo.create(amount, source))


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	var previous_health: float = current_health
	current_health = minf(max_health, current_health + amount)
	healed.emit(current_health - previous_health)
	health_changed.emit(current_health, max_health)


## Changes the maximum; [param heal_difference] adds the gained max to current health.
func set_max_health(new_max_health: float, heal_difference: bool = true) -> void:
	var difference: float = new_max_health - max_health
	max_health = maxf(1.0, new_max_health)
	current_health = clampf(current_health + (difference if heal_difference and difference > 0.0 else 0.0), 0.0, max_health)
	health_changed.emit(current_health, max_health)


## Full reset — used when pooled entities are reused.
func revive(new_max_health: float = -1.0) -> void:
	if new_max_health > 0.0:
		max_health = new_max_health
	current_health = max_health
	is_dead = false
	_invulnerable_until_msec = 0
	health_changed.emit(current_health, max_health)


func is_invulnerable() -> bool:
	return Time.get_ticks_msec() < _invulnerable_until_msec


func get_health_ratio() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0
