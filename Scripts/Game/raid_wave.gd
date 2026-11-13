## One wave of a police raid: how many cops and SWAT officers come, which
## vehicles (squad cars full of cops, an armored vehicle, a helicopter) and
## how tough they are. Built by RaidPlanner, spawned by the FrontGarden's
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
## Squad cars that drive up and unload their cops (each car is one target,
## its cops come on top).
var car_count: int = 0
## Armored vehicles that shell the front door from the street.
var tank_count: int = 0
## Helicopters that circle the house and drop SWAT officers into the yard.
var helicopter_count: int = 0
## Multiplier on every officer's base health.
var health_multiplier: float = 1.0


func _init(index: int = 0, cops: int = 0, swat_officers: int = 0, health_scale: float = 1.0, rams: int = 0) -> void:
	wave_index = index
	cop_count = maxi(0, cops)
	swat_count = maxi(0, swat_officers)
	ram_count = maxi(0, rams)
	health_multiplier = maxf(0.1, health_scale)


## Raiders in this wave as they start out (a ram team and every vehicle
## count as one; cops a vehicle brings come on top).
func get_total() -> int:
	return cop_count + swat_count + ram_count + get_vehicle_count()


func get_vehicle_count() -> int:
	return car_count + tank_count + helicopter_count
