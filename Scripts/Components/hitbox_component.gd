## Area that deals damage to HurtboxComponents it overlaps. Set its collision
## mask to the hurtbox layer it should hit. With hit_interval > 0 it keeps
## damaging while overlapping (contact damage, spikes, auras).
##
## Dependencies: HurtboxComponent, DamageInfo, Types autoload
class_name HitboxComponent
extends Area2D

signal hit_landed(hurtbox: HurtboxComponent, damage_info: DamageInfo)

@export var damage: float = 10.0
@export var damage_type: Types.DamageType = Types.DamageType.PHYSICAL
@export var knockback_force: float = 0.0
## 0 = hit once on contact; > 0 = repeat every N seconds while overlapping.
@export var hit_interval: float = 0.0
@export_range(0.0, 1.0) var critical_chance: float = 0.0
@export var critical_multiplier: float = 2.0
## Node credited for kills. Defaults to this hitbox's owner.
@export var damage_source: Node

var _overlap_cooldowns: Dictionary[HurtboxComponent, float] = {}


func _ready() -> void:
	monitorable = false
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _physics_process(delta: float) -> void:
	if hit_interval <= 0.0 or _overlap_cooldowns.is_empty():
		return
	for tracked: Variant in _overlap_cooldowns.keys():
		if not is_instance_valid(tracked) or not (tracked as Node).is_inside_tree():
			_overlap_cooldowns.erase(tracked)
			continue
		var hurtbox: HurtboxComponent = tracked as HurtboxComponent
		_overlap_cooldowns[hurtbox] -= delta
		if _overlap_cooldowns[hurtbox] <= 0.0:
			_overlap_cooldowns[hurtbox] = hit_interval
			deal_hit(hurtbox)


func deal_hit(hurtbox: HurtboxComponent) -> void:
	if not hurtbox.can_be_hit():
		return
	var damage_info: DamageInfo = build_damage_info(hurtbox)
	hurtbox.receive_hit(damage_info)
	hit_landed.emit(hurtbox, damage_info)


func build_damage_info(hurtbox: HurtboxComponent) -> DamageInfo:
	var push_direction: Vector2 = global_position.direction_to(hurtbox.global_position)
	var damage_info: DamageInfo = DamageInfo.create(damage, damage_source if damage_source != null else owner, push_direction * knockback_force)
	damage_info.damage_type = damage_type
	if critical_chance > 0.0 and randf() < critical_chance:
		damage_info.amount *= critical_multiplier
		damage_info.is_critical = true
	return damage_info


func _on_area_entered(area: Area2D) -> void:
	var hurtbox: HurtboxComponent = area as HurtboxComponent
	if hurtbox == null:
		return
	deal_hit(hurtbox)
	if hit_interval > 0.0:
		_overlap_cooldowns[hurtbox] = hit_interval


func _on_area_exited(area: Area2D) -> void:
	var hurtbox: HurtboxComponent = area as HurtboxComponent
	if hurtbox != null:
		_overlap_cooldowns.erase(hurtbox)
