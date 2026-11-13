## How the house's 3-day cycle and its police raids are tuned: how many days
## of selling come before a raid, how many waves a raid has, how many cops and
## SWAT officers each wave brings, which vehicles join, how much tougher
## every raid gets and how the police come through the town.
## RaidPlanner turns this into the waves of one raid; HouseCycle runs them.
##
##   var waves: Array[RaidWave] = RaidPlanner.build_raid(raid_data, 2, heat_ratio)
##
## Instance: Ressources/Raids/police_raids.tres (on HouseCycle.tscn).
##
## Dependencies: none
class_name RaidData
extends Resource

@export_group("Cycle")
## Days of selling per cycle; the raid comes at the night of the last one.
@export_range(1, 10) var days_per_cycle: int = 3

@export_group("Waves")
## Waves in the first raid.
@export_range(1, 10) var first_raid_waves: int = 2
## Every later raid adds this many waves...
@export_range(0, 5) var extra_waves_per_raid: int = 1
## ...up to this many.
@export_range(1, 20) var max_waves: int = 6
## Seconds from the raid alarm to the first wave (time to lock the door and arm up).
@export var seconds_before_first_wave: float = 10.0
## Seconds of calm between two waves.
@export var seconds_between_waves: float = 8.0
## Seconds between two officers of one squad setting off (they jog in a column).
@export var seconds_between_spawns: float = 0.4
## Seconds between two squads of a wave setting off (each from its own direction).
@export var seconds_between_squads: float = 3.0
## Officers who set off together and take the same way through the town.
@export_range(1, 20) var squad_size: int = 6
## No wave brings more officers on foot than this (vehicles and their crews
## come on top): a horde a standalone headset can still draw.
@export_range(1, 200) var max_officers_per_wave: int = 54

@export_group("Cops")
## Cops in the first wave of the first raid.
@export_range(0, 50) var first_wave_cops: int = 3
## Each later wave of a raid brings this many more cops.
@export_range(0, 10) var cops_per_later_wave: int = 1
## Each later raid brings this many more cops in every wave.
@export_range(0, 10) var cops_per_later_raid: int = 1
## Extra cops in the last wave at full police heat (scaled by the heat ratio):
## selling hot gets you a bigger raid.
@export_range(0, 20) var max_heat_extra_cops: int = 4

@export_group("SWAT")
## First raid with SWAT officers (better equipment).
@export_range(1, 20) var swat_from_raid: int = 2
## SWAT officers per wave in that raid (from its second wave on).
@export_range(0, 10) var swat_per_wave: int = 1
## Each later raid adds this many SWAT officers per wave.
@export_range(0, 10) var swat_per_later_raid: int = 1

@export_group("Battering ram")
## First raid whose last wave brings a battering-ram team.
@export_range(1, 20) var ram_from_raid: int = 2
## Every this many raids after that, the last wave brings one more ram.
@export_range(1, 20) var raids_per_extra_ram: int = 3

@export_group("Squad cars")
## First raid with squad cars (they come in the last wave first, then in every wave).
@export_range(1, 20) var cars_from_raid: int = 1
## Squad cars in the last wave of that raid; each later raid adds one, and
## from the next raid every wave brings half as many (at least one).
@export_range(0, 10) var cars_in_first_car_raid: int = 1

@export_group("Armored vehicle")
## First raid whose last wave brings an armored vehicle...
@export_range(1, 20) var tanks_from_raid: int = 2
## ...and every this many raids one more.
@export_range(1, 20) var raids_per_extra_tank: int = 3

@export_group("Helicopter")
## First raid whose last wave brings a helicopter...
@export_range(1, 20) var helicopters_from_raid: int = 3
## ...and every this many raids one more.
@export_range(1, 20) var raids_per_extra_helicopter: int = 3

@export_group("Through the town")
## Squads set off at a street crossing this far from the house (meters,
## random between x and y) and take their own way through the streets.
@export var march_start_distance: Vector2 = Vector2(110.0, 190.0)
## How much a squad prefers detours (1 = always the shortest way; higher
## = more different ways from raid to raid).
@export_range(1.0, 5.0) var route_variety: float = 2.2
## Farthest an officer walks from the middle of the street (meters): a squad
## spreads over the street instead of walking in single file.
@export var lane_spread: float = 3.4
## Seconds after a wave starts before its armored vehicle and its
## helicopters set off (squad cars go with the squads).
@export var tank_delay_seconds: float = 4.0
@export var helicopter_delay_seconds: float = 8.0
## The helicopter comes in from this far away (meters).
@export var helicopter_start_distance: float = 170.0

@export_group("Toughness")
## Officer health grows by this share every raid after the first.
@export var health_growth_per_raid: float = 0.15
## The last wave of every raid is this much tougher.
@export var last_wave_health_multiplier: float = 1.1
