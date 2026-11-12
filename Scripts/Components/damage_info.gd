## Data passed from a hitbox to a hurtbox for one hit.
##
## Dependencies: Types autoload
class_name DamageInfo
extends RefCounted

var amount: float = 0.0
var damage_type: Types.DamageType = Types.DamageType.PHYSICAL
## Node credited for the hit (the shooter, not the bullet).
var source: Node = null
var knockback: Vector2 = Vector2.ZERO
var is_critical: bool = false


static func create(damage_amount: float, damage_source: Node = null, knockback_impulse: Vector2 = Vector2.ZERO) -> DamageInfo:
	var info: DamageInfo = DamageInfo.new()
	info.amount = damage_amount
	info.source = damage_source
	info.knockback = knockback_impulse
	return info
