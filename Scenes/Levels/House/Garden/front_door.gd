## The front door: the objective of every attacker. When it breaks, the
## shift is lost. Reinforcement upgrades raise its health; it shows damage
## with a health bar above the frame and shakes when hit.
##
## Dependencies: HealthComponent, PlaceholderMesh3D, Palette, Audio autoload, SfxSynth
class_name FrontDoor
extends Node3D

signal broken

const BAR_WIDTH: float = 1.2
const BAR_HEIGHT: float = 0.08

@export var base_max_health: float = 600.0

var _shake_tween: Tween

@onready var health_component: HealthComponent = %HealthComponent
@onready var _panel: Node3D = %Panel
@onready var _bar_fill: MeshInstance3D = %BarFill
@onready var _bar_back: MeshInstance3D = %BarBack


func _ready() -> void:
	_bar_back.material_override = PlaceholderMesh3D.get_shared_material(Palette.BACKGROUND, 0.0, true)
	health_component.damaged.connect(_on_damaged)
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(func() -> void: broken.emit())
	set_max_health(base_max_health)


func is_alive() -> bool:
	return not health_component.is_dead


## Sets a new maximum (reinforcement upgrades) and repairs the door fully.
func set_max_health(new_max_health: float) -> void:
	health_component.revive(new_max_health)


func get_health_ratio() -> float:
	return health_component.get_health_ratio()


func _on_health_changed(current_health: float, max_health: float) -> void:
	var ratio: float = current_health / maxf(1.0, max_health)
	_bar_fill.scale.x = maxf(0.001, ratio)
	_bar_fill.position.x = -BAR_WIDTH * 0.5 * (1.0 - ratio)
	_bar_fill.material_override = PlaceholderMesh3D.get_shared_material(Palette.SUCCESS if ratio > 0.5 else (Palette.WARNING if ratio > 0.25 else Palette.DANGER), 0.6, true)


func _on_damaged(_damage_info: DamageInfo) -> void:
	if _shake_tween != null:
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.tween_property(_panel, "rotation:y", deg_to_rad(2.5), 0.04)
	_shake_tween.tween_property(_panel, "rotation:y", 0.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
