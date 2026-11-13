## A small box of snap traps beside the cabin's stash shelf. Grabbing it
## (grip or trigger, like an ingredient crate) hands out one RatTrap; a trap
## let go where it can't stand comes back into the box. It holds a few
## traps a day and only exists with the rats (it is part of the RatPack).
##
## Dependencies: RatTrap, RatPack, Pools, Audio, Types autoloads
class_name TrapBox
extends Node3D

const TRAP_SCENE: PackedScene = preload("res://Scenes/Levels/House/Rats/RatTrap.tscn")

## Traps in the box at the start of a day.
@export var trap_count: int = 4
## Radius of the sphere hands and pointers grab it with.
@export var grab_radius: float = 0.22

## The rats the traps are for (set by the RatPack).
var pack: RatPack = null

var _traps_left: int = 0

@onready var _label: Label3D = %Label


func _ready() -> void:
	add_to_group(Types.GROUP_GRAB_SOURCE)
	_traps_left = trap_count
	_update_label()


## Where hands and pointers grab it: the top of the box.
func get_grab_center() -> Vector3:
	return global_position + Vector3(0.0, 0.12, 0.0)


func get_traps_left() -> int:
	return _traps_left


## Hands out one trap (InteractionQuery calls this on a grab), or null when empty.
func take_item() -> Grabbable:
	if _traps_left <= 0 or pack == null:
		Audio.play_ui(Audio.UI_ERROR)
		return null
	_traps_left -= 1
	_update_label()
	var trap: RatTrap = Pools.spawn(TRAP_SCENE, pack, get_grab_center() + Vector3(0.0, 0.08, 0.0)) as RatTrap
	trap.setup(pack, self)
	return trap


## A trap came back unused.
func take_back(trap: RatTrap) -> void:
	_traps_left = mini(trap_count, _traps_left + 1)
	_update_label()
	Pools.despawn(trap)


func _update_label() -> void:
	_label.text = tr("Rat traps ×%d") % _traps_left
