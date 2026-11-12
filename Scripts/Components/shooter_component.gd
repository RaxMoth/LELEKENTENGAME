## Fires pooled projectiles with a fire rate, spread and multi-shot.
## Place it where bullets should appear (muzzle) and call try_fire(direction).
##
## Dependencies: Projectile, Pools, Global, Audio autoloads
class_name ShooterComponent
extends Marker2D

signal fired(projectile_count: int)

@export var projectile_scene: PackedScene
## Physics layers the projectiles damage (e.g. Types.LAYER_ENEMY_HURTBOX = 16).
@export_flags_2d_physics var hit_mask: int = 16
@export var shots_per_second: float = 2.0
@export var damage: float = 10.0
@export var projectiles_per_shot: int = 1
@export var spread_degrees: float = 12.0
@export var projectile_speed_override: float = 0.0
## Turn rate passed to projectiles when a homing target is given (0 = straight shots).
@export var homing_turn_rate: float = 0.0
@export var fire_sound_preset: StringName = &"shoot"
## Node credited with kills (defaults to owner).
@export var damage_source: Node

## Multipliers modified by upgrades / perks.
var fire_rate_multiplier: float = 1.0
var damage_multiplier: float = 1.0
var extra_projectiles: int = 0

var _cooldown_remaining: float = 0.0


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)


func is_ready_to_fire() -> bool:
	return _cooldown_remaining <= 0.0 and projectile_scene != null


func try_fire(direction: Vector2, homing_target: Node2D = null) -> bool:
	if not is_ready_to_fire() or direction == Vector2.ZERO:
		return false
	_cooldown_remaining = 1.0 / maxf(0.01, shots_per_second * fire_rate_multiplier)
	var total_projectiles: int = maxi(1, projectiles_per_shot + extra_projectiles)
	var base_angle: float = direction.angle()
	var spread_radians: float = deg_to_rad(spread_degrees)
	for projectile_index: int in total_projectiles:
		var angle_offset: float = 0.0
		if total_projectiles > 1:
			angle_offset = lerpf(-spread_radians, spread_radians, float(projectile_index) / (total_projectiles - 1))
		var projectile: Projectile = Pools.spawn(projectile_scene, Global.get_world_root(), global_position) as Projectile
		if projectile_speed_override > 0.0:
			projectile.speed = projectile_speed_override
		projectile.launch(Vector2.from_angle(base_angle + angle_offset), hit_mask, damage * damage_multiplier, damage_source if damage_source != null else owner)
		projectile.homing_target = homing_target
		if homing_target != null and homing_turn_rate > 0.0:
			projectile.homing_turn_rate = homing_turn_rate
	Audio.play_sfx(SfxSynth.get_preset(fire_sound_preset), 0.1, -10.0)
	fired.emit(total_projectiles)
	return true


func reset_cooldown() -> void:
	_cooldown_remaining = 0.0
