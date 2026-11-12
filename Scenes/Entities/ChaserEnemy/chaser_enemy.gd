## Reusable pooled melee enemy that chases the nearest player and deals
## contact damage. Drops loot, shows damage numbers and scales with waves.
## State: Alive { Chasing } -> Dead, Dead -> Alive on respawn (pool reuse).
##
## Dependencies: Types, Events, Profile, Pools, Global autoloads, components
class_name ChaserEnemy
extends CharacterBody2D

@export var base_max_health: float = 30.0
@export var base_move_speed: float = 120.0
@export var score_value: int = 10
@export var show_damage_numbers: bool = true

@onready var velocity_component: VelocityComponent = %VelocityComponent
@onready var health_component: HealthComponent = %HealthComponent
@onready var hit_flash_component: HitFlashComponent = %HitFlashComponent
@onready var loot_drop_component: LootDropComponent = %LootDropComponent
@onready var state_chart: StateChart = %StateChart
@onready var _visual: Node2D = %Visual

var _target: Node2D = null
var _retarget_remaining: float = 0.0
var _has_been_used: bool = false


func _ready() -> void:
	add_to_group(Types.GROUP_ENEMY)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(func() -> void: state_chart.send_event(Types.EVENT_DIED))
	_reset_stats(1.0, 1.0)


## Called by WaveSpawner after spawning.
func apply_wave_modifiers(health_multiplier: float, speed_multiplier: float) -> void:
	_reset_stats(health_multiplier, speed_multiplier)


func _reset_stats(health_multiplier: float, speed_multiplier: float) -> void:
	health_component.revive(base_max_health * health_multiplier)
	velocity_component.reset()
	velocity_component.max_speed = base_move_speed * speed_multiplier


func _on_pool_spawned() -> void:
	_reset_stats(1.0, 1.0)
	hit_flash_component.reset()
	_visual.scale = Vector2.ONE
	collision_layer = Types.LAYER_ENEMY
	if _has_been_used:
		state_chart.send_event(Types.EVENT_RESPAWN)
	_has_been_used = true

# ============================================
# STATE CHART CALLBACKS
# ============================================

func _on_chasing_state_physics_processing(delta: float) -> void:
	_retarget_remaining -= delta
	if _retarget_remaining <= 0.0 or not is_instance_valid(_target):
		_retarget_remaining = 0.5
		_target = Global.find_nearest_in_group(Types.GROUP_PLAYER, global_position)
	if is_instance_valid(_target) and _target.is_inside_tree():
		velocity_component.accelerate_toward(_target.global_position, global_position, delta)
		_visual.scale.x = -1.0 if _target.global_position.x < global_position.x else 1.0
	else:
		velocity_component.decelerate(delta)
	velocity_component.move(self, delta)


func _on_dead_state_entered() -> void:
	collision_layer = 0
	Profile.stats.increment(Types.STAT_ENEMIES_DEFEATED)
	Events.enemy_defeated.emit(self)
	loot_drop_component.drop(global_position)
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "scale", Vector2.ZERO, 0.15)
	tween.tween_callback(Pools.despawn.bind(self))


func _on_damaged(damage_info: DamageInfo) -> void:
	velocity_component.apply_knockback(damage_info.knockback)
	if show_damage_numbers:
		var number_color: Color = Palette.WARNING if damage_info.is_critical else Palette.TEXT
		FloatingText.spawn(str(roundi(damage_info.amount)), global_position + Vector2(0, -30), number_color, 40 if damage_info.is_critical else 30)
