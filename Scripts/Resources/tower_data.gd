## One kind of tower the player can buy and set up anywhere outside — in the
## garden or the streets of the town: what it costs, how it fights and what
## its upgrades add. Towers come as kits from the tower depot in the garden;
## carried outside, a pull of the trigger at the ground puts one up.
##
## Kinds:
##   GUN    — a fast single-target gun.
##   MORTAR — lobs a shell that blasts everyone around where it lands.
##   BEAM   — a heat beam on one target that burns hotter the longer it stays on it.
##   SHOCK  — a discharge that jumps from the target to the officers next to it.
##
## Dependencies: none
class_name TowerData
extends Resource

enum Kind { GUN, MORTAR, BEAM, SHOCK }

@export var id: StringName = &""
@export var display_name: String = "Tower"
@export_multiline var description: String = ""
@export var kind: Kind = Kind.GUN
## Price of a kit at the tower depot.
@export_range(0, 100000) var cost: int = 500
## Main color of the tower's model (a Palette color).
@export var color: Color = Color("#5b7cfa")

@export_group("Fighting")
## Damage of one hit (MORTAR: of the blast; BEAM: per second at the start).
@export var damage: float = 20.0
@export var fire_interval_seconds: float = 0.4
@export var range_meters: float = 24.0
## Officers closer than this (meters) are out of reach (a mortar can't lob that short).
@export var min_range_meters: float = 0.0
@export var pierces_armor: bool = false
## Degrees per second the head swings.
@export var turn_speed_degrees: float = 160.0

@export_group("Kind specifics")
## MORTAR: radius (meters) of the blast, and the shell's flight time.
@export var splash_radius: float = 0.0
@export var shell_flight_seconds: float = 0.7
## BEAM: the damage multiplies up to beam_max_multiplier over beam_ramp_seconds on one target.
@export var beam_ramp_seconds: float = 4.0
@export var beam_max_multiplier: float = 6.0
## SHOCK: how many officers one discharge hits, jumping this far (meters) between them.
@export_range(1, 10) var chain_count: int = 1
@export var chain_range: float = 0.0

@export_group("Upgrades")
## Price of each upgrade level (level 1, 2, ...): its length is how often it can be upgraded.
@export var upgrade_costs: PackedInt32Array = PackedInt32Array()
## Each level adds this share of the base damage...
@export var damage_per_level: float = 0.35
## ...and this many meters of range.
@export var range_per_level: float = 3.0


func get_max_level() -> int:
	return upgrade_costs.size()


## Price of upgrading from [param level] to the next (0 when it can't go higher).
func get_upgrade_cost(level: int) -> int:
	return upgrade_costs[level] if level >= 0 and level < upgrade_costs.size() else 0


func get_damage(level: int) -> float:
	return damage * (1.0 + damage_per_level * maxi(0, level))


func get_range(level: int) -> float:
	return range_meters + range_per_level * maxi(0, level)
