## Pooled, moving hitbox. Spawn through ShooterComponent or Pools.spawn and call
## launch(). Despawns on lifetime end, wall hit, or after its pierce count.
##
## Dependencies: HitboxComponent, Pools, Types autoloads
class_name Projectile
extends HitboxComponent

@export var speed: float = 700.0
@export var lifetime_seconds: float = 2.0
## How many extra enemies it passes through (0 = stops at the first).
@export var pierce_count: int = 0
## Turn rate (radians/s) toward the homing target; 0 disables homing.
@export var homing_turn_rate: float = 0.0
@export var rotate_to_direction: bool = true
@export var hit_sound_preset: StringName = &"hit"

var direction: Vector2 = Vector2.RIGHT
var homing_target: Node2D = null

var _time_alive: float = 0.0
var _pierce_remaining: int = 0


func _ready() -> void:
	super()
	body_entered.connect(_on_body_entered)


## Configures and fires the projectile. Collision mask decides what it can hit.
func launch(launch_direction: Vector2, hit_mask: int, projectile_damage: float, source: Node = null) -> void:
	direction = launch_direction.normalized()
	collision_mask = hit_mask | Types.LAYER_WORLD
	damage = projectile_damage
	damage_source = source
	_pierce_remaining = pierce_count
	_time_alive = 0.0
	if rotate_to_direction:
		rotation = direction.angle()


func _physics_process(delta: float) -> void:
	super(delta)
	_time_alive += delta
	if _time_alive >= lifetime_seconds:
		Pools.despawn(self)
		return
	if homing_turn_rate > 0.0 and is_instance_valid(homing_target) and homing_target.is_inside_tree():
		var desired_angle: float = global_position.direction_to(homing_target.global_position).angle()
		direction = Vector2.from_angle(rotate_toward(direction.angle(), desired_angle, homing_turn_rate * delta))
		if rotate_to_direction:
			rotation = direction.angle()
	global_position += direction * speed * delta


func deal_hit(hurtbox: HurtboxComponent) -> void:
	if Pools.is_in_pool(self) or not hurtbox.can_be_hit():
		return
	super(hurtbox)
	Audio.play_sfx(SfxSynth.get_preset(hit_sound_preset), 0.15, -8.0)
	_pierce_remaining -= 1
	if _pierce_remaining < 0:
		Pools.despawn(self)


func _on_body_entered(_body: Node2D) -> void:
	Pools.despawn(self)


func _on_pool_spawned() -> void:
	_time_alive = 0.0
	homing_target = null


func _on_pool_despawned() -> void:
	_overlap_cooldowns.clear()
