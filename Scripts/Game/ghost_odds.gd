## Whether the ghost haunts tonight: now and then, never on the first
## nights, never two hauntings close together. Pure rules (no autoloads).
##
##   if GhostOdds.haunts_tonight(day, last_ghost_night, randf(), 0.15, 2, 4): ...
##
## Dependencies: none
class_name GhostOdds
extends RefCounted


## True when the ghost comes on the night of [param day_number]: from
## [param first_night] on, at least [param min_nights_between] nights after
## the last one ([param last_ghost_night], 0 = never), and only when
## [param roll] (0..1) falls under [param chance].
static func haunts_tonight(day_number: int, last_ghost_night: int, roll: float, chance: float, first_night: int, min_nights_between: int) -> bool:
	if day_number < first_night:
		return false
	if last_ghost_night > 0 and day_number - last_ghost_night < min_nights_between:
		return false
	return roll < chance
