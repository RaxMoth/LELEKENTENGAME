## Rats in the starter cabin: a few scurry about the floor while the house
## is still the one-room cabin (level 0 of "Extend the House"; they are gone
## once it is extended). Now and then — by pure chance, when one is close
## to the player's feet — a rat bites: 1 health, and each rat only once.
## They also go for the stash shelf and chew through a bag (a unit lost)
## unless they are caught first: the box of traps beside the shelf hands
## out snap traps (TrapBox, RatTrap) the player sets on the floor; a rat
## that runs over an armed one is caught for the day. Each player's copy
## runs its own rats (like the ghost); a bite or a chewed bag goes up
## through signals and the House level acts on it.
##
##   pack.feet_source = rig.get_feet_position
##   pack.player_bitten.connect(level.hurt_local_player)
##   pack.stash_chewed.connect(level._on_stash_chewed)
##
## Dependencies: UpgradeReaction, Rat, RatTrap, TrapBox, WalkableArea
class_name RatPack
extends UpgradeReaction

## A rat bit the local player for [param damage] health.
signal player_bitten(damage: float)
## A rat chewed through a bag on the stash shelf (at [param where]).
signal stash_chewed(where: Vector3)
## A snap trap caught a rat.
signal rat_caught

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

@export_group("Stash")
## The stash shelf the rats go for (it moves with the house's stages).
@export var stash_spot: Node3D
## Chance that a rat's next dash goes to the stash...
@export_range(0.0, 1.0, 0.01) var stash_visit_chance: float = 0.2
## ...where it chews this many seconds through a bag (a unit lost)...
@export var chew_seconds: float = 4.0
## ...and not again for this long.
@export var chew_cooldown_seconds: float = 45.0

@export_group("Traps")
## A rat this close to an armed trap (meters) is caught.
@export var trap_reach: float = 0.12
## Where the local player's feet are now (a Callable returning Vector3).
var feet_source: Callable = Callable()

var _rats: Array[Rat] = []
var _traps: Array[RatTrap] = []

@onready var _trap_box: TrapBox = %TrapBox


func _ready() -> void:
	super()
	for child: Node in get_children():
		var rat: Rat = child as Rat
		if rat != null:
			rat.pack = self
			_rats.append(rat)
	_trap_box.pack = self


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


## The box of traps beside the stash shelf.
func get_trap_box() -> TrapBox:
	return _trap_box


## Where the local player's feet are, or Vector3.INF when unknown.
func get_player_feet() -> Vector3:
	return feet_source.call() if feet_source.is_valid() else Vector3.INF


## Called by a rat whose bite landed.
func report_bite() -> void:
	player_bitten.emit(bite_damage)


## Called by a rat that chewed through a bag on the stash shelf.
func report_chew(where: Vector3) -> void:
	stash_chewed.emit(where)


## Where the rats go to chew (Vector3.INF without a stash shelf).
func get_stash_point() -> Vector3:
	return stash_spot.global_position if stash_spot != null and stash_spot.is_inside_tree() else Vector3.INF


## A trap was set on the floor: rats can run into it.
func register_trap(trap: RatTrap) -> void:
	if not _traps.has(trap):
		_traps.append(trap)


## A trap was picked up or has sprung: it catches nothing more.
func unregister_trap(trap: RatTrap) -> void:
	_traps.erase(trap)


## The armed trap a rat at [param point] runs into, or null.
func find_trap_at(point: Vector3) -> RatTrap:
	for trap: RatTrap in _traps:
		if trap.is_armed and Vector2(trap.global_position.x - point.x, trap.global_position.z - point.z).length() <= trap_reach and absf(trap.global_position.y - point.y) < 0.3:
			return trap
	return null


## Called by a trap that caught a rat.
func report_catch() -> void:
	rat_caught.emit()


## How many rats are still about (not caught).
func get_free_rat_count() -> int:
	var free_rats: int = 0
	for rat: Rat in _rats:
		if not rat.is_caught():
			free_rats += 1
	return free_rats
