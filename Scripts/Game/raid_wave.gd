## One wave of a police raid: how many cops and SWAT officers come and how
## tough they are. Built by RaidPlanner, spawned by the FrontGarden's
## AttackerDirector.
##
## Pure data; no nodes.
##
## Dependencies: none
class_name RaidWave
extends RefCounted

## 0-based position of the wave in its raid.
var wave_index: int = 0
var cop_count: int = 0
var swat_count: int = 0
## Battering-ram teams (two officers carrying a ram; one target).
var ram_count: int = 0
## Multiplier on every officer's base health.
var health_multiplier: float = 1.0


func _init(index: int = 0, cops: int = 0, swat_officers: int = 0, health_scale: float = 1.0, rams: int = 0) -> void:
	wave_index = index
	cop_count = maxi(0, cops)
	swat_count = maxi(0, swat_officers)
	ram_count = maxi(0, rams)
	health_multiplier = maxf(0.1, health_scale)


## Raiders in this wave (a ram team counts as one).
func get_total() -> int:
	return cop_count + swat_count + ram_count
