## One gun the player can buy at the armory terminal and fire from the front
## room (off-hand trigger / right-click). Weapons differ in damage, fire rate,
## range, armor piercing and ammo; the starter pistol is free and never runs
## dry, so a raid can never leave the player unarmed.
##
## Instances: Ressources/Weapons/*.tres, listed in weapon_catalog.tres.
##
## Dependencies: none
class_name WeaponData
extends Resource

@export var id: StringName = &""
@export var display_name: String = "Weapon"
@export_multiline var description: String = ""
## Cash to buy the gun (0 = owned from the start).
@export_range(0, 100000) var cost: int = 0

@export_group("Firing")
## Damage per hit before armor.
@export var damage: float = 20.0
## Seconds between two shots.
@export var fire_interval_seconds: float = 0.3
## Meters a shot reaches.
@export var range_meters: float = 30.0
## Ignores the target's armor (rifles against SWAT).
@export var pierces_armor: bool = false
## Haptic kick of one shot, in Types.HapticStrength order (kept as a plain
## int so the resource loads without autoloads, e.g. in unit tests).
@export_enum("Light", "Medium", "Heavy") var recoil: int = 0

@export_group("Ammo")
## Never runs out (the starter pistol).
@export var has_unlimited_ammo: bool = false
## Rounds that come with the gun.
@export_range(0, 1000) var starting_ammo: int = 0
## Rounds in one ammo box at the armory...
@export_range(1, 1000) var ammo_pack_size: int = 30
## ...and what the box costs.
@export_range(0, 100000) var ammo_pack_cost: int = 30
## Rounds the player can carry for this gun.
@export_range(1, 10000) var max_ammo: int = 240


## True for the gun every player starts with.
func is_starter() -> bool:
	return cost <= 0
