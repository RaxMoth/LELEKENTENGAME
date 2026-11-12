## What every front of the house gets at the start of a shift: the level (is
## a shift running?), the player rig, the shared Operation and the DayCycle.
## This is the whole contract between the fronts — a front never reaches into
## another front's nodes, only into these.
##
## Dependencies: LevelBase, XRPlayerRig, Operation, DayCycle
class_name HouseContext
extends RefCounted

var level: LevelBase = null
var rig: XRPlayerRig = null
var operation: Operation = null
var day_cycle: DayCycle = null


func _init(shift_level: LevelBase, player_rig: XRPlayerRig, house_operation: Operation, house_day_cycle: DayCycle) -> void:
	level = shift_level
	rig = player_rig
	operation = house_operation
	day_cycle = house_day_cycle


func is_playing() -> bool:
	return level != null and level.is_playing()
