## What every front of the house gets at the start of a shift: the level (is
## a shift running?), the player rig, the shared Operation, the DayCycle and
## the HouseCycle (selling days or a police raid?). This is the whole
## contract between the fronts — a front never reaches into another front's
## nodes, only into these.
##
## Dependencies: LevelBase, XRPlayerRig, Operation, DayCycle, HouseCycle
class_name HouseContext
extends RefCounted

var level: LevelBase = null
var rig: XRPlayerRig = null
var operation: Operation = null
var day_cycle: DayCycle = null
## The 3-day cycle: selling phase or raid (null in scenes without one).
var cycle: HouseCycle = null


func _init(shift_level: LevelBase, player_rig: XRPlayerRig, house_operation: Operation, house_day_cycle: DayCycle, house_cycle: HouseCycle = null) -> void:
	level = shift_level
	rig = player_rig
	operation = house_operation
	day_cycle = house_day_cycle
	cycle = house_cycle


func is_playing() -> bool:
	return level != null and level.is_playing()


## True while customers may come (always, when there is no cycle).
func allows_customers() -> bool:
	return cycle == null or cycle.allows_customers()


## True while a police raid is on.
func is_raid_active() -> bool:
	return cycle != null and cycle.is_raid_active()
