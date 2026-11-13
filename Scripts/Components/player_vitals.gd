## A player's health in the house (PlayerHealth: 100 HP that comes back
## slowly a few seconds after the last hit). Raiders that got in through the
## broken front door find living players in Types.GROUP_PLAYER_TARGET and
## hit them; at 0 the player is down and the House level ends the shift.
## The host keeps one per player — its own follows the rig, a co-op guest's
## follows their avatar — and a guest shows its own from the host's numbers
## (is_mirror: no hits or healing run there).
##
##   vitals.feet_source = rig.get_feet_position
##   vitals.take_damage(12.0, raider)
##
## Dependencies: PlayerHealth, Types autoload
class_name PlayerVitals
extends Node

## A hit landed (current is what's left).
signal hit_taken(amount: float, current: float)
## Health went up or down (bars, the wrist).
signal health_changed(current: float, maximum: float)
## The player is down.
signal died

@export var max_health: float = 100.0
## Seconds without a hit before health starts coming back ...
@export var regen_delay_seconds: float = 5.0
## ... and how much comes back per second then.
@export var regen_per_second: float = 6.0

## Where the player's feet are now (a Callable returning Vector3).
var feet_source: Callable = Callable()
## Name used when this player goes down ("You", "Player 2").
var display_name: String = ""
## Co-op guest: only shows the host's numbers.
var is_mirror: bool = false

var health: PlayerHealth = null


func _ready() -> void:
	health = PlayerHealth.new(max_health, regen_delay_seconds, regen_per_second)
	add_to_group(Types.GROUP_PLAYER_TARGET)


func _process(delta: float) -> void:
	if is_mirror or health == null:
		return
	if health.recover(delta):
		health_changed.emit(health.current, health.maximum)


## Hits the player for [param amount]. No effect once down or on a mirror.
func take_damage(amount: float, _source: Node = null) -> void:
	if is_mirror or health.is_down():
		return
	var is_down_now: bool = health.take(amount)
	hit_taken.emit(amount, health.current)
	health_changed.emit(health.current, health.maximum)
	if is_down_now:
		died.emit()


func is_alive() -> bool:
	return health != null and not health.is_down()


func get_health() -> float:
	return health.current


func get_max_health() -> float:
	return health.maximum


## Where raiders head for: the player's feet.
func get_feet_position() -> Vector3:
	return feet_source.call() if feet_source.is_valid() else Vector3.ZERO


## Co-op guest: the host's numbers for this player; a drop is shown as a hit.
func apply_net_health(current: float, maximum: float) -> void:
	var previous: float = health.current
	health.maximum = maximum
	health.current = current
	if current < previous:
		hit_taken.emit(previous - current, current)
	if not is_equal_approx(current, previous):
		health_changed.emit(current, maximum)
