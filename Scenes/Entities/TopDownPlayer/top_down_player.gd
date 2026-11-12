## Reusable top-down player: joystick/keyboard movement, auto-aim shooting,
## pickups magnet, health with i-frames and stat-driven upgrades.
## State: Alive { Idle <-> Moving } -> Dead (godot_state_charts).
##
## Dependencies: Types, Events autoloads, Velocity/Health/Hurtbox/Collector/
##               Targeting/Shooter/Stats/HitFlash components
class_name TopDownPlayer
extends CharacterBody2D

signal died
signal health_changed(current_health: float, max_health: float)

@export var auto_fire: bool = true

@onready var velocity_component: VelocityComponent = %VelocityComponent
@onready var health_component: HealthComponent = %HealthComponent
@onready var targeting_component: TargetingComponent = %TargetingComponent
@onready var shooter_component: ShooterComponent = %ShooterComponent
@onready var collector_component: CollectorComponent = %CollectorComponent
@onready var stats_component: StatsComponent = %StatsComponent
@onready var state_chart: StateChart = %StateChart
@onready var _visual: Node2D = %Visual

func _ready() -> void:
	add_to_group(Types.GROUP_PLAYER)
	_capture_base_stats()
	stats_component.stat_changed.connect(func(_stat_id: StringName, _value: float) -> void: apply_stats())
	health_component.health_changed.connect(func(current_health: float, max_health: float) -> void: health_changed.emit(current_health, max_health))
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(func() -> void: state_chart.send_event(Types.EVENT_DIED))
	apply_stats()


## Re-reads every stat from the StatsComponent (called automatically when modifiers change).
func apply_stats() -> void:
	health_component.set_max_health(stats_component.get_stat(Types.ENTITY_STAT_MAX_HEALTH))
	velocity_component.max_speed = stats_component.get_stat(Types.ENTITY_STAT_MOVE_SPEED)
	shooter_component.damage = stats_component.get_stat(Types.ENTITY_STAT_DAMAGE)
	shooter_component.shots_per_second = stats_component.get_stat(Types.ENTITY_STAT_FIRE_RATE)
	shooter_component.extra_projectiles = int(stats_component.get_stat(Types.ENTITY_STAT_PROJECTILE_COUNT))
	collector_component.magnet_radius = stats_component.get_stat(Types.ENTITY_STAT_PICKUP_RADIUS)


## Seeds StatsComponent base values from the components' inspector values,
## unless the scene already defines them in StatsComponent.base_stats.
func _capture_base_stats() -> void:
	var component_values: Dictionary[StringName, float] = {
		Types.ENTITY_STAT_MAX_HEALTH: health_component.max_health,
		Types.ENTITY_STAT_MOVE_SPEED: velocity_component.max_speed,
		Types.ENTITY_STAT_DAMAGE: shooter_component.damage,
		Types.ENTITY_STAT_FIRE_RATE: shooter_component.shots_per_second,
		Types.ENTITY_STAT_PROJECTILE_COUNT: 0.0,
		Types.ENTITY_STAT_PICKUP_RADIUS: collector_component.magnet_radius,
	}
	for stat_id: StringName in component_values:
		if not stats_component.base_stats.has(stat_id):
			stats_component.base_stats[stat_id] = component_values[stat_id]


func is_alive() -> bool:
	return not health_component.is_dead


func _read_move_input() -> Vector2:
	return Input.get_vector(Types.ACTION_MOVE_LEFT, Types.ACTION_MOVE_RIGHT, Types.ACTION_MOVE_UP, Types.ACTION_MOVE_DOWN)

# ============================================
# STATE CHART CALLBACKS
# ============================================

func _on_alive_state_physics_processing(delta: float) -> void:
	var move_input: Vector2 = _read_move_input()
	velocity_component.accelerate_in_direction(move_input, delta)
	velocity_component.move(self, delta)
	if move_input.x != 0.0:
		_visual.scale.x = signf(move_input.x)
	if auto_fire and targeting_component.has_target():
		var target: Node2D = targeting_component.current_target
		shooter_component.try_fire(global_position.direction_to(target.global_position))


func _on_idle_state_physics_processing(_delta: float) -> void:
	if _read_move_input() != Vector2.ZERO:
		state_chart.send_event(Types.EVENT_MOVE_STARTED)


func _on_moving_state_physics_processing(_delta: float) -> void:
	if _read_move_input() == Vector2.ZERO:
		state_chart.send_event(Types.EVENT_MOVE_STOPPED)


func _on_moving_state_entered() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "rotation", 0.12 * _visual.scale.x, 0.1)


func _on_idle_state_entered() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "rotation", 0.0, 0.1)


func _on_dead_state_entered() -> void:
	velocity_component.reset()
	collision_layer = 0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_visual, "scale", Vector2.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_visual, "rotation", TAU, 0.4)
	Events.camera_shake_requested.emit(0.8)
	Platform.vibrate(Types.HapticStrength.HEAVY)
	died.emit()


func _on_damaged(damage_info: DamageInfo) -> void:
	velocity_component.apply_knockback(damage_info.knockback)
	Events.camera_shake_requested.emit(0.35)
	Platform.vibrate(Types.HapticStrength.MEDIUM)
