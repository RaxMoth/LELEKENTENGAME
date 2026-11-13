## Rats in the starter cabin: a few scurry about the floor while the house
## is still the one-room cabin (level 0 of "Extend the House"; they are gone
## once it is extended). Now and then — by pure chance, when one is close
## to the player's feet — a rat bites: 1 health, and each rat only once.
## Just a nuisance. Each player's copy runs its own rats (like the ghost);
## a bite goes up through player_bitten and the House level hurts the
## local player.
##
##   pack.feet_source = rig.get_feet_position
##   pack.player_bitten.connect(level.hurt_local_player)
##
## Dependencies: UpgradeReaction, Rat, WalkableArea
class_name RatPack
extends UpgradeReaction

## A rat bit the local player for [param damage] health.
signal player_bitten(damage: float)

## The player's floor: rats slide along its walls and furniture.
@export var walkable: WalkableArea
## The floor the rats roam (world X / Z): the cabin's room.
@export var roam_area: Rect2 = Rect2(-4.6, -4.6, 5.2, 9.2)
## The rats are about while the upgrade's level is at most this (0: the cabin).
@export var max_level: int = 0

@export_group("Bites")
## Chance per second that a rat close to the player's feet bites.
@export_range(0.0, 100.0, 0.01) var bite_chance_per_second: float = 0.15
## How close (meters, across the floor) a rat must be to the player's feet.
@export var bite_range: float = 0.45
## Health one bite costs.
@export var bite_damage: float = 1.0

## Where the local player's feet are now (a Callable returning Vector3).
var feet_source: Callable = Callable()

var _rats: Array[Rat] = []


func _ready() -> void:
	super()
	for child: Node in get_children():
		var rat: Rat = child as Rat
		if rat != null:
			rat.pack = self
			_rats.append(rat)


## Rats only in the cabin: hidden (and asleep) once the house is extended.
func apply_level(level: int) -> void:
	var is_about: bool = level <= max_level
	visible = is_about
	process_mode = Node.PROCESS_MODE_INHERIT if is_about else Node.PROCESS_MODE_DISABLED


## True while the rats are about (the cabin).
func is_about() -> bool:
	return visible


func get_rats() -> Array[Rat]:
	return _rats


## Where the local player's feet are, or Vector3.INF when unknown.
func get_player_feet() -> Vector3:
	return feet_source.call() if feet_source.is_valid() else Vector3.INF


## Called by a rat whose bite landed.
func report_bite() -> void:
	player_bitten.emit(bite_damage)
