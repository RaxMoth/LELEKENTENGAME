## Area that can be hit. Put it on the "player_hurtbox" or "enemy_hurtbox"
## physics layer; hitboxes find it through their collision mask.
## Forwards damage to an optional HealthComponent.
##
## Dependencies: HealthComponent, DamageInfo
class_name HurtboxComponent
extends Area2D

signal hurt(damage_info: DamageInfo)

@export var health_component: HealthComponent


func _ready() -> void:
	# Hurtboxes are passive: they are detected, they don't detect.
	monitoring = false
	monitorable = true


func can_be_hit() -> bool:
	return health_component == null or (not health_component.is_dead and not health_component.is_invulnerable())


func receive_hit(damage_info: DamageInfo) -> void:
	if not can_be_hit():
		return
	hurt.emit(damage_info)
	if health_component != null:
		health_component.apply_damage(damage_info)
