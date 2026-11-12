## Data for one hit, passed to HealthComponent.apply_damage().
##
## Dependencies: Types autoload
class_name DamageInfo
extends RefCounted

var amount: float = 0.0
var damage_type: Types.DamageType = Types.DamageType.PHYSICAL
## Node credited for the hit (the shooter, not the bullet).
var source: Node = null
## World-space push in meters per second (Vector3.ZERO = none).
var knockback: Vector3 = Vector3.ZERO
var is_critical: bool = false


static func create(damage_amount: float, damage_source: Node = null, knockback_impulse: Vector3 = Vector3.ZERO) -> DamageInfo:
	var info: DamageInfo = DamageInfo.new()
	info.amount = damage_amount
	info.source = damage_source
	info.knockback = knockback_impulse
	return info
