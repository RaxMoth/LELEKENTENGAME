## Tower-defense turret: aims at the enemy furthest along the path and fires
## homing projectiles. Upgradeable up to max_level.
##
## Dependencies: TargetingComponent, ShooterComponent
class_name TDTower
extends Node2D

@export var max_level: int = 3
@export var damage_growth: float = 1.6
@export var fire_rate_growth: float = 1.25
@export var range_growth: float = 30.0

var level: int = 1

@onready var targeting_component: TargetingComponent = %TargetingComponent
@onready var shooter_component: ShooterComponent = %ShooterComponent
@onready var _turret: Node2D = %Turret
@onready var _base: PlaceholderShape = %Base
@onready var _range_indicator: PlaceholderShape = %RangeIndicator


func _ready() -> void:
	_show_range()
	TweenFX.bounce_in(self)


func _physics_process(_delta: float) -> void:
	if not targeting_component.has_target():
		return
	var target: Node2D = targeting_component.current_target
	var aim_direction: Vector2 = global_position.direction_to(target.global_position)
	_turret.rotation = aim_direction.angle()
	shooter_component.try_fire(aim_direction, target)


func can_upgrade() -> bool:
	return level < max_level


func upgrade() -> void:
	if not can_upgrade():
		return
	level += 1
	shooter_component.damage *= damage_growth
	shooter_component.shots_per_second *= fire_rate_growth
	targeting_component.detection_radius += range_growth
	_base.color = _base.color.lightened(0.2)
	_turret.scale *= 1.15
	TweenFX.punch_scale(self, 1.25)
	_show_range()


func _show_range() -> void:
	_range_indicator.size = Vector2.ONE * targeting_component.detection_radius * 2.0
	_range_indicator.modulate.a = 1.0
	var tween: Tween = _range_indicator.create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(_range_indicator, "modulate:a", 0.0, 0.4)
