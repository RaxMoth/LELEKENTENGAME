## How the house's 3-day cycle and its police raids are tuned: how many days
## of selling come before a raid, how many waves a raid has, how many cops and
## SWAT officers each wave brings and how much tougher every raid gets.
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
## Seconds between two officers of one wave entering the garden.
@export var seconds_between_spawns: float = 1.4

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

@export_group("Toughness")
## Officer health grows by this share every raid after the first.
@export var health_growth_per_raid: float = 0.15
## The last wave of every raid is this much tougher.
@export var last_wave_health_multiplier: float = 1.1
