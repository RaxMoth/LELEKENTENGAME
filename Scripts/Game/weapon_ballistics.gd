## How a gun's shot leaves the barrel: how many projectiles (a shotgun's
## pellets), in which directions (a cone that widens while an automatic gun
## keeps firing), and how much damage each still does at a distance.
##
##   var directions: Array[Vector3] = WeaponBallistics.get_shot_directions(forward, weapon, bloom, random)
##   var damage: float = WeaponBallistics.get_damage_at(weapon, distance)
##
## Pure functions (unit-tested in Tests/Unit/weapon_ballistics_test.gd).
##
## Dependencies: WeaponData
class_name WeaponBallistics
extends RefCounted


## One direction per projectile of one shot, spread in a cone of half-angle
## spread_degrees + [param bloom_degrees] around [param forward].
static func get_shot_directions(forward: Vector3, weapon: WeaponData, bloom_degrees: float = 0.0, random: RandomNumberGenerator = null) -> Array[Vector3]:
	var directions: Array[Vector3] = []
	var aim: Vector3 = forward.normalized()
	var cone: float = deg_to_rad(maxf(0.0, weapon.spread_degrees + bloom_degrees))
	# Any axis across the aim works; the roll around the aim is random anyway.
	var across: Vector3 = aim.cross(Vector3.UP if absf(aim.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT).normalized()
	for pellet: int in maxi(1, weapon.pellets):
		if cone <= 0.0:
			directions.append(aim)
			continue
		# Uniform over the cone's disc: sqrt keeps the centre from crowding.
		var tilt: float = cone * sqrt(_randf(random))
		var roll: float = TAU * _randf(random)
		directions.append(aim.rotated(across.rotated(aim, roll), tilt).normalized())
	return directions


## Damage of one projectile after [param distance] meters: full up to
## falloff_start_meters, then down to falloff_min_multiplier at falloff_end_meters.
static func get_damage_at(weapon: WeaponData, distance: float) -> float:
	if weapon.falloff_end_meters <= weapon.falloff_start_meters:
		return weapon.damage
	var weight: float = clampf((distance - weapon.falloff_start_meters) / (weapon.falloff_end_meters - weapon.falloff_start_meters), 0.0, 1.0)
	return weapon.damage * lerpf(1.0, weapon.falloff_min_multiplier, weight)


## Extra spread after [param shots_in_burst] shots in a row (automatic guns
## climb), capped at max_bloom_degrees.
static func get_bloom(weapon: WeaponData, shots_in_burst: int) -> float:
	return minf(weapon.max_bloom_degrees, weapon.bloom_per_shot_degrees * maxi(0, shots_in_burst))


static func _randf(random: RandomNumberGenerator) -> float:
	return random.randf() if random != null else randf()
