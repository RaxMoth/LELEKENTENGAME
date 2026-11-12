## Tower-defense creep: follows the level path, can be shot, escapes at the end.
## Pooled; WaveSpawner assigns the path and scales its health per wave.
##
## Dependencies: Pools, Profile, Events, Types autoloads, components
class_name TDEnemy
extends Node2D

signal escaped(enemy: TDEnemy)
signal killed(enemy: TDEnemy)

@export var base_max_health: float = 40.0
@export var base_speed: float = 90.0
@export var gold_reward: int = 8

@onready var health_component: HealthComponent = %HealthComponent
@onready var path_mover: PathMoverComponent = %PathMoverComponent
@onready var hit_flash_component: HitFlashComponent = %HitFlashComponent
@onready var _visual: Node2D = %Visual


func _ready() -> void:
	add_to_group(Types.GROUP_ENEMY)
	health_component.died.connect(_on_died)
	path_mover.reached_end.connect(_on_reached_end)


func apply_wave_modifiers(health_multiplier: float, speed_multiplier: float) -> void:
	health_component.revive(base_max_health * health_multiplier)
	path_mover.speed = base_speed * speed_multiplier


func _on_pool_spawned() -> void:
	health_component.revive(base_max_health)
	path_mover.speed = base_speed
	hit_flash_component.reset()
	_visual.scale = Vector2.ONE


func _on_died() -> void:
	Profile.stats.increment(Types.STAT_ENEMIES_DEFEATED)
	Events.enemy_defeated.emit(self)
	killed.emit(self)
	FloatingText.spawn("+%d" % gold_reward, global_position, Palette.GOLD, 28)
	Pools.despawn(self)


func _on_reached_end() -> void:
	escaped.emit(self)
	Pools.despawn(self)
