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
## The animated model held in the hand (a GunModel scene).
@export var model_scene: PackedScene

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
## SfxSynth preset of the shot (each gun sounds different).
@export var sound_preset: StringName = &"shoot"
## Keeps firing while the trigger is held (SMG); otherwise one shot per pull.
@export var is_automatic: bool = false

@export_group("Projectiles")
## Projectiles per shot (a shotgun's pellets); damage is per projectile.
@export_range(1, 32) var pellets: int = 1
## Half-angle of the cone the projectiles fly in (0 = dead accurate).
@export var spread_degrees: float = 0.0
## Automatic fire: the cone widens by this much per shot in a burst...
@export var bloom_per_shot_degrees: float = 0.0
## ...up to this much.
@export var max_bloom_degrees: float = 0.0
## Raiders one projectile can pass through (a rifle round: 2).
@export_range(1, 5) var pierce_count: int = 1

@export_group("Damage falloff")
## Full damage up to here (meters)...
@export var falloff_start_meters: float = 100.0
## ...down to falloff_min_multiplier at this distance (end <= start = no falloff).
@export var falloff_end_meters: float = 0.0
@export_range(0.0, 1.0) var falloff_min_multiplier: float = 1.0

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
