## A player's health: hits take it, it comes back slowly once the player has
## not been hit for a while, and at 0 the player is down (and stays down).
## Pure rules; PlayerVitals puts them on a player in the house.
##
##   var health: PlayerHealth = PlayerHealth.new(100.0, 5.0, 6.0)
##   var is_down: bool = health.take(20.0)
##   health.recover(delta)
##
## Dependencies: none
class_name PlayerHealth
extends RefCounted

var maximum: float = 100.0
var current: float = 100.0
## Seconds without a hit before health starts coming back ...
var regen_delay_seconds: float = 5.0
## ... and how much comes back per second then.
var regen_per_second: float = 6.0

var _seconds_since_hit: float = INF


func _init(max_health: float = 100.0, delay_seconds: float = 5.0, per_second: float = 6.0) -> void:
	maximum = max_health
	current = max_health
	regen_delay_seconds = delay_seconds
	regen_per_second = per_second


## Takes [param amount]; true when this hit put the player down.
func take(amount: float) -> bool:
	if is_down() or amount <= 0.0:
		return false
	current = maxf(0.0, current - amount)
	_seconds_since_hit = 0.0
	return is_down()


## Time passes: after regen_delay_seconds without a hit, health comes back.
## Returns true when it changed.
func recover(delta: float) -> bool:
	if is_down():
		return false
	_seconds_since_hit += delta
	if _seconds_since_hit < regen_delay_seconds or current >= maximum:
		return false
	current = minf(maximum, current + regen_per_second * delta)
	return true


func is_down() -> bool:
	return current <= 0.0


## 0..1 for bars and warnings.
func get_ratio() -> float:
	return current / maxf(1.0, maximum)


## Back to full (a new player, tests).
func reset() -> void:
	current = maximum
	_seconds_since_hit = INF
