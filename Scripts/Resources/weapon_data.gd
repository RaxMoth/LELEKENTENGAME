## One weapon the player fights with. A new player has only their fists;
## the armory terminal sells the rest one after the other — a knife, an axe,
## then the guns ([member required_weapon_id]). Guns (Kind.GUN) are fired
## along the beam from the front room or porch (off-hand trigger /
## right-click); melee weapons (Kind.MELEE: fists, knife, axe) hit a raider
## in reach anywhere — swung at them in a headset, or with the trigger /
## a click. Weapons differ in damage, rate, reach, armor piercing and ammo;
## melee weapons and the pistol never run dry.
##
## Instances: Ressources/Weapons/*.tres, listed in weapon_catalog.tres.
##
## Dependencies: none
class_name WeaponData
extends Resource

## How a weapon is used.
enum Kind { GUN, MELEE }

@export var id: StringName = &""
@export var display_name: String = "Weapon"
@export_multiline var description: String = ""
@export var kind: Kind = Kind.GUN
## Cash to buy the weapon (0 = owned from the start: the fists).
@export_range(0, 100000) var cost: int = 0
## For sale only once the player owns this weapon (the axe needs the knife,
## the pistol the axe); empty = always for sale.
@export var required_weapon_id: StringName = &""
## The animated model held in the hand (a WeaponModel scene); none for fists.
@export var model_scene: PackedScene
## Small icon of it (Assets/Icons) shown while it is in a hand; none for fists.
@export var icon: Texture2D
## Where it hangs on the player's body in a headset ("hip", "chest" or
## "back", WalkingBody.HOLSTER_*); empty for the fists. Grip near it to draw.
@export var holster_slot: StringName = &""

@export_group("Firing")
## Damage per hit before armor.
@export var damage: float = 20.0
## Seconds between two shots.
@export var fire_interval_seconds: float = 0.3
## Meters a shot reaches; for a melee weapon, the reach of a strike with the
## trigger or a click (from the hand in a headset, the eyes on a screen).
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

@export_group("Melee")
## How far past the hand a swing reaches (the knuckles, the blade, the axe head).
@export var swing_reach_meters: float = 0.1

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

@export_group("Upgrades")
## Price of each upgrade level at the armory, in order (level 1, 2, ...):
## its length is how often the weapon can be upgraded.
@export var upgrade_costs: PackedInt32Array = PackedInt32Array()
## Each level adds this share of the base damage...
@export var damage_per_level: float = 0.25
## ...and fires this share faster (shorter time between shots).
@export var fire_rate_per_level: float = 0.1
## Each level adds this many rounds to what the player can carry.
@export var ammo_per_level: int = 30


## True for the weapon every player starts with (the fists).
func is_starter() -> bool:
	return cost <= 0


## True for fists, the knife and the axe.
func is_melee() -> bool:
	return kind == Kind.MELEE


## Upgrade levels this weapon has at the armory.
func get_max_upgrade_level() -> int:
	return upgrade_costs.size()


## Price of upgrading from [param level] to the next (0 when it can't go higher).
func get_upgrade_cost(level: int) -> int:
	return upgrade_costs[level] if level >= 0 and level < upgrade_costs.size() else 0


## Damage of one hit (or pellet) at upgrade [param level].
func get_damage(level: int) -> float:
	return damage * (1.0 + damage_per_level * maxi(0, level))


## Seconds between two shots or swings at upgrade [param level].
func get_fire_interval(level: int) -> float:
	return fire_interval_seconds / (1.0 + fire_rate_per_level * maxi(0, level))


## Rounds the player can carry at upgrade [param level].
func get_max_ammo(level: int) -> int:
	return max_ammo + ammo_per_level * maxi(0, level)
